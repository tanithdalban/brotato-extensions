# Tanith-WaveRollback — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter un troisième choix à l'écran de défaite de Brotato — « Retour au magasin » — qui restaure l'inventaire et l'or d'avant les achats du dernier magasin, pour retenter la vague avec un autre équipement.

**Architecture:** Deux extensions ModLoader. `base_shop.gd` capture l'état de run en fin de `_ready()` (après les effets d'entrée de magasin, avant le premier achat) dans un store rangé en méta sur `Engine`. `retry_wave.gd` injecte un bouton dans l'écran de défaite qui restaure cet état via `RunData.resume_from_state()`, incrémente `RunData.retries` et rouvre le magasin. Toute la logique décidable sans le jeu (garde de validité, libellé) vit dans `content/logic/rollback_rules.gd` et se teste en headless.

**Tech Stack:** GDScript (Godot 3.6/3.7), godot-mod-loader 6.3.0 (script extensions uniquement, pas de hooks), runner de tests GDScript autonome (pas de GUT).

**Spec:** `docs/superpowers/specs/2026-09-02-wave-rollback-design.md`

## Global Constraints

- **Langue** : commentaires, docs et libellés de commit en **français**. Libellés UI **bilingues FR/EN** via un helper local `_t`/`button_label` — on ne touche à **aucune** clé de traduction vanilla.
- **Préfixe obligatoire dans `extensions/`** : tout `const`, `var` ou `func` déclaré dans un fichier sous `extensions/` porte le préfixe du mod (`WaveRollback…`, `_waverollback_…`). Deux extensions du même script vanilla partagent un espace de noms : un `const` homonyme provoque une Parse Error qui casse entièrement l'extension de l'autre mod, une **méthode** homonyme la surcharge **silencieusement**. Les tests ne voient rien.
- **Aucune persistance disque** : le snapshot vit en mémoire et meurt avec la session.
- **Purger les logs Godot après chaque lancement du runner** — `tools/clean-godot-logs.sh`, appelé automatiquement par le wrapper `.sh`. Sans ça, le CrashReporter de Brotato conclut au démarrage suivant qu'un mod a planté et **désactive réellement les mods**.
- **`compatible_mod_loader_version`** : `["6.3.0"]`, comme les deux mods existants.
- **Le runner ne teste que la logique 100 % pure.** Tout ce qui touche aux autoloads (`RunData`, `ItemService`, `ProgressData`, `ModLoaderLog`) ne peut pas se charger en headless et se valide **en jeu**.
- **Commits fréquents**, un par tâche minimum, en français, préfixe `feat(waverollback):` / `test(waverollback):` / `docs(waverollback):`.

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `Brotato/mods-unpacked/Tanith-WaveRollback/manifest.json` | métadonnées ModLoader + `config_schema` (`debug_log`) |
| `…/mod_main.gd` | initialise le logger, installe les deux extensions |
| `…/content/logic/mod_log.gd` | logger désactivable (drapeau en méta `Engine`) |
| `…/content/logic/rollback_rules.gd` | **logique pure** : garde de validité, libellé bilingue |
| `…/singletons/rollback_store.gd` | le store du snapshot (`Reference` en méta `Engine`) |
| `…/extensions/ui/menus/shop/base_shop.gd` | capture le snapshot en fin de `_ready()` |
| `…/extensions/ui/menus/ingame/retry_wave.gd` | injecte le bouton, exécute le retour |
| `…/test/run_tests.gd` | runner de tests autonome |
| `run-tests-waverollback.sh` | wrapper (bit +x, code de sortie, purge des logs) |

---

### Task 1 : Squelette du mod, logger et store

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-WaveRollback/manifest.json`
- Create: `Brotato/mods-unpacked/Tanith-WaveRollback/mod_main.gd`
- Create: `Brotato/mods-unpacked/Tanith-WaveRollback/content/logic/mod_log.gd`
- Create: `Brotato/mods-unpacked/Tanith-WaveRollback/singletons/rollback_store.gd`
- Test: `Brotato/mods-unpacked/Tanith-WaveRollback/test/run_tests.gd`
- Create: `run-tests-waverollback.sh`
- Modify: `.gitignore` (ajouter le nouveau dossier de mod à la liste des dossiers suivis)

**Interfaces:**
- Consomme : rien.
- Produit :
  - `RollbackStore.get_instance() -> RollbackStore` (statique, instance unique en méta `Engine`)
  - `RollbackStore.store(state: Dictionary) -> void` (écrase)
  - `RollbackStore.peek() -> Dictionary`
  - `RollbackStore.has_snapshot() -> bool`
  - `RollbackStore.clear() -> void`
  - `ModLog.set_enabled(bool)`, `ModLog.is_enabled()`, `ModLog.info(String)`, `ModLog.error(String)`

- [ ] **Étape 1 : vérifier que `.gitignore` suivra le nouveau mod**

Le jeu décompilé n'est pas versionné ; `.gitignore` liste explicitement les dossiers de mods **suivis**. Lire le fichier :

```bash
cat .gitignore
```

Repérer les lignes qui dé-ignorent `Tanith-ShopConfig` et `Tanith-Bomberman`, et ajouter les lignes équivalentes pour `Tanith-WaveRollback` en suivant **exactement** la même forme. Vérifier ensuite :

```bash
mkdir -p Brotato/mods-unpacked/Tanith-WaveRollback && touch Brotato/mods-unpacked/Tanith-WaveRollback/.keep
git check-ignore -v Brotato/mods-unpacked/Tanith-WaveRollback/.keep ; echo "exit=$?"
```

Attendu : `exit=1` (le fichier n'est **pas** ignoré). S'il est ignoré, corriger `.gitignore` avant de continuer.

- [ ] **Étape 2 : écrire le test qui échoue (le store)**

Créer `Brotato/mods-unpacked/Tanith-WaveRollback/test/run_tests.gd` :

```gdscript
extends SceneTree
# Runner de tests autonome (GUT n'est pas embarqué dans le build Brotato).
# Lancer : Godot --path Brotato --no-window -s res://mods-unpacked/Tanith-WaveRollback/test/run_tests.gd
# Code de sortie = nombre d'échecs (0 = tout passe).
#
# NB : on ne preload PAS mod_log.gd ici — il référence le global ModLoaderLog,
# qui ne peut pas se charger dans ce harness headless. mod_log est trivial
# (Engine.meta) et se vérifie en jeu. Ici on ne teste que les unités 100 % pures.
const Store = preload("res://mods-unpacked/Tanith-WaveRollback/singletons/rollback_store.gd")

