extends "res://singletons/progress_data.gd"
# Fait exister le contenu du mod AVANT que la sauvegarde de la run en cours soit
# désérialisée.
#
# LE BUG (v3.0.0) : quitter une partie en cours, fermer le jeu, puis la reprendre
# rendait un joueur SANS ARME et sans Bomberto — et la sauvegarde était aussitôt
# RÉÉCRITE amputée, donc la perte était définitive. Constaté sur la sauvegarde :
# le fichier d'avant la fermeture contenait `character_bomberman` +
# `weapon_bomb_leech_1` + `weapon_bomb_1` ; celui d'après, `current_character: null`
# et `weapons: []`.
#
# POURQUOI : ProgressData._ready() -> load_game_file() -> ProgressDataLoaderV3
# -> deserialize_run_state() -> PlayerRunData.deserialize(), qui résout perso, armes
# et objets par my_id contre ItemService.characters/weapons/items
# (player_run_data.gd:133/149/165/177). Un id introuvable est jeté SILENCIEUSEMENT :
# il n'y a aucun `else` sur ces `if xxx_data:`.
# Or ProgressData est l'autoload #9 et ItemService le #11 (project.godot). Godot 3
# instancie TOUS les autoloads puis les ajoute à l'arbre dans l'ordre : au moment de
# ce chargement, ItemService ne contient donc que ses tableaux EXPORTÉS par
# item_service.tscn (le contenu vanilla) — notre ItemService._ready(), qui injecte
# les bombes et Bomberto, n'a pas encore tourné. Le NŒUD ItemService, lui, existe
# déjà (c'est aussi pour ça que ProgressData._ready() peut appeler RunData.reset()) :
# on peut donc y écrire dès maintenant.
#
# POURQUOI load_game_file() ET PAS _ready() :
#   - c'est LUI qui désérialise : le point d'accroche le plus précis, et le seul
#     endroit où l'on est sûr que ProgressData.settings est déjà chargé
#     (init_settings/load_settings sont plus haut dans _ready()) — les icônes de
#     bombes lisent les couleurs de tier via ItemService.get_color_from_tier(),
#     qui tape dans ces settings ;
#   - surcharger le _ready() d'un script vanilla est un piège connu : deux mods qui
#     le font en rappelant `._ready()` font tourner le _ready() vanilla DEUX fois
#     (déjà vécu sur ce dépôt). Ici, ça rechargerait la sauvegarde entière.
#
# load_game_file() se rappelle lui-même via _use_fallback_save() ; sans importance,
# register_bomberman_content() est idempotent.

func load_game_file(try_fallback: = true) -> void :
	ItemService.register_bomberman_content()
	.load_game_file(try_fallback)
