extends Reference
# Logique PURE du filtrage du pool d'ARMES du magasin pour le Bomberto.
# Le jeu vanilla ne sait pas bannir une arme du magasin par ID (character.banned_items
# n'est consulté QUE pour les items, jamais les armes) : on filtre nous-mêmes le pool
# d'armes pour ne garder que le roster du Bomberto.
#
# Une arme est conservée si : son ID commence par le préfixe "weapon_bomb" (bombes standard
# et élémentaires), OU elle appartient au set explosive, OU elle a un knockback >= 20 ET
# est une arme de mêlée (les armes à distance qui atteignent 20 au tier 4 — sniper,
# potato thrower — sont exclues, hors thème).

const BOMB_WEAPON_ID := "weapon_bomb"
const EXPLOSIVE_SET_ID := "set_explosive"
const KNOCKBACK_THRESHOLD := 20
const TYPE_MELEE := 0  # WeaponData.Type.MELEE


# Vrai si l'arme appartient au roster accessible du Bomberto.
static func is_allowed(weapon) -> bool:
	if weapon == null:
		return false
	if ("weapon_id" in weapon) and (weapon.weapon_id as String).begins_with(BOMB_WEAPON_ID):
		return true
	if _in_explosive_set(weapon):
		return true
	if _has_strong_knockback_melee(weapon):
		return true
	return false


static func _in_explosive_set(weapon) -> bool:
	if not ("sets" in weapon) or weapon.sets == null:
		return false
	for s in weapon.sets:
		if s != null and ("my_id" in s) and s.my_id == EXPLOSIVE_SET_ID:
			return true
	return false


static func _has_strong_knockback_melee(weapon) -> bool:
	if not ("type" in weapon) or weapon.type != TYPE_MELEE:
		return false
	if not ("stats" in weapon) or weapon.stats == null:
		return false
	if not ("knockback" in weapon.stats):
		return false
	return weapon.stats.knockback >= KNOCKBACK_THRESHOLD


# Retourne une NOUVELLE liste filtrée. N'altère pas `pool` ; conserve l'ordre.
static func keep_allowed_weapons(pool: Array) -> Array:
	var result := []
	for item in pool:
		if is_allowed(item):
			result.push_back(item)
	return result


# --- Versement des bombes dans les pools du magasin (Brotato >= 1.2) ---
#
# Depuis la 1.2, ItemService.init_unlocked_pool() remplit les pools par tier à
# partir des PAQUETS de contenu (jeu de base + mises à jour/DLC actifs), et non
# plus de la liste `weapons` où le mod inscrit ses bombes : elles n'entraient
# plus jamais en boutique. L'extension ItemService les reverse derrière le
# parent ; cette fonction décide lesquelles, avec les règles du vanilla :
# lootable (can_be_looted) ET débloquée (weapon_id_hash dans `unlocked`, ce qui
# respecte le verrouillage des bombes élémentaires par défis).
#
# `tier_pools` : pools d'ARMES indexés par tier (_tiers_data[t][TierData.WEAPONS]).
# Rend, dans l'ordre des candidates, les armes à verser : absentes du pool de
# leur tier (pas de doublon si le jeu les y met un jour lui-même), tier dans les
# bornes, chaque arme une seule fois. N'altère ni `candidates` ni `tier_pools`.
static func weapons_to_add_to_tiers(candidates: Array, unlocked: Array, tier_pools: Array) -> Array:
	var result := []
	for weapon in candidates:
		if weapon == null or not weapon.can_be_looted:
			continue
		if not unlocked.has(weapon.weapon_id_hash):
			continue
		if weapon.tier < 0 or weapon.tier >= tier_pools.size():
			continue
		if tier_pools[weapon.tier].has(weapon) or result.has(weapon):
			continue
		result.push_back(weapon)
	return result
