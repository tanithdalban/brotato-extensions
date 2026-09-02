# Spec — Retour au magasin après une défaite (mod `Tanith-WaveRollback`)

- **Date** : 2026-09-02
- **Statut** : Design validé, en attente de revue finale
- **Type** : Mod Brotato (Godot 3.7, godot-mod-loader branche Godot 3 — **script extensions uniquement, pas de hooks**)
- **Dossier** : `Brotato/mods-unpacked/Tanith-WaveRollback/`
- **Distribution** : Steam Workshop (nouvel item à créer)

## 1. Objectif

Quand on perd une vague, Brotato ne propose que deux issues : **réessayer la vague** (avec exactement le même équipement) ou **abandonner la run**. Si l'erreur ne vient pas de la vague mais des **achats du magasin qui l'a précédée**, réessayer ne sert à rien : on rejoue le même mauvais build, et il faut recommencer toute la partie.

Le mod ajoute une **troisième issue** : revenir au magasin d'avant la vague ratée, avec l'inventaire et l'or tels qu'ils étaient **avant les achats**, pour tenter un autre équipement.

## 2. Modèle conceptuel

```
vague 3 gagnée  ──►  magasin  ──►  vague 4 perdue
                     ▲   │
                     │   └─ achats (mauvais choix)
                     └────────── retour proposé ici
```

Un **unique** point de restauration, écrasé à chaque passage en magasin : celui du **dernier magasin visité**. Pas d'historique, pas de sélecteur de vague.

Le retour restaure **l'état de run** (inventaire, or, stats, niveau, effets), **pas** la vitrine du magasin : celle-ci est **régénérée** normalement. Décision assumée : le joueur peut de toute façon rerolle, figer la vitrine n'apporterait rien et ne ferait qu'ajouter du code.

## 3. Périmètre

**Dans le périmètre (v1) :**

- Snapshot automatique de l'état de run à chaque entrée en magasin.
- Bouton « Retour au magasin » sur l'écran de défaite, à côté de « Réessayer la vague ».
- Restauration complète de l'état des **quatre** joueurs (solo et coop local).
- Incrément du compteur `RunData.retries` vanilla à chaque retour.
- Libellé bilingue FR/EN.

**Hors périmètre (v1) :**

