extends PanelContainer
# Un quadrant = un joueur : grille d'icônes (objets/armes) filtrée par son perso,
# filtres tier/classe, actions rapides, garde-fou, bouton Prêt. UI construite
# intégralement en code (pas de .tscn). Un panneau de ce type est instancié par
# joueur dans shop_config_screen.gd.
#
# ── CYCLE DE VIE (pour la maintenance) ──────────────────────────────────────
# setup(player_index, character_data)  ← appelé par l'écran avant l'affichage
#   1. _collect_compatible()   : liste les objets/armes proposables à ce perso,
#                                 et déduplique les armes PAR FAMILLE (cf. plus bas)
#   2. _build_class_keys_cache : indexe les « classes » (stats) de chaque élément
#   3. _build_ui()             : crée header, filtres, actions, onglets, grilles…
#   4. _populate_grids()       : une case (Button) par élément collecté
#   5. _refresh_state()        : état initial du bouton Prêt / avertissements
#
# ── INVARIANTS IMPORTANTS ───────────────────────────────────────────────────
# • Identité d'un élément = `my_id` (String). _excluded, _entry_by_id et les
#   métadonnées des cases sont tous indexés par ce my_id.
# • ARMES : une WeaponData distincte existe par tier (même `weapon_id` de famille).
#   On n'affiche qu'UN représentant par famille (le tier le plus bas) ; exclure ce
#   représentant exclut TOUTE la famille (tous les tiers) — cf. get_excluded_ids()
#   et _all_weapon_ids_by_family. Donc tous les comptes (get_total_count, etc.)
#   raisonnent en « familles », pas en tiers.
# • Le filtrage réel du pool se fait ailleurs : l'écran lit get_excluded_ids() et
#   le pousse dans le store ; ItemService (extension) consulte le store à la pioche.
#   Ce panneau ne fait QUE construire l'ensemble des my_id exclus.

signal ready_changed(is_ready)

const GRID_COLUMNS := 6
const CELL_SIZE := Vector2(64, 64)
const MAX_CLASS_OPTIONS := 10   # nb de classes proposées ; le reste -> « Autre »
# On réutilise le vrai panneau de description du magasin pour l'infobulle riche.
const ItemPopupScene := preload("res://ui/menus/shop/item_popup.tscn")
# Helpers purs de calcul du carry-over (owned_ids / carried).
const PoolFilter := preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/pool_filter.gd")

var _player_index := 0
var _excluded := {}        # { my_id: true } (clé = my_id du représentant)
# Carry-over : exclusions mémorisées pour ce slot mais NON affichables avec le
# perso courant (grille filtrée). Gelées ici à l'ouverture (cf. _apply_saved) et
# re-fusionnées à l'export (get_excluded_ids) pour ne pas les perdre au commit.
var _carried_excluded := {}  # { my_id: true }
var _all_entries := []      # ItemParentData compatibles (un représentant/famille d'arme)
var _cells := []           # Button (un par entrée)
var _entry_by_id := {}     # my_id -> ItemParentData

# Armes : une WeaponData distincte par tier partage le même weapon_id de famille.
# On n'affiche qu'un représentant (tier le plus bas) et on aplatit à l'export.
var _all_weapon_ids_by_family := {}   # fkey -> [tous les my_id de la famille]
var _repr_by_family := {}             # fkey -> my_id du représentant affiché
var _starting_weapon_family_keys := {}  # fkey -> true (armes de départ du perso)

# Popup d'info : mécanique native du magasin (touche ui_info F / Y manette), un
# état par joueur (= par panneau). _focused_* mémorise la case survolée pour
# pouvoir réafficher la popup quand on la réactive sans changer de case.
var _hide_popup := false
var _focused_entry = null
var _focused_attach = null

# Changement d'onglet : focus a deplacer dans le nouvel onglet. En coop, on passe
# par le FocusEmulator du joueur (transmis par l'ecran) ; en solo, grab_focus().
var _focus_emulator = null
# Bouton « tout l'affiche » a deux etats : false = exclure, true = inclure.
var _exclude_shown_is_include := false

var _items_grid
var _weapons_grid
var _tabs
var _items_tab_button
var _weapons_tab_button
var _tier_filter
var _class_filter
var _exclude_shown_button
var _ready_button
var _warning_label
var _popup            # ItemPopup (description riche style magasin)