var _failures := 0
var _count := 0


func _init():
	print("=== WaveRollback tests ===")
	_test_store()
	print("=== %d tests, %d échec(s) ===" % [_count, _failures])
	quit(_failures)


func _check(cond, name):
	_count += 1
	if not cond:
		_failures += 1
		print("FAIL: ", name)
	else:
		print("ok  : ", name)


func _test_store():
	var store = Store.new()
	_check(not store.has_snapshot(), "store: vide à la création")
	_check(store.peek().empty(), "store: peek vide à la création")

	store.store({"current_wave": 3, "marqueur": "a"})
	_check(store.has_snapshot(), "store: has_snapshot après store")
	_check(store.peek().marqueur == "a", "store: peek rend ce qui a été stocké")

	# Un seul point de restauration : le second écrase le premier.
	store.store({"current_wave": 4, "marqueur": "b"})
	_check(store.peek().marqueur == "b", "store: le second snapshot écrase le premier")
	_check(int(store.peek().current_wave) == 4, "store: la vague suit l'écrasement")

	store.clear()
	_check(not store.has_snapshot(), "store: clear vide le snapshot")

	# L'instance globale (méta Engine) est unique et survit à l'appelant.
	var a = Store.get_instance()
	var b = Store.get_instance()
	_check(a == b, "store: get_instance rend toujours la même instance")
	a.store({"current_wave": 7})
	_check(int(Store.get_instance().peek().current_wave) == 7, "store: l'instance globale conserve l'état entre deux accès")
	Store.get_instance().clear()
```

- [ ] **Étape 3 : créer le wrapper de test et vérifier que le test échoue**

Créer `run-tests-waverollback.sh` :

```bash
#!/usr/bin/env bash
# Lance les tests unitaires (logique pure) du mod Tanith-WaveRollback.
#
# Utilise le Godot 3.6.2 livré dans le repo. Sous WSL/Linux, le binaire
# Windows tourne via l'interop ; il faut juste le bit exécutable (posé ici
# au besoin). Aucun Godot natif Linux 3.6.2 n'existe en téléchargement.
#
# Code de sortie = nombre d'échecs (0 = tout vert). Les erreurs moteur
# affichées APRÈS « N tests, M échec(s) » sont la fermeture des autoloads
# du jeu (DLC, cursor…) et n'affectent pas le résultat.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT="$ROOT/Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe"

if [ ! -e "$GODOT" ]; then
  echo "Godot introuvable : $GODOT" >&2
  echo "Place le dossier Godot_v3.6.2-stable_win64.exe/ à la racine du repo." >&2
  exit 127
fi
[ -x "$GODOT" ] || chmod +x "$GODOT"

# --path relatif : on se place à la racine pour que Godot trouve Brotato/.
cd "$ROOT"
status=0
"$GODOT" --path Brotato --no-window \
  -s res://mods-unpacked/Tanith-WaveRollback/test/run_tests.gd "$@" || status=$?

# Le runner vient d'écrire dans le dossier de logs du JEU. Sans cette purge,
# Brotato lit ce log au lancement suivant et croit qu'un mod l'a fait planter
# (« mods désactivés »). Voir tools/clean-godot-logs.sh pour le détail.
[ -x "$ROOT/tools/clean-godot-logs.sh" ] || chmod +x "$ROOT/tools/clean-godot-logs.sh" 2>/dev/null || true
"$ROOT/tools/clean-godot-logs.sh" || true

exit $status
```

Puis :

```bash
chmod +x run-tests-waverollback.sh && ./run-tests-waverollback.sh
```

Attendu : ÉCHEC — Godot signale que `res://mods-unpacked/Tanith-WaveRollback/singletons/rollback_store.gd` est introuvable (le `preload` ne résout pas).

- [ ] **Étape 4 : écrire le store**

Créer `Brotato/mods-unpacked/Tanith-WaveRollback/singletons/rollback_store.gd` :

```gdscript
extends Reference
# Store du point de restauration « retour au magasin ».
#
# Un SEUL snapshot, écrasé à chaque entrée en magasin : on ne remonte jamais
# plus d'un magasin en arrière.
#
# Godot 3 n'a pas de static var, et cette version de ModLoader n'expose pas
# add_autoload (addons/mod_loader/api/mod.gd). L'instance est donc rangée en
# méta globale sur Engine : elle survit aux changements de scène (les deux
# consommateurs sont des scènes, pas des singletons) et meurt avec la session,
# sans jamais toucher le disque.

const _META := "tanith_waverollback_store"
const _SELF_PATH := "res://mods-unpacked/Tanith-WaveRollback/singletons/rollback_store.gd"

var _snapshot := {}


# load() et non preload() : un preload de son propre script serait cyclique.
static func get_instance():
	if not Engine.has_meta(_META):
		Engine.set_meta(_META, load(_SELF_PATH).new())
	return Engine.get_meta(_META)


func store(state: Dictionary) -> void:
	_snapshot = state


func peek() -> Dictionary:
	return _snapshot


func has_snapshot() -> bool:
	return not _snapshot.empty()


func clear() -> void:
	_snapshot = {}
```

- [ ] **Étape 5 : vérifier que les tests passent**

```bash
./run-tests-waverollback.sh ; echo "exit=$?"
```

Attendu : `=== 9 tests, 0 échec(s) ===` puis `exit=0`. Vérifier aussi que la sortie ne contient **ni `parse error` ni `compile error`**.

