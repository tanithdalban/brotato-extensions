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