# Filtre de classe unifié : pour une arme = ses stats de scaling
# (WeaponData.stats.scaling_stats) ; pour un objet = les `key` de ses effets
# (ItemData *.tres). Les deux sont normalisés en chaînes (ex. "stat_ranged_damage")
# pour qu'une même classe couvre armes ET objets liés à cette stat.
var _class_keys_by_id := {}   # my_id -> Array[String]
var _filter_keys := []        # (index option - 1) -> clé de classe (String) ; top N
var _class_counts := {}       # clé -> nb d'éléments (pour le tri par effectif)
var _top_key_set := {}        # ensemble des clés du top N
var _has_other := false       # une option « Autre » est-elle nécessaire ?
# Valeurs de tier alignées sur les options du filtre (après « Tous tiers »).
# On sélectionne par INDEX et non par id : add_item(label, -1) ferait coller
# l'id de l'option « tout » avec celui de la 1re vraie option (cf. Godot).
const _TIER_VALUES := [
	ItemParentData.Tier.COMMON,
	ItemParentData.Tier.UNCOMMON,
	ItemParentData.Tier.RARE,
	ItemParentData.Tier.LEGENDARY,
]


# Point d'entrée unique (appelé par l'écran AVANT l'ajout à l'arbre). Reconstruit
# tout le panneau pour ce joueur. Voir l'ordre des étapes dans l'en-tête du fichier.
# `saved_ids` = exclusions mémorisées pour ce slot (ensemble {my_id: true} à plat,
# familles d'armes incluses) ; pré-coche les cases correspondantes et gèle le reste.
func setup(player_index, character_data, saved_ids = {}) -> void:
	_player_index = player_index
	_excluded = {}
	_carried_excluded = {}
	_all_entries = _collect_compatible(character_data)
	_build_class_keys_cache()
	_build_ui()
	_populate_grids()
	_apply_saved(saved_ids)
	_update_exclude_shown_button()
	_refresh_state()


# Restaure les exclusions mémorisées sur la grille du perso courant :
#  • pré-coche chaque case dont le représentant OU un membre de sa famille est mémorisé ;
#  • gèle dans _carried_excluded les ids mémorisés non représentables ici (perso
#    différent → grille différente), pour les conserver au prochain commit.
func _apply_saved(saved_ids) -> void:
	if saved_ids == null or saved_ids.empty():
		return
	# Ensemble des ids que les cases affichées peuvent représenter (objet = son
	# my_id ; arme = toute sa famille). Sert à isoler le carry-over.
	var item_ids := []
	var weapon_family_id_lists := []
	for entry in _all_entries:
		if _is_weapon(entry):
			var fkey = _weapon_family_key(entry)
			weapon_family_id_lists.append(_all_weapon_ids_by_family.get(fkey, [entry.my_id]))
		else:
			item_ids.append(entry.my_id)
	var owned = PoolFilter.owned_ids(item_ids, weapon_family_id_lists)
	_carried_excluded = PoolFilter.carried(saved_ids, owned)
	# Pré-cochage des cases visibles concernées.
	for btn in _cells:
		var my_id = btn.get_meta("my_id")
		var entry = _entry_by_id.get(my_id)
		var hit = false
		if entry != null and _is_weapon(entry):
			for mid in _all_weapon_ids_by_family.get(_weapon_family_key(entry), [my_id]):
				if saved_ids.has(mid):
					hit = true
					break
		else:
			hit = saved_ids.has(my_id)
		if hit:
			_set_cell_excluded(my_id, btn, true)


# ---------- collecte filtrée par perso ----------