- [ ] **Étape 6 : écrire le logger**

Créer `Brotato/mods-unpacked/Tanith-WaveRollback/content/logic/mod_log.gd` :

```gdscript
extends Reference
# Logger propre au mod, désactivable. Godot 3 n'a pas de static var :
# le drapeau est stocké en méta globale sur Engine.

const LOG_NAME := "Tanith-WaveRollback"
const _META := "tanith_waverollback_log_enabled"

static func set_enabled(value: bool) -> void:
	Engine.set_meta(_META, value)

static func is_enabled() -> bool:
	return Engine.has_meta(_META) and Engine.get_meta(_META)

static func info(msg: String) -> void:
	if is_enabled():
		ModLoaderLog.info(msg, LOG_NAME)

static func error(msg: String) -> void:
	ModLoaderLog.error(msg, LOG_NAME)
```

- [ ] **Étape 7 : écrire le manifest**

Créer `Brotato/mods-unpacked/Tanith-WaveRollback/manifest.json` :

```json
{
    "name": "WaveRollback",
    "namespace": "Tanith",
    "version_number": "1.0.0",
    "description": "Après une défaite, propose de revenir au magasin d'avant la vague avec l'inventaire et l'or d'avant achats.",
    "website_url": "",
    "dependencies": [],
    "extra": {
        "godot": {
            "authors": ["Tanith"],
            "tags": ["utility", "quality-of-life"],
            "optional_dependencies": [],
            "load_before": [],
            "incompatibilities": [],
            "compatible_mod_loader_version": ["6.3.0"],
            "compatible_game_version": [],
            "config_schema": {
                "type": "object",
                "properties": {
                    "debug_log": { "type": "boolean", "description": "Active les logs détaillés de WaveRollback.", "default": false }
                }
            }
        }
    }
}
```

- [ ] **Étape 8 : écrire `mod_main.gd`**

Créer `Brotato/mods-unpacked/Tanith-WaveRollback/mod_main.gd`. Les deux extensions n'existent pas encore : `_install_extensions()` est volontairement vide à ce stade et sera rempli aux tâches 3 et 4.

```gdscript
extends Node

const LOG_NAME := "Tanith-WaveRollback"
const ModLog = preload("res://mods-unpacked/Tanith-WaveRollback/content/logic/mod_log.gd")

func _init() -> void:
	_setup_logging()
	ModLog.info("init")
	_install_extensions()

func _setup_logging() -> void:
	var enabled := false
	# Config courante si l'utilisateur en a choisi une, sinon la config par défaut
	# (générée depuis le config_schema). On évite get_current_config avec un nom vide.
	var conf = null
	if ModLoaderConfig.get_current_config_name(LOG_NAME) != "":
		conf = ModLoaderConfig.get_current_config(LOG_NAME)
	else:
		conf = ModLoaderConfig.get_default_config(LOG_NAME)
	if conf != null and conf.data is Dictionary:
		enabled = bool(conf.data.get("debug_log", false))
	ModLog.set_enabled(enabled)

func _install_extensions() -> void:
	pass
```

- [ ] **Étape 9 : relancer les tests et commiter**

```bash
rm -f Brotato/mods-unpacked/Tanith-WaveRollback/.keep
./run-tests-waverollback.sh ; echo "exit=$?"
```

Attendu : `=== 9 tests, 0 échec(s) ===`, `exit=0`.

```bash
git add .gitignore run-tests-waverollback.sh Brotato/mods-unpacked/Tanith-WaveRollback
git commit -m "feat(waverollback): squelette du mod, logger et store du snapshot"
```

---

### Task 2 : Logique pure — garde de validité et libellé

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-WaveRollback/content/logic/rollback_rules.gd`
- Modify: `Brotato/mods-unpacked/Tanith-WaveRollback/test/run_tests.gd`

**Interfaces:**
- Consomme : rien (logique pure, aucun accès au jeu).
- Produit :
  - `RollbackRules.can_offer(snapshot: Dictionary, current_wave: int) -> bool`
  - `RollbackRules.button_label(is_french: bool, wave: int) -> String`

**Contexte — pourquoi la garde est `<` et pas `==`**

Le magasin capture à `current_wave = N-1` ; `base_shop.gd:345` incrémente au clic sur GO. Pendant la vague N, `RunData.current_wave == N`. Un snapshot n'est donc proposable que si sa vague est **strictement antérieure** à la vague en cours.

Cette forme écarte aussi un snapshot périmé d'une **run précédente** (le joueur quitte au menu principal en pleine partie, en relance une autre) : dès la vague 2 un magasin a forcément été visité et a écrasé le snapshot, donc la seule fenêtre de péremption est la vague 1 — où la garde vaut `1 < 1`, faux.

- [ ] **Étape 1 : écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter le `const` en tête, à côté de `Store` :

```gdscript
const Rules = preload("res://mods-unpacked/Tanith-WaveRollback/content/logic/rollback_rules.gd")
```

Ajouter l'appel dans `_init()`, juste après `_test_store()` :

```gdscript
	_test_rules()
```

Et ajouter les deux fonctions de test en fin de fichier :

```gdscript
func _test_rules():
	# Cas nominal : snapshot du magasin d'avant la vague 4, mort en vague 4.
	_check(Rules.can_offer({"current_wave": 3}, 4), "can_offer: snapshot antérieur = proposable")

	# Absence de snapshot.
	_check(not Rules.can_offer({}, 4), "can_offer: snapshot vide = refusé")
	_check(not Rules.can_offer({"autre_cle": 1}, 4), "can_offer: snapshot sans current_wave = refusé")

	# Vague 1 : aucun magasin n'a encore été visité dans CETTE run. Un snapshot
	# résiduel d'une run précédente doit être refusé.
	_check(not Rules.can_offer({"current_wave": 1}, 1), "can_offer: vague 1 avec snapshot périmé = refusé")
	_check(not Rules.can_offer({"current_wave": 12}, 1), "can_offer: vague 1, snapshot d'une run plus avancée = refusé")

	# Incohérence : snapshot postérieur à la vague en cours.
	_check(not Rules.can_offer({"current_wave": 5}, 4), "can_offer: snapshot postérieur = refusé")

	# current_wave sérialisé en float (le JSON de sauvegarde du jeu ramène des
	# TYPE_REAL, cf. progress_data.gd:810-812) : la garde doit tenir quand même.
	_check(Rules.can_offer({"current_wave": 3.0}, 4), "can_offer: current_wave en float = géré")


