extends PanelContainer
# Un quadrant : grille d'icônes (objets/armes) filtrée par le perso du joueur,
# filtres de navigation, actions rapides, garde-fou, bouton Prêt.
# UI construite intégralement en code (pas de .tscn).

signal ready_changed(is_ready)

const GRID_COLUMNS := 6
const CELL_SIZE := Vector2(64, 64)
const MAX_CLASS_OPTIONS := 10   # nb de classes proposées ; le reste -> « Autre »
# On réutilise le vrai panneau de description du magasin pour l'infobulle riche.
const ItemPopupScene := preload("res://ui/menus/shop/item_popup.tscn")

var _player_index := 0
var _excluded := {}        # { my_id: true }
var _all_entries := []      # ItemParentData compatibles
var _cells := []           # Button (un par entrée)
var _entry_by_id := {}     # my_id -> ItemParentData

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


func setup(player_index, character_data) -> void:
	_player_index = player_index
	_excluded = {}
	_all_entries = _collect_compatible(character_data)
	_build_class_keys_cache()
	_build_ui()
	_populate_grids()
	_refresh_state()


# ---------- collecte filtrée par perso ----------

func _collect_compatible(character_data) -> Array:
	var entries = []
	var no_melee = RunData.get_player_effect_bool(Keys.no_melee_weapons_hash, _player_index)
	var no_ranged = RunData.get_player_effect_bool(Keys.no_ranged_weapons_hash, _player_index)
	var removed_cats = RunData.get_player_effect(Keys.remove_shop_items_hash, _player_index)
	var banned = RunData.players_data[_player_index].banned_items
	var starting_ids = _starting_ids(character_data)
	# Sans slot d'arme (ex. Dompteur, effet weapon_slot=0), la boutique ne
	# propose JAMAIS d'arme (item_service.gd:256) -> on n'affiche aucune arme.
	var has_weapon_slots = RunData.player_has_weapon_slots(_player_index)
	for item in ItemService.items:
		if not item.can_be_looted:
			continue
		if starting_ids.has(item.my_id):
			continue
		if _is_banned(item, banned):
			continue
		if _is_char_banned(item, character_data):
			continue
		if item.is_structure_item() and removed_cats.has(Keys.structure_hash):
			continue
		entries.append(item)
	for weapon in ItemService.weapons:
		if not has_weapon_slots:
			break
		if not weapon.can_be_looted:
			continue
		if starting_ids.has(weapon.my_id):
			continue
		if _is_banned(weapon, banned):
			continue
		if _is_char_banned(weapon, character_data):
			continue
		if no_melee and weapon.type == WeaponType.MELEE:
			continue
		if no_ranged and weapon.type == WeaponType.RANGED:
			continue
		entries.append(weapon)
	return entries


# my_id des armes/objets de DÉPART de la classe : on ne les propose pas dans la
# liste de config (cohérence avec le jeu de base : ils sont donnés/choisis au
# départ, pas filtrables ici).
func _starting_ids(character_data) -> Dictionary:
	var ids := {}
	if character_data == null:
		return ids
	for w in character_data.starting_weapons:
		if w != null:
			ids[w.my_id] = true
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

	# Sélecteur d'onglets Objets / Armes : de VRAIS boutons focusables. Le
	# bandeau interne du TabContainer n'est pas navigable au focus/manette (pas
	# des Control FOCUS_ALL), donc on le masque (tabs_visible = false) et on
	# pilote current_tab via ces boutons.
	var tab_bar = HBoxContainer.new()
	root.add_child(tab_bar)
	_items_tab_button = Button.new()
	_items_tab_button.text = _t("Items", "Objets")
	_items_tab_button.connect("pressed", self, "_on_tab_button_pressed", [0])
	tab_bar.add_child(_items_tab_button)
	_weapons_tab_button = Button.new()
	_weapons_tab_button.text = _t("Weapons", "Armes")
	_weapons_tab_button.connect("pressed", self, "_on_tab_button_pressed", [1])
	tab_bar.add_child(_weapons_tab_button)

	_tabs = TabContainer.new()
	_tabs.tabs_visible = false
	_tabs.size_flags_horizontal = SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_items_grid = _make_grid_tab(_tabs, _t("Items", "Objets"))
	_weapons_grid = _make_grid_tab(_tabs, _t("Weapons", "Armes"))
	_set_active_tab(0)

	# Actions rapides
	var actions = HBoxContainer.new()
	root.add_child(actions)
	var reset_button = Button.new()
	reset_button.text = _t("Reset all", "Tout réinitialiser")
	reset_button.connect("pressed", self, "_on_reset_pressed")
	actions.add_child(reset_button)
	var deselect_button = Button.new()
	deselect_button.text = _t("Deselect all", "Tout désélectionner")
	deselect_button.connect("pressed", self, "_on_deselect_all_pressed")
	actions.add_child(deselect_button)
	_exclude_shown_button = Button.new()
	_exclude_shown_button.text = _t("Exclude all shown", "Exclure tout l'affiché")
	_exclude_shown_button.connect("pressed", self, "_on_exclude_shown_pressed")
	actions.add_child(_exclude_shown_button)

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


