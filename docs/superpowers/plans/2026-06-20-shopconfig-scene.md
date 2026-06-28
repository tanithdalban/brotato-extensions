# ShopConfig — Passage en vraie scène + split coop par joueur — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformer l'écran de config du magasin (actuellement superposé à la sélection de perso) en une vraie scène, maillon de la chaîne `character_selection → [shop_config] → weapon/difficulty`, avec une navigation coop indépendante par joueur calquée sur `weapon_selection`.

**Architecture:** L'écran devient une scène autonome (racine `Control` construite en code). On y entre par un **swap manuel de `current_scene`** (la scène est construite en code, pas un `.tscn`), ce qui libère la sélection de perso → plus aucune superposition. On en sort par les `change_scene` standards (cibles `.tscn` de `MenuData`). En coop, on instancie **un `FocusEmulator` par joueur**, borné au panneau du joueur (l'émulateur du joueur 0 couvre aussi le bouton Retour), exactement comme `weapon_selection.tscn`.

**Tech Stack:** Godot 3.7 (GDScript), Brotato ModLoader, mod `Tanith-ShopConfig`.

## Global Constraints

- Godot **3.7**, GDScript (syntaxe 3.x : `onready`, `export`, `yield`, pas de typed `:=` obligatoire).
- UI construite **en code** (pas de fichier `.tscn` pour le mod). Le « vraie scène » se fait par swap manuel de `current_scene`.
- Namespace mod : **`Tanith-ShopConfig`** ; chemins `res://mods-unpacked/Tanith-ShopConfig/...`.
- Le `dist/stage/...` est un artefact de build régénéré : **ne pas l'éditer à la main**.
- Réutiliser les classes natives par `class_name` global : `FocusEmulator`, `FocusEmulatorBaseData` (pas de preload nécessaire).
- Vérification **manuelle en jeu** (pas de harnais Godot exécutable dans l'environnement de dev) ; les tests purs `test/run_tests.gd` restent verts et ne couvrent pas l'UI/coop.
- Référence canonique du split par joueur : `Brotato/ui/menus/run/weapon_selection.tscn` + `weapon_selection.gd`.

---

## Structure de fichiers

- **Modifier** `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.gd`
  → devient la **racine de scène autonome** : construit son UI dans `_ready`, fond opaque, split horizontal des panneaux, gère Retour/Confirmation par `change_scene`, focus solo + `ui_cancel`, et (Task 3) le focus coop par joueur.
- **Modifier** `Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd`
  → `_on_selections_completed` ajoute les persos puis **swap** vers la scène ; suppression de toutes les rustines de superposition (fond, masquage, `CoopService`, emprunt d'émulateurs, signaux).
- **Inchangé** `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd`
  → déjà doté de `get_initial_focus_control()`. Aucun changement requis.

---

## Task 1 : `shop_config_screen.gd` devient une scène autonome (solo correct)

**Files:**
- Modify (réécriture complète) : `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.gd`

**Interfaces:**
- Consumes : `player_shop_config_panel.gd` (`setup(player_index, character_data)`, `is_ready()`, `get_player_index()`, `get_excluded_ids()`, `get_total_count()`, `get_initial_focus_control()`), `ItemService.get_shopconfig_store()` (`reset()`, `set_excluded(idx, dict)`), `RunData`, `MenuData`, `Utils`.
- Produces (consommé par Task 2) :
  - `set_players(players: Array) -> void` — `players` = `[{ "index": int, "character_data": ItemParentData }]`, à appeler **avant** l'ajout au SceneTree.
  - La scène se construit seule dans `_ready` et gère Retour/Confirmation toute seule (aucun signal externe).

- [ ] **Step 1 : Réécrire le fichier**

Remplacer **tout** le contenu de `shop_config_screen.gd` par :

```gdscript
extends Control
# Scène autonome de config du magasin : maillon entre la sélection du perso et
# celle de l'arme. Un panneau par joueur en split HORIZONTAL (calqué sur
# weapon_selection.tscn). En coop, chaque joueur pilote son panneau via un
# FocusEmulator dédié (cf. Task 3). UI construite en code (pas de .tscn).
# Entrée : swap manuel de current_scene (cf. extension). Sortie : change_scene.

const PanelScript = preload("res://mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd")
const ModLog = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/mod_log.gd")

var _players := []          # défini par set_players() avant entrée dans l'arbre
var _panels := []
var _back_button
var _emulators := []        # FocusEmulator par joueur (coop)


func _init() -> void:
	# plein écran
	anchor_right = 1.0
	anchor_bottom = 1.0


# Appelé par l'extension AVANT l'ajout au SceneTree.
func set_players(players) -> void:
	_players = players


func _ready() -> void:
	ItemService.get_shopconfig_store().reset()
	_build_ui()
	_setup_focus()


func _build_ui() -> void:
	# Fond opaque plein écran : la scène n'a rien derrière elle, mais le split
	# laisse des espaces transparents — ce fond garantit un écran net.
	var background = ColorRect.new()
	background.color = Color(0.06, 0.06, 0.08, 1.0)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var root = VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	# Barre supérieure : bouton Retour (libellé natif, suit la langue).
	var topbar = HBoxContainer.new()
	root.add_child(topbar)
	_back_button = Button.new()
	_back_button.text = tr("MENU_BACK")
	_back_button.connect("pressed", self, "_on_back_pressed")
	topbar.add_child(_back_button)

	# Split HORIZONTAL : un panneau par joueur, côte à côte (comme les
	# Inventory1..4 de weapon_selection). Chaque panneau s'étire à parts égales.
	var panels_box = HBoxContainer.new()
	panels_box.size_flags_horizontal = SIZE_EXPAND_FILL
	panels_box.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(panels_box)

	for p in _players:
		var panel = PanelScript.new()
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
		panel.size_flags_vertical = SIZE_EXPAND_FILL
		panels_box.add_child(panel)
		panel.setup(p.index, p.character_data)
		panel.connect("ready_changed", self, "_on_ready_changed")
		_panels.append(panel)


# Focus solo : focus Godot réel. Focus coop : cf. Task 3 (_setup_coop_focus).
func _setup_focus() -> void:
	if RunData.is_coop_run:
		_setup_coop_focus()
	elif _back_button != null:
		_back_button.grab_focus()


func _setup_coop_focus() -> void:
	# Implémenté en Task 3.
	pass


# En solo uniquement : ui_cancel revient en arrière (en coop, c'est le bouton
# Retour, joignable par le joueur 0 — cf. _can_go_back façon weapon_selection).
func _input(event: InputEvent) -> void:
	if not RunData.is_coop_run and event.is_action_released("ui_cancel"):
		_go_back()


func _on_back_pressed() -> void:
	_go_back()


func _on_ready_changed(_is_ready) -> void:
	for panel in _panels:
		if not panel.is_ready():
			return
	_commit_and_advance()


func _commit_and_advance() -> void:
	var store = ItemService.get_shopconfig_store()
	for panel in _panels:
		store.set_excluded(panel.get_player_index(), panel.get_excluded_ids())
	if RunData.some_player_has_weapon_slots():
		_change_scene(MenuData.weapon_selection_scene)
	else:
		RunData.add_starting_items_and_weapons()
		_change_scene(MenuData.difficulty_selection_scene)


# Retour vers la sélection des personnages : on défait l'ajout des persos
# (même logique que weapon_selection._go_back) et on vide les exclusions.
func _go_back() -> void:
	ItemService.get_shopconfig_store().reset()
	for player_index in RunData.get_player_count():
		var character = RunData.get_player_character(player_index)
		Utils.last_elt_selected[player_index] = character
		RunData.remove_character(character, player_index)
	RunData.revert_all_selections()
	RunData.menu_selection_back = true
	_change_scene(MenuData.character_selection_scene)


func _change_scene(path: String) -> void:
	var _error = get_tree().change_scene(path)
```

- [ ] **Step 2 : Vérifier qu'il n'y a pas d'erreur de chargement de script**

Lancer le jeu avec le mod ; ouvrir la console ModLoader.
Attendu : aucune erreur de parsing GDScript sur `shop_config_screen.gd` au chargement.
(La scène n'est pas encore atteignable tant que Task 2 n'est pas faite — c'est normal.)

- [ ] **Step 3 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.gd
git commit -m "refactor(shopconfig): l'ecran devient une scene autonome (split horizontal, sortie par change_scene)"
```

---

## Task 2 : Entrée par swap de scène + suppression des rustines de superposition

**Files:**
- Modify : `Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd`

**Interfaces:**
- Consumes : `ShopConfigScreen.set_players(players)` (Task 1), `_shopconfig_players_info()` (conservé).
- Produces : flux complet **solo** fonctionnel de bout en bout via une vraie scène.

- [ ] **Step 1 : Réécrire le corps de l'override + le helper d'entrée**

Remplacer **tout** le contenu de `extensions/ui/menus/run/character_selection.gd` par :

```gdscript
extends "res://ui/menus/run/character_selection.gd"
# Insère l'écran de config du magasin entre la sélection du perso et celle de
# l'arme. Reproduit le corps vanilla de _on_selections_completed
# (character_selection.gd:211-223) mais, au lieu de changer vers la sélection
# d'arme, on bascule (swap de current_scene) vers NOTRE scène de config.
# À revérifier si Brotato modifie cette fonction.

const ScreenScript = preload("res://mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.gd")
const ModLog = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/mod_log.gd")

func _on_selections_completed() -> void:
	if ProgressData.settings.zone_is_random:
		_setup_zone(ProgressData.settings.zone_selected)
	for player_index in RunData.get_player_count():
		var character = _player_characters[player_index]
		RunData.add_character(character, player_index)
	if Utils.on_nintendo_nx_or_ounce and RunData.is_coop_run:
		OS.set_max_controller_count(RunData.get_player_count())

	ModLog.info("bascule vers la scene de config du magasin")
	var screen = ScreenScript.new()
	screen.set_players(_shopconfig_players_info())
	_change_to_scene_node(screen)


func _shopconfig_players_info() -> Array:
	var infos = []
	for player_index in RunData.get_player_count():
		infos.append({ "index": player_index, "character_data": RunData.get_player_character(player_index) })
	return infos


# Bascule vers une scène construite en code (pas de chemin .tscn) : on l'ajoute
# à la racine, on en fait la current_scene, et on libère la scène courante (la
# sélection de perso). Plus de superposition : l'ancienne scène est détruite.
func _change_to_scene_node(node) -> void:
	var tree = get_tree()
	tree.get_root().add_child(node)
	tree.current_scene = node
	queue_free()
```

- [ ] **Step 2 : Vérifier le flux solo de bout en bout**

Lancer le jeu, partie **solo** :
1. Choisir un perso → valider.
   Attendu : on arrive sur l'écran de config (vraie scène, fond opaque, **aucune** trace de la sélection de perso derrière).
2. Bouton **Retour** (ou Échap).
   Attendu : retour à la sélection de perso, intacte (perso re-sélectionnable, pas d'exclusion résiduelle).
3. Re-valider, exclure quelques éléments, **Prêt**.
   Attendu : passage à la sélection d'arme (ou à la difficulté si le perso n'a pas de slot d'arme). Le magasin en jeu respecte les exclusions.

- [ ] **Step 3 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd
git commit -m "refactor(shopconfig): entree par swap de scene; suppression des rustines de superposition"
```

---

## Task 3 : Focus coop par joueur (un FocusEmulator par panneau)

**Files:**
- Modify : `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.gd` (remplir `_setup_coop_focus`)

**Interfaces:**
- Consumes : `FocusEmulator` (class_name, `res://ui/menus/global/focus_emulator.gd`), `FocusEmulatorBaseData` (class_name), `Utils.focus_player_control(control, player_index, focus_emulator)`, `panel.get_initial_focus_control()`.
- Produces : en coop, chaque joueur navigue uniquement dans son panneau ; le joueur 0 peut aussi atteindre le bouton Retour.

**Notes de conception (issues de `weapon_selection.tscn`) :**
- Les `FocusEmulator` sont des `Node2D` enfants **directs** de la racine de scène, nommés `FocusEmulator1..N`.
- Chaque émulateur a `player_index = i` et un `focus_base_data` = tableau de `FocusEmulatorBaseData`.
- L'émulateur du joueur 0 a **deux** bases : son panneau **et** le bouton Retour. Les autres : leur seul panneau.
- `FocusEmulator._ready` résout `_focus_base_nodes` à partir des `path` des bases. Ici on construit la scène en code : on **renseigne `_focus_base_nodes` et `focus_base_data` directement** après l'ajout (les `path` ne sont pas fiables pour des nœuds créés dynamiquement). `focus_base_data` et `_focus_base_nodes` doivent rester **parallèles** (même longueur, même ordre) car `_find_control_base_data` les indexe ensemble.
- `_set_player_index`/`_ready` appellent `_on_connected_players_updated(CoopService.connected_players)` → fixe le `_device` du joueur. Les joueurs sont déjà connectés à ce stade.

- [ ] **Step 1 : Implémenter `_setup_coop_focus`**

Dans `shop_config_screen.gd`, remplacer :

```gdscript
func _setup_coop_focus() -> void:
	# Implémenté en Task 3.
	pass
```

par :

```gdscript
func _setup_coop_focus() -> void:
	_emulators = []
	for i in _panels.size():
		var panel = _panels[i]
		var emulator = FocusEmulator.new()
		emulator.name = "FocusEmulator%s" % (i + 1)
		emulator.focus_base_data = []   # rempli après l'ajout (cf. ci-dessous)
		emulator.player_index = i
		add_child(emulator)

		# Bornes de navigation du joueur : son panneau (+ le bouton Retour pour
		# le joueur 0). On renseigne les deux tableaux EN PARALLÈLE : la base
		# résolue (_focus_base_nodes) et sa donnée (focus_base_data).
		var bases = [panel]
		var datas = [_make_base_data(panel)]
		if i == 0 and _back_button != null:
			bases.append(_back_button)
			datas.append(_make_base_data(_back_button))
		emulator.focus_base_data = datas
		emulator._focus_base_nodes = bases

		# Focus initial dans le panneau du joueur.
		var control = panel.get_initial_focus_control()
		if control != null:
			Utils.focus_player_control(control, i, emulator)

		_emulators.append(emulator)


func _make_base_data(node):
	var bd = FocusEmulatorBaseData.new()
	bd.path = NodePath()                       # non utilisé (nœuds dynamiques)
	bd.apply_player_color = true
	bd.contain_horizontal_focus = false
	bd.contain_horizontal_focus_exception_paths = []
	bd.contain_vertical_focus = false
	bd.require_entry_from_control_paths = []
	bd.focus_neighbour_top_paths = []
	bd.focus_neighbour_bottom_paths = []
	bd.focus_neighbour_left_paths = []
	bd.focus_neighbour_right_paths = []
	return bd
```

- [ ] **Step 2 : Vérifier le focus coop en jeu**

Lancer une partie **coop à 3 joueurs** (cas le plus révélateur) :
1. Chaque joueur arrive avec un focus dans **son** panneau (liseré à sa couleur).
2. Chaque manette ne navigue **que** dans son propre panneau (cases, filtres, Prêt) — impossible de déborder sur un autre panneau.
3. Le **joueur 0** peut descendre/monter jusqu'au bouton **Retour** et l'activer.
4. Quand **tous** les joueurs passent **Prêt**, on avance vers la sélection d'arme/difficulté.
5. Les exclusions de chaque joueur sont bien appliquées dans son magasin.

Vérifier aussi **2 joueurs** et **4 joueurs** (le split horizontal doit rester lisible).

- [ ] **Step 3 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.gd
git commit -m "feat(shopconfig): navigation coop par joueur via un FocusEmulator par panneau"
```

---

## Auto-revue

**Couverture du besoin :**
- « Vraie scène » → Task 2 (swap `current_scene`, ancienne scène libérée).
- « Plus de superposition / rustines » → Task 2 Step 1 (réécriture sans fond-rustine/masquage/CoopService/emprunt).
- « Split par joueur façon weapon_selection » → Task 1 (HBox horizontal) + Task 3 (un FocusEmulator par panneau, joueur 0 + Retour).
- « Le mécanisme actuel est bancal » → remplacé : grille 2×2 → split horizontal ; emprunt d'émulateurs → émulateurs propres à la scène.

**Cohérence des types :**
- `set_players(players)` ↔ `_shopconfig_players_info()` renvoient le même format `{index, character_data}`. ✔
- `_make_base_data` renvoie un `FocusEmulatorBaseData` ; `focus_base_data`/`_focus_base_nodes` parallèles. ✔
- Sorties via `MenuData.weapon_selection_scene` / `difficulty_selection_scene` / `character_selection_scene` (chemins `.tscn`, `change_scene` standard). ✔

**Risques connus (non testables sans Godot ici) :**
- `FocusEmulator` instancié/configuré en code (vs `.tscn`) : à valider en jeu (Task 3 Step 2). Si le dessin du liseré ou la navigation ne se déclenche pas, vérifier que les émulateurs sont bien enfants **directs** de la racine et visibles.
- `ui_cancel` solo : si conflit avec la fermeture d'un popup d'`OptionButton`, restreindre le `_input` (à traiter seulement si observé).