func _test_button_label():
	_check(Rules.button_label(true, 4) == "Retour au magasin (avant vague 4)", "libellé: version française")
	_check(Rules.button_label(false, 4) == "Back to shop (before wave 4)", "libellé: version anglaise")
	_check(Rules.button_label(true, 12).find("12") != -1, "libellé: le numéro de vague est interpolé")
```

Ajouter aussi l'appel correspondant dans `_init()`, après `_test_rules()` :

```gdscript
	_test_button_label()
```

- [ ] **Étape 2 : vérifier que les tests échouent**

```bash
./run-tests-waverollback.sh ; echo "exit=$?"
```

Attendu : ÉCHEC — `rollback_rules.gd` n'existe pas, le `preload` ne résout pas.

- [ ] **Étape 3 : écrire la logique**

Créer `Brotato/mods-unpacked/Tanith-WaveRollback/content/logic/rollback_rules.gd` :

```gdscript
extends Reference
# Logique pure du mod : aucune dépendance au jeu, donc testable en headless.

# Un snapshot est proposable si, et seulement si, il est STRICTEMENT antérieur
# à la vague en cours.
#
# Le magasin capture à current_wave = N-1 et base_shop.gd:345 incrémente au GO :
# pendant la vague N, RunData.current_wave vaut N. La comparaison stricte écarte
# donc à la fois l'incohérence (snapshot postérieur) et le snapshot périmé d'une
# run précédente — ce dernier ne peut survivre qu'en vague 1, où 1 < 1 est faux.
static func can_offer(snapshot: Dictionary, current_wave: int) -> bool:
	if snapshot.empty():
		return false
	if not snapshot.has("current_wave"):
		return false
	return int(snapshot["current_wave"]) < current_wave


# Libellé bilingue. On n'utilise AUCUNE clé de traduction vanilla : en écraser
# une casserait la localisation officielle dans toutes les langues qu'on
# n'assure pas. `wave` est la vague que le joueur vient de perdre.
static func button_label(is_french: bool, wave: int) -> String:
	if is_french:
		return "Retour au magasin (avant vague %d)" % wave
	return "Back to shop (before wave %d)" % wave
```

- [ ] **Étape 4 : vérifier que les tests passent**

```bash
./run-tests-waverollback.sh ; echo "exit=$?"
```

Attendu : `=== 19 tests, 0 échec(s) ===`, `exit=0`, et aucune ligne `parse error` / `compile error`.

- [ ] **Étape 5 : commiter**

```bash
git add Brotato/mods-unpacked/Tanith-WaveRollback
git commit -m "feat(waverollback): garde de validite du snapshot et libelle bilingue"
```

---

### Task 3 : Capture du snapshot à l'entrée du magasin

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-WaveRollback/extensions/ui/menus/shop/base_shop.gd`
- Modify: `Brotato/mods-unpacked/Tanith-WaveRollback/mod_main.gd` (remplir `_install_extensions`)

**Interfaces:**
- Consomme : `RollbackStore.get_instance().store(Dictionary)`, `ModLog.info(String)` (tâche 1).
- Produit : un snapshot dans le store, de la forme `RunData.get_state()` **dont la clé `players_data` contient des dictionnaires sérialisés** au lieu d'objets `PlayerRunData`. La tâche 5 reconstruit ces objets.

**Contexte — le moment de la capture décide d'un exploit**

| Instant | Pourquoi c'est faux |
|---|---|
| `RunData.on_wave_end()` (`main.gd:1138`) | trop tôt : montées de niveau et caisses de la vague gagnée pas encore résolues (`main.gd:1155-1170`) → le retour les ferait **perdre**, sans pouvoir les rejouer |
| début de `base_shop._ready()` | trop tôt : les effets d'entrée de magasin (`base_shop.gd:53-82`, dont l'upgrade aléatoire de l'Enclume) ne sont pas appliqués. Ils sont gardés par `RunData.shop_effects_checked`, qui **fait partie de `get_state()`** ; capturé à `false`, il serait restauré à `false` → **une arme gratuite à chaque retour** |
| au clic sur GO (`base_shop.gd:319`) | trop tard : les achats sont faits, c'est exactement ce qu'on annule |

**Contexte — pourquoi sérialiser les joueurs**

`PlayerRunData.duplicate()` (`player_run_data.gd:49`) copie `weapons` et `items` **en surface** : les instances `WeaponData`/`ItemData` restent partagées avec la partie en cours, et toute mutation en place pendant le magasin ou la vague fuirait dans le snapshot. Le vanilla compense à la main (`run_data.gd:1773`), mais sur une fenêtre d'une seule vague — la nôtre couvre magasin + vague entière.

`Resource.duplicate()` ne sauve pas non plus la mise : `tracked_value` et `tracked_value_added_this_wave` (`weapon_data.gd:19-20`) sont des `var` **non exportées**, donc perdues à la copie.

On réutilise donc le round-trip que le jeu emploie déjà pour sauvegarder et reprendre une partie : `player_data.serialize()` (`progress_data_loader_v3.gd:594`) → `PlayerRunData.new().deserialize(dict)` (`progress_data_loader_v3.gd:374`).

- [ ] **Étape 1 : écrire l'extension**

Créer `Brotato/mods-unpacked/Tanith-WaveRollback/extensions/ui/menus/shop/base_shop.gd` :