func _on_tab_button_pressed(index) -> void:
	_set_active_tab(index)


# Affiche l'onglet voulu et indique l'onglet actif (l'inactif est atténué).
func _set_active_tab(index) -> void:
	_tabs.current_tab = index
	_items_tab_button.modulate = Color(1, 1, 1, 1) if index == 0 else Color(1, 1, 1, 0.5)
	_weapons_tab_button.modulate = Color(1, 1, 1, 1) if index == 1 else Color(1, 1, 1, 0.5)


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
	_refresh_state()


func _set_cell_excluded(my_id, btn, excluded) -> void:
	if excluded:
		_excluded[my_id] = true
	else:
		_excluded.erase(my_id)
	btn.get_meta("overlay").visible = excluded


func _on_cell_focused(entry, btn) -> void:
	if _popup != null:
		_popup.display_item_data(entry, btn)


func _on_cell_unfocused() -> void:
	if _popup != null:
		_popup.hide()


func _on_reset_pressed() -> void:
	_excluded = {}
	for btn in _cells:
		btn.get_meta("overlay").visible = false
	_refresh_state()


func _on_deselect_all_pressed() -> void:
	for btn in _cells:
		_set_cell_excluded(btn.get_meta("my_id"), btn, true)
	_refresh_state()


func _on_exclude_shown_pressed() -> void:
	if not _has_active_filter():
		return
	for btn in _cells:
		if btn.visible:
			_set_cell_excluded(btn.get_meta("my_id"), btn, true)
	_refresh_state()


func _on_ready_toggled(pressed) -> void:
	if pressed and not _has_any_in_pool():
		_ready_button.pressed = false
		return
	emit_signal("ready_changed", is_ready())


func _on_filter_changed(_idx = 0) -> void:
	for btn in _cells:
		btn.visible = _matches_filter(btn.get_meta("my_id"))
	_exclude_shown_button.disabled = not _has_active_filter()


# ---------- filtres ----------

# Tier sélectionné (valeur d'enum) ou -1 pour « Tous tiers ». Sélection par
# INDEX : l'index 0 = « Tous tiers », les suivants pointent dans _TIER_VALUES.
func _selected_tier() -> int:
	var idx = _tier_filter.get_selected()
	return -1 if idx <= 0 else _TIER_VALUES[idx - 1]

func _has_active_filter() -> bool:
	return _selected_tier() != -1 or _class_filter.get_selected() > 0

func _matches_filter(my_id) -> bool:
	var entry = _entry_by_id[my_id]
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
	_ready_button.disabled = not has_any
	if not has_any:
		_warning_label.visible = true
		_warning_label.text = _t("Keep at least some items/weapons.", "Garde au moins quelques objets/armes.")
		if _ready_button.pressed:
			_ready_button.pressed = false
		emit_signal("ready_changed", false)
	else:
		_warning_label.visible = remaining < ItemService.NB_SHOP_ITEMS
		_warning_label.text = _t("The shop will offer fewer items.", "Le magasin proposera moins d'éléments.")
		emit_signal("ready_changed", is_ready())


func is_ready() -> bool:
	return _ready_button.pressed and _has_any_in_pool()

func get_excluded_ids() -> Dictionary:
	return _excluded.duplicate()

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
