extends Reference
# Élément d'une bombe, déduit du weapon_id partagé par ses 4 tiers.
# Pilote le sous-comportement à l'explosion.
#
# ⚠️ TROIS QUESTIONS DISTINCTES, TROIS PRÉDICATS — ne pas les refondre en un seul.
# Un unique `is_effect()` a longtemps suffi parce que les réponses coïncidaient :
# la normale faisait des dégâts ET pouvait troller, les bombes à effet ni l'un ni
# l'autre. La Frag est le premier cas qui les SÉPARE : elle fait des dégâts (via ses
# fragments) et ne troll JAMAIS. Les reconfondre rendrait la Frag impossible.

const NORMAL := "normal"
const ICE := "ice"
const POISON := "poison"
const STORM := "storm"
const LEECH := "leech"
# L'obus Frag : explose SANS dégâts (simple vecteur) et se scinde en fragments.
const FRAG := "frag"
# Le fragment projeté par la Frag. Élément INTERNE : aucun weapon_id ne le produit
# (il est absent de _BY_WEAPON_ID). C'est ce qui rend la garde anti-récursion
# STRUCTURELLE plutôt que conditionnelle : un FRAG_CHILD n'est pas un FRAG, donc
# is_cluster() est faux et la branche de dispersion ne peut pas le reprendre.
# Rien à tester côté récursion : elle est impossible par construction.
const FRAG_CHILD := "frag_child"

const _BY_WEAPON_ID := {
	"weapon_bomb_ice": ICE,
	"weapon_bomb_poison": POISON,
	"weapon_bomb_storm": STORM,
	"weapon_bomb_leech": LEECH,
	"weapon_bomb_frag": FRAG,
}

# Élément d'une arme d'après son weapon_id. Repli NORMAL (dont "weapon_bomb").
static func from_weapon_id(weapon_id: String) -> String:
	return _BY_WEAPON_ID.get(weapon_id, NORMAL)


# Qui inflige des DÉGÂTS d'explosion ?
# - la Bombe normale ;
# - le FRAGMENT de la Frag, qui porte TOUT le dégât de celle-ci.
# Les bombes à effet (glace/poison/sangsue) sont à 0 par design ; la foudre porte ses
# dégâts dans ses éclairs, pas dans une zone ; et l'OBUS Frag lui-même est à 0 (il
# n'est qu'un vecteur de dispersion).
static func deals_explosion_damage(element: String) -> bool:
	return element == NORMAL or element == FRAG_CHILD


# Qui peut se réveiller en troll bombe ? La Bombe normale SEULE — c'est sa signature
# exclusive, et la Frag ne doit pas la lui voler.
static func can_troll(element: String) -> bool:
	return element == NORMAL


# Qui se scinde en fragments à la détonation ? La Frag SEULE.
static func is_cluster(element: String) -> bool:
	return element == FRAG
