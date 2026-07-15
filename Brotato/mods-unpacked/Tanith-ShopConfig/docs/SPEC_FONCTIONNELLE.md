# ShopConfig — Spec fonctionnelle

Vue d'ensemble consolidée de **tout ce que fait le mod**, avec pointeurs vers le code.
Sert d'index de reprise.

- **Mod** : `Tanith-ShopConfig`, version manifest **1.0.0**, Godot 3.7 via ModLoader.
- **Pitch** : un écran de **configuration du pool du magasin, par joueur**, inséré **entre la
  sélection du personnage et celle de l'arme**. Chaque joueur y **exclut** des objets/armes pour
  qu'ils n'apparaissent **jamais dans SA boutique** de la run.
- **Intégration** : 3 script extensions ModLoader + 2 scènes construites **100 % en code** (pas de
  `.tscn`). Libellés **bilingues FR/EN** (helper `_t(en, fr)`).

---

## 1. Le flux — où le mod s'insère

Vanilla : sélection perso → sélection arme. Avec le mod : sélection perso → **écran ShopConfig** →
sélection arme.

- **Insertion** (`extensions/ui/menus/run/character_selection.gd`) : surcharge
  `_on_selections_completed()`. Reproduit le corps vanilla (ajout des persos) puis fait un **swap
  manuel de `current_scene`** vers `scenes/shop_config_screen.gd` (au lieu de basculer vers l'arme).
  ⚠️ Ce corps est **copié du vanilla** (`character_selection.gd:211-223`) — à revérifier si une
  MAJ de Brotato modifie cette fonction.
- **Activation optionnelle** : l'écran ne s'insère que si l'option « Config du magasin » est cochée
  (défaut **vrai**). Sinon, on appelle le `._on_selections_completed()` vanilla → flux normal.

---

## 2. L'option d'activation (case à cocher)

`extensions/ui/menus/run/run_options_panel.gd`.

- Ajoute un `CheckButton` **« Config du magasin / Shop Config »** dans le panneau d'options de la
  run (écran de sélection perso), tout en bas du **VBox extérieur** (pas dans le VBox intérieur des
  DLC, sinon chevauchement).
- Valeur persistée dans `ProgressData.settings["tanith_shopconfig_enabled"]`, **défaut vrai**.
- ⚠️ **Idempotence** (`init()` peut être appelée plusieurs fois sur le même panneau — voir §7) :
  on ne pose la case que si elle n'existe pas déjà. Corrige le bug « double case » quand Bomberman
  est aussi actif.

---

## 3. L'écran de configuration

`scenes/shop_config_screen.gd` (`Control` plein écran, autonome, construit en code).

- **Split horizontal** : un `player_shop_config_panel` **par joueur** (calqué sur
  `weapon_selection.tscn`).
- **Sortie** via `change_scene` : vers la **sélection d'arme**, ou directement vers la **sélection
  de difficulté** si aucun joueur n'a de slot d'arme.
- **Coop** : navigation manette **par joueur** via un `FocusEmulator` natif **par panneau**
  (`_setup_coop_focus`), chacun borné à son panneau (+ bouton Retour pour le joueur 0). En **solo**,
  focus Godot classique et `ui_cancel` = retour.

### Le panneau joueur — `scenes/player_shop_config_panel.gd` (`PanelContainer`)

Un quadrant par joueur :

- **Grille d'icônes** objets/armes, **filtrée par compatibilité du perso** du slot (cf. §5).
- **Onglets Objets / Armes** : de vrais `Button` (pas le bandeau natif du `TabContainer`).
- **Filtres tier / classe** : listes déroulantes **« maison »** (pas des `OptionButton` — voir §7),
  rangées dans un overlay superposé, navigation manette confinée par voisins de focus.
- **Actions rapides** (tout exclure / tout garder / réinitialiser…) et **garde-fou** : on empêche
  d'exclure la **totalité** (« garde au moins quelques éléments » — `store.has_any_available`).
- **Infobulle** : réutilise le **vrai `item_popup.tscn`** du magasin.
- **Bouton Prêt** par joueur.

---

## 4. Le filtrage du pool du magasin

`extensions/singletons/item_service.gd` + logique pure `content/logic/pool_filter.gd`.

Cœur du mod : retirer les IDs exclus **uniquement** de la boutique du joueur courant.

- **Contexte de pioche** : `get_player_shop_items()` pose un drapeau
  (`store.begin_shop_draw(player_index)` / `end_shop_draw()`). Le filtrage n'agit **que** pendant
  ce contexte → ne touche **jamais** les autres tirages (boîtes à objets) ni le **ban natif**
  (`RunData.players_data[i].banned_items`).
- **Retrait** : `get_pool()` consulte le store et retire les `my_id` exclus (`PoolFilter.filter`,
  garde les candidats dont `my_id` n'est pas clé de `{id: true}`).
- ⚠️ **Garde-fou anti-fuite** (`_get_rand_item_for_wave`) : si le joueur restreint la boutique à
  **un seul élément**, le fallback vanilla (`_tiers_data[tier][type]` en **accès direct, non
  filtré**) peut réintroduire un élément **exclu**. On enveloppe donc le tirage : si l'élément rendu
  est exclu, on le **remplace** par un élément autorisé (même type d'abord, sinon l'autre ; doublon
  toléré — c'est le but d'une boutique mono-élément).

---

## 5. Compatibilité perso (ce qui est affichable/exclu)

Pour masquer un élément incompatible dans la grille, on **reproduit les tests du jeu**
(`_collect_compatible()` dans le panneau) :

- effets joueur (`no_melee_weapons_hash`, `no_ranged_weapons_hash`, `remove_shop_items_hash`…) ;
- bans de classe (`banned_items` + `banned_item_groups` via `ItemService.item_groups`) ;
- objets/armes de départ, `can_be_looted`, slots d'arme.

---

## 6. Mémoire de session & carry-over

`singletons/shop_config_store.gd` (instance `Reference` unique, tenue par l'extension `ItemService`,
accès via `ItemService.get_shopconfig_store()`).

- **Persistance run-à-run SANS disque** : les exclusions restent en mémoire **toute la session**
  (nettoyage auto à la fermeture). L'écran **ne reset PLUS** à l'ouverture : chaque panneau est
  **pré-chargé** depuis `store.get_excluded(player_index)` (clé = slot joueur).
- **Carry-over** (logique pure `pool_filter.gd`) : la grille étant filtrée par perso, les ids
  mémorisés **non affichables** par le perso courant sont **gelés** (`carried` = `saved_ids` absents
  des `owned_ids`) puis **re-fusionnés à l'export** — pour ne pas les perdre quand le slot rejoue
  un perso différent.
- Le bouton **« Tout réinitialiser »** vide aussi le carry-over (= oublier la config du slot).
- Le store porte **aussi** le contexte de pioche (`_shop_draw_active`, `_shop_draw_player`).

---

## 7. Décisions techniques notables

- **Pas d'`OptionButton` pour les filtres** : un `OptionButton` ouvre un `PopupMenu` natif
  **globalement modal** qui fige l'autre joueur en coop (capte n'importe quel device). Remplacés par
  une liste in-panel de vrais `Button` (territoire du `FocusEmulator`). On raisonne toujours par
  **INDEX** (`_tier_index`/`_class_index`, 0 = « tout »).
- **Scènes 100 % en code** : pas de `.tscn`, tout est construit à la main (robustesse face aux
  corruptions d'import de `.tres`).
- ⚠️ **Collision avec Bomberman** (les deux étendent `character_selection.gd`) :
  - un `const` homonyme entre extensions casse le mod chargé en second (leçon partagée) ;
  - **l'empilement fait tourner le `_ready()` vanilla DEUX fois** → tout ajout additif doit être
    **idempotent** (cause du bug « double case », corrigé §2).

---

## 8. Architecture — logique pure (testable headless)

Le test-runner (`./run-tests.sh`) ne couvre que la **logique 100 % pure** ; tout ce qui touche aux
autoloads ModLoader se vérifie **en jeu**.

| Module | Responsabilité |
|---|---|
| `content/logic/pool_filter.gd` | `filter` (retrait par id), `owned_ids`/`carried` (carry-over) |
| `singletons/shop_config_store.gd` | exclusions par joueur + contexte de pioche |
| `content/logic/mod_log.gd` | logger désactivable (`debug_log`, défaut `false`) |

Extensions ModLoader (`mod_main.gd`) : `run_options_panel.gd` (case), `item_service.gd` (filtrage
pool), `character_selection.gd` (insertion de l'écran).

---

## Statut

- **Workshop** : item `3748276960`, testé OK **solo + coop**. Déploiement Steam Workshop.
- **Fix récent** (branche `fix/shopconfig-double-checkbox`, off-master) : suppression de la case
  « Config du magasin » affichée en double quand Bomberman est aussi actif (idempotence de `init()`).
