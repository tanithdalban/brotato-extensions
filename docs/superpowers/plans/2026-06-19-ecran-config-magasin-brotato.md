# Écran de configuration du magasin (mod Brotato) — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter un écran, entre la sélection du personnage et celle de l'arme de départ, qui permet à chaque joueur de retirer des objets/armes du pool de pioche de **son magasin** (boutique uniquement).

**Architecture:** Mod Brotato (**Godot 3.7** + GodotModLoader 6.x bundlé). Modèle = curation du pool : on ne stocke que les exclusions par joueur. Filtrage **borné au magasin** en surchargeant `ItemService.get_pool()`, activé seulement pendant `ItemService.get_player_shop_items()` via un drapeau de contexte. Écran inséré en surchargeant `CharacterSelection._on_selections_completed()`. Logique de filtrage isolée dans une fonction pure testée (GUT, bundlé).

**Tech Stack:** GDScript (Godot 3), GodotModLoader (`res://addons/mod_loader/`), GUT (`res://addons/gut/`). Projet de dev = Brotato décompilé dans `./Brotato/` ; mod sous `./Brotato/mods-unpacked/Tanith-ShopConfig/`.

## Global Constraints

- **Moteur Godot 3.7** → **GDScript 3** : base `Reference` (pas `RefCounted`), **pas de `static var`**, pas de nœuds `%` (utiliser `onready var x = $Chemin`), signaux via `connect("sig", self, "_methode")`, appel parent via `.methode()` (pas `super()`), `instance()` (pas `instantiate()`), pas de tableaux typés ni lambdas. **Pas de script hooks** : intégration par `ModLoaderMod.install_script_extension()` seulement.
- **Non destructif** : ne jamais écrire dans `RunData.players_data[i].banned_items` (exclusion native 8 slots) ni dans aucune donnée native. Couche additive.
- **Filtrage borné au magasin** : les exclusions n'affectent QUE la boutique (pas les boîtes à objets). Mécanisme : drapeau de contexte posé autour de `get_player_shop_items`, lu dans `get_pool`.
- **On ne stocke que les exclusions**, par joueur, `{my_id: true}`. **Reset** à l'ouverture de l'écran. Aucune persistance entre parties.
- **Pas de garantie absolue** : on retire seulement des candidats ; le tier naturel (`get_tier_from_wave`) est intact.
- **Garde-fou global** : interdiction de valider un pool vide (au moins un élément achetable, objet **ou** arme).
- **Coop 1-4 joueurs** : un pool par joueur ; layout responsive (1 = plein écran, 2 = moitiés, 3-4 = quarts) ; navigation manette par quadrant.
- **ID du mod** : `Tanith-ShopConfig` (namespace `Tanith`, nom `ShopConfig`). Racine `res://mods-unpacked/Tanith-ShopConfig/`.
- **Logger** : tout passe par `ModLog` (namespace `Tanith-ShopConfig`), toggle `debug_log` (config mod, défaut **false**) stocké via `Engine.set_meta` (faute de `static var`). `error` toujours émis.

## Points d'intégration (depuis `docs/superpowers/notes/integration-points.md`)

- Pool magasin : `ItemService.get_player_shop_items(wave, player_index, args)` (item_service.gd:222) ; chokepoint `ItemService.get_pool(item_tier, type)` (item_service.gd:277, retourne un `.duplicate()`).
- `item_service.gd` = `extends Node`, **sans class_name** → extension simple.
- Insertion écran : `CharacterSelection._on_selections_completed()` (character_selection.gd:211 → `_change_scene(MenuData.weapon_selection_scene)` l.220). `CharacterSelection` a un class_name (extension par chemin, à valider au runtime).
- Data élément (`ItemParentData`) : `my_id:String`, `icon:Texture` (`get_icon()`), `name:String` (`get_name_text()`), `tier:enum`. Listes `ItemService.items` / `ItemService.weapons`. `NB_SHOP_ITEMS = 4`.
- Compat perso : effets `RunData.get_player_effect(Keys.no_melee_weapons_hash / no_ranged_weapons_hash / remove_shop_items_hash, player_index)` + `weapon.type` (WeaponType.MELEE/RANGED). Perso courant : `RunData.get_player_character(player_index)`.

---

## File Structure

```
Brotato/mods-unpacked/Tanith-ShopConfig/
├── manifest.json
├── mod_main.gd
├── content/logic/
│   ├── pool_filter.gd                     # PUR : retire les exclusions des candidats
│   └── mod_log.gd                         # logger désactivable (Engine.meta)
├── singletons/
│   └── shop_config_store.gd               # store (exclusions + drapeau contexte magasin)
├── extensions/
│   ├── singletons/item_service.gd         # surcharge get_player_shop_items + get_pool
│   └── ui/menus/run/character_selection.gd# surcharge _on_selections_completed
├── scenes/
│   ├── shop_config_screen.gd / .tscn      # conteneur responsive multi-joueurs
│   └── player_shop_config_panel.gd / .tscn# un quadrant
└── test/
    ├── test_pool_filter.gd                # GUT
    ├── test_shop_config_store.gd          # GUT
    └── test_mod_log.gd                    # GUT
```