func _collect_compatible(character_data) -> Array:
	var entries = []
	var no_melee = RunData.get_player_effect_bool(Keys.no_melee_weapons_hash, _player_index)
	var no_ranged = RunData.get_player_effect_bool(Keys.no_ranged_weapons_hash, _player_index)
	var removed_cats = RunData.get_player_effect(Keys.remove_shop_items_hash, _player_index)
	var banned = RunData.players_data[_player_index].banned_items
	var starting_item_ids = _starting_item_ids(character_data)
	# Sans slot d'arme (ex. Dompteur, effet weapon_slot=0), la boutique ne
	# propose JAMAIS d'arme (item_service.gd:256) -> on n'affiche aucune arme.
	var has_weapon_slots = RunData.player_has_weapon_slots(_player_index)
	for item in ItemService.items:
		if not item.can_be_looted:
			continue
		if starting_item_ids.has(item.my_id):
			continue
		if _is_banned(item, banned):
			continue
		if _is_char_banned(item, character_data):
			continue
		if item.is_structure_item() and removed_cats.has(Keys.structure_hash):
			continue
		entries.append(item)

	# --- Armes : déduplication par famille (un weapon_id, un my_id par tier) ---
	# Map famille -> TOUS ses my_id, en balayant toutes les armes (même tiers non
	# lootables : les exclure est sans effet et garantit que la famille entière
	# sort du pool à l'export).
	_all_weapon_ids_by_family = {}
	for weapon in ItemService.weapons:
		var all_fkey = _weapon_family_key(weapon)
		if not _all_weapon_ids_by_family.has(all_fkey):
			_all_weapon_ids_by_family[all_fkey] = []
		_all_weapon_ids_by_family[all_fkey].append(weapon.my_id)

	# Familles d'armes de départ (garde-fou change 4).
	_starting_weapon_family_keys = {}
	if character_data != null:
		for w in character_data.starting_weapons:
			if w != null:
				_starting_weapon_family_keys[_weapon_family_key(w)] = true

	# Représentant compatible par famille = le tier le plus bas. Les armes de
	# départ ne sont PLUS sautées (elles sont cochables, protégées par le garde-fou).
	_repr_by_family = {}
	var repr_candidates = {}   # fkey -> WeaponData (tier minimal)
	for weapon in ItemService.weapons:
		if not has_weapon_slots:
			break
		if not weapon.can_be_looted:
			continue
		if _is_banned(weapon, banned):
			continue
		if _is_char_banned(weapon, character_data):
			continue
		if no_melee and weapon.type == WeaponType.MELEE:
			continue
		if no_ranged and weapon.type == WeaponType.RANGED:
			continue
		var fkey = _weapon_family_key(weapon)
		if not repr_candidates.has(fkey) or weapon.tier < repr_candidates[fkey].tier:
			repr_candidates[fkey] = weapon
	for fkey in repr_candidates:
		var rep = repr_candidates[fkey]
		_repr_by_family[fkey] = rep.my_id
		entries.append(rep)
	return entries


# Clé de famille d'une arme : son weapon_id si défini, sinon son my_id.
func _weapon_family_key(weapon) -> String:
	return weapon.weapon_id if weapon.weapon_id != "" else weapon.my_id


# my_id des OBJETS de départ de la classe : on ne les propose pas dans la liste
# (cohérence avec le jeu : donnés au départ, pas filtrables ici). Les ARMES de
# départ, elles, sont désormais affichées (cf. garde-fou _starting_weapon_ok).
func _starting_item_ids(character_data) -> Dictionary:
	var ids := {}
	if character_data == null:
		return ids
	for it in character_data.starting_items:
		if it != null:
			ids[it.my_id] = true
	return ids


func _is_banned(entry, banned) -> bool:
	for b in banned:
		if (b is String and b == entry.my_id) or b == entry.my_id_hash:
			return true
	return false


# Bans propres à la classe du perso (comme le fait le jeu pour le pool magasin) :
# liste explicite `banned_items` + groupes `banned_item_groups` (résolus via
# ItemService.item_groups). Voir item_service.gd:420-439.
func _is_char_banned(entry, character_data) -> bool:
	if character_data == null:
		return false
	if character_data.banned_items.has(entry.my_id):
		return true
	for group in character_data.banned_item_groups:
		if ItemService.item_groups.has(group) and ItemService.item_groups[group].has(entry.my_id):
			return true
	return false


func _is_weapon(entry) -> bool:
	return entry is WeaponData


# ---------- i18n (libellés propres au mod : FR sinon EN) ----------

func _t(en, fr) -> String:
	return fr if _is_french() else en

func _is_french() -> bool:
	var loc = ""
	if ProgressData != null and ProgressData.settings != null:
		loc = str(ProgressData.settings.language)
	if loc == "":
		loc = TranslationServer.get_locale()
	return loc.begins_with("fr")


