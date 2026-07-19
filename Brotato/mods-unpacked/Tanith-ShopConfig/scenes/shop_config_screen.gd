extends Control
# Scène autonome de config du magasin : maillon entre la sélection du perso et
# celle de l'arme. Un panneau par joueur en split HORIZONTAL (calqué sur
# weapon_selection.tscn). En coop, chaque joueur pilote son panneau via un
# FocusEmulator dédié (cf. _setup_coop_focus). UI construite en code (pas de
# .tscn). Entrée : swap manuel de current_scene (cf. extension). Sortie :
# change_scene.

const PanelScript = preload("res://mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd")
const InterceptorScript = preload("res://mods-unpacked/Tanith-ShopConfig/scenes/tab_switch_interceptor.gd")
const ModLog = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/mod_log.gd")
# Thème du jeu de base : posé sur le Control racine de l'écran, Godot 3 le
# propage à TOUTE la descendance (panneaux, dropdowns, boutons, labels). Pose
# 100 % runtime — aucun éditeur, aucun .tres modifié -> aucun risque de corruption.
const BaseTheme := preload("res://resources/themes/base_theme.tres")
# Fond texturé du magasin (même image que l'écran de sélection d'arme, juste
# après le nôtre) : sans lui, les panneaux/boutons du thème (sombres,
# semi-transparents) s'effondrent dans le noir et ne se distinguent plus.
const ShopBackground := preload("res://ui/menus/shop/shop_background.png")
# Polices compactes : la police par défaut du thème fait 40 px, bien trop grosse
# pour la grille dense. On la réduit selon la largeur disponible (nb de joueurs).
const CompactFont2P := preload("res://resources/fonts/actual/base/font_26.tres")
const CompactFont4P := preload("res://resources/fonts/actual/base/font_22.tres")

# DEBUG (test de mise en page uniquement) : force N panneaux à l'écran même avec
# moins de joueurs réels, en réutilisant les données des vrais joueurs (indices
# valides pour RunData). Sert à juger la densité à 3-4 joueurs quand on n'a pas
# assez de manettes. À tester en SOLO (pas de FocusEmulator coop parasite).
# ⚠️ REMETTRE À 0 avant tout commit / packaging.
const DEBUG_FORCE_PANELS := 0

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
	# Pas de reset() ici : le store du singleton ItemService conserve les exclusions
	# pour toute la SESSION de jeu (mémoire run-à-run, sans disque). Les panneaux se
	# pré-chargent depuis lui (cf. _build_ui). Le nettoyage est automatique à la
	# fermeture du jeu (libération mémoire) ; rien n'est écrit sur disque.
	_build_ui()
	_setup_focus()


func _build_ui() -> void:
	# Look du jeu de base : le thème se propage à tous les enfants ajoutés
	# ci-dessous (et dans les panneaux). Les overrides explicites (police du
	# bouton Prêt, modulate des onglets) l'emportent et restent intacts.
	# On DUPLIQUE le thème (jamais muter la ressource partagée du jeu) pour lui
	# imposer une police compacte : celle du thème fait 40 px, trop grosse pour la
	# grille dense — d'autant plus que le split se resserre à 3-4 joueurs.
	var players = _effective_players()
	var compact = CompactFont4P if players.size() >= 3 else CompactFont2P
	var t = BaseTheme.duplicate()
	t.set_default_font(compact)          # Labels (pas de font explicite au thème)
	t.set_font("font", "Button", compact)  # Boutons (font explicite au thème)
	theme = t

	# Fond texturé du magasin, plein écran : donne aux panneaux/boutons
	# semi-transparents du thème un support sur lequel se détacher (sinon tout
	# vire au noir). Même image que l'écran de sélection d'arme qui suit le nôtre.
	var background = TextureRect.new()
	background.texture = ShopBackground
	background.expand = true
	background.stretch_mode = TextureRect.STRETCH_SCALE
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

	# Marge autour des panneaux : les décolle des bords et les fait lire comme des
	# cartes posées sur le fond (façon MarginContainer de weapon_selection).
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_constant_override("margin_left", 20)
	margin.add_constant_override("margin_right", 20)
	margin.add_constant_override("margin_top", 10)
	margin.add_constant_override("margin_bottom", 20)
	root.add_child(margin)

	# Split HORIZONTAL : un panneau par joueur, côte à côte (comme les
	# Inventory1..4 de weapon_selection). Chaque panneau s'étire à parts égales.
	# Séparation pour distinguer les cartes joueur les unes des autres.
	var panels_box = HBoxContainer.new()
	panels_box.add_constant_override("separation", 16)
	panels_box.size_flags_horizontal = SIZE_EXPAND_FILL
	panels_box.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_child(panels_box)

	# Mémoire de session : on pré-charge chaque panneau avec les exclusions déjà
	# mémorisées pour SON slot (player_index), pour qu'elles soient pré-cochées.
	var store = ItemService.get_shopconfig_store()
	for p in players:
		var panel = PanelScript.new()
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
		panel.size_flags_vertical = SIZE_EXPAND_FILL
		panels_box.add_child(panel)
		panel.setup(p.index, p.character_data, store.get_excluded(p.index))
		panel.connect("ready_changed", self, "_on_ready_changed")
		_panels.append(panel)


