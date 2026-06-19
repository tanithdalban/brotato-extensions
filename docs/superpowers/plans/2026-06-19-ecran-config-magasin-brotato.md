# Écran de configuration du magasin (mod Brotato) — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter un écran, entre la sélection du personnage et celle de l'arme de départ, qui permet à chaque joueur de retirer des objets/armes du pool de pioche de son magasin.

**Architecture:** Mod Brotato (Godot 4 + Godot ModLoader). Le modèle est une **curation du pool** : on ne stocke que les exclusions par joueur dans un store à variables statiques, et on filtre les candidats du magasin avant la pioche pondérée native (Approche A). L'UI est une scène multi-joueurs responsive injectée dans le flux de menus. La logique de filtrage est isolée dans une fonction pure testable.

**Tech Stack:** Godot 4, GDScript, Godot ModLoader (script extensions + script hooks), GUT (Godot Unit Test) pour la logique pure, GDRE Tools / gdsdecomp pour décompiler Brotato.

## Global Constraints

- **Godot 4** + **Godot ModLoader 6.x** (API : `install_script_extension`, `add_hook`, `ModLoaderHookChain`).
- **Non destructif** : ne jamais écrire dans les données natives du jeu, ni dans la liste d'exclusion native (8 slots). Couche additive uniquement.
- **3 couches de filtrage** combinées sans interférence : compatibilité perso (natif) → exclusion native (natif) → exclusions de notre écran (mod).
- **On ne stocke que les exclusions**, par joueur. Aucune persistance entre parties. `reset()` à l'ouverture de l'écran.
- **Pas de garantie absolue** : aucune injection ni manipulation de tier ; on ne fait que retirer des candidats.
- **Garde-fou global** : interdiction de valider un pool entièrement vide (au moins un élément achetable, objet **ou** arme).
- **Coop 1-4 joueurs** : un pool par joueur, layout responsive (1 = plein écran, 2 = moitiés, 3-4 = quarts), navigation manette par quadrant.
- **Conventions ModLoader** : fichiers en `snake_case` ; ID de mod `{namespace}-{name}` ; chemins sous `res://mods-unpacked/{namespace}-{name}/`.
- **Logging spécifique et désactivable** : tous les logs du mod passent par un wrapper (`ModLog`) sous le namespace `Tanit-ShopConfig` (donc filtrables dans la console ModLoader) ; un drapeau `debug_log` (config du mod, **défaut : false**) active/désactive les logs `info`/`debug`. Les `error` restent toujours émis. Aucun `print()` brut ni `ModLoaderLog` appelé directement ailleurs.
- **Namespace/nom du mod** : `Tanit-ShopConfig` (ID `Tanit-ShopConfig`). Remplacer `Tanit` par le namespace réel souhaité partout si différent.

---

## File Structure

```
mods-unpacked/Tanit-ShopConfig/
├── manifest.json                          # métadonnées Thunderstore + compat
├── mod_main.gd                            # entrée ModLoader : installe extensions/hooks
├── content/logic/
│   ├── pool_filter.gd                     # fonction PURE : retire les exclusions des candidats
│   └── mod_log.gd                         # logger propre au mod, désactivable (défaut off)
├── singletons/
│   └── shop_config_store.gd               # store statique : exclusions par joueur (reset/par run)
├── scenes/
│   ├── shop_config_screen.gd / .tscn      # conteneur responsive multi-joueurs
│   └── player_shop_config_panel.gd / .tscn# un quadrant : grille, filtres, infobulle, Prêt
├── extensions/                            # script extensions miroir de l'arbo native
│   └── <rempli en Phase 5 selon recon>
└── hooks installés dans mod_main.gd       # si points natifs en class_name/préchargés

docs/superpowers/notes/
└── integration-points.md                  # SORTIE de la Phase 0 : chemins/signatures natifs
```

Fichiers de test (dans le projet de dev décompilé) :
```
test/unit/test_pool_filter.gd              # GUT
test/unit/test_shop_config_store.gd        # GUT
```

---

## Phase 0 — Environnement & reconnaissance

> Cette phase est **investigatrice**, pas TDD. Son livrable est `docs/superpowers/notes/integration-points.md` rempli avec des valeurs concrètes que les phases suivantes consomment. Une tâche est « terminée » quand chaque champ du document a une réponse vérifiée dans le code décompilé.

### Task 0.1 : Mettre en place l'environnement de dev modding

**Files:**
- Create: (aucun fichier de code ; mise en place d'outils et du projet)

**Interfaces:**
- Produces: un projet Godot 4 ouvrable contenant les sources **décompilées** de Brotato, avec **Godot ModLoader** installé et le jeu lançable depuis l'éditeur.

- [ ] **Step 1 : Installer les outils**

Installer Godot 4 (version correspondant à celle de Brotato — à confirmer dans `project.godot` après décompilation) et GDRE Tools (gdsdecomp) pour décompiler le jeu.

- [ ] **Step 2 : Décompiler Brotato**

Avec GDRE Tools, ouvrir le `Brotato.exe` / `.pck` et extraire le projet vers un dossier de travail (ex. `~/brotato-decomp/`).

- [ ] **Step 3 : Installer Godot ModLoader dans le projet décompilé**

Suivre le guide d'installation du ModLoader (https://wiki.godotmodding.com/) : ajouter l'autoload `ModLoaderStore` et `ModLoader`, et le dossier `addons/mod_loader`.

- [ ] **Step 4 : Vérifier que le jeu se lance depuis l'éditeur**

Run : lancer la scène principale depuis l'éditeur Godot.
Expected : le jeu démarre, et la console affiche les logs d'init du ModLoader (aucun mod chargé pour l'instant).

- [ ] **Step 5 : Noter la version exacte**

Relever dans `project.godot` / logs : version de Godot, version de Brotato, version de ModLoader. Les reporter dans `docs/superpowers/notes/integration-points.md` (section « Versions »).

---

### Task 0.2 : Localiser et documenter les points d'intégration natifs

**Files:**
- Create: `docs/superpowers/notes/integration-points.md`