# ---------- construction de l'UI ----------

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root = VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(root)

	var header = Label.new()
	header.text = _t("Player %d", "Joueur %d") % (_player_index + 1)
	root.add_child(header)

	# Barre de filtres
	var filter_bar = HBoxContainer.new()
	root.add_child(filter_bar)
	_tier_filter = OptionButton.new()
	_tier_filter.add_item(_t("All tiers", "Tous tiers"))
	_tier_filter.add_item(_t("Common", "Commun"))
	_tier_filter.add_item(_t("Uncommon", "Peu commun"))
	_tier_filter.add_item(_t("Rare", "Rare"))
	_tier_filter.add_item(_t("Legendary", "Légendaire"))
	_tier_filter.connect("item_selected", self, "_on_filter_changed")
	filter_bar.add_child(_tier_filter)
	# Filtre par classe (stat) — couvre armes (scaling_stats) et objets (key
	# des effets). Construit dynamiquement à partir des classes présentes.
	# Quand une classe est choisie, seuls les éléments liés à cette stat
	# restent, pour que « Exclure tout l'affiché » cible précisément la classe.
	_filter_keys = _collect_class_keys()
	_class_filter = OptionButton.new()
	_class_filter.add_item(_t("All classes", "Toutes classes"))
	for i in _filter_keys.size():
		_class_filter.add_item(_key_label(_filter_keys[i]))
	if _has_other:
		_class_filter.add_item(_t("Other", "Autre"))
	_class_filter.connect("item_selected", self, "_on_filter_changed")
	filter_bar.add_child(_class_filter)
	# Rappel de la touche pour basculer la popup d'info : on affiche l'ICONE reelle
	# de la touche (ui_info = F clavier / Y manette), suivant le joueur et son
	# peripherique (helper natif). Fallback texte si pas d'icone.
	filter_bar.add_child(_make_key_hint("ui_info",
		_t("= show/hide tooltip", "= affiche/masque l'infobulle"), "[F/Y]"))

	# Actions rapides — juste sous les filtres, au-dessus des onglets.
	var actions = HBoxContainer.new()
	root.add_child(actions)
	var reset_button = Button.new()
	reset_button.text = _t("Reset all", "Tout réinitialiser")
	reset_button.hint_tooltip = _t(
		"Clear everything and forget the saved config for this slot.",
		"Tout effacer et oublier la config mémorisée pour ce slot.")
	reset_button.connect("pressed", self, "_on_reset_pressed")
	actions.add_child(reset_button)
	# Bouton a deux etats Exclure <-> Inclure « tout l'affiché » (libelle pilote
	# par l'etat via _update_exclude_shown_button).
	_exclude_shown_button = Button.new()
	_exclude_shown_button.connect("pressed", self, "_on_exclude_shown_pressed")
	actions.add_child(_exclude_shown_button)

	# Sélecteur d'onglets Objets / Armes : de VRAIS boutons focusables. Le
	# bandeau interne du TabContainer n'est pas navigable au focus/manette (pas
	# des Control FOCUS_ALL), donc on le masque (tabs_visible = false) et on
	# pilote current_tab via ces boutons.
	# Raccourcis d'onglet : L1/R1 manette (icone) ou A/E clavier (texte). On flanque
	# chaque bouton d'onglet de son hint de touche.
	var tab_bar = HBoxContainer.new()
	root.add_child(tab_bar)
	tab_bar.add_child(_make_key_hint("ltrigger", "", "A"))
	_items_tab_button = Button.new()
	_items_tab_button.text = _t("Items", "Objets")
	_items_tab_button.connect("pressed", self, "_on_tab_button_pressed", [0])
	tab_bar.add_child(_items_tab_button)
	_weapons_tab_button = Button.new()
	_weapons_tab_button.text = _t("Weapons", "Armes")
	_weapons_tab_button.connect("pressed", self, "_on_tab_button_pressed", [1])
	tab_bar.add_child(_weapons_tab_button)
	tab_bar.add_child(_make_key_hint("rtrigger", "", "E"))

	_tabs = TabContainer.new()
	_tabs.tabs_visible = false
	_tabs.size_flags_horizontal = SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_items_grid = _make_grid_tab(_tabs, _t("Items", "Objets"))
	_weapons_grid = _make_grid_tab(_tabs, _t("Weapons", "Armes"))
	_set_active_tab(0)

	_warning_label = Label.new()
	_warning_label.visible = false
	root.add_child(_warning_label)

	_ready_button = Button.new()
	_ready_button.text = _t("Ready", "Prêt")
	_ready_button.toggle_mode = true
	_ready_button.connect("toggled", self, "_on_ready_toggled")
	root.add_child(_ready_button)

	# Infobulle riche, sur un calque au-dessus de tout (style magasin).
	var layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_popup = ItemPopupScene.instance()
	layer.add_child(_popup)
	_popup.player_index = _player_index
	_popup.hide()


# Hint de touche : icone native du peripherique du joueur pour `action`, sinon
# (pas d'icone, ex. ltrigger/rtrigger au clavier) un libelle texte de repli. Un
# `suffix` optionnel ajoute un libelle apres l'icone (ex. « = … » pour ui_info).
func _make_key_hint(action, suffix, text_fallback) -> Control:
	var box = HBoxContainer.new()
	var tex = CoopService.get_player_key_texture(action, _player_index)
	if tex != null:
		var icon = TextureRect.new()
		icon.texture = tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.rect_min_size = Vector2(28, 28)
		box.add_child(icon)
	else:
		var lbl = Label.new()
		lbl.text = text_fallback
		box.add_child(lbl)
	if suffix != "":
		var sfx = Label.new()
		sfx.text = " " + suffix
		box.add_child(sfx)
	return box


