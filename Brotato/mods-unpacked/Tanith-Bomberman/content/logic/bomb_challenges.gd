extends Reference
# Logique PURE de la chaîne de défis des bombes.
# Aucune dépendance aux autoloads du jeu -> testable en headless.
#
# La chaîne : monter une bombe au niveau IV débloque la bombe suivante.
#   Bombe IV -> Glace, Glace IV -> Foudre, Foudre IV -> Poison.
# Le Poison est la fin de la chaîne : il ne débloque rien.

# ItemParentData.Tier : COMMON=0, UNCOMMON=1, RARE=2, LEGENDARY=3.
# Le niveau IV affiché en jeu est donc le tier 3.
const TIER_IV := 3

# weapon_id -> my_id du défi que « posséder cette arme au tier IV » complète.
# ⚠️ La correspondance est EXACTE, jamais un begins_with() : "weapon_bomb" est un
# préfixe de "weapon_bomb_ice", "weapon_bomb_storm" et "weapon_bomb_poison".
const CHAIN := {
	"weapon_bomb": "chal_bomb_ice",
	"weapon_bomb_ice": "chal_bomb_storm",
	"weapon_bomb_storm": "chal_bomb_poison",
}

# my_id du défi -> weapon_id de la bombe qu'il débloque.
const REWARD := {
	"chal_bomb_ice": "weapon_bomb_ice",
	"chal_bomb_storm": "weapon_bomb_storm",
	"chal_bomb_poison": "weapon_bomb_poison",
}

# Défi CACHÉ, sans ChallengeData ni récompense : sa seule fonction est de mémoriser
# qu'on a déjà posé la question de migration au joueur. Poussé tel quel dans
# ProgressData.challenges_completed (que le jeu sauvegarde), il reste invisible :
# l'écran Progression itère le tableau ChallengeService.challenges, pas les hash
# complétés. Aucun fichier maison, aucune persistance à écrire.
const MIGRATION_ASKED_ID := "chal_bomb_migration_asked"


# Le défi complété par l'obtention de cette arme, ou "" si aucun.
static func challenge_for(weapon_id: String, tier: int) -> String:
	if tier != TIER_IV:
		return ""
	return CHAIN.get(weapon_id, "")


# Les bombes que le joueur POSSÈDE sans les avoir GAGNÉES (défi non complété).
# C'est ce qui déclenche la proposition de migration, et exactement ce qu'on
# reverrouille s'il l'accepte. Trié pour être déterministe.
static func unearned_bombs(unlocked_weapon_ids: Array, completed_challenge_ids: Array) -> Array:
	var result := []
	for chal_id in REWARD:
		var weapon_id: String = REWARD[chal_id]
		if unlocked_weapon_ids.has(weapon_id) and not completed_challenge_ids.has(chal_id):
			result.append(weapon_id)
	result.sort()
	return result
