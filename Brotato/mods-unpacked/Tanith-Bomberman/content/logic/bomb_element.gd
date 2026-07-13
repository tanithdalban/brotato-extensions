extends Reference
# Élément d'une bombe, déduit du weapon_id partagé par ses 4 tiers.
# Pilote le sous-comportement à l'explosion (normal = dégâts+brûlure+troll ;
# glace/poison/foudre/sangsue = "bombes à effet" : 0 dégât AoE, jamais de trollbombe).

const NORMAL := "normal"
const ICE := "ice"
const POISON := "poison"
const STORM := "storm"
const LEECH := "leech"

const _BY_WEAPON_ID := {
	"weapon_bomb_ice": ICE,
	"weapon_bomb_poison": POISON,
	"weapon_bomb_storm": STORM,
	"weapon_bomb_leech": LEECH,
}

# Élément d'une arme d'après son weapon_id. Repli NORMAL (dont "weapon_bomb").
static func from_weapon_id(weapon_id: String) -> String:
	return _BY_WEAPON_ID.get(weapon_id, NORMAL)

# Vrai pour les bombes "à effet" (pas la Bombe normale) : 0 dégât AoE, pas de troll.
static func is_effect(element: String) -> bool:
	return element != NORMAL