func _make_grid_tab(tabs, title) -> GridContainer:
	var scroll = ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	tabs.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(grid)
	return grid


# Transmis par l'ecran en coop (cf. shop_config_screen._setup_coop_focus) pour
# pouvoir deplacer le focus du joueur lors d'un changement d'onglet.
func set_focus_emulator(emu) -> void:
	_focus_emulator = emu


func _on_tab_button_pressed(index) -> void:
	_set_active_tab(index)


# Affiche l'onglet voulu et indique l'onglet actif (l'inactif est atténué).
# NB : le TabContainer masque la PAGE de l'onglet inactif, mais le `visible` propre
# de chaque case y reste true — d'où _cell_in_current_tab() pour savoir ce qui est
# réellement « à l'écran » (cf. bouton « tout l'affiché »).
func _set_active_tab(index) -> void:
	_tabs.current_tab = index
	_items_tab_button.modulate = Color(1, 1, 1, 1) if index == 0 else Color(1, 1, 1, 0.5)
	_weapons_tab_button.modulate = Color(1, 1, 1, 1) if index == 1 else Color(1, 1, 1, 0.5)
	_update_exclude_shown_button()


# API publique appelee par l'intercepteur clavier coop (cf. tab_switch_interceptor.gd).
func switch_tab(dir) -> void:
	_switch_tab(dir)


# Bascule d'onglet (dir = -1 / +1) via L1/R1 ou A/E, en deplacant le focus dans
# le nouvel onglet (sinon le focus reste sur une cellule masquee).
func _switch_tab(dir) -> void:
	var index = int(clamp(_tabs.current_tab + dir, 0, 1))
	if index == _tabs.current_tab:
		return
	_set_active_tab(index)
	var cell = _first_visible_cell_in_tab(index)
	if cell == null:
		return
	if _focus_emulator != null:
		Utils.focus_player_control(cell, _player_index, _focus_emulator)
	else:
		cell.grab_focus()


# 1re cellule visible (filtre courant) de l'onglet `index` (0 = objets, 1 = armes).
func _first_visible_cell_in_tab(index) -> Button:
	for btn in _cells:
		var is_weapon = _is_weapon(_entry_by_id[btn.get_meta("my_id")])
		if btn.visible and is_weapon == (index == 1):
			return btn
	return null


# Crée une case (Button) par élément collecté et la range dans la grille Objets
# ou Armes selon son type. Remplit _cells (toutes les cases) et _entry_by_id
# (my_id -> donnée), les deux index utilisés partout ensuite.
func _populate_grids() -> void:
	_cells = []
	_entry_by_id = {}
	for entry in _all_entries:
		_entry_by_id[entry.my_id] = entry
		var btn = _make_cell(entry)
		_cells.append(btn)
		if _is_weapon(entry):
			_weapons_grid.add_child(btn)
		else:
			_items_grid.add_child(btn)


func _make_cell(entry) -> Button:
	var btn = Button.new()
	btn.icon = entry.get_icon()
	btn.expand_icon = true
	btn.rect_min_size = CELL_SIZE
	btn.set_meta("my_id", entry.my_id)
	# Indicateur d'exclusion : un voile sombre + une croix, par-dessus l'icône.
	# On n'utilise plus modulate (qui se cumulait avec l'état du bouton).
	var overlay = _make_exclusion_overlay()
	btn.add_child(overlay)
	btn.set_meta("overlay", overlay)
	btn.connect("pressed", self, "_on_cell_pressed", [entry.my_id, btn])
	btn.connect("mouse_entered", self, "_on_cell_focused", [entry, btn])
	btn.connect("focus_entered", self, "_on_cell_focused", [entry, btn])
	btn.connect("mouse_exited", self, "_on_cell_unfocused")
	btn.connect("focus_exited", self, "_on_cell_unfocused")
	return btn


func _make_exclusion_overlay() -> Control:
	var ov = ColorRect.new()
	ov.color = Color(0, 0, 0, 0.6)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.anchor_right = 1.0
	ov.anchor_bottom = 1.0
	ov.margin_left = 0
	ov.margin_top = 0
	ov.margin_right = 0
	ov.margin_bottom = 0
	ov.visible = false
	var cross = Label.new()
	cross.text = "X"
	cross.add_color_override("font_color", Color(1, 0.3, 0.3))
	cross.align = Label.ALIGN_CENTER
	cross.valign = Label.VALIGN_CENTER
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.anchor_right = 1.0
	cross.anchor_bottom = 1.0
	cross.margin_left = 0
	cross.margin_top = 0
	cross.margin_right = 0
	cross.margin_bottom = 0
	ov.add_child(cross)
	return ov