**Interfaces:**
- Consumes: projet décompilé (Task 0.1).
- Produces: document avec, pour **chaque** champ ci-dessous, un chemin `res://...`, un nom de méthode/propriété exact, et la mention **extension vs hook** (hook obligatoire si le script vanilla a un `class_name`). Ces valeurs sont consommées par les Tasks 4.x et 5.x.

Champs à remplir (chacun avec sa réponse vérifiée) :

- [ ] **Step 1 : `CONTENT_LIST` — accès à la liste vivante des objets et armes**

Trouver comment obtenir tous les objets et toutes les armes avec, pour chacun : identifiant (probablement `my_id`), icône, nom, description, **tier**, **tags**, et (pour les armes) **type/classe d'arme**.
Chercher dans le code décompilé : `ItemService`, `WeaponService`, `items`, `weapons`, `my_id`, `tier`, `tags`.
Documenter : le chemin du service, la propriété/fonction d'accès, et le nom **exact** de la propriété d'ID.

- [ ] **Step 2 : `CHAR_COMPAT` — compatibilité objet/arme ↔ personnage**

Trouver la fonction native qui détermine si un objet/arme est disponible pour un personnage donné (restrictions de classe d'armes, items interdits par perso).
Chercher : `get_shop_items`, `can_appear`, `is_*_compatible`, références au personnage / `character_id`, listes d'items interdits sur la `CharacterData`.
Documenter : chemin + signature exacte de la fonction de compatibilité réutilisable.

- [ ] **Step 3 : `SHOP_POOL` — génération du pool du magasin par joueur**

Trouver le script + la méthode qui construit la liste des candidats dans laquelle le magasin pioche, **par joueur**.
Chercher : `shop`, `_get_shop_items`, `get_items`, `roll`, `weighted`, `tier_weights`, références au `player_index`.
Documenter : chemin `res://...`, nom **exact** de la méthode, sa **signature** (paramètres + type de retour), comment le **player_index** y est accessible, et si le script a un `class_name` (→ **hook**) ou non (→ **extension**), et s'il est **préchargé** (préchargé = ni extension ni hook possibles → trouver un point d'accroche alternatif en amont).

- [ ] **Step 4 : `MENU_NAV` — transition sélection perso → sélection arme**

Trouver le script + la méthode qui déclenche le passage de l'écran de sélection de personnage à celui de sélection d'arme de départ.
Chercher : `character_selection`, `weapon_selection`, `_on_*_ready`, `goto_*`, `change_scene`, `_on_continue_pressed`.
Documenter : chemin, méthode exacte, signature, `class_name`/préchargé (extension vs hook), et **comment récupérer la liste des joueurs et leur personnage choisi** à ce stade (pour construire la grille filtrée par perso).

- [ ] **Step 5 : Renseigner le document et vérifier la complétude**

Le document `integration-points.md` doit contenir une valeur concrète pour `CONTENT_LIST`, `CHAR_COMPAT`, `SHOP_POOL`, `MENU_NAV`, plus la section « Versions ».
Expected : aucun champ vide ; chaque champ cite un fichier `res://...` et un symbole exact.

---

## Phase 1 — Squelette du mod

### Task 1.1 : Mod minimal qui se charge

**Files:**
- Create: `mods-unpacked/Tanit-ShopConfig/manifest.json`
- Create: `mods-unpacked/Tanit-ShopConfig/mod_main.gd`

**Interfaces:**
- Produces: un mod chargé par le ModLoader, qui logge une ligne d'init. `mod_main.gd` exposera ensuite `_init()` comme point d'installation des extensions/hooks.

- [ ] **Step 1 : Écrire le manifest**