# Liste des joueurs à afficher. En temps normal = les vrais joueurs. En debug
# (DEBUG_FORCE_PANELS > 0), on complète jusqu'à N en RÉUTILISANT les entrées
# réelles (round-robin) : les indices restent valides pour RunData, seul le
# nombre de panneaux à l'écran change — pour tester la densité 3-4 joueurs.
func _effective_players() -> Array:
	if DEBUG_FORCE_PANELS <= _players.size() or _players.empty():
		return _players
	var out := []
	for i in DEBUG_FORCE_PANELS:
		out.append(_players[i % _players.size()])
	return out


# Focus solo : focus Godot réel. Focus coop : un FocusEmulator par panneau.
func _setup_focus() -> void:
	if RunData.is_coop_run:
		_setup_coop_focus()
	elif _back_button != null:
		_back_button.grab_focus()


func _setup_coop_focus() -> void:
	_emulators = []
	for i in _panels.size():
		var panel = _panels[i]
		var emulator = FocusEmulator.new()
		emulator.name = "FocusEmulator%s" % (i + 1)
		emulator.focus_base_data = []   # rempli après l'ajout (cf. ci-dessous)
		emulator.player_index = i
		add_child(emulator)
		# Le panneau a besoin de son emulateur pour deplacer le focus au changement
		# d'onglet (L1/R1 ou A/E).
		panel.set_focus_emulator(emulator)

		# Bornes de navigation du joueur : son panneau (+ le bouton Retour pour
		# le joueur 0). On renseigne les deux tableaux EN PARALLÈLE : la base
		# résolue (_focus_base_nodes) et sa donnée (focus_base_data), car
		# _find_control_base_data les indexe ensemble.
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

	# Intercepteur clavier A/E ajoute EN DERNIER : il recoit _input avant les
	# FocusEmulator (ordre inverse de l'arbre) pour que A (= ui_left) ne soit pas
	# mangee par la navigation coop. cf. tab_switch_interceptor.gd.
	var interceptor = InterceptorScript.new()
	interceptor.panels = _panels
	add_child(interceptor)


func _make_base_data(_node):
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


# En solo uniquement : ui_cancel ferme d'abord une liste déroulante ouverte ;
# sinon il revient en arrière (en coop, c'est le bouton Retour, joignable par le
# joueur 0 — cf. weapon_selection ; la fermeture de liste coop est gérée par le panneau).
func _input(event: InputEvent) -> void:
	if not RunData.is_coop_run and event.is_action_released("ui_cancel"):
		for panel in _panels:
			if panel.is_dropdown_open():
				panel.close_dropdown()
				return
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
# (même logique que weapon_selection._go_back). On NE vide PAS le store : la
# mémoire de session des exclusions doit survivre à un aller-retour de menu.
func _go_back() -> void:
	for player_index in RunData.get_player_count():
		var character = RunData.get_player_character(player_index)
		Utils.last_elt_selected[player_index] = character
		RunData.remove_character(character, player_index)
	RunData.revert_all_selections()
	RunData.menu_selection_back = true
	_change_scene(MenuData.character_selection_scene)


func _change_scene(path: String) -> void:
	var _error = get_tree().change_scene(path)