# ---------- interactions ----------

func _on_cell_pressed(my_id, btn) -> void:
	_set_cell_excluded(my_id, btn, not _excluded.has(my_id))
	_update_exclude_shown_button()
	_refresh_state()


func _set_cell_excluded(my_id, btn, excluded) -> void:
	if excluded:
		_excluded[my_id] = true
	else:
		_excluded.erase(my_id)
	btn.get_meta("overlay").visible = excluded


# Entrees globales du panneau, par joueur (chaque panneau ne reagit qu'a SON
# _player_index, faithful au magasin coop) : touche ui_info (F / Y) pour la popup
# d'info, et changement d'onglet (L1/R1 manette, A/E clavier).
func _input(event) -> void:
	if Utils.is_player_info_pressed(event, _player_index):
		_hide_popup = not _hide_popup
		if _hide_popup:
			if _popup != null:
				_popup.hide()
		elif _focused_entry != null and _popup != null:
			_popup.display_item_data(_focused_entry, _focused_attach)
		return
	# Changement d'onglet Objets/Armes — manette L1/R1 (par joueur, le FocusEmulator
	# coop ignore deja ltrigger/rtrigger), clavier A/E pour le joueur au clavier.
	#
	# MAINTENANCE — pourquoi A/E est gere a DEUX endroits :
	# En SOLO, pas de FocusEmulator : ce _input voit la touche en premier -> la
	# branche clavier ci-dessous suffit. En COOP, le FocusEmulator de chaque joueur
	# CONSOMME les touches de deplacement (A = ui_left) avant nous, donc cette
	# branche ne verrait jamais le A coop. C'est pourquoi tab_switch_interceptor.gd
	# (ajoute en dernier dans l'ecran -> recoit _input AVANT les FocusEmulator) gere
	# le clavier en coop. Les deux ne font jamais double emploi : en coop
	# l'intercepteur consomme l'event avant que cette branche ne le voie.
	if Utils.is_player_action_pressed(event, _player_index, "ltrigger"):
		_switch_tab(-1)
		get_tree().set_input_as_handled()
	elif Utils.is_player_action_pressed(event, _player_index, "rtrigger"):
		_switch_tab(1)
		get_tree().set_input_as_handled()
	elif (event is InputEventKey and event.pressed and not event.echo
			and (not RunData.is_coop_run or not CoopService.is_player_using_gamepad(_player_index))):
		# On matche le CARACTERE tape (event.unicode), pas le scancode : ce dernier
		# suit la position US (sur AZERTY, la touche « A » a le scancode du « Q »).
		# Repli sur scancode pour les cas ou unicode serait absent (QWERTY).
		var ch = char(event.unicode).to_lower()
		if ch == "a" or event.scancode == KEY_A:
			_switch_tab(-1)
			get_tree().set_input_as_handled()
		elif ch == "e" or event.scancode == KEY_E:
			_switch_tab(1)
			get_tree().set_input_as_handled()


func _on_cell_focused(entry, btn) -> void:
	_focused_entry = entry
	_focused_attach = btn
	if _popup != null and not _hide_popup:
		_popup.display_item_data(entry, btn)


func _on_cell_unfocused() -> void:
	_focused_entry = null
	if _popup != null:
		_popup.hide()


# « Repartir de zéro » : vide la sélection courante ET le carry-over mémorisé.
# Après validation « Prêt », le store mémorise une liste vide pour ce slot = la
# config sauvegardée de la session est oubliée.
func _on_reset_pressed() -> void:
	_excluded = {}
	_carried_excluded = {}
	for btn in _cells:
		btn.get_meta("overlay").visible = false
	_update_exclude_shown_button()
	_refresh_state()


# Bouton a deux etats, borne a l'onglet + filtre courant : exclut tout l'affiche,
# ou (si tout l'affiche est deja exclu) le re-inclut.
func _on_exclude_shown_pressed() -> void:
	var target_excluded = not _exclude_shown_is_include
	for btn in _cells:
		if _cell_shown(btn):
			_set_cell_excluded(btn.get_meta("my_id"), btn, target_excluded)
	_update_exclude_shown_button()
	_refresh_state()