- Historique multi-vagues (remonter plus d'un magasin en arrière).
- Restauration de la vitrine du magasin à l'identique.
- Limite du nombre de retours, compteur dédié, affichage sur l'écran de fin.
- Persistance sur disque (le snapshot vit en mémoire, il meurt avec la session).
- Annulation des acquis hors run-state (défis validés, déblocages écrits dans `ProgressData` pendant la vague ratée).

## 4. Flux utilisateur

1. Le joueur gagne la vague N-1, ramasse ses caisses, choisit sa montée de niveau.
2. Le magasin s'ouvre → **snapshot pris silencieusement**, aucun retour visuel.
3. Le joueur achète, valide (GO), joue la vague N et **meurt**.
4. L'écran de défaite affiche désormais trois choix :
   - **Oui** → réessayer la vague N avec le même équipement (vanilla).
   - **Retour au magasin** → *(nouveau)*.
   - **Non** → fin de run (vanilla).
5. Sur « Retour au magasin » : l'état d'avant achats est restauré, `retries` est incrémenté, et le magasin se rouvre avec une **nouvelle vitrine**.
6. Le joueur rachète autrement, valide, rejoue la vague N. Le magasin ayant été revisité, un **nouveau snapshot** a été pris : s'il remeurt, il peut recommencer indéfiniment.

**Quand le bouton n'apparaît pas :** vague 1 (aucun magasin visité), ou snapshot invalide (§7.3). Le réglage vanilla « réessayer la vague » désactivé masque tout le bloc, notre bouton compris — voir §6.

## 5. Architecture

Trois fichiers d'extension, un store, une logique pure.

```
Tanith-WaveRollback/
├── mod_main.gd                                  installe les extensions, config du log
├── manifest.json
├── extensions/
│   ├── ui/menus/shop/base_shop.gd               capture le snapshot
│   └── ui/menus/ingame/retry_wave.gd            injecte le bouton, exécute le retour
├── content/logic/
│   ├── mod_log.gd                               logger désactivable (calqué sur ShopConfig)
│   └── rollback_rules.gd                        logique PURE : garde de validité
├── singletons/
│   └── rollback_store.gd                        le store (Reference, méta Engine)
└── test/run_tests.gd                            runner dédié
```

### 5.1 Le store

Godot 3 n'a pas de `static var`, et cette version de ModLoader n'expose **pas** `add_autoload` (`addons/mod_loader/api/mod.gd` ne fournit que `install_script_extension`, `append_node_in_scene`, `add_translation`, `register_global_classes_from_array`). Le store est donc une instance `Reference` rangée en **méta globale sur `Engine`**, exactement l'idiome déjà employé par `Tanith-ShopConfig/content/logic/mod_log.gd`.

```gdscript
# singletons/rollback_store.gd — extends Reference
const _META := "tanith_waverollback_store"

static func get_instance()          # crée à la volée, survit aux changements de scène
func store(state: Dictionary)       # écrase le snapshot précédent
func peek() -> Dictionary
func has_snapshot() -> bool
func clear() -> void
```

**Pourquoi pas le patron ShopConfig** (store en `var` d'une extension d'autoload) : les deux consommateurs (`base_shop`, `retry_wave`) sont des **scènes**, pas des singletons. Greffer sur un autoload obligerait à étendre un troisième script vanilla uniquement pour porter une variable.

**Pourquoi pas `singletons/run_data.gd`**, pourtant l'hôte sémantiquement naturel : `Tanith-Bomberman/extensions/singletons/run_data.gd:16` y déclare un `const ModLog` **non préfixé**. Deux extensions du même script vanilla partagent un espace de noms ; un homonyme provoque une Parse Error qui **détruit entièrement** l'extension de l'autre mod, sans que les tests le voient. Voir §10.

### 5.2 Point d'accroche 1 — la capture

Extension de `ui/menus/shop/base_shop.gd`, surcharge de `_ready()` :

```gdscript
func _ready() -> void:
    ._ready()
    WaveRollbackStore.get_instance().store(_waverollback_snapshot())
```

`shop.gd` (solo) et `coop_shop.gd` (coop) héritent tous deux de `BaseShop` — un seul point d'accroche couvre les deux modes.

**Le moment est critique.** La capture doit être **en fin de `_ready()`**, pas plus tôt :

| Instant | Pourquoi c'est faux |
|---|---|
| `RunData.on_wave_end()` (`main.gd:1138`) | trop tôt : les montées de niveau et les caisses de la vague gagnée ne sont pas encore résolues (`main.gd:1155-1170`) → le retour les ferait **perdre**, sans possibilité de les rejouer |
| début de `base_shop._ready()` | trop tôt : les effets d'entrée de magasin (`base_shop.gd:53-82` — destruction d'armes, upgrade aléatoire de l'Enclume) ne sont pas encore appliqués. Ils sont protégés par `RunData.shop_effects_checked`, qui **fait partie de `get_state()`** ; capturé à `false`, il serait restauré à `false` et l'Enclume offrirait **une arme gratuite à chaque retour** |
| au clic sur GO | trop tard : les achats sont déjà faits, c'est précisément ce qu'on veut annuler |

La capture est **idempotente** (elle écrase), ce qui la rend insensible au double `_ready()` déjà rencontré entre extensions ModLoader.

### 5.3 Point d'accroche 2 — le bouton et le retour

Extension de `ui/menus/ingame/retry_wave.gd`. Surcharge de `_ready()` (injection idempotente du bouton) et de `show()` (mise à jour de la visibilité et du libellé).

Le retour lui-même :

```gdscript
RunData.resume_from_state(_waverollback_restored_state())
RunData.retries += 1
get_tree().change_scene(RunData.get_shop_scene_path())
```

On ne met **pas** `RunData.resumed_from_state_in_shop = true` : c'est ce drapeau qui ferait relire la vitrine sauvegardée (`base_shop.gd:105-113`). En le laissant à `false`, le magasin repasse par son chemin normal et **régénère** ses objets.

## 6. UI

Structure vanilla de `ui/menus/ingame/retry_wave.tscn` :

```
Menu (VBox)
├── KilledByContainer
├── Retry_WaveContainer          ← masqué si ProgressData.settings.retry_wave = false
│   ├── Label            "RETRY_WAVE_QUESTION"
│   ├── ConfirmButton    "MENU_YES"
│   ├── CancelButton     "MENU_NO"          → fin de run
│   ├── ► RollbackButton  (injecté ici)
│   └── Label_number_retry "RETRY_WAVE_NUMBER"
└── OkButton             "OK_BUTTON"        ← visible si retry_wave = false
```

Le bouton est inséré **dans `Retry_WaveContainer`, après `CancelButton`**, avec le script `my_menu_button.gd` des autres boutons pour hériter du style.

**Conséquence assumée : le bouton suit le réglage vanilla `retry_wave`.** Si le joueur a désactivé le réessai, il veut mourir au premier échec ; le mod élargit l'horizon du retry, il ne le contourne pas. Aucun bouton n'est alors affiché.

**Libellé** : bilingue via un helper `_t(en, fr)` local, comme ShopConfig. On ne touche à **aucune** clé de traduction vanilla — sinon on écraserait la localisation officielle dans toutes les langues qu'on n'assure pas.

- FR : `Retour au magasin (avant vague N)`
- EN : `Back to shop (before wave N)`

où `N = RunData.current_wave`, c'est-à-dire la vague que le joueur vient de perdre.

**Écarté** : renommer les boutons vanilla en « Réessayer » / « Abandonner » pour homogénéiser les trois choix — meilleure lecture, mais casse la localisation officielle.

## 7. Détails techniques critiques

### 7.1 Détacher réellement l'état des objets vivants

`PlayerRunData.duplicate()` (`player_run_data.gd:49`) copie `weapons` et `items` **en surface** : les instances `WeaponData`/`ItemData` restent **partagées** avec la partie en cours. Toute mutation en place pendant le magasin ou la vague fuirait dans le snapshot. Le vanilla en est conscient et compense à la main (`run_data.gd:1773` retranche `weapon.tracked_value_added_this_wave` avant de restaurer) — mais sur une fenêtre d'une seule vague, alors que la nôtre couvre **magasin + vague entière**.

`Resource.duplicate()` ne suffit pas non plus : `tracked_value` et `tracked_value_added_this_wave` (`weapon_data.gd:19-20`) sont des `var` **non exportées**, donc perdues à la copie.

**Solution retenue** — réutiliser le round-trip que le jeu emploie déjà pour sauvegarder et reprendre une partie :

- **capture** : `player_data.serialize()` → `Dictionary` totalement détaché (`progress_data_loader_v3.gd:594`) ;
- **restauration** : `PlayerRunData.new().deserialize(dict)` (`progress_data_loader_v3.gd:374`), puis `RunData.resume_from_state()` avec ces objets reconstruits.

Le snapshot est donc `RunData.get_state()` **dont la clé `players_data` est remplacée par des dictionnaires sérialisés**. Fidélité identique à celle de la fonction « reprendre la partie » du jeu.

`deserialize()` retrouve les données de base via `ItemService.get_element_safe(...)` : le contenu **moddé** (armes bombe de Bomberman, par exemple) est retrouvé sans traitement particulier, puisqu'il est enregistré dans `ItemService` au `_ready()`.

### 7.2 Cohérence de la sauvegarde disque

Après restauration, `ProgressData.saved_run_state` pointe encore sur la run morte. Ce n'est pas un problème durable : `base_shop.gd:201` réécrit l'état sauvegardé dès l'ouverture du magasin. La fenêtre d'incohérence se limite au `change_scene`, pendant lequel aucune sauvegarde ne peut être déclenchée.

### 7.3 Validité du snapshot

Le snapshot vit en mémoire toute la session. Il faut éviter d'offrir un retour vers l'état d'une **run précédente** (le joueur quitte au menu principal en pleine run, en relance une autre, meurt vague 1).

**Garde retenue** : offrir le bouton seulement si `snapshot.current_wave < RunData.current_wave`.

Elle est suffisante parce que le magasin capture à `current_wave = N-1` et que `base_shop.gd:345` incrémente au GO. Une run neuve ne peut mourir avec un snapshot périmé qu'en **vague 1** (dès la vague 2, un magasin a forcément été visité et a écrasé le snapshot) ; or en vague 1 la garde vaut `1 < 1`, donc faux.

**Écarté** : purger le store en fin de run ou à la sélection de personnage. Cela imposerait d'étendre `character_selection.gd`, où ShopConfig **et** Bomberman déclarent déjà des symboles et où Bomberman surcharge `_ready()` — ajouter un troisième `_ready()` dans cette chaîne aggraverait le bug de double appel déjà consigné. Une garde d'une ligne coûte moins qu'une extension de plus.

### 7.4 Coop

Rien de spécifique. `RunData.get_state()` couvre les quatre joueurs d'un bloc, et le `FocusEmulator` de `retry_wave.tscn` est câblé sur `player_index = 0` : le joueur 1 tranche pour la table, exactement comme pour le réessai vanilla. Le bouton injecté hérite de ce fonctionnement sans code dédié.

## 8. Ce que le retour ne défait pas

Limites connues, assumées :

- **Défis validés et déblocages** obtenus pendant la vague ratée : écrits dans `ProgressData`, hors run-state. Ils restent acquis.
- **Statistiques globales** (pas franchis, ennemis tués…) : idem.
- Le compteur `retries` monte, et s'affiche dans le score de fin et les records de difficulté (suffixe `- R3`, `utils.gd:568`). C'est **voulu** : le retour est permis mais tracé, comme le réessai vanilla.

## 9. Configuration du mod

Une seule clé, calquée sur ShopConfig :

- `debug_log` (bool, défaut `false`) — active le logger `mod_log.gd`.

Pas d'option pour désactiver le bouton : le mod n'a pas d'autre fonction, on le désabonne pour s'en passer.

## 10. Convention de nommage dans les extensions

Deux mods qui étendent le **même** script vanilla partagent un espace de noms. Un `const` homonyme provoque une Parse Error qui casse **entièrement** l'extension de l'autre mod ; une **méthode** homonyme, elle, la surcharge **silencieusement** — pire encore. Les tests ne voient rien : le runner ne charge que la logique pure, les extensions ne compilent qu'en jeu.

`base_shop.gd` est une cible très fréquentée par les mods d'objets. **Règle** : tout symbole déclaré dans `extensions/` porte le préfixe du mod.

```gdscript
const WaveRollbackModLog = preload(".../content/logic/mod_log.gd")
const WaveRollbackStore  = preload(".../singletons/rollback_store.gd")
func _waverollback_snapshot() -> Dictionary:
var _waverollback_button = null
```

*(Dette connexe, hors périmètre de ce mod : ShopConfig et Bomberman portent encore des symboles génériques — `ModLog`, `ScreenScript`, `PoolFilter`, `CHECKBOX_TEXT`, `AnimatedIcon` — exposés à une collision avec un mod tiers. À traiter séparément.)*

## 11. Tests

**Runner dédié** `test/run_tests.gd` (`./run-tests-waverollback.sh`), sur le modèle des deux mods existants. Ne couvre que la **logique 100 % pure** :

- `rollback_store.gd` — écrasement, `has_snapshot`, `clear`, isolation de l'instance en méta.
- `rollback_rules.gd` — la garde de validité (`snapshot.current_wave < current_wave`), les cas limites vague 1 et snapshot absent.

Le **détachement** (§7.1) n'est **pas** testable en headless : il repose sur `PlayerRunData.serialize()`/`deserialize()`, qui dépendent d'`ItemService`, donc d'autoloads que le runner ne peut pas charger. Il se valide en jeu (contrôle n°4).

**Validation en jeu obligatoire** (rien de ce qui suit ne se teste en headless) :

1. Vague 1 : aucun bouton.
2. Vague 2+ : le bouton apparaît, l'or et l'inventaire d'avant achats sont exacts, la vitrine est neuve.
3. **Enclume** (`item_anvil`) : faire trois retours d'affilée, vérifier qu'aucune arme gratuite n'est offerte (contrôle de `shop_effects_checked`).
4. **Valeurs suivies** : porter un objet à compteur (Bague du justicier), faire un retour, vérifier que le compteur revient à sa valeur d'avant vague et ne dérive pas.
5. Coop 2 joueurs : le joueur 1 déclenche, les deux inventaires sont restaurés.
6. Réglage vanilla « réessayer la vague » désactivé : aucun bouton.
7. Cohabitation avec ShopConfig et Bomberman actifs : **le log ModLoader ne doit contenir ni `Parse Error` ni `compile error`**.
8. Purger les logs Godot après chaque session de test (`tools/clean-godot-logs.sh`) — faux positif du CrashReporter.

## 12. Décisions écartées (et pourquoi)

| Écarté | Raison |
|---|---|
| Historique multi-vagues | UI de sélection à concevoir, et cohérence douteuse (les vagues suivantes ont été jouées avec un autre équipement). Le store est déjà écrit pour qu'une pile s'y substitue sans refonte. |
| Restaurer la vitrine à l'identique | Le reroll existe : figer la vitrine n'apporte rien. |
| Retour gratuit (sans incrémenter `retries`) | Fausserait silencieusement les records de difficulté. |
| Limite de N retours par run | Un mod installé pour ne pas rester bloqué ne doit pas bloquer. Se pose par-dessus plus tard si besoin. |
| Snapshot par liste d'ids (patron ShopConfig) | Un inventaire n'est pas une liste d'ids : réappliquer des objets n'est pas idempotent (`RunData.apply_item_effects` empile les effets) → état divergent. |
| Store greffé sur `run_data.gd` | Collision `ModLog` avec l'extension Bomberman du même script. |
| Renommer les boutons vanilla | Écraserait la localisation officielle dans toutes les langues non assurées. |