```gdscript
extends "res://ui/menus/shop/base_shop.gd"
# Capture du point de restauration du mod WaveRollback.
#
# La capture a lieu APRÈS ._ready(), donc après les effets d'entrée de magasin
# (base_shop.gd:53-82) qui posent RunData.shop_effects_checked = true. Ce
# drapeau fait partie de get_state() : capturé avant, il serait restauré à
# false et l'Enclume offrirait une arme gratuite à chaque retour.
#
# shop.gd (solo) et coop_shop.gd (coop) héritent tous deux de BaseShop : un
# seul point d'accroche couvre les deux modes.
#
# Tous les symboles sont préfixés : base_shop.gd est très fréquenté par les
# mods d'objets, et deux extensions du même script vanilla partagent un espace
# de noms (const homonyme = Parse Error, méthode homonyme = surcharge muette).

const WaveRollbackModLog = preload("res://mods-unpacked/Tanith-WaveRollback/content/logic/mod_log.gd")
const WaveRollbackStore = preload("res://mods-unpacked/Tanith-WaveRollback/singletons/rollback_store.gd")


func _ready() -> void:
	._ready()
	_waverollback_capture()


# Écrase le snapshot précédent, donc naturellement idempotente : insensible au
# double _ready() qui survient quand plusieurs extensions ModLoader surchargent
# le même script vanilla.
func _waverollback_capture() -> void:
	var state = RunData.get_state()
	var serialized := []
	for player_data in state.players_data:
		serialized.append(player_data.serialize())
	state.players_data = serialized
	WaveRollbackStore.get_instance().store(state)
	WaveRollbackModLog.info(
		"snapshot pris (vague %d, %d joueur(s))" % [int(state.current_wave), serialized.size()]
	)
```

- [ ] **Étape 2 : déclarer l'extension**

Dans `Brotato/mods-unpacked/Tanith-WaveRollback/mod_main.gd`, remplacer le corps de `_install_extensions` :

```gdscript
func _install_extensions() -> void:
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-WaveRollback/extensions/ui/menus/shop/base_shop.gd")
```

- [ ] **Étape 3 : vérifier que les tests headless restent verts**

L'extension n'est pas chargée par le runner, mais on contrôle qu'on n'a rien cassé :

```bash
./run-tests-waverollback.sh ; echo "exit=$?"
```

Attendu : `=== 19 tests, 0 échec(s) ===`, `exit=0`.

- [ ] **Étape 4 : valider en jeu que la capture a lieu**

Activer le log du mod : dans le menu des mods de Brotato, mettre `debug_log` à `true` pour WaveRollback (ou éditer la config du mod). Puis :

1. Lancer Brotato, démarrer une run solo.
2. Gagner la vague 1, entrer dans le magasin.
3. Quitter le jeu et ouvrir le log ModLoader.

Attendu : une ligne `Tanith-WaveRollback` `snapshot pris (vague 1, 1 joueur(s))`. Contrôler aussi qu'il n'y a **ni `Parse Error` ni `compile error`** dans le log — c'est le seul filet contre une collision de symboles, les tests n'en voient rien.

4. Rejouer, atteindre le magasin d'après la vague 2 : une **seconde** ligne doit apparaître avec `vague 2`, confirmant l'écrasement.

- [ ] **Étape 5 : purger les logs et commiter**

```bash
./tools/clean-godot-logs.sh
git add Brotato/mods-unpacked/Tanith-WaveRollback
git commit -m "feat(waverollback): capture du snapshot en fin de base_shop._ready()"
```

---

### Task 4 : Bouton « Retour au magasin » sur l'écran de défaite

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-WaveRollback/extensions/ui/menus/ingame/retry_wave.gd`
- Modify: `Brotato/mods-unpacked/Tanith-WaveRollback/mod_main.gd` (ajouter la seconde extension)

**Interfaces:**
- Consomme : `RollbackStore.get_instance().peek()`, `RollbackRules.can_offer(...)`, `RollbackRules.button_label(...)`, `ModLog.error(String)`.
- Produit : un nœud `Button` nommé `WaveRollbackButton`, enfant de `Menu/Retry_WaveContainer`, positionné juste après `CancelButton`. La tâche 5 branche son signal `pressed`.

**Contexte — structure vanilla de `ui/menus/ingame/retry_wave.tscn`**

```
Menu (VBox)
├── KilledByContainer
├── Retry_WaveContainer          ← masqué si ProgressData.settings.retry_wave = false
│   ├── Label            "RETRY_WAVE_QUESTION"
│   ├── ConfirmButton    "MENU_YES"
│   ├── CancelButton     "MENU_NO"          → fin de run
│   ├── ► WaveRollbackButton  (injecté ici)
│   └── Label_number_retry "RETRY_WAVE_NUMBER"
└── OkButton             "OK_BUTTON"        ← visible si retry_wave = false
```

Le bouton vit **dans** `Retry_WaveContainer` : il suit donc le réglage vanilla « réessayer la vague ». C'est voulu — si le joueur a désactivé le réessai, il veut mourir au premier échec ; le mod élargit l'horizon du retry, il ne le contourne pas.

`MyMenuButtonParent extends Button` (`ui/menus/global/my_menu_button_parent.gd`), donc poser le script `my_menu_button.gd` sur un `Button.new()` suffit à hériter du style et des sons. Le script doit être posé **avant** `add_child`, pour que son `_ready()` branche ses signaux.

Cet écran est affiché par `main.gd:1127` (`_retry_wave.show()`) **avant** `RunData.on_wave_end()`, donc `RunData.current_wave` vaut encore la vague perdue.

- [ ] **Étape 1 : écrire l'extension**

Créer `Brotato/mods-unpacked/Tanith-WaveRollback/extensions/ui/menus/ingame/retry_wave.gd` :

```gdscript
extends "res://ui/menus/ingame/retry_wave.gd"
# Ajoute un troisième choix à l'écran de défaite : revenir au magasin d'avant
# la vague ratée, avec l'inventaire et l'or d'avant achats.
#
# Symboles tous préfixés (espace de noms partagé entre extensions du même
# script vanilla).