---

## Phase 0 — Reconnaissance — ✅ FAIT

`docs/superpowers/notes/integration-points.md` rempli. ModLoader + GUT bundlés (rien à installer). Environnement : Brotato décompilé dans `./Brotato/`, éditeur Godot 3.6.2.

---

## Phase 1 — Squelette du mod & logger

### Task 1.1 : Mod minimal qui se charge

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/manifest.json`
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/mod_main.gd`

**Interfaces:**
- Produces: mod chargé par le ModLoader ; `mod_main.gd` expose `_init()` comme point d'installation des extensions.

- [ ] **Step 1 : Manifest** — `manifest.json` :
```json
{
    "name": "ShopConfig",
    "namespace": "Tanith",
    "version_number": "0.1.0",
    "description": "Écran de configuration du pool du magasin, par joueur, entre sélection perso et arme.",
    "website_url": "",
    "dependencies": [],
    "extra": {
        "godot": {
            "authors": ["Tanith"],
            "tags": ["utility", "ui"],
            "optional_dependencies": [],
            "load_before": [],
            "incompatibilities": [],
            "compatible_mod_loader_version": [],
            "compatible_game_version": [],
            "config_schema": {
                "type": "object",
                "properties": {
                    "debug_log": { "type": "boolean", "description": "Active les logs détaillés de ShopConfig.", "default": false }
                }
            }
        }
    }
}
```

- [ ] **Step 2 : mod_main minimal** — `mod_main.gd` :
```gdscript
extends Node

const LOG_NAME := "Tanith-ShopConfig"

func _init() -> void:
    ModLoaderLog.info("init", LOG_NAME)
    _install_extensions()

func _install_extensions() -> void:
    pass
```

- [ ] **Step 3 : Lancer le jeu** — Run : lancer Brotato depuis l'éditeur (ou `Brotato.exe`). Expected : le log liste `Tanith-ShopConfig` chargé et affiche `init`.

- [ ] **Step 4 : Commit**
```bash
git add Brotato/mods-unpacked/Tanith-ShopConfig/manifest.json Brotato/mods-unpacked/Tanith-ShopConfig/mod_main.gd
git commit -m "feat: squelette du mod ShopConfig qui se charge"
```
> Note : `Brotato/` est git-ignoré globalement. Forcer l'ajout du sous-dossier mod : `git add -f <paths>` (ou retirer `mods-unpacked` de l'ignore). Adapter le `.gitignore` pour ne suivre que `Brotato/mods-unpacked/Tanith-ShopConfig/`.

---

### Task 1.2 : Logger désactivable (TDD via GUT)

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/content/logic/mod_log.gd`
- Modify: `Brotato/mods-unpacked/Tanith-ShopConfig/mod_main.gd`
- Test: `Brotato/mods-unpacked/Tanith-ShopConfig/test/test_mod_log.gd`

**Interfaces:**
- Produces (statique, appelé partout) : `ModLog.set_enabled(v)`, `ModLog.is_enabled()`, `ModLog.info(msg)`, `ModLog.error(msg)`, `ModLog.LOG_NAME == "Tanith-ShopConfig"`. `info` émis seulement si activé ; `error` toujours.

- [ ] **Step 1 : Test qui échoue** — `test/test_mod_log.gd` :
```gdscript
extends "res://addons/gut/test.gd"

const ModLog = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/mod_log.gd")

func after_each():
    ModLog.set_enabled(false)

func test_disabled_by_default():
    ModLog.set_enabled(false)
    assert_false(ModLog.is_enabled())

func test_enable_toggle():
    ModLog.set_enabled(true)
    assert_true(ModLog.is_enabled())
    ModLog.set_enabled(false)
    assert_false(ModLog.is_enabled())

func test_log_name():
    assert_eq(ModLog.LOG_NAME, "Tanith-ShopConfig")

func test_methods_do_not_crash():
    ModLog.set_enabled(true)
    ModLog.info("visible")
    ModLog.error("toujours")
    ModLog.set_enabled(false)
    ModLog.info("muet")
    assert_true(true)
```

- [ ] **Step 2 : Vérifier l'échec** — Run : `godot -s addons/gut/gut_cmdln.gd -gdir=res://mods-unpacked/Tanith-ShopConfig/test -gexit` (depuis `./Brotato/`). Expected : ÉCHEC (mod_log.gd absent).