# Met a jour libelle/etat du bouton selon l'affiche courant (onglet + filtre) :
# tout affiche deja exclu -> propose « Inclure » ; sinon « Exclure ». Desactive
# s'il n'y a rien d'affiche dans l'onglet courant.
func _update_exclude_shown_button() -> void:
	if _exclude_shown_button == null:
		return
	var shown_count = 0
	var excluded_count = 0
	for btn in _cells:
		if _cell_shown(btn):
			shown_count += 1
			if _excluded.has(btn.get_meta("my_id")):
				excluded_count += 1
	_exclude_shown_button.disabled = shown_count == 0
	_exclude_shown_is_include = shown_count > 0 and excluded_count == shown_count
	if _exclude_shown_is_include:
		_exclude_shown_button.text = _t("Include all shown", "Inclure tout l'affiché")
	else:
		_exclude_shown_button.text = _t("Exclude all shown", "Exclure tout l'affiché")


func _on_ready_toggled(pressed) -> void:
	if pressed and (not _has_any_in_pool() or not _starting_weapon_ok()):
		_ready_button.pressed = false
		return
	emit_signal("ready_changed", is_ready())


func _on_filter_changed(_idx = 0) -> void:
	for btn in _cells:
		btn.visible = _matches_filter(btn.get_meta("my_id"))
	_update_exclude_shown_button()


# Une cellule appartient a l'onglet courant (0 = objets, 1 = armes).
func _cell_in_current_tab(btn) -> bool:
	return _is_weapon(_entry_by_id[btn.get_meta("my_id")]) == (_tabs.current_tab == 1)

# « Affiche » = visible (filtre tier/classe) ET dans l'onglet courant.
func _cell_shown(btn) -> bool:
	return btn.visible and _cell_in_current_tab(btn)


# ---------- filtres ----------

# Tier sélectionné (valeur d'enum) ou -1 pour « Tous tiers ». Sélection par
# INDEX : l'index 0 = « Tous tiers », les suivants pointent dans _TIER_VALUES.
func _selected_tier() -> int:
	var idx = _tier_filter.get_selected()
	return -1 if idx <= 0 else _TIER_VALUES[idx - 1]

func _matches_filter(my_id) -> bool:
	var entry = _entry_by_id[my_id]
	# Le filtre de tier est ignoré pour les armes (un seul représentant/famille,
	# raretés confondues) : elles restent toujours visibles. La classe s'applique.
	if not _is_weapon(entry):
		var tier = _selected_tier()
		if tier != -1 and entry.tier != tier:
			return false
	return _matches_class(my_id)

# Index 0 = « Toutes classes » ; 1..N = une classe du top N ; dernier (si
# présent) = « Autre » = éléments couverts par aucune classe du top N.
func _matches_class(my_id) -> bool:
	var idx = _class_filter.get_selected()
	if idx <= 0:
		return true
	if _has_other and idx == _filter_keys.size() + 1:
		return not _has_any_top_key(my_id)
	return _class_keys_by_id.get(my_id, []).has(_filter_keys[idx - 1])

func _has_any_top_key(my_id) -> bool:
	for k in _class_keys_by_id.get(my_id, []):
		if _top_key_set.has(k):
			return true
	return false


# ---------- classes (scaling armes / key effets objets) ----------
# Une « classe » est une stat (ex. "stat_ranged_damage"). Le filtre de classe
# regroupe armes (par leurs scaling_stats) et objets (par la `key` de leurs effets)
# sous ces stats. Calculé une fois (cache) au setup, car _all_entries est figé.

# Pré-calcule, pour chaque élément, ses clés de classe (my_id -> [stats]).
func _build_class_keys_cache() -> void:
	_class_keys_by_id = {}
	for entry in _all_entries:
		_class_keys_by_id[entry.my_id] = _compute_class_keys(entry)


# Clés de classe d'un élément, normalisées en chaînes (ex. "stat_ranged_damage").
func _compute_class_keys(entry) -> Array:
	var keys := []
	if _is_weapon(entry):
		if entry.stats != null and entry.stats.scaling_stats is Array:
			for pair in entry.stats.scaling_stats:
				if pair is Array and pair.size() > 0:
					var h = pair[0]
					var s = Keys.hash_to_string[h] if (h is int and Keys.hash_to_string.has(h)) else str(h)
					if s != "" and not keys.has(s):
						keys.append(s)
	else:
		if entry.effects is Array:
			for effect in entry.effects:
				var k = effect.get("key")
				if k != null and k is String and k != "" and not keys.has(k):
					keys.append(k)
	return keys