const WaveRollbackModLog = preload("res://mods-unpacked/Tanith-WaveRollback/content/logic/mod_log.gd")
const WaveRollbackStore = preload("res://mods-unpacked/Tanith-WaveRollback/singletons/rollback_store.gd")
const WaveRollbackRules = preload("res://mods-unpacked/Tanith-WaveRollback/content/logic/rollback_rules.gd")
const _WAVEROLLBACK_BUTTON_NAME := "WaveRollbackButton"
const _WAVEROLLBACK_CONTAINER := "Menu/Retry_WaveContainer"


func _ready() -> void:
	._ready()
	_waverollback_inject_button()


func show() -> void:
	.show()
	_waverollback_refresh_button()


# Injection idempotente : deux extensions qui surchargent _ready() en rappelant
# ._ready() font tourner le _ready() vanilla DEUX fois — cas déjà rencontré sur
# character_selection.gd, qui avait produit deux cases à cocher identiques.
func _waverollback_inject_button() -> void:
	var container = get_node_or_null(_WAVEROLLBACK_CONTAINER)
	if container == null:
		WaveRollbackModLog.error("Retry_WaveContainer introuvable : bouton non injecté")
		return
	if container.has_node(_WAVEROLLBACK_BUTTON_NAME):
		return

	var button = Button.new()
	button.name = _WAVEROLLBACK_BUTTON_NAME
	# Script posé AVANT add_child : son _ready() branche les sons et le focus.
	button.set_script(load("res://ui/menus/global/my_menu_button.gd"))
	button.visible = false
	container.add_child(button)

	# Juste après « Non », avant le compteur de réessais.
	var cancel = container.get_node_or_null("CancelButton")
	if cancel != null:
		container.move_child(button, cancel.get_index() + 1)

	var _error = button.connect("pressed", self, "_on_waverollback_button_pressed")


func _waverollback_refresh_button() -> void:
	var button = get_node_or_null(_WAVEROLLBACK_CONTAINER + "/" + _WAVEROLLBACK_BUTTON_NAME)
	if button == null:
		return
	var snapshot = WaveRollbackStore.get_instance().peek()
	var offerable = WaveRollbackRules.can_offer(snapshot, RunData.current_wave)
	button.visible = offerable
	if offerable:
		button.text = WaveRollbackRules.button_label(_waverollback_is_french(), RunData.current_wave)


func _waverollback_is_french() -> bool:
	var loc = ""
	if ProgressData != null and ProgressData.settings != null:
		loc = str(ProgressData.settings.language)
	if loc == "":
		loc = TranslationServer.get_locale()
	return loc.begins_with("fr")


# Branché dès l'injection ; le corps arrive à la tâche 5.
func _on_waverollback_button_pressed() -> void:
	pass
```

- [ ] **Étape 2 : déclarer la seconde extension**

Dans `mod_main.gd`, `_install_extensions` devient :

```gdscript
func _install_extensions() -> void:
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-WaveRollback/extensions/ui/menus/shop/base_shop.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-WaveRollback/extensions/ui/menus/ingame/retry_wave.gd")
```

- [ ] **Étape 3 : vérifier que les tests headless restent verts**

```bash
./run-tests-waverollback.sh ; echo "exit=$?"
```

Attendu : `=== 19 tests, 0 échec(s) ===`, `exit=0`.

- [ ] **Étape 4 : valider l'affichage en jeu**

Le bouton ne fait encore rien : on ne valide que son apparition, sa position et son libellé.

1. Run solo, **mourir volontairement en vague 1** → l'écran de défaite s'affiche **sans** notre bouton (aucun magasin visité).
2. Nouvelle run, gagner la vague 1, passer le magasin, **mourir en vague 2** → le bouton apparaît **entre « Non » et le compteur de réessais**, libellé `Retour au magasin (avant vague 2)` en français.
3. Basculer le jeu en anglais, refaire le cas 2 → `Back to shop (before wave 2)`.
4. Dans les options du jeu, **désactiver « réessayer la vague »**, remourir en vague 2 → aucun bouton (tout le bloc est masqué, seul « OK » reste).
5. À la manette, vérifier que le focus descend bien de « Non » vers notre bouton.
6. Contrôler le log ModLoader : **ni `Parse Error` ni `compile error`**, et pas de ligne `Retry_WaveContainer introuvable`.

- [ ] **Étape 5 : purger les logs et commiter**

```bash
./tools/clean-godot-logs.sh
git add Brotato/mods-unpacked/Tanith-WaveRollback
git commit -m "feat(waverollback): bouton Retour au magasin sur l'ecran de defaite"
```

---

### Task 5 : Le retour effectif

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-WaveRollback/extensions/ui/menus/ingame/retry_wave.gd`

**Interfaces:**
- Consomme : le snapshot produit par la tâche 3 (`players_data` = dictionnaires sérialisés), `RollbackRules.can_offer(...)`.
- Produit : rien pour d'autres tâches — c'est le comportement final.

**Contexte**

- `RunData.resume_from_state()` (`run_data.gd:1786`) attend de **vrais objets `PlayerRunData`** : il appelle `.duplicate()` sur chaque entrée de `state.players_data`. On reconstruit donc les objets depuis les dictionnaires sérialisés, exactement comme le chargement d'une partie sauvegardée.
- On ne met **pas** `RunData.resumed_from_state_in_shop = true` : c'est ce drapeau qui ferait relire la vitrine sauvegardée (`base_shop.gd:105-113`). En le laissant à `false`, le magasin repasse par son chemin normal et **régénère** ses objets — comportement voulu.
- `RunData.retries += 1` : le retour est permis mais **tracé**, comme le réessai vanilla (le suffixe `- R3` du score vient de `utils.gd:568`).
- Le garde-fou `_waverollback_pressed` reproduit `confirm_button_pressed` / `cancel_button_pressed` du vanilla : il empêche un double déclenchement pendant le changement de scène.
- `snapshot.duplicate()` (copie de surface du dictionnaire) évite que le remplacement de `players_data` n'écrase la version sérialisée conservée dans le store.