- [ ] **Step 3 : Implémentation** — `content/logic/mod_log.gd` :
```gdscript
extends Reference
# Logger propre au mod, désactivable. Godot 3 n'a pas de static var :
# le drapeau est stocké en méta globale sur Engine.

const LOG_NAME := "Tanith-ShopConfig"
const _META := "tanith_shopconfig_log_enabled"

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

- [ ] **Step 4 : Vérifier le succès** — Run : même commande GUT. Expected : 4 tests passent.

- [ ] **Step 5 : Câbler le toggle dans mod_main** — remplacer `mod_main.gd` :
```gdscript
extends Node

const LOG_NAME := "Tanith-ShopConfig"
const ModLog = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/mod_log.gd")

func _init() -> void:
    _setup_logging()
    ModLog.info("init")
    _install_extensions()

func _setup_logging() -> void:
    var enabled := false
    var conf = ModLoaderConfig.get_current_config("Tanith-ShopConfig")
    if conf != null and conf.data is Dictionary:
        enabled = bool(conf.data.get("debug_log", false))
    ModLog.set_enabled(enabled)

func _install_extensions() -> void:
    pass
```
> `ModLoaderConfig.get_current_config` est l'API bundlée (`res://addons/mod_loader/api/config.gd`). Le défaut (off) doit tenir même si la config est absente.

- [ ] **Step 6 : Vérif manuelle** — lancer avec `debug_log` à false puis true (menu mods du jeu). Expected : à false, aucun log `info` ; à true, `init` + `info` sous `Tanith-ShopConfig`.

- [ ] **Step 7 : Commit**
```bash
git add -f Brotato/mods-unpacked/Tanith-ShopConfig/content/logic/mod_log.gd Brotato/mods-unpacked/Tanith-ShopConfig/mod_main.gd Brotato/mods-unpacked/Tanith-ShopConfig/test/test_mod_log.gd
git commit -m "feat: logger désactivable via config (défaut off)"
```

---

## Phase 2 — Logique pure de filtrage

### Task 2.1 : `pool_filter.gd` (TDD via GUT)

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/content/logic/pool_filter.gd`
- Test: `Brotato/mods-unpacked/Tanith-ShopConfig/test/test_pool_filter.gd`

**Interfaces:**
- Produces : `PoolFilter.filter(candidates: Array, excluded_ids: Dictionary) -> Array` — garde les candidats dont `.my_id` n'est pas clé de `excluded_ids` ({id: true}). Consommé par Task 4.x (extension item_service).

- [ ] **Step 1 : Test qui échoue** — `test/test_pool_filter.gd` :
```gdscript
extends "res://addons/gut/test.gd"

const PoolFilter = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/pool_filter.gd")

class StubItem:
    extends Reference
    var my_id := ""
    func _init(id):
        my_id = id

func _items(ids):
    var out = []
    for id in ids:
        out.append(StubItem.new(id))
    return out

func _ids(items):
    var out = []
    for it in items:
        out.append(it.my_id)
    return out

func test_removes_excluded():
    var result = PoolFilter.filter(_items(["a", "b", "c"]), {"b": true})
    assert_eq(_ids(result), ["a", "c"])

func test_unknown_id_ignored():
    var result = PoolFilter.filter(_items(["a", "b"]), {"zzz": true})
    assert_eq(_ids(result), ["a", "b"])

func test_empty_exclusions_returns_all():
    var result = PoolFilter.filter(_items(["a", "b"]), {})
    assert_eq(_ids(result), ["a", "b"])

func test_excluding_all_returns_empty():
    var result = PoolFilter.filter(_items(["a", "b"]), {"a": true, "b": true})
    assert_eq(result.size(), 0)

func test_does_not_mutate_input():
    var candidates = _items(["a", "b"])
    PoolFilter.filter(candidates, {"a": true})
    assert_eq(candidates.size(), 2)
```

- [ ] **Step 2 : Vérifier l'échec** — Run GUT (`-gdir=res://mods-unpacked/Tanith-ShopConfig/test`). Expected : ÉCHEC.

- [ ] **Step 3 : Implémentation** — `content/logic/pool_filter.gd` :
```gdscript
extends Reference
# Fonction pure : aucune dépendance au jeu.

# Garde les candidats dont `my_id` n'est pas clé de `excluded_ids` (ensemble {id: true}).
static func filter(candidates: Array, excluded_ids: Dictionary) -> Array:
    var result := []
    for candidate in candidates:
        if not excluded_ids.has(candidate.my_id):
            result.append(candidate)
    return result
```

- [ ] **Step 4 : Vérifier le succès** — Run GUT. Expected : 5 tests passent.