`mods-unpacked/Tanit-ShopConfig/manifest.json` :
```json
{
    "name": "ShopConfig",
    "namespace": "Tanit",
    "version_number": "0.1.0",
    "description": "Écran de configuration du pool du magasin, par joueur, entre sélection perso et arme.",
    "website_url": "",
    "dependencies": [],
    "extra": {
        "godot": {
            "authors": ["Tanit"],
            "tags": ["utility", "ui"],
            "optional_dependencies": [],
            "load_before": [],
            "incompatibilities": [],
            "compatible_mod_loader_version": ["6.2.0"],
            "compatible_game_version": [],
            "config_schema": {
                "type": "object",
                "properties": {
                    "debug_log": {
                        "type": "boolean",
                        "description": "Active les logs détaillés de ShopConfig.",
                        "default": false
                    }
                }
            }
        }
    }
}
```
(Renseigner `compatible_mod_loader_version` et `compatible_game_version` avec les valeurs relevées en Task 0.1. Le `config_schema` déclare l'interrupteur de log `debug_log`, désactivé par défaut.)

- [ ] **Step 2 : Écrire le mod_main minimal**

`mods-unpacked/Tanit-ShopConfig/mod_main.gd` :
```gdscript
extends Node

const MOD_DIR := "res://mods-unpacked/Tanit-ShopConfig/"

func _init() -> void:
    ModLoaderLog.info("ShopConfig: init", "Tanit-ShopConfig")
    _install_extensions()
    _install_hooks()

func _install_extensions() -> void:
    pass

func _install_hooks() -> void:
    pass
```

- [ ] **Step 3 : Lancer le jeu et vérifier le chargement**

Run : lancer le jeu depuis l'éditeur.
Expected : le log contient `ShopConfig: init` et le ModLoader liste `Tanit-ShopConfig` parmi les mods chargés.

- [ ] **Step 4 : Commit**

```bash
git add mods-unpacked/Tanit-ShopConfig/manifest.json mods-unpacked/Tanit-ShopConfig/mod_main.gd
git commit -m "feat: squelette du mod ShopConfig qui se charge"
```

---

### Task 1.2 : Logger propre au mod, désactivable (TDD via GUT)

**Files:**
- Create: `mods-unpacked/Tanit-ShopConfig/content/logic/mod_log.gd`
- Modify: `mods-unpacked/Tanit-ShopConfig/mod_main.gd`
- Test: `test/unit/test_mod_log.gd`

**Interfaces:**
- Produces (consommé par toutes les phases pour journaliser) :
  - `ModLog.set_enabled(value: bool) -> void`
  - `ModLog.is_enabled() -> bool`
  - `ModLog.info(msg: String) -> void` / `ModLog.debug(msg: String) -> void` (émis seulement si activé)
  - `ModLog.error(msg: String) -> void` (toujours émis)
  - Tous sous le namespace `Tanit-ShopConfig`.

- [ ] **Step 1 : Écrire le test qui échoue**

`test/unit/test_mod_log.gd` :
```gdscript
extends GutTest

const ModLog := preload("res://mods-unpacked/Tanit-ShopConfig/content/logic/mod_log.gd")

func after_each() -> void:
    ModLog.set_enabled(false)

func test_disabled_by_default() -> void:
    assert_false(ModLog.is_enabled())

func test_enable_toggle() -> void:
    ModLog.set_enabled(true)
    assert_true(ModLog.is_enabled())
    ModLog.set_enabled(false)
    assert_false(ModLog.is_enabled())

func test_log_name_is_mod_specific() -> void:
    assert_eq(ModLog.LOG_NAME, "Tanit-ShopConfig")

func test_logging_methods_do_not_crash_when_disabled_or_enabled() -> void:
    ModLog.set_enabled(false)
    ModLog.info("muet")
    ModLog.debug("muet")
    ModLog.set_enabled(true)
    ModLog.info("visible")
    ModLog.error("toujours")
    assert_true(true)  # aucune exception levée
```

- [ ] **Step 2 : Lancer le test et vérifier l'échec**

Run : GUT sur `test/unit/test_mod_log.gd`.
Expected : ÉCHEC — `mod_log.gd` n'existe pas.

- [ ] **Step 3 : Écrire l'implémentation**

`mods-unpacked/Tanit-ShopConfig/content/logic/mod_log.gd` :
```gdscript
extends RefCounted
## Logger propre au mod, désactivable. Namespace fixe pour filtrer dans la console.

const LOG_NAME := "Tanit-ShopConfig"

static var _enabled: bool = false

static func set_enabled(value: bool) -> void:
    _enabled = value

static func is_enabled() -> bool:
    return _enabled

static func info(msg: String) -> void:
    if _enabled:
        ModLoaderLog.info(msg, LOG_NAME)

static func debug(msg: String) -> void:
    if _enabled:
        ModLoaderLog.debug(msg, LOG_NAME)

static func error(msg: String) -> void:
    # Les erreurs sont toujours émises, même logs désactivés.
    ModLoaderLog.error(msg, LOG_NAME)
```

- [ ] **Step 4 : Lancer le test et vérifier le succès**

Run : GUT sur `test/unit/test_mod_log.gd`.
Expected : SUCCÈS — 4 tests passent.

- [ ] **Step 5 : Câbler le drapeau depuis la config du mod dans mod_main**

Remplacer le `mod_main.gd` par :
```gdscript
extends Node

const MOD_DIR := "res://mods-unpacked/Tanit-ShopConfig/"
const ModLog := preload("res://mods-unpacked/Tanit-ShopConfig/content/logic/mod_log.gd")

func _init() -> void:
    _setup_logging()
    ModLog.info("init")
    _install_extensions()
    _install_hooks()

func _setup_logging() -> void:
    # Lit le drapeau debug_log depuis la config du mod (défaut false si indispo).
    var enabled := false
    var config := ModLoaderConfig.get_current_config("Tanit-ShopConfig")
    if config != null and config.data is Dictionary:
        enabled = bool(config.data.get("debug_log", false))
    ModLog.set_enabled(enabled)

func _install_extensions() -> void:
    pass

func _install_hooks() -> void:
    pass
```
> L'API exacte de lecture de config (`ModLoaderConfig.get_current_config`) est à confirmer pour la version relevée en Task 0.1 ; le comportement par défaut (logs off) doit rester vrai même si la config est absente.

- [ ] **Step 6 : Vérification manuelle**

Lancer le jeu avec `debug_log` à false (défaut) puis à true (via le menu de config du mod du ModLoader).
Expected : à false, aucun log `ShopConfig` hormis les erreurs ; à true, le log `init` et les logs `info` apparaissent sous le namespace `Tanit-ShopConfig`.

- [ ] **Step 7 : Commit**

```bash
git add mods-unpacked/Tanit-ShopConfig/content/logic/mod_log.gd mods-unpacked/Tanit-ShopConfig/mod_main.gd test/unit/test_mod_log.gd
git commit -m "feat: logger propre au mod, désactivable via config (défaut off)"
```

---

## Phase 2 — Logique pure de filtrage

### Task 2.1 : `pool_filter.gd` (fonction pure, TDD via GUT)

**Files:**
- Create: `mods-unpacked/Tanit-ShopConfig/content/logic/pool_filter.gd`
- Test: `test/unit/test_pool_filter.gd`

**Interfaces:**
- Produces: `PoolFilter.filter(candidates: Array, excluded_ids: Dictionary) -> Array` — retourne les candidats dont la propriété `my_id` n'est PAS une clé de `excluded_ids`. `excluded_ids` est utilisé comme un ensemble (`{id: true}`). Consommé par la Task 5.2.

> Prérequis : GUT installé dans le projet de dev (addon `gut`). Si absent : l'installer via l'Asset Library, activer le plugin, créer le dossier `test/unit/`.

- [ ] **Step 1 : Écrire le test qui échoue**

`test/unit/test_pool_filter.gd` :
```gdscript
extends GutTest

const PoolFilter := preload("res://mods-unpacked/Tanit-ShopConfig/content/logic/pool_filter.gd")

class StubItem:
    var my_id: String
    func _init(id: String) -> void:
        my_id = id

func _items(ids: Array) -> Array:
    var out: Array = []
    for id in ids:
        out.append(StubItem.new(id))
    return out

func _ids(items: Array) -> Array:
    var out: Array = []
    for it in items:
        out.append(it.my_id)
    return out

func test_removes_excluded_ids() -> void:
    var candidates := _items(["a", "b", "c"])
    var excluded := {"b": true}
    var result := PoolFilter.filter(candidates, excluded)
    assert_eq(_ids(result), ["a", "c"])

func test_unknown_excluded_id_is_ignored() -> void:
    var candidates := _items(["a", "b"])
    var excluded := {"zzz": true}
    var result := PoolFilter.filter(candidates, excluded)
    assert_eq(_ids(result), ["a", "b"])

func test_empty_exclusions_returns_all() -> void:
    var candidates := _items(["a", "b"])
    var result := PoolFilter.filter(candidates, {})
    assert_eq(_ids(result), ["a", "b"])

func test_excluding_everything_returns_empty() -> void:
    var candidates := _items(["a", "b"])
    var excluded := {"a": true, "b": true}
    var result := PoolFilter.filter(candidates, excluded)
    assert_eq(result.size(), 0)

func test_does_not_mutate_input() -> void:
    var candidates := _items(["a", "b"])
    PoolFilter.filter(candidates, {"a": true})
    assert_eq(candidates.size(), 2)
```

- [ ] **Step 2 : Lancer le test et vérifier l'échec**

Run : exécuter GUT sur `test/unit/test_pool_filter.gd` (panneau GUT ou ligne de commande `godot -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_pool_filter.gd -gexit`).
Expected : ÉCHEC — `pool_filter.gd` n'existe pas / `filter` indéfini.

- [ ] **Step 3 : Écrire l'implémentation minimale**

`mods-unpacked/Tanit-ShopConfig/content/logic/pool_filter.gd` :
```gdscript
extends RefCounted
## Fonction pure de filtrage du pool. Aucune dépendance au jeu.

## Retourne les candidats dont `my_id` n'est pas une clé de `excluded_ids`.
## `excluded_ids` est utilisé comme un ensemble : {id: true}.
static func filter(candidates: Array, excluded_ids: Dictionary) -> Array:
    var result: Array = []
    for candidate in candidates:
        if not excluded_ids.has(candidate.my_id):
            result.append(candidate)
    return result
```

- [ ] **Step 4 : Lancer le test et vérifier le succès**

Run : exécuter GUT sur `test/unit/test_pool_filter.gd`.
Expected : SUCCÈS — 5 tests passent.

- [ ] **Step 5 : Commit**

```bash
git add mods-unpacked/Tanit-ShopConfig/content/logic/pool_filter.gd test/unit/test_pool_filter.gd
git commit -m "feat: fonction pure pool_filter + tests GUT"
```

---

## Phase 3 — Store des exclusions par joueur

### Task 3.1 : `shop_config_store.gd` (TDD via GUT)

**Files:**
- Create: `mods-unpacked/Tanit-ShopConfig/singletons/shop_config_store.gd`
- Test: `test/unit/test_shop_config_store.gd`

**Interfaces:**
- Produces, consommé par Tasks 4.4 et 5.2 :
  - `ShopConfigStore.reset() -> void`
  - `ShopConfigStore.set_excluded(player_index: int, excluded_ids: Dictionary) -> void` (stocke une **copie**)
  - `ShopConfigStore.get_excluded(player_index: int) -> Dictionary` (`{}` si aucun)
  - `ShopConfigStore.has_any_available(player_index: int, total_count: int) -> bool` (vrai s'il reste ≥ 1 candidat ; garde-fou global)

- [ ] **Step 1 : Écrire le test qui échoue**

`test/unit/test_shop_config_store.gd` :
```gdscript
extends GutTest

const Store := preload("res://mods-unpacked/Tanit-ShopConfig/singletons/shop_config_store.gd")

func before_each() -> void:
    Store.reset()

func test_get_excluded_defaults_empty() -> void:
    assert_eq(Store.get_excluded(0), {})

func test_set_and_get_excluded() -> void:
    Store.set_excluded(0, {"a": true})
    assert_eq(Store.get_excluded(0), {"a": true})

func test_players_are_independent() -> void:
    Store.set_excluded(0, {"a": true})
    Store.set_excluded(1, {"b": true})
    assert_eq(Store.get_excluded(0), {"a": true})
    assert_eq(Store.get_excluded(1), {"b": true})

func test_set_stores_a_copy() -> void:
    var src := {"a": true}
    Store.set_excluded(0, src)
    src["b"] = true
    assert_eq(Store.get_excluded(0), {"a": true})

func test_reset_clears_all() -> void:
    Store.set_excluded(0, {"a": true})
    Store.reset()
    assert_eq(Store.get_excluded(0), {})

func test_has_any_available_true_when_some_remain() -> void:
    Store.set_excluded(0, {"a": true})
    assert_true(Store.has_any_available(0, 3))

func test_has_any_available_false_when_all_excluded() -> void:
    Store.set_excluded(0, {"a": true, "b": true})
    assert_false(Store.has_any_available(0, 2))
```

- [ ] **Step 2 : Lancer le test et vérifier l'échec**

Run : GUT sur `test/unit/test_shop_config_store.gd`.
Expected : ÉCHEC — `shop_config_store.gd` n'existe pas.

- [ ] **Step 3 : Écrire l'implémentation minimale**

`mods-unpacked/Tanit-ShopConfig/singletons/shop_config_store.gd` :
```gdscript
extends RefCounted
## Store des exclusions par joueur pour la partie en cours.
## Variables statiques : persistent pendant la session, vidées par reset() à chaque run.

static var _excluded_by_player: Dictionary = {}

static func reset() -> void:
    _excluded_by_player.clear()

static func set_excluded(player_index: int, excluded_ids: Dictionary) -> void:
    _excluded_by_player[player_index] = excluded_ids.duplicate(true)

static func get_excluded(player_index: int) -> Dictionary:
    return _excluded_by_player.get(player_index, {})

## Garde-fou global : reste-t-il au moins un candidat non exclu ?
## `total_count` = nombre total d'éléments achetables proposés au joueur
## (objets + armes compatibles avec son perso).
static func has_any_available(player_index: int, total_count: int) -> bool:
    return get_excluded(player_index).size() < total_count
```

- [ ] **Step 4 : Lancer le test et vérifier le succès**

Run : GUT sur `test/unit/test_shop_config_store.gd`.
Expected : SUCCÈS — 7 tests passent.

- [ ] **Step 5 : Commit**

```bash
git add mods-unpacked/Tanit-ShopConfig/singletons/shop_config_store.gd test/unit/test_shop_config_store.gd
git commit -m "feat: store statique des exclusions par joueur + tests GUT"
```

---

## Phase 4 — Interface (scène & quadrants)

> L'UI n'est pas testable en TDD automatisé : chaque tâche se termine par une **vérification manuelle** explicite. Le code GDScript est fourni complet ; les appels dépendant du natif référencent les champs de `integration-points.md` (Phase 0), notés `CONTENT_LIST`, `CHAR_COMPAT`, `MENU_NAV`.

### Task 4.1 : Panneau joueur — construire la grille filtrée par perso

**Files:**
- Create: `mods-unpacked/Tanit-ShopConfig/scenes/player_shop_config_panel.gd`
- Create: `mods-unpacked/Tanit-ShopConfig/scenes/player_shop_config_panel.tscn`

**Interfaces:**
- Consumes: `CONTENT_LIST` (accès items/armes + métadonnées), `CHAR_COMPAT` (compat perso) de `integration-points.md`.
- Produces: `PlayerShopConfigPanel.setup(player_index: int, character_data) -> void` qui peuple deux grilles (objets, armes) avec uniquement les éléments compatibles avec `character_data`. Expose `get_excluded_ids() -> Dictionary` et `get_total_count() -> int`. Consommé par Tasks 4.2–4.4.

- [ ] **Step 1 : Construire la scène `.tscn`**

Racine `PanelContainer` nommée `PlayerShopConfigPanel`, script attaché. Enfants : `TabContainer` avec deux onglets `Objets` et `Armes`, chacun contenant un `ScrollContainer > GridContainer` (`%ItemsGrid`, `%WeaponsGrid`, marqués « Accès en tant que scène unique »). Ajouter un `Label` `%WarningLabel` (caché) et un `Button` `%ReadyButton`.

- [ ] **Step 2 : Écrire `setup()` qui peuple les grilles**

`player_shop_config_panel.gd` :
```gdscript
extends PanelContainer

const PoolFilter := preload("res://mods-unpacked/Tanit-ShopConfig/content/logic/pool_filter.gd")

var _player_index: int = 0
var _excluded: Dictionary = {}          # {my_id: true}
var _all_entries: Array = []            # objets+armes compatibles (données natives)

## `character_data` : la CharacterData native du joueur (depuis MENU_NAV).
func setup(player_index: int, character_data) -> void:
    _player_index = player_index
    _excluded.clear()
    _all_entries = _collect_compatible(character_data)
    _populate_grids()

## Remplit _all_entries via CONTENT_LIST filtré par CHAR_COMPAT.
## Remplacer les appels <...> par les symboles exacts de integration-points.md.
func _collect_compatible(character_data) -> Array:
    var entries: Array = []
    for item in CONTENT_LIST.get_all_items():        # <CONTENT_LIST: items>
        if CHAR_COMPAT.is_available(item, character_data):  # <CHAR_COMPAT>
            entries.append(item)
    for weapon in CONTENT_LIST.get_all_weapons():    # <CONTENT_LIST: weapons>
        if CHAR_COMPAT.is_available(weapon, character_data):
            entries.append(weapon)
    return entries

func _populate_grids() -> void:
    # créé dans Task 4.2 (cases à cocher) ; ici, vérifier seulement le comptage
    pass

func get_excluded_ids() -> Dictionary:
    return _excluded.duplicate(true)

func get_total_count() -> int:
    return _all_entries.size()
```
> Les jetons `CONTENT_LIST` / `CHAR_COMPAT` correspondent aux symboles natifs documentés en Phase 0. Les remplacer par les chemins/préchargements et noms réels.

- [ ] **Step 3 : Vérification manuelle (instrumentation temporaire)**

Ajouter temporairement dans `setup()` : `ModLog.info("panel total=%d" % get_total_count())` (le logger de la Task 1.2 ; activer `debug_log` le temps du test). Instancier le panneau depuis un script de test rapide avec un `character_data` connu sans restriction.
Expected : le total loggé correspond au nombre d'objets+armes compatibles attendu (et un perso restreint affiche moins). Retirer l'instrumentation ensuite.

- [ ] **Step 4 : Commit**

```bash
git add mods-unpacked/Tanit-ShopConfig/scenes/player_shop_config_panel.gd mods-unpacked/Tanit-ShopConfig/scenes/player_shop_config_panel.tscn
git commit -m "feat: panneau joueur, collecte des éléments compatibles avec le perso"
```

---

### Task 4.2 : Panneau joueur — cases à cocher (icône + infobulle + bascule)

**Files:**
- Modify: `mods-unpacked/Tanit-ShopConfig/scenes/player_shop_config_panel.gd`

**Interfaces:**
- Consumes: métadonnées d'un élément (icône, nom, description, `my_id`) via `CONTENT_LIST`.
- Produces: `_excluded` reflète l'état coché/décoché ; signal `pool_changed` émis à chaque bascule. Consommé par Tasks 4.3 (garde-fou) et 4.4.

- [ ] **Step 1 : Implémenter la création des cases et la bascule**

Remplacer `_populate_grids()` et ajouter le toggle :
```gdscript
signal pool_changed

func _populate_grids() -> void:
    _clear_grid(%ItemsGrid)
    _clear_grid(%WeaponsGrid)
    for entry in _all_entries:
        var grid: GridContainer = %WeaponsGrid if _is_weapon(entry) else %ItemsGrid
        grid.add_child(_make_cell(entry))

func _make_cell(entry) -> Control:
    var btn := TextureButton.new()
    btn.toggle_mode = true
    btn.button_pressed = true                     # coché = dans le pool par défaut
    btn.texture_normal = entry.icon               # <CONTENT_LIST: icône>
    btn.tooltip_text = "%s\n%s" % [entry.name, entry.description]  # <CONTENT_LIST: nom/desc>
    btn.set_meta("my_id", entry.my_id)
    btn.toggled.connect(_on_cell_toggled.bind(entry.my_id, btn))
    return btn

func _on_cell_toggled(is_in_pool: bool, my_id: String, btn: TextureButton) -> void:
    if is_in_pool:
        _excluded.erase(my_id)
    else:
        _excluded[my_id] = true
    btn.modulate = Color(1, 1, 1) if is_in_pool else Color(0.35, 0.35, 0.35)
    pool_changed.emit()

func _clear_grid(grid: GridContainer) -> void:
    for child in grid.get_children():
        child.queue_free()

func _is_weapon(entry) -> bool:
    return CONTENT_LIST.is_weapon(entry)          # <CONTENT_LIST: discriminant arme/objet>
```

- [ ] **Step 2 : Vérification manuelle**

Instancier le panneau, parcourir à la manette.
Expected : grille d'icônes, tout coché ; décocher grise la case et ajoute l'ID à `_excluded` ; l'infobulle affiche nom + description au focus ; recocher retire de `_excluded`.

- [ ] **Step 3 : Commit**

```bash
git add mods-unpacked/Tanit-ShopConfig/scenes/player_shop_config_panel.gd
git commit -m "feat: cases icône/infobulle et bascule d'exclusion"
```

---

### Task 4.3 : Panneau joueur — filtres, actions rapides, garde-fou, bouton Prêt

**Files:**
- Modify: `mods-unpacked/Tanit-ShopConfig/scenes/player_shop_config_panel.gd`
- Modify: `mods-unpacked/Tanit-ShopConfig/scenes/player_shop_config_panel.tscn`

**Interfaces:**
- Produces: signal `ready_changed(is_ready: bool)` ; méthode `is_ready() -> bool`. La validation respecte le garde-fou global (`ShopConfigStore.has_any_available`). Consommé par Task 4.4.

- [ ] **Step 1 : Ajouter les contrôles à la scène**

Dans le `.tscn`, ajouter une barre de filtres (`OptionButton` tier, `OptionButton` tag, `OptionButton` type d'arme) et trois `Button` : `%ResetButton` (« Tout réinitialiser »), `%DeselectAllButton` (« Tout désélectionner »), `%ExcludeShownButton` (« Exclure tout l'affiché »).

- [ ] **Step 2 : Implémenter filtres + actions + garde-fou**

```gdscript
signal ready_changed(is_ready: bool)

func _apply_filter() -> void:
    # Affiche/masque les cases selon tier/tag/type sélectionnés (navigation seulement).
    for btn in _all_cells():
        btn.visible = _matches_active_filter(btn.get_meta("my_id"))
    %ExcludeShownButton.disabled = not _has_active_filter()

func _on_reset_pressed() -> void:                 # tout dans le pool
    for btn in _all_cells():
        btn.button_pressed = true
    _excluded.clear()
    pool_changed.emit()

func _on_deselect_all_pressed() -> void:          # tout hors du pool
    for btn in _all_cells():
        btn.button_pressed = false
        _excluded[btn.get_meta("my_id")] = true
    pool_changed.emit()

func _on_exclude_shown_pressed() -> void:         # seulement le sous-ensemble filtré
    if not _has_active_filter():
        return
    for btn in _all_cells():
        if btn.visible:
            btn.button_pressed = false
            _excluded[btn.get_meta("my_id")] = true
    pool_changed.emit()

# Garde-fou : il doit rester au moins un candidat dans le pool du joueur.
func _has_any_in_pool() -> bool:
    return (get_total_count() - _excluded.size()) > 0

func _on_pool_changed() -> void:
    var remaining := get_total_count() - _excluded.size()
    var has_any := _has_any_in_pool()
    %ReadyButton.disabled = not has_any
    if not has_any:
        %WarningLabel.visible = true
        %WarningLabel.text = "Garde au moins quelques objets/armes."
        if %ReadyButton.button_pressed:
            %ReadyButton.button_pressed = false   # un pool vidé annule l'état Prêt
        ready_changed.emit(false)
    else:
        %WarningLabel.visible = remaining < _shop_size()
        %WarningLabel.text = "Le magasin proposera moins d'éléments."
        ready_changed.emit(is_ready())

func _on_ready_button_toggled(pressed: bool) -> void:
    if pressed and not _has_any_in_pool():
        %ReadyButton.button_pressed = false       # interdit de valider un pool vide
        return
    ready_changed.emit(is_ready())

func is_ready() -> bool:
    return %ReadyButton.button_pressed and _has_any_in_pool()
```
> Note : le garde-fou global est la règle `(total - exclus) > 0` (au moins un élément achetable, objet **ou** arme). Le store expose la même règle via `has_any_available()` ; elle est la **source de vérité** au moment de l'écriture (Task 4.4), tandis que le panneau l'évalue localement pour l'UI temps réel (les exclusions ne sont écrites dans le store qu'à la validation). `_shop_size()` lit la taille de magasin native (constante repérée en Phase 0) ; à défaut, valeur de repli `4`.

- [ ] **Step 3 : Câbler les signaux**

Dans `_ready()` du panneau : connecter `%ResetButton.pressed` → `_on_reset_pressed`, `%DeselectAllButton.pressed` → `_on_deselect_all_pressed`, `%ExcludeShownButton.pressed` → `_on_exclude_shown_pressed`, `%ReadyButton.toggled` → `_on_ready_button_toggled`, le signal `pool_changed` → `_on_pool_changed`, et chaque `OptionButton` de filtre → `_apply_filter`. Rendre `%ReadyButton` à bascule (`toggle_mode = true`).

- [ ] **Step 4 : Vérification manuelle**

Expected :
- « Tout réinitialiser » recoche tout, `_excluded` vide.
- « Tout désélectionner » décoche tout ; le bouton Prêt devient **désactivé** et l'avertissement « Garde au moins… » s'affiche ; recocher 1 élément réactive Prêt.
- « Exclure tout l'affiché » est désactivé sans filtre ; avec un filtre (ex. un tier), il n'exclut que l'affiché.
- Avertissement discret quand pool réduit mais non vide.

- [ ] **Step 5 : Commit**

```bash
git add mods-unpacked/Tanit-ShopConfig/scenes/player_shop_config_panel.gd mods-unpacked/Tanit-ShopConfig/scenes/player_shop_config_panel.tscn
git commit -m "feat: filtres, actions rapides, garde-fou pool vide, bouton Prêt"
```

---

### Task 4.4 : Écran conteneur responsive + écriture dans le store

**Files:**
- Create: `mods-unpacked/Tanit-ShopConfig/scenes/shop_config_screen.gd`
- Create: `mods-unpacked/Tanit-ShopConfig/scenes/shop_config_screen.tscn`

**Interfaces:**
- Consumes: `PlayerShopConfigPanel.setup/is_ready/get_excluded_ids` (Tasks 4.1–4.3), `ShopConfigStore` (Task 3.1), liste des joueurs + persos (depuis `MENU_NAV`, fournie par l'appelant en Task 5.1).
- Produces: `ShopConfigScreen.setup(players: Array) -> void` (chaque entrée : `{index, character_data}`) ; signal `all_confirmed()` émis quand tous les joueurs sont prêts, **après** avoir écrit les exclusions de chaque joueur dans `ShopConfigStore`. Consommé par Task 5.1.

- [ ] **Step 1 : Construire la scène responsive**

Racine `Control` plein écran nommée `ShopConfigScreen`, avec un `GridContainer` `%PanelsGrid`. Le script règle `columns` selon le nombre de joueurs (1→1, 2→2, 3→2, 4→2) pour obtenir plein écran / moitiés / quarts.

- [ ] **Step 2 : Implémenter setup + agrégation des Prêt**

`shop_config_screen.gd` :
```gdscript
extends Control

const Store := preload("res://mods-unpacked/Tanit-ShopConfig/singletons/shop_config_store.gd")
const PanelScene := preload("res://mods-unpacked/Tanit-ShopConfig/scenes/player_shop_config_panel.tscn")

signal all_confirmed

var _panels: Array = []

func setup(players: Array) -> void:
    Store.reset()                                  # nouvelle partie = état neuf
    %PanelsGrid.columns = 1 if players.size() <= 1 else 2
    for p in players:
        var panel := PanelScene.instantiate()
        %PanelsGrid.add_child(panel)
        panel.setup(p.index, p.character_data)
        panel.ready_changed.connect(_on_any_ready_changed)
        _panels.append(panel)

func _on_any_ready_changed(_is_ready: bool) -> void:
    for panel in _panels:
        if not panel.is_ready():
            return
    _commit_and_advance()

func _commit_and_advance() -> void:
    for panel in _panels:
        Store.set_excluded(panel._player_index, panel.get_excluded_ids())
    all_confirmed.emit()
```

- [ ] **Step 3 : Vérification manuelle (1/2/3/4 joueurs)**

Instancier l'écran avec 1, 2, 3 puis 4 entrées factices.
Expected : layout plein écran / moitiés / quarts ; chaque panneau pilotable indépendamment ; `all_confirmed` n'est émis que lorsque **tous** sont Prêt ; après émission, `Store.get_excluded(i)` contient bien les exclusions de chaque joueur.

- [ ] **Step 4 : Commit**

```bash
git add mods-unpacked/Tanit-ShopConfig/scenes/shop_config_screen.gd mods-unpacked/Tanit-ShopConfig/scenes/shop_config_screen.tscn
git commit -m "feat: écran responsive multi-joueurs + écriture des exclusions dans le store"
```

---

## Phase 5 — Intégration native

> Pour chaque point : utiliser une **script extension** si le script vanilla n'a pas de `class_name` et n'est pas préchargé ; sinon un **script hook** (`add_hook`). Le choix exact est dans `integration-points.md` (Phase 0).

### Task 5.1 : Insérer l'écran entre sélection perso et sélection arme

**Files:**
- Create: `mods-unpacked/Tanit-ShopConfig/extensions/<MENU_NAV.path miroir>.gd` **ou** hook dans `mod_main.gd`
- Modify: `mods-unpacked/Tanit-ShopConfig/mod_main.gd`

**Interfaces:**
- Consumes: `MENU_NAV` (Phase 0), `ShopConfigScreen.setup/all_confirmed` (Task 4.4).
- Produces: à la fin de la sélection de perso, l'écran de config s'affiche ; sur `all_confirmed`, la navigation native vers la sélection d'arme reprend.

- [ ] **Step 1 : Écrire l'interception (variante extension)**

Si `MENU_NAV` est extensible (`res://.../character_selection.gd`, méthode `_on_continue_pressed` p.ex.), créer `extensions/.../character_selection.gd` :
```gdscript
extends "res://<MENU_NAV.path>"   # chemin exact depuis integration-points.md

const ScreenScene := preload("res://mods-unpacked/Tanit-ShopConfig/scenes/shop_config_screen.tscn")

func _on_continue_pressed() -> void:            # <MENU_NAV.method>
    var screen := ScreenScene.instantiate()
    add_child(screen)
    screen.setup(_collect_players())            # construit {index, character_data} par joueur
    screen.all_confirmed.connect(func() -> void:
        screen.queue_free()
        super()                                  # reprend la navigation native vers l'arme
    )

func _collect_players() -> Array:
    # Construire depuis l'état natif relevé en Phase 0 (joueurs + perso choisi).
    return _shopconfig_players                   # <MENU_NAV: accès joueurs/persos>
```

- [ ] **Step 2 : Variante hook (si `class_name`/nécessaire)**

Si extension impossible, dans `mod_main.gd._install_hooks()` :
```gdscript
ModLoaderMod.add_hook(_hook_after_character_select, "res://<MENU_NAV.path>", "<MENU_NAV.method>")
```
et définir `_hook_after_character_select(chain: ModLoaderHookChain, ...)` qui instancie l'écran, puis appelle `chain.execute_next()` seulement sur `all_confirmed`.

- [ ] **Step 3 : Enregistrer l'extension dans mod_main**

Dans `_install_extensions()` (si variante extension) :
```gdscript
ModLoaderMod.install_script_extension("res://mods-unpacked/Tanit-ShopConfig/extensions/<MENU_NAV.path miroir>.gd")
```

- [ ] **Step 4 : Vérification manuelle**

Lancer une partie solo.
Expected : après la sélection du perso, l'écran de config apparaît ; après « Prêt », l'écran de sélection d'arme s'affiche normalement.

- [ ] **Step 5 : Commit**

```bash
git add mods-unpacked/Tanit-ShopConfig/extensions mods-unpacked/Tanit-ShopConfig/mod_main.gd
git commit -m "feat: insertion de l'écran de config dans le flux de menus"
```

---

### Task 5.2 : Filtrer le pool du magasin avec les exclusions

**Files:**
- Create: `mods-unpacked/Tanit-ShopConfig/extensions/<SHOP_POOL.path miroir>.gd` **ou** hook dans `mod_main.gd`
- Modify: `mods-unpacked/Tanit-ShopConfig/mod_main.gd`

**Interfaces:**
- Consumes: `SHOP_POOL` + `PLAYER_INDEX` (Phase 0), `PoolFilter.filter` (Task 2.1), `ShopConfigStore.get_excluded` (Task 3.1).
- Produces: la liste des candidats du magasin de chaque joueur est filtrée des exclusions **avant** la pioche pondérée native ; couches compat perso et exclusion native intactes.

- [ ] **Step 1 : Écrire l'extension (variante extension)**

`extensions/.../shop.gd` :
```gdscript
extends "res://<SHOP_POOL.path>"   # chemin exact depuis integration-points.md

const PoolFilter := preload("res://mods-unpacked/Tanit-ShopConfig/content/logic/pool_filter.gd")
const Store := preload("res://mods-unpacked/Tanit-ShopConfig/singletons/shop_config_store.gd")

# Signature EXACTE à reprendre de integration-points.md (SHOP_POOL.method + params).
func <SHOP_POOL.method>(<SHOP_POOL.params>):
    var candidates: Array = super(<SHOP_POOL.args>)   # pool natif (compat perso + exclusion native déjà appliquées)
    var excluded := Store.get_excluded(<PLAYER_INDEX expr>)
    return PoolFilter.filter(candidates, excluded)
```

- [ ] **Step 2 : Variante hook (si nécessaire)**

Dans `mod_main.gd._install_hooks()` :
```gdscript
ModLoaderMod.add_hook(_hook_filter_shop_pool, "res://<SHOP_POOL.path>", "<SHOP_POOL.method>")
```
```gdscript
func _hook_filter_shop_pool(chain: ModLoaderHookChain, <SHOP_POOL.params>):
    var candidates = chain.execute_next()             # résultat natif
    var excluded := Store.get_excluded(<PLAYER_INDEX expr>)
    return PoolFilter.filter(candidates, excluded)
```

- [ ] **Step 3 : Enregistrer dans mod_main (si variante extension)**

```gdscript
ModLoaderMod.install_script_extension("res://mods-unpacked/Tanit-ShopConfig/extensions/<SHOP_POOL.path miroir>.gd")
```

- [ ] **Step 4 : Vérification manuelle**

Lancer une partie en excluant des objets/armes précis.
Expected : les éléments exclus n'apparaissent **jamais** dans le magasin sur plusieurs vagues ; les éléments gardés apparaissent selon les tiers/vagues normaux ; l'exclusion native (8 slots) fonctionne toujours et s'additionne.

- [ ] **Step 5 : Commit**

```bash
git add mods-unpacked/Tanit-ShopConfig/extensions mods-unpacked/Tanit-ShopConfig/mod_main.gd
git commit -m "feat: filtrage du pool du magasin par les exclusions du joueur"
```

---

## Phase 6 — Recette end-to-end (manuelle)

### Task 6.1 : Checklist QA complète

**Files:**
- Create: `docs/superpowers/notes/qa-checklist.md` (cocher au fur et à mesure)

- [ ] **Step 1 : Dérouler la checklist (spec §7)**

- [ ] Les éléments exclus n'apparaissent jamais dans le magasin sur ≥ 5 vagues.
- [ ] L'exclusion native (8 slots) reste pleinement fonctionnelle et indépendante.
- [ ] Le reroll et le verrouillage (lock) natifs du magasin fonctionnent normalement sur le pool curé.
- [ ] Les interdits de classe sont absents de la grille (tester un perso à restriction d'arme).
- [ ] Layouts corrects en 1 / 2 / 3 / 4 joueurs, chacun pilotable à la manette.
- [ ] Garde-fou : « Tout désélectionner » désactive Prêt ; recocher 1 élément le réactive.
- [ ] Avertissement affiché quand pool réduit mais non vide.
- [ ] « Tout réinitialiser » et « Exclure tout l'affiché » (désactivée sans filtre) se comportent comme spécifié.
- [ ] Garde-fou global : impossible de valider avec pool vide (objet OU arme suffit).
- [ ] Config remise à zéro à la partie suivante (les exclusions ne persistent pas).
- [ ] Build précis : tout désélectionner puis re-cocher 3 éléments → seuls ces éléments dominent le magasin.

- [ ] **Step 2 : Commit**

```bash
git add docs/superpowers/notes/qa-checklist.md
git commit -m "test: checklist QA end-to-end renseignée"
```

---

## Notes de risques

- **Préchargement** : si `SHOP_POOL` ou `MENU_NAV` sont dans des scripts **préchargés**, ni extension ni hook ne s'appliquent (caveat ModLoader). Plan B (à décider en Phase 0) : s'accrocher à un point **en amont** non préchargé qui appelle ces scripts, ou intercepter la construction de la scène concernée.
- **Nom de propriété d'ID** : le plan suppose `my_id` (convention Brotato). À confirmer en Phase 0 ; si différent, ajuster `pool_filter` et les tests.
- **`character_data` au moment du menu** : la disponibilité de l'info perso par joueur à l'étape `MENU_NAV` est à confirmer en Phase 0 ; sinon, récupérer via l'état de run natif.