- [ ] **Étape 1 : déclarer le garde-fou**

Dans `extensions/ui/menus/ingame/retry_wave.gd`, ajouter après le bloc de constantes :

```gdscript
var _waverollback_pressed := false
```

- [ ] **Étape 2 : implémenter l'action**

Remplacer le `_on_waverollback_button_pressed()` provisoire par :

```gdscript
func _on_waverollback_button_pressed() -> void:
	if _waverollback_pressed:
		return

	var snapshot = WaveRollbackStore.get_instance().peek()
	if not WaveRollbackRules.can_offer(snapshot, RunData.current_wave):
		WaveRollbackModLog.error("retour demandé sans snapshot valide, ignoré")
		return

	_waverollback_pressed = true
	RunData.resume_from_state(_waverollback_rebuild_state(snapshot))
	RunData.retries += 1
	WaveRollbackModLog.info(
		"retour au magasin d'avant la vague %d (retries = %d)" % [RunData.current_wave + 1, RunData.retries]
	)
	var _error = get_tree().change_scene(RunData.get_shop_scene_path())


# resume_from_state attend de vrais PlayerRunData (il appelle .duplicate() sur
# chaque entrée). On reconstruit les objets depuis les dictionnaires sérialisés,
# comme le chargement d'une partie sauvegardée (progress_data_loader_v3.gd:374).
func _waverollback_rebuild_state(snapshot: Dictionary) -> Dictionary:
	var state = snapshot.duplicate()
	var players := []
	for serialized in snapshot.players_data:
		players.append(PlayerRunData.new().deserialize(serialized))
	state.players_data = players
	return state
```

Note sur le message de log : après `resume_from_state`, `RunData.current_wave` vaut la vague du **magasin** (N-1) ; `+ 1` restitue le numéro de la vague perdue.

- [ ] **Étape 3 : vérifier que les tests headless restent verts**

```bash
./run-tests-waverollback.sh ; echo "exit=$?"
```

Attendu : `=== 19 tests, 0 échec(s) ===`, `exit=0`.

- [ ] **Étape 4 : valider le retour en jeu**

1. Run solo. Gagner la vague 1. **Noter l'or affiché à l'ouverture du magasin** et la liste des armes/objets.
2. Tout dépenser en achats délibérément mauvais, valider (GO), mourir en vague 2.
3. Cliquer « Retour au magasin ».