- [ ] **Step 5 : Commit**
```bash
git add -f Brotato/mods-unpacked/Tanith-ShopConfig/content/logic/pool_filter.gd Brotato/mods-unpacked/Tanith-ShopConfig/test/test_pool_filter.gd
git commit -m "feat: fonction pure pool_filter + tests GUT"
```

---

## Phase 3 — Store des exclusions + contexte magasin

### Task 3.1 : `shop_config_store.gd` (TDD via GUT)

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/singletons/shop_config_store.gd`
- Test: `Brotato/mods-unpacked/Tanith-ShopConfig/test/test_shop_config_store.gd`

**Interfaces:**
- Produces (instance unique tenue par l'extension ItemService, Task 4.1) :
  - `reset()`, `set_excluded(player_index:int, ids:Dictionary)`, `get_excluded(player_index:int) -> Dictionary`
  - `has_any_available(player_index:int, total_count:int) -> bool` (garde-fou : exclus < total)
  - `begin_shop_draw(player_index:int)`, `end_shop_draw()`, `is_shop_draw_active() -> bool`, `current_shop_player() -> int`

- [ ] **Step 1 : Test qui échoue** — `test/test_shop_config_store.gd` :
```gdscript
extends "res://addons/gut/test.gd"

const Store = preload("res://mods-unpacked/Tanith-ShopConfig/singletons/shop_config_store.gd")

var store

func before_each():
    store = Store.new()

func test_get_excluded_defaults_empty():
    assert_eq(store.get_excluded(0), {})

func test_set_and_get():
    store.set_excluded(0, {"a": true})
    assert_eq(store.get_excluded(0), {"a": true})

func test_players_independent():
    store.set_excluded(0, {"a": true})
    store.set_excluded(1, {"b": true})
    assert_eq(store.get_excluded(0), {"a": true})
    assert_eq(store.get_excluded(1), {"b": true})

func test_set_stores_copy():
    var src = {"a": true}
    store.set_excluded(0, src)
    src["b"] = true
    assert_eq(store.get_excluded(0), {"a": true})

func test_reset_clears():
    store.set_excluded(0, {"a": true})
    store.begin_shop_draw(0)
    store.reset()
    assert_eq(store.get_excluded(0), {})
    assert_false(store.is_shop_draw_active())

func test_has_any_available():
    store.set_excluded(0, {"a": true})
    assert_true(store.has_any_available(0, 3))
    store.set_excluded(0, {"a": true, "b": true})
    assert_false(store.has_any_available(0, 2))

func test_shop_draw_context():
    assert_false(store.is_shop_draw_active())
    store.begin_shop_draw(2)
    assert_true(store.is_shop_draw_active())
    assert_eq(store.current_shop_player(), 2)
    store.end_shop_draw()
    assert_false(store.is_shop_draw_active())
    assert_eq(store.current_shop_player(), -1)
```

- [ ] **Step 2 : Vérifier l'échec** — Run GUT. Expected : ÉCHEC.

- [ ] **Step 3 : Implémentation** — `singletons/shop_config_store.gd` :
```gdscript
extends Reference
# Store des exclusions par joueur + contexte de pioche magasin.
# Instance unique tenue par l'extension ItemService. Reset à l'ouverture de l'écran.

var _excluded_by_player := {}   # player_index -> { my_id: true }
var _shop_draw_active := false
var _shop_draw_player := -1

func reset() -> void:
    _excluded_by_player.clear()
    _shop_draw_active = false
    _shop_draw_player = -1

func set_excluded(player_index: int, excluded_ids: Dictionary) -> void:
    _excluded_by_player[player_index] = excluded_ids.duplicate()

func get_excluded(player_index: int) -> Dictionary:
    if _excluded_by_player.has(player_index):
        return _excluded_by_player[player_index]
    return {}

func has_any_available(player_index: int, total_count: int) -> bool:
    return get_excluded(player_index).size() < total_count

func begin_shop_draw(player_index: int) -> void:
    _shop_draw_active = true
    _shop_draw_player = player_index

func end_shop_draw() -> void:
    _shop_draw_active = false
    _shop_draw_player = -1

func is_shop_draw_active() -> bool:
    return _shop_draw_active

func current_shop_player() -> int:
    return _shop_draw_player
```

- [ ] **Step 4 : Vérifier le succès** — Run GUT. Expected : 7 tests passent.

- [ ] **Step 5 : Commit**
```bash
git add -f Brotato/mods-unpacked/Tanith-ShopConfig/singletons/shop_config_store.gd Brotato/mods-unpacked/Tanith-ShopConfig/test/test_shop_config_store.gd
git commit -m "feat: store exclusions + contexte magasin + tests GUT"
```

---

## Phase 4 — Intégration magasin (extension ItemService)

### Task 4.1 : Filtrer le pool, borné au magasin

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/extensions/singletons/item_service.gd`
- Modify: `Brotato/mods-unpacked/Tanith-ShopConfig/mod_main.gd`

