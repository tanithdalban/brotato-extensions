extends "res://ui/menus/run/character_selection.gd"
# Insère l'écran de config du magasin entre la sélection du perso et celle de
# l'arme. Reproduit le corps vanilla de _on_selections_completed
# (character_selection.gd:211-223) en intercalant notre écran avant le
# changement de scène. À revérifier si Brotato modifie cette fonction.

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

	ModLog.info("ouverture de l'écran de config du magasin")
	var screen = ScreenScript.new()
	add_child(screen)
	screen.setup(_shopconfig_players_info())
	screen.connect("all_confirmed", self, "_on_shopconfig_confirmed", [screen])


func _shopconfig_players_info() -> Array:
	var infos = []
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