Attendu :
- le magasin se rouvre ;
- l'**or** est exactement celui noté à l'étape 1 ;
- l'inventaire (armes, objets, stats, niveau) est celui d'avant achats ;
- la **vitrine est différente** (objets régénérés) ;
- le bouton GO annonce toujours « Vague 2 » ;
- le compteur de réessais a augmenté de 1 (visible sur l'écran de défaite suivant, et en suffixe `- R1` sur le score de fin de run).

4. Racheter autre chose, rejouer la vague 2, remourir : le bouton doit être **de nouveau proposé** (un nouveau snapshot a été pris à la réouverture du magasin).

- [ ] **Étape 5 : purger les logs et commiter**

```bash
./tools/clean-godot-logs.sh
git add Brotato/mods-unpacked/Tanith-WaveRollback
git commit -m "feat(waverollback): restauration de l'etat et reouverture du magasin"
```

---

### Task 6 : Validation en jeu complète

**Files:**
- Modify: `CLAUDE.md` (documenter le nouveau mod et son runner)

**Interfaces:**
- Consomme : le mod complet des tâches 1 à 5.
- Produit : la confirmation que le mod est livrable.

Aucun de ces contrôles ne se teste en headless : ils touchent tous des autoloads. Les exécuter **dans l'ordre**, et noter le résultat de chacun.

- [ ] **Étape 1 : contrôle anti-exploit de l'Enclume**

C'est le contrôle le plus important du plan : il valide que `shop_effects_checked` est bien capturé à `true` (§ tâche 3).

1. Se procurer l'**Enclume** (`item_anvil`) — l'effet « améliore une arme au hasard à l'entrée du magasin ». Le menu de debug natif du jeu (`F2` en build debug, `debug_service.gd:68`) permet de se donner de l'or et de forcer des objets.
2. Entrer dans un magasin avec l'Enclume : une arme est améliorée.
3. Mourir la vague suivante, faire **trois retours au magasin d'affilée**.

Attendu : **aucune** arme supplémentaire améliorée à chaque retour. Si des armes montent en tier à chaque passage, la capture est faite trop tôt — revoir la tâche 3.

- [ ] **Étape 2 : contrôle des valeurs suivies**

1. Porter un objet à compteur (Bague du justicier, `item_vigilante_ring`) et jouer une vague pour faire monter son compteur.
2. Entrer au magasin, noter la valeur du compteur.
3. Mourir la vague suivante, revenir au magasin.

Attendu : le compteur est **exactement** celui noté à l'étape 2, et il ne dérive pas si on répète l'opération. C'est le contrôle du détachement par `serialize()`/`deserialize()`.

- [ ] **Étape 3 : contrôle coop**

1. Lancer une run coop 2 joueurs, atteindre la vague 2, mourir.
2. Le joueur 1 déclenche « Retour au magasin ».

Attendu : les **deux** inventaires et les deux réserves d'or sont restaurés. Le joueur 2 n'a pas la main sur ce menu — c'est le comportement vanilla (le `FocusEmulator` de `retry_wave.tscn` est câblé sur `player_index = 0`).

- [ ] **Étape 4 : contrôle de cohabitation**

Activer **simultanément** WaveRollback, ShopConfig et Bomberman. Lancer une run, atteindre un magasin, mourir, faire un retour.

Attendu :
- le log ModLoader ne contient **ni `Parse Error` ni `compile error`** ;
- l'écran de config du magasin de ShopConfig fonctionne toujours ;
- le personnage Bomberto et ses armes bombe apparaissent toujours ;
- après un retour, les armes bombe sont bien restaurées (contrôle que `deserialize()` retrouve le contenu moddé via `ItemService`).

- [ ] **Étape 5 : contrôle de non-régression du snapshot périmé**

1. Lancer une run, atteindre la vague 3 (donc au moins deux magasins visités).
2. Mettre la partie en pause et **quitter au menu principal** sans finir la run.
3. Lancer une **nouvelle** run et mourir en **vague 1**.

Attendu : **aucun** bouton « Retour au magasin ». S'il apparaît, la garde de la tâche 2 est en défaut.

- [ ] **Étape 6 : documenter le mod dans `CLAUDE.md`**

Ajouter `Tanith-WaveRollback` là où `CLAUDE.md` décrit les mods du dépôt :

- dans la section **Commandes**, ajouter `./run-tests-waverollback.sh` à la liste des runners (« Chaque mod a son **propre** runner »), avec l'équivalent Windows ;
- ajouter une courte section d'architecture : les deux points d'accroche (`base_shop.gd` pour la capture, `retry_wave.gd` pour le bouton), le store en méta `Engine`, et la raison pour laquelle la capture est en **fin** de `_ready()` (`shop_effects_checked`) ;
- dans **Conventions**, ajouter la règle de **préfixe des symboles dans `extensions/`** et son mode de défaite (Parse Error pour un `const`, surcharge muette pour une méthode).

- [ ] **Étape 7 : purger les logs, relancer tous les runners, commiter**

```bash
./tools/clean-godot-logs.sh
./run-tests.sh ; echo "shopconfig=$?"
./run-tests-bomberman.sh ; echo "bomberman=$?"
./run-tests-waverollback.sh ; echo "waverollback=$?"
```

Attendu : les trois à `0`.

```bash
git add CLAUDE.md
git commit -m "docs(waverollback): documente le mod et son runner dans CLAUDE.md"
```

---

### Task 7 : Packaging Workshop

**Files:**
- Create: `dist/Tanith-WaveRollback-1.0.0.zip` (non versionné)
- Create: `docs/workshop-changenotes-waverollback_1.0.0.txt`

**Interfaces:**
- Consomme : le mod validé de la tâche 6.
- Produit : l'archive prête pour l'upload.

**Contexte de packaging** (leçons des deux mods précédents)

- Le `.zip` doit contenir le préfixe `mods-unpacked/` dans les chemins, avec des **slashes** `/`.
- `dist/` n'est pas versionné.
- L'item Workshop **n'existe pas encore** : sa création est une action manuelle de l'utilisateur dans Steam. Ne pas tenter de l'automatiser.

- [ ] **Étape 1 : construire l'archive**

Depuis la racine du repo :

```bash
mkdir -p dist
rm -f dist/Tanith-WaveRollback-1.0.0.zip
cd Brotato && zip -r ../dist/Tanith-WaveRollback-1.0.0.zip mods-unpacked/Tanith-WaveRollback -x '*/.*' && cd ..
unzip -l dist/Tanith-WaveRollback-1.0.0.zip
```

Attendu : tous les chemins commencent par `mods-unpacked/Tanith-WaveRollback/`, avec des `/`, et l'archive contient `manifest.json`, `mod_main.gd`, les deux `extensions/`, `content/logic/`, `singletons/`. Le dossier `test/` peut rester, il est inerte en jeu.

- [ ] **Étape 2 : vérifier l'archive en conditions réelles**

Retirer le dossier `Tanith-WaveRollback` de `mods-unpacked/`, dézipper l'archive à sa place, relancer le jeu et refaire le contrôle de base : gagner la vague 1, mourir en vague 2, faire un retour.

Attendu : comportement identique, aucun `Parse Error` dans le log.

- [ ] **Étape 3 : rédiger les notes de version bilingues**

Créer `docs/workshop-changenotes-waverollback_1.0.0.txt` en **BBCode bilingue EN/FR**, sur le modèle de `docs/workshop-changenotes_3.1.0.txt` (Bomberman). Contenu : ce que fait le mod, le fait que le compteur de réessais augmente, et que la vitrine du magasin est régénérée (ce n'est pas un « annuler » figé).

- [ ] **Étape 4 : commiter et remonter à l'utilisateur**

```bash
git add docs/workshop-changenotes-waverollback_1.0.0.txt
git commit -m "docs(waverollback): notes de version Workshop 1.0.0 (BBCode bilingue)"
```

Puis **signaler à l'utilisateur** que l'upload demande deux actions manuelles de sa part :
1. créer l'item Workshop dans Steam pour ce nouveau mod ;
2. noter l'ID obtenu dans `docs/superpowers/WorkshopID.md`, à côté de ceux de ShopConfig (`3748276960`) et Bomberman (`3752197886`).

---

## Couverture de la spec

| Section de la spec | Tâche |
|---|---|
| §2 modèle conceptuel (un seul snapshot, écrasé) | 1 (store), 3 (écrasement à chaque magasin) |
| §4 flux utilisateur | 4 (bouton), 5 (retour) |
| §5.1 store en méta `Engine` | 1 |
| §5.2 capture en fin de `base_shop._ready()` | 3 |
| §5.3 bouton et retour | 4, 5 |
| §6 UI, position, libellé bilingue, réglage vanilla | 2 (libellé), 4 (position, visibilité) |
| §7.1 détachement par `serialize`/`deserialize` | 3 (capture), 5 (reconstruction), 6 étape 2 (contrôle) |
| §7.2 cohérence de la sauvegarde disque | aucune action : `base_shop.gd:201` réécrit l'état à l'ouverture |
| §7.3 garde de validité | 2, 6 étape 5 |
| §7.4 coop | 6 étape 3 |
| §9 config `debug_log` | 1 (manifest + `mod_main`) |
| §10 préfixe des symboles | 3, 4 (code), 6 étape 4 (contrôle), 6 étape 6 (doc) |
| §11 tests | 1, 2 (headless), 6 (en jeu) |
