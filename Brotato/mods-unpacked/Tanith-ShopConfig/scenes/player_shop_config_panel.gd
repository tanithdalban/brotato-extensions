extends PanelContainer
# Un quadrant : grille d'icônes (objets/armes) filtrée par le perso du joueur,
# filtres de navigation, actions rapides, garde-fou, bouton Prêt.
# UI construite intégralement en code (pas de .tscn).

signal ready_changed(is_ready)

const GRID_COLUMNS := 6
const CELL_SIZE := Vector2(64, 64)

var _player_index := 0
var _excluded := {}        # { my_id: true }
var _all_entries := []      # ItemParentData compatibles
var _cells := []           # Button (toggle), un par entrée
var _entry_by_id := {}     # my_id -> ItemParentData

var _items_grid
var _weapons_grid
var _tier_filter
var _type_filter
var _exclude_shown_button
var _ready_button
var _warning_label


func setup(player_index, character_data) -> void:
	_player_index = player_index
	_excluded = {}
	_all_entries = _collect_compatible(character_data)
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


# ---------- construction de l'UI ----------

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root = VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(root)

	var header = Label.new()
	header.text = "Joueur %d" % (_player_index + 1)
	root.add_child(header)

	# Barre de filtres
	var filter_bar = HBoxContainer.new()
	root.add_child(filter_bar)
	_tier_filter = OptionButton.new()
	_tier_filter.add_item("Tous tiers", -1)
	_tier_filter.add_item("Commun", ItemParentData.Tier.COMMON)
	_tier_filter.add_item("Peu commun", ItemParentData.Tier.UNCOMMON)
	_tier_filter.add_item("Rare", ItemParentData.Tier.RARE)
	_tier_filter.add_item("Légendaire", ItemParentData.Tier.LEGENDARY)
	_tier_filter.connect("item_selected", self, "_on_filter_changed")
	filter_bar.add_child(_tier_filter)
	_type_filter = OptionButton.new()
	_type_filter.add_item("Tout", 0)
	_type_filter.add_item("Objets", 1)
	_type_filter.add_item("Armes", 2)
	_type_filter.connect("item_selected", self, "_on_filter_changed")
	filter_bar.add_child(_type_filter)

	# Onglets Objets / Armes
	var tabs = TabContainer.new()
	tabs.size_flags_horizontal = SIZE_EXPAND_FILL
	tabs.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(tabs)
	_items_grid = _make_grid_tab(tabs, "Objets")
	_weapons_grid = _make_grid_tab(tabs, "Armes")

	# Actions rapides
	var actions = HBoxContainer.new()
	root.add_child(actions)
	var reset_button = Button.new()
	reset_button.text = "Tout réinitialiser"
	reset_button.connect("pressed", self, "_on_reset_pressed")
	actions.add_child(reset_button)
	var deselect_button = Button.new()
	deselect_button.text = "Tout désélectionner"
	deselect_button.connect("pressed", self, "_on_deselect_all_pressed")
	actions.add_child(deselect_button)
	_exclude_shown_button = Button.new()
	_exclude_shown_button.text = "Exclure tout l'affiché"
	_exclude_shown_button.connect("pressed", self, "_on_exclude_shown_pressed")
	actions.add_child(_exclude_shown_button)

	_warning_label = Label.new()
	_warning_label.visible = false
	root.add_child(_warning_label)

	_ready_button = Button.new()
	_ready_button.text = "Prêt"
	_ready_button.toggle_mode = true
	_ready_button.connect("toggled", self, "_on_ready_toggled")
	root.add_child(_ready_button)


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


func _populate_grids() -> void:
	_cells = []
	_entry_by_id = {}
	for entry in _all_entries:
		_entry_by_id[entry.my_id] = entry
		var btn = Button.new()
		btn.toggle_mode = true
		btn.pressed = true
		btn.icon = entry.get_icon()
		btn.hint_tooltip = entry.get_name_text()
		btn.rect_min_size = CELL_SIZE
		btn.set_meta("my_id", entry.my_id)
		btn.connect("toggled", self, "_on_cell_toggled", [entry.my_id, btn])
		_cells.append(btn)
		if _is_weapon(entry):
			_weapons_grid.add_child(btn)
		else:
			_items_grid.add_child(btn)


# ---------- interactions ----------

func _on_cell_toggled(is_in_pool, my_id, btn) -> void:
	if is_in_pool:
		_excluded.erase(my_id)
		btn.modulate = Color(1, 1, 1)
	else:
		_excluded[my_id] = true
		btn.modulate = Color(0.35, 0.35, 0.35)
	_refresh_state()


func _on_reset_pressed() -> void:
	for btn in _cells:
		btn.pressed = true
		btn.modulate = Color(1, 1, 1)
	_excluded = {}
	_refresh_state()


func _on_deselect_all_pressed() -> void:
	for btn in _cells:
		btn.pressed = false
		btn.modulate = Color(0.35, 0.35, 0.35)
		_excluded[btn.get_meta("my_id")] = true
	_refresh_state()


func _on_exclude_shown_pressed() -> void:
	if not _has_active_filter():
		return
	for btn in _cells:
		if btn.visible:
			btn.pressed = false
			btn.modulate = Color(0.35, 0.35, 0.35)
			_excluded[btn.get_meta("my_id")] = true
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

func _selected_tier() -> int:
	return _tier_filter.get_selected_id()

func _selected_type() -> int:
	return _type_filter.get_selected_id()

func _has_active_filter() -> bool:
	return _selected_tier() != -1 or _selected_type() != 0

func _matches_filter(my_id) -> bool:
	var entry = _entry_by_id[my_id]
	var tier_sel = _selected_tier()
	if tier_sel != -1 and entry.tier != tier_sel:
		return false
	var type_sel = _selected_type()
	if type_sel == 1 and _is_weapon(entry):
		return false
	if type_sel == 2 and not _is_weapon(entry):
		return false
	return true


# ---------- état / garde-fou ----------

func _has_any_in_pool() -> bool:
	return (get_total_count() - _excluded.size()) > 0

func _refresh_state() -> void:
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
	return _ready_button.pressed and _has_any_in_pool()

func get_excluded_ids() -> Dictionary:
	return _excluded.duplicate()

func get_total_count() -> int:
	return _all_entries.size()

func get_player_index() -> int:
	return _player_index
