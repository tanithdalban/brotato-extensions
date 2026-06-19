extends Control
# Conteneur responsive : un panneau de config par joueur (1=plein écran,
# 2=moitiés, 3-4=quarts). Émet all_confirmed quand tous sont prêts, après
# avoir écrit les exclusions de chaque joueur dans le store de ItemService.
# UI construite en code (pas de .tscn).

signal all_confirmed

const PanelScript = preload("res://mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd")

var _panels := []
var _grid


func _init() -> void:
	# plein écran
	anchor_right = 1.0
	anchor_bottom = 1.0


func setup(players) -> void:
	ItemService.get_shopconfig_store().reset()

	_grid = GridContainer.new()
	_grid.anchor_right = 1.0
	_grid.anchor_bottom = 1.0
	_grid.columns = 1 if players.size() <= 1 else 2
	add_child(_grid)

	for p in players:
		var panel = PanelScript.new()
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
		panel.size_flags_vertical = SIZE_EXPAND_FILL
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
		store.set_excluded(panel.get_player_index(), panel.get_excluded_ids())
	emit_signal("all_confirmed")
