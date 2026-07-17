extends "res://singletons/challenge_service.gd"
# Enregistre les défis du mod dans le service de défis du jeu.
#
# POURQUOI ICI, et pas dans l'extension item_service : ChallengeService est un autoload
# chargé APRÈS ItemService (project.godot:2466 puis :2474). Depuis item_service._ready(),
# le singleton ChallengeService n'existe pas encore.
#
# ⚠️ L'injection DOIT précéder l'appel au parent : _generate_hashes() est gardé par le
# drapeau _hashes_generated et ne repassera jamais. En injectant avant ._ready(), nos
# défis sont hashés par le passage natif (qui remplit aussi hash_to_id).

const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")

const _CHALLENGES := [
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_ice_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_storm_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_poison_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_leech_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_frag_data.tres",
]


func _ready() -> void:
	for path in _CHALLENGES:
		var chal = load(path)
		if chal != null and not challenges.has(chal):
			challenges.append(chal)
			ModLog.info("défi enregistré: " + str(chal.my_id))

	._ready()
