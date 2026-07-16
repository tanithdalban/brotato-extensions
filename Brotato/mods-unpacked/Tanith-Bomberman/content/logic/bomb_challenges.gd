extends Reference
# Logique PURE de la chaîne de défis des bombes.
# Aucune dépendance aux autoloads du jeu -> testable en headless.
#
# Deux mécanismes de déblocage, distincts :
#
# 1. La CHAÎNE (CHAIN) : monter une bombe au niveau IV débloque la suivante.
#      Bombe IV -> Glace, Glace IV -> Foudre, Foudre IV -> Poison.
#      Puis, en bout de parcours : Sangsue IV -> Frag.
#    Le Poison est la fin de la BRANCHE ÉLÉMENTAIRE : il ne débloque rien.
#    La Frag est la fin de TOUT l'arbre : elle ne débloque rien non plus.
#
# 2. La COLLECTION (unlocks_leech) : détenir les 4 bombes EN MÊME TEMPS, quels que
#    soient leurs tiers, débloque la Bombe sangsue. Ça immobilise 4 des 6 slots
#    d'arme : c'est un sacrifice de build délibéré, et c'est tout l'intérêt du défi.
#
# ⚠️ La sangsue n'est donc PAS dans CHAIN en tant que RÉCOMPENSE (qui est indexé
# « arme X au tier IV »), mais elle y est comme SOURCE (Sangsue IV -> Frag) — et elle
# EST dans REWARD, ce qui suffit à ce que le popup de migration la couvre.
#
# ⚠️ La Frag n'entre PAS dans LEECH_REQUIRED : le défi de la sangsue exige les 4 bombes
# d'ORIGINE. L'ajouter rendrait le défi ingérable (5 slots sur 6 immobilisés) et la
# boutique élargie de Bomberto inutilisable pendant la tentative.

# ItemParentData.Tier : COMMON=0, UNCOMMON=1, RARE=2, LEGENDARY=3.
# Le niveau IV affiché en jeu est donc le tier 3.
const TIER_IV := 3

# weapon_id -> my_id du défi que « posséder cette arme au tier IV » complète.
# ⚠️ La correspondance est EXACTE, jamais un begins_with() : "weapon_bomb" est un
# préfixe de "weapon_bomb_ice", "weapon_bomb_storm", "weapon_bomb_poison",
# "weapon_bomb_leech" et "weapon_bomb_frag".
const CHAIN := {
	"weapon_bomb": "chal_bomb_ice",
	"weapon_bomb_ice": "chal_bomb_storm",
	"weapon_bomb_storm": "chal_bomb_poison",
	"weapon_bomb_leech": "chal_bomb_frag",
}

# my_id du défi -> weapon_id de la bombe qu'il débloque.
const REWARD := {
	"chal_bomb_ice": "weapon_bomb_ice",
	"chal_bomb_storm": "weapon_bomb_storm",
	"chal_bomb_poison": "weapon_bomb_poison",
	"chal_bomb_leech": "weapon_bomb_leech",
	"chal_bomb_frag": "weapon_bomb_frag",
}

# --- Bombe sangsue : déblocage par la COLLECTION (pas par un tier IV). ---

# Les 4 bombes à détenir SIMULTANÉMENT (tier indifférent).
const LEECH_REQUIRED := [
	"weapon_bomb",
	"weapon_bomb_ice",
	"weapon_bomb_poison",
	"weapon_bomb_storm",
]

const LEECH_CHALLENGE := "chal_bomb_leech"


# Vrai si l'inventaire (liste de weapon_id, doublons tolérés) contient les 4 bombes.
# ⚠️ Des doublons ne remplacent JAMAIS une bombe manquante : on vérifie la présence
# de CHACUNE des 4, pas un simple compte.
static func unlocks_leech(weapon_ids: Array) -> bool:
	for required in LEECH_REQUIRED:
		if not weapon_ids.has(required):
			return false
	return true


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
