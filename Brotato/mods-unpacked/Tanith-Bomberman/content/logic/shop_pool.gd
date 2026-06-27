extends Reference
# Logique PURE du filtrage du pool d'ARMES du magasin pour le Bomberman.
# Le jeu vanilla ne sait pas bannir une arme du magasin par ID
# (character.banned_items n'est consulté QUE pour les items, jamais les armes) :
# on filtre donc nous-mêmes le pool d'armes pour ne garder que la Bombe.
# Les 4 tiers de Bombe partagent tous weapon_id == BOMB_WEAPON_ID.

const BOMB_WEAPON_ID := "weapon_bomb"

# Retourne une NOUVELLE liste ne contenant que les armes Bombe.
# N'altère pas `pool` ; conserve l'ordre. Les éléments sans `weapon_id`
# (ou d'un autre weapon_id) sont retirés.
static func keep_only_bombs(pool: Array) -> Array:
	var result := []
	for item in pool:
		if item != null and ("weapon_id" in item) and item.weapon_id == BOMB_WEAPON_ID:
			result.push_back(item)
	return result