# Classes les plus fournies : on compte le nombre d'éléments par classe et on
# garde les MAX_CLASS_OPTIONS plus grosses. Le reste (et les éléments sans
# classe) sera regroupé sous « Autre » (_has_other).
func _collect_class_keys() -> Array:
	_class_counts = {}
	for entry in _all_entries:
		for k in _class_keys_by_id.get(entry.my_id, []):
			_class_counts[k] = _class_counts.get(k, 0) + 1
	var keys = _class_counts.keys()
	keys.sort_custom(self, "_cmp_class_count")
	var top := []
	_top_key_set = {}
	for k in keys:
		if top.size() >= MAX_CLASS_OPTIONS:
			break
		top.append(k)
		_top_key_set[k] = true
	# « Autre » utile s'il existe au moins un élément non couvert par le top.
	_has_other = false
	for entry in _all_entries:
		if not _has_any_top_key(entry.my_id):
			_has_other = true
			break
	return top


# Tri : effectif décroissant, puis alphabétique pour la stabilité.
func _cmp_class_count(a, b) -> bool:
	var ca = _class_counts.get(a, 0)
	var cb = _class_counts.get(b, 0)
	if ca == cb:
		return a < b
	return ca > cb


# Label d'une classe : on réutilise la traduction du jeu (clé en MAJUSCULES,
# ex. "stat_armor" -> tr("STAT_ARMOR")), ce qui suit la langue du jeu. Si pas
# de traduction, on nettoie la clé brute.
func _key_label(k) -> String:
	var up = k.to_upper()
	var t = tr(up)
	if t != up:
		return t
	return k.replace("stat_", "").replace("_", " ").capitalize()


# ---------- état / garde-fou ----------

func _has_any_in_pool() -> bool:
	return (get_total_count() - _excluded.size()) > 0

func _refresh_state() -> void:
	var remaining = get_total_count() - _excluded.size()
	var has_any = remaining > 0
	if not has_any:
		_ready_button.disabled = true
		_warning_label.visible = true
		_warning_label.text = _t("Keep at least some items/weapons.", "Garde au moins quelques objets/armes.")
		if _ready_button.pressed:
			_ready_button.pressed = false
		emit_signal("ready_changed", false)
	elif not _starting_weapon_ok():
		_ready_button.disabled = true
		_warning_label.visible = true
		_warning_label.text = _t("Keep at least one of your starting weapons.", "Garde au moins une de tes armes de départ.")
		if _ready_button.pressed:
			_ready_button.pressed = false
		emit_signal("ready_changed", false)
	else:
		_ready_button.disabled = false
		_warning_label.visible = remaining < ItemService.NB_SHOP_ITEMS
		_warning_label.text = _t("The shop will offer fewer items.", "Le magasin proposera moins d'éléments.")
		emit_signal("ready_changed", is_ready())


# Garde-fou armes de départ : au moins une famille d'arme de départ doit rester
# disponible. Famille non affichée (non lootable, etc.) = compte comme dispo.
func _starting_weapon_ok() -> bool:
	if _starting_weapon_family_keys.empty():
		return true
	for fkey in _starting_weapon_family_keys:
		if not _repr_by_family.has(fkey):
			return true
		if not _excluded.has(_repr_by_family[fkey]):
			return true
	return false


func is_ready() -> bool:
	return _ready_button.pressed and _has_any_in_pool() and _starting_weapon_ok()

# Exclusions à plat pour le store/pool : pour une arme, on émet TOUS les my_id de
# sa famille (tous tiers) ; pour un objet, son my_id tel quel.
func get_excluded_ids() -> Dictionary:
	var out := {}
	for key in _excluded:
		var entry = _entry_by_id.get(key)
		if entry != null and _is_weapon(entry):
			var fkey = _weapon_family_key(entry)
			for mid in _all_weapon_ids_by_family.get(fkey, [entry.my_id]):
				out[mid] = true
		else:
			out[key] = true
	# Carry-over : exclusions mémorisées non affichables avec ce perso (déjà à plat).
	for cid in _carried_excluded:
		out[cid] = true
	return out

# Nombre d'éléments proposables = nb d'objets + nb de FAMILLES d'armes (un
# représentant par famille). Sert au calcul du garde-fou « reste-t-il du stock ? ».
func get_total_count() -> int:
	return _all_entries.size()

func get_player_index() -> int:
	return _player_index


# Contrôle où ancrer le focus d'un joueur à l'ouverture (sa première case ;
# le bouton Prêt si le pool est vide). Utilisé par le routage de focus coop.
func get_initial_focus_control() -> Control:
	if _cells.size() > 0:
		return _cells[0]
	return _ready_button