**Interfaces:**
- Consumes: `PoolFilter` (2.1), `ShopConfigStore` (3.1).
- Produces: `ItemService.get_shopconfig_store()` (instance partagée, lue par l'écran en Task 5.x) ; pendant `get_player_shop_items`, `get_pool` retire les exclusions du joueur courant.

- [ ] **Step 1 : Écrire l'extension** — `extensions/singletons/item_service.gd` :
```gdscript
extends "res://singletons/item_service.gd"

const PoolFilter = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/pool_filter.gd")
const ShopConfigStore = preload("res://mods-unpacked/Tanith-ShopConfig/singletons/shop_config_store.gd")

var _shopconfig_store = ShopConfigStore.new()

func get_shopconfig_store():
    return _shopconfig_store

func get_player_shop_items(wave: int, player_index: int, args) -> Array:
    _shopconfig_store.begin_shop_draw(player_index)
    var result = .get_player_shop_items(wave, player_index, args)
    _shopconfig_store.end_shop_draw()
    return result

func get_pool(item_tier: int, type: int) -> Array:
    var pool = .get_pool(item_tier, type)
    if _shopconfig_store.is_shop_draw_active():
        var excluded = _shopconfig_store.get_excluded(_shopconfig_store.current_shop_player())
        if excluded.size() > 0:
            pool = PoolFilter.filter(pool, excluded)
    return pool
```
> `.get_pool(...)` renvoie déjà un `.duplicate()` (item_service.gd:277-278) → filtrage sans risque de muter les données natives. Le ban natif et le tier naturel restent gérés par le code vanilla.

- [ ] **Step 2 : Installer l'extension** — dans `mod_main.gd._install_extensions()` :
```gdscript
func _install_extensions() -> void:
    ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-ShopConfig/extensions/singletons/item_service.gd")
```

- [ ] **Step 3 : Vérif manuelle (instrumentée)** — temporairement, dans une partie solo, après le chargement : `ItemService.get_shopconfig_store().set_excluded(0, {"item_piggy_bank": true})` (via la console debug du jeu ou un log au lancement de partie), puis ouvrir le magasin sur plusieurs vagues. Expected : l'objet exclu n'apparaît jamais en boutique ; il peut encore sortir d'une boîte à objets (portée magasin-seul) ; aucune régression du ban natif. Retirer l'instrumentation.

- [ ] **Step 4 : Commit**
```bash
git add -f Brotato/mods-unpacked/Tanith-ShopConfig/extensions/singletons/item_service.gd Brotato/mods-unpacked/Tanith-ShopConfig/mod_main.gd
git commit -m "feat: filtrage du pool magasin borné à la boutique"
```

---

## Phase 5 — Interface & insertion dans le flux

### Task 5.1 : Panneau joueur — grille filtrée par perso + cases icône/infobulle

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd`
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.tscn`

**Interfaces:**
- Consumes: `ItemService.items` / `.weapons` + métadonnées (`my_id`, `get_icon()`, `get_name_text()`, `tier`, `type`), `RunData.get_player_effect(...)` (compat perso).
- Produces: `setup(player_index:int, character_data) -> void`, `get_excluded_ids() -> Dictionary`, `get_total_count() -> int`, signal `pool_changed`, signal `ready_changed(is_ready)`, `is_ready() -> bool`.

- [ ] **Step 1 : Scène** — racine `PanelContainer` `PlayerShopConfigPanel` (script attaché). Enfants : `TabContainer` (onglets `Objets`/`Armes`) → `ScrollContainer` → `GridContainer` (`ItemsGrid`, `WeaponsGrid`) ; barre de filtres (`OptionButton` tier, `OptionButton` type d'arme) ; `Label` `WarningLabel` (caché) ; `Button` `ResetButton`, `DeselectAllButton`, `ExcludeShownButton` ; `Button` `ReadyButton` (`toggle_mode = true`).

- [ ] **Step 2 : Construire la grille filtrée par perso** — `player_shop_config_panel.gd` :
```gdscript
extends PanelContainer

signal pool_changed
signal ready_changed(is_ready)

onready var _items_grid = $TabContainer/Objets/ScrollContainer/ItemsGrid
onready var _weapons_grid = $TabContainer/Armes/ScrollContainer/WeaponsGrid
onready var _warning_label = $WarningLabel
onready var _ready_button = $ReadyButton

var _player_index := 0
var _excluded := {}        # { my_id: true }
var _all_entries := []     # ItemParentData compatibles
var _cells := []           # TextureButton

func setup(player_index: int, character_data) -> void:
    _player_index = player_index
    _excluded = {}
    _all_entries = _collect_compatible(character_data)
    _populate_grids()
    _on_pool_changed()

func _collect_compatible(_character_data) -> Array:
    var entries := []
    var no_melee = RunData.get_player_effect_bool(Keys.no_melee_weapons_hash, _player_index)
    var no_ranged = RunData.get_player_effect_bool(Keys.no_ranged_weapons_hash, _player_index)
    var removed_cats = RunData.get_player_effect(Keys.remove_shop_items_hash, _player_index)
    var banned = RunData.players_data[_player_index].banned_items
    for item in ItemService.items:
        if _is_banned(item, banned):
            continue
        if item.is_structure_item() and removed_cats.has(Keys.structure_hash):
            continue
        entries.append(item)
    for weapon in ItemService.weapons:
        if _is_banned(weapon, banned):
            continue
        if no_melee and weapon.type == WeaponType.MELEE:
            continue
        if no_ranged and weapon.type == WeaponType.RANGED:
            continue
        entries.append(weapon)
    return entries

func _is_banned(entry, banned) -> bool:
    for b in banned:
        if (b is String and b == entry.my_id) or b == entry.my_id_hash:
            return true
    return false

func _is_weapon(entry) -> bool:
    return entry is WeaponData

func _populate_grids() -> void:
    _cells = []
    for entry in _all_entries:
        var btn = TextureButton.new()
        btn.toggle_mode = true
        btn.pressed = true                     # coché = dans le pool
        btn.texture_normal = entry.get_icon()
        btn.hint_tooltip = entry.get_name_text()
        btn.set_meta("my_id", entry.my_id)
        btn.connect("toggled", self, "_on_cell_toggled", [entry.my_id, btn])
        _cells.append(btn)
        if _is_weapon(entry):
            _weapons_grid.add_child(btn)
        else:
            _items_grid.add_child(btn)

func _on_cell_toggled(is_in_pool, my_id, btn) -> void:
    if is_in_pool:
        _excluded.erase(my_id)
    else:
        _excluded[my_id] = true
    btn.modulate = Color(1, 1, 1) if is_in_pool else Color(0.35, 0.35, 0.35)
    emit_signal("pool_changed")
    _on_pool_changed()

func get_excluded_ids() -> Dictionary:
    return _excluded.duplicate()

func get_total_count() -> int:
    return _all_entries.size()

func _on_pool_changed() -> void:
    var remaining = get_total_count() - _excluded.size()
    var has_any = remaining > 0
    _ready_button.disabled = not has_any
    if not has_any:
        _warning_label.visible = true
        _warning_label.text = "Garde au moins quelques objets/armes."
        if _ready_button.pressed:
            _ready_button.pressed = false
        emit_signal("ready_changed", false)
    else:
        _warning_label.visible = remaining < ItemService.NB_SHOP_ITEMS
        _warning_label.text = "Le magasin proposera moins d'éléments."
        emit_signal("ready_changed", is_ready())

func is_ready() -> bool:
    return _ready_button.pressed and (get_total_count() - _excluded.size()) > 0
```
> `RunData.get_player_effect_bool` / `Keys.*_hash` / `WeaponType` / `WeaponData` sont natifs (cf. item_service.gd:341-344). Si un nom diffère, l'ajuster d'après le code décompilé.

- [ ] **Step 3 : Vérif manuelle** — instancier le panneau (perso sans restriction, puis perso à restriction d'arme), naviguer manette. Expected : grille d'icônes tout coché ; décocher grise + remplit `_excluded` ; infobulle nom au focus ; un perso « no melee » n'affiche aucune arme de mêlée ; les objets bannis (8-slots) absents.

- [ ] **Step 4 : Commit**
```bash
git add -f Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.tscn
git commit -m "feat: panneau joueur (grille filtrée perso, cases icône/infobulle, garde-fou)"
```

---

### Task 5.2 : Panneau joueur — filtres & actions rapides

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd`
- Modify: `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.tscn`

**Interfaces:**
- Produces: filtres de navigation (tier / type d'arme) ; actions `Tout réinitialiser`, `Tout désélectionner`, `Exclure tout l'affiché` (désactivée sans filtre actif).

- [ ] **Step 1 : Câbler dans `_ready`** :
```gdscript
func _ready() -> void:
    $ResetButton.connect("pressed", self, "_on_reset_pressed")
    $DeselectAllButton.connect("pressed", self, "_on_deselect_all_pressed")
    $ExcludeShownButton.connect("pressed", self, "_on_exclude_shown_pressed")
    $ReadyButton.connect("toggled", self, "_on_ready_toggled")
    $TierFilter.connect("item_selected", self, "_on_filter_changed")
    $WeaponTypeFilter.connect("item_selected", self, "_on_filter_changed")
```

- [ ] **Step 2 : Filtres & actions** :
```gdscript
func _on_filter_changed(_idx = 0) -> void:
    for btn in _cells:
        btn.visible = _matches_filter(btn.get_meta("my_id"))
    $ExcludeShownButton.disabled = not _has_active_filter()

func _on_reset_pressed() -> void:
    for btn in _cells:
        btn.pressed = true
    _excluded = {}
    emit_signal("pool_changed")
    _on_pool_changed()

func _on_deselect_all_pressed() -> void:
    for btn in _cells:
        btn.pressed = false
        _excluded[btn.get_meta("my_id")] = true
    emit_signal("pool_changed")
    _on_pool_changed()

func _on_exclude_shown_pressed() -> void:
    if not _has_active_filter():
        return
    for btn in _cells:
        if btn.visible:
            btn.pressed = false
            _excluded[btn.get_meta("my_id")] = true
    emit_signal("pool_changed")
    _on_pool_changed()

func _on_ready_toggled(pressed) -> void:
    if pressed and (get_total_count() - _excluded.size()) <= 0:
        $ReadyButton.pressed = false
        return
    emit_signal("ready_changed", is_ready())
```
> `_matches_filter(my_id)` et `_has_active_filter()` : comparer le tier/type de l'élément (retrouvé via son entrée dans `_all_entries`) aux valeurs sélectionnées dans `TierFilter`/`WeaponTypeFilter` ; « aucun filtre » = options sur « Tous ». Implémenter avec un index `my_id -> entry` construit dans `_populate_grids`.

- [ ] **Step 3 : Vérif manuelle** — Expected : « Tout réinitialiser » recoche tout ; « Tout désélectionner » désactive Prêt + avertissement, recocher 1 réactive ; « Exclure tout l'affiché » désactivé sans filtre, sinon n'exclut que l'affiché ; avertissement quand pool réduit non vide.

- [ ] **Step 4 : Commit**
```bash
git add -f Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.tscn
git commit -m "feat: filtres de navigation et actions rapides"
```

---

### Task 5.3 : Écran responsive + écriture dans le store

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.gd`
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.tscn`

**Interfaces:**
- Consumes: `PlayerShopConfigPanel` (5.1-5.2), `ItemService.get_shopconfig_store()` (4.1).
- Produces: `setup(players: Array) -> void` (entrées `{index, character_data}`) ; signal `all_confirmed` émis quand tous prêts, **après** avoir écrit les exclusions de chaque joueur dans le store.

- [ ] **Step 1 : Scène** — racine `Control` plein écran `ShopConfigScreen` avec `GridContainer` `PanelsGrid` (script règle `columns`).

- [ ] **Step 2 : Logique** — `shop_config_screen.gd` :
```gdscript
extends Control

signal all_confirmed

const PanelScene = preload("res://mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.tscn")

onready var _grid = $PanelsGrid
var _panels := []

func setup(players: Array) -> void:
    ItemService.get_shopconfig_store().reset()
    _grid.columns = 1 if players.size() <= 1 else 2
    for p in players:
        var panel = PanelScene.instance()
        _grid.add_child(panel)
        panel.setup(p.index, p.character_data)
        panel.connect("ready_changed", self, "_on_ready_changed")
        _panels.append(panel)

func _on_ready_changed(_is_ready) -> void:
    for panel in _panels:
        if not panel.is_ready():
            return
    _commit_and_advance()

func _commit_and_advance() -> void:
    var store = ItemService.get_shopconfig_store()
    for panel in _panels:
        store.set_excluded(panel._player_index, panel.get_excluded_ids())
    emit_signal("all_confirmed")
```

- [ ] **Step 3 : Vérif manuelle (1/2/3/4 joueurs)** — instancier avec 1, 2, 3, 4 entrées factices. Expected : plein écran / moitiés / quarts ; panneaux indépendants ; `all_confirmed` seulement quand tous prêts ; `store.get_excluded(i)` correct après.

- [ ] **Step 4 : Commit**
```bash
git add -f Brotato/mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.gd Brotato/mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.tscn
git commit -m "feat: écran responsive multi-joueurs + écriture des exclusions"
```

---

### Task 5.4 : Insérer l'écran entre sélection perso et arme

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd`
- Modify: `Brotato/mods-unpacked/Tanith-ShopConfig/mod_main.gd`

**Interfaces:**
- Consumes: `ShopConfigScreen` (5.3).
- Produces: après validation des persos, l'écran de config s'affiche ; sur `all_confirmed`, la navigation native reprend.

- [ ] **Step 1 : Extension** — `extensions/ui/menus/run/character_selection.gd` :
```gdscript
extends "res://ui/menus/run/character_selection.gd"

const ScreenScene = preload("res://mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.tscn")

func _on_selections_completed() -> void:
    if ProgressData.settings.zone_is_random:
        _setup_zone(ProgressData.settings.zone_selected)
    for player_index in RunData.get_player_count():
        var character = _player_characters[player_index]
        RunData.add_character(character, player_index)
    if Utils.on_nintendo_nx_or_ounce and RunData.is_coop_run:
        OS.set_max_controller_count(RunData.get_player_count())

    var screen = ScreenScene.instance()
    add_child(screen)
    screen.setup(_shopconfig_players_info())
    screen.connect("all_confirmed", self, "_on_shopconfig_confirmed", [screen])

func _shopconfig_players_info() -> Array:
    var infos := []
    for player_index in RunData.get_player_count():
        infos.append({ "index": player_index, "character_data": RunData.get_player_character(player_index) })
    return infos

func _on_shopconfig_confirmed(screen) -> void:
    screen.queue_free()
    if RunData.some_player_has_weapon_slots():
        _change_scene(MenuData.weapon_selection_scene)
    else:
        RunData.add_starting_items_and_weapons()
        _change_scene(MenuData.difficulty_selection_scene)
```
> Cette surcharge **reproduit** le corps vanilla de `_on_selections_completed` (character_selection.gd:212-223) en insérant notre écran avant le changement de scène. Risque de dérive si Brotato modifie cette fonction → à revérifier à chaque mise à jour du jeu (noté en risques).

- [ ] **Step 2 : Installer l'extension** — ajouter dans `mod_main.gd._install_extensions()` :
```gdscript
    ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd")
```

- [ ] **Step 3 : Vérif manuelle (end-to-end)** — lancer une partie solo : choisir un perso → l'écran de config apparaît → exclure quelques objets/armes → Prêt → sélection d'arme normale → en jeu, les exclus n'apparaissent pas en boutique. Tester aussi un perso sans arme (flux difficulté).

- [ ] **Step 4 : Commit**
```bash
git add -f Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd Brotato/mods-unpacked/Tanith-ShopConfig/mod_main.gd
git commit -m "feat: insertion de l'écran de config dans le flux de menus"
```

---

## Phase 6 — Recette end-to-end (manuelle)

### Task 6.1 : Checklist QA

**Files:**
- Create: `docs/superpowers/notes/qa-checklist.md`

- [ ] **Step 1 : Dérouler (spec §7)**
- [ ] Objets/armes exclus jamais en boutique sur ≥ 5 vagues.
- [ ] Les exclus peuvent encore sortir d'une boîte à objets (portée magasin-seul confirmée).
- [ ] Exclusion native (8 slots) toujours fonctionnelle et indépendante ; reroll/lock natifs OK.
- [ ] Interdits de classe absents de la grille (perso à restriction d'arme).
- [ ] Layouts 1/2/3/4 joueurs, chacun à la manette.
- [ ] « Tout désélectionner » désactive Prêt ; recocher 1 réactive ; garde-fou global (objet OU arme).
- [ ] « Tout réinitialiser » / « Exclure tout l'affiché » (désactivée sans filtre) conformes.
- [ ] Config remise à zéro à la partie suivante.
- [ ] Build précis : tout désélectionner + recocher 3 → seuls ces éléments dominent la boutique.
- [ ] `debug_log` off = pas de logs info ; on = logs sous `Tanith-ShopConfig`.

- [ ] **Step 2 : Commit**
```bash
git add docs/superpowers/notes/qa-checklist.md
git commit -m "test: checklist QA end-to-end renseignée"
```

---

## Notes de risques

- **Extension de `character_selection.gd` (class_name)** : valider au runtime que le ModLoader Brotato applique bien l'extension d'un script à `class_name`. Sinon, replier sur la surcharge de `_change_scene` (intercepter la cible `MenuData.weapon_selection_scene`).
- **Copie du corps de `_on_selections_completed`** : dérive possible aux mises à jour de Brotato. Revérifier `character_selection.gd:211-223` à chaque maj.
- **Noms natifs exacts** (`get_player_effect_bool`, `Keys.*_hash`, `WeaponType`, `WeaponData`, `is_structure_item`) : confirmés partiellement via `item_service.gd` ; valider au premier lancement et ajuster si besoin.
- **Variable d'instance dans l'extension ItemService** (`_shopconfig_store`) : s'assurer que l'extension est installée avant l'instanciation de l'autoload ItemService (installation en `_init` de mod_main = early, OK).
- **Filtres tier/type** (Task 5.2) : nécessitent un index `my_id -> entry` ; le construire dans `_populate_grids`.
