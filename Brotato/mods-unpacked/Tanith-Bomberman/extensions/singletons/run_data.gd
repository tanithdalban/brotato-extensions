extends "res://singletons/run_data.gd"
# Complète les défis des bombes à l'acquisition d'une arme. Deux mécanismes :
#   - la CHAÎNE : une bombe de niveau IV entre dans l'inventaire -> débloque la suivante ;
#   - la COLLECTION : les 4 bombes sont détenues EN MÊME TEMPS -> débloque la sangsue.
#
# POURQUOI add_weapon : c'est l'entonnoir UNIQUE de toute acquisition d'arme —
# fusion en boutique (base_shop.gd:693), achat direct d'une arme de tier IV
# (base_shop.gd:615/620) ET arme de départ. La fusion est le chemin normal, mais le
# magasin propose aussi des armes de tier IV à l'acheter en fin de run : un défi
# accroché à la seule fusion laisserait ce joueur bloqué sans comprendre pourquoi.
#
# Le déblocage prend effet à la RUN SUIVANTE : on ne rappelle PAS init_unlocked_pool()
# à chaud. C'est le comportement de tous les déblocages du jeu (les pools sont
# reconstruits au démarrage de chaque run, run_data.gd:574).

const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")
const BombChallenges = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd")


func add_weapon(weapon: WeaponData, player_index: int, is_selection: bool = false) -> WeaponData:
	var new_weapon = .add_weapon(weapon, player_index, is_selection)
	_try_complete_bomb_challenge(new_weapon)
	_try_complete_leech_challenge(player_index)
	return new_weapon


func _try_complete_bomb_challenge(weapon) -> void:
	if weapon == null:
		return

	var chal_id: String = BombChallenges.challenge_for(weapon.weapon_id, weapon.tier)
	if chal_id == "":
		return

	_complete(chal_id)


# Bombe sangsue : débloquée par la COLLECTION (les 4 bombes en inventaire en même
# temps, tier indifférent), pas par un tier IV. On relit l'inventaire du joueur
# APRÈS l'ajout de l'arme — add_weapon est l'entonnoir unique de toute acquisition.
func _try_complete_leech_challenge(player_index: int) -> void:
	if player_index < 0 or player_index >= players_data.size():
		return

	var weapon_ids := []
	for w in players_data[player_index].weapons:
		if w != null:
			weapon_ids.append(w.weapon_id)

	if not BombChallenges.unlocks_leech(weapon_ids):
		return

	_complete(BombChallenges.LEECH_CHALLENGE)


func _complete(chal_id: String) -> void:
	# Keys.generate_hash alimente aussi hash_to_string (keys.gd:450), dont dépend
	# SteamPlatform.complete_challenge : sans ça, un hash inconnu y planterait.
	var chal_hash: int = Keys.generate_hash(chal_id)
	if ChallengeService.is_challenge_completed(chal_hash):
		return

	# false = ne JAMAIS toucher aux succès de la plateforme. Un mod ne peut pas créer
	# de succès Steam (ils sont déclarés par l'éditeur) ; nos défis restent 100 % locaux.
	ChallengeService.complete_challenge(chal_hash, false)
	ModLog.info("défi complété: " + chal_id)
