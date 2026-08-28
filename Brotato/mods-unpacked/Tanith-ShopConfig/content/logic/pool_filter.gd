extends Reference
# Fonction pure de filtrage du pool. Aucune dépendance au jeu.

# Garde les candidats dont `my_id` n'est pas clé de `excluded_ids` (ensemble {id: true}).
static func filter(candidates: Array, excluded_ids: Dictionary) -> Array:
	var result := []
	for candidate in candidates:
		if not excluded_ids.has(candidate.my_id):
			result.append(candidate)
	return result


# Ensemble {my_id: true} des ids que les cases AFFICHÉES d'un panneau peuvent
# représenter : pour un objet, son `my_id` ; pour une arme, TOUS les my_id de sa
# famille (un argument = une famille). Sert au calcul du carry-over (cf. carried).
static func owned_ids(item_ids: Array, weapon_family_id_lists: Array) -> Dictionary:
	var out := {}
	for id in item_ids:
		out[id] = true
	for family in weapon_family_id_lists:
		for id in family:
			out[id] = true
	return out


# Carry-over : ids mémorisés (`saved_ids`, ensemble {id: true}) que le perso courant
# ne peut PAS afficher (absents de `owned`). On les conserve gelés pour ne pas les
# perdre au commit quand le slot rejoue un perso à la grille différente.
static func carried(saved_ids: Dictionary, owned: Dictionary) -> Dictionary:
	var out := {}
	for id in saved_ids:
		if not owned.has(id):
			out[id] = true
	return out


# ---------- signe d'une « classe » (stat) ----------
# Le filtre de classe ne doit lister un élément que si l'attribut filtré lui est
# BÉNÉFIQUE : chercher « Dégâts à distance » ne doit pas remonter un objet qui en
# RETIRE. Le jeu sait déjà trancher — c'est ce qui colore l'effet en vert ou en
# rouge dans l'infobulle : `Effect.effect_sign` + `Effect.get_sign()`
# (res://items/global/effect.gd). On en reproduit ici la résolution plutôt que de
# tester naïvement `value > 0`, parce que des bonus ont une valeur NÉGATIVE
# (Coupon : items_price = -5 ; Escargot : enemy_speed = -8) et sont explicitement
# marqués POSITIVE. Recopié en constantes locales pour garder ce fichier sans
# aucune dépendance au jeu (donc testable en headless).
const SIGN_POSITIVE := 0
const SIGN_NEGATIVE := 1
const SIGN_NEUTRAL := 2
const SIGN_FROM_VALUE := 3
const SIGN_FROM_ARG := 4
const SIGN_OVERRIDE := 5

# Vrai si l'effet est affiché comme un bonus. NEUTRAL, OVERRIDE (la malédiction
# du DLC) et tout enum inattendu ne sont pas des bonus : on n'en invente pas un.
static func is_positive_sign(effect_sign: int, value: int) -> bool:
	if effect_sign == SIGN_POSITIVE:
		return true
	if effect_sign == SIGN_FROM_VALUE or effect_sign == SIGN_FROM_ARG:
		return value > 0
	return false


# Armes : pas de notion de signe, seul le scaling compte (quatre armes lourdes
# du jeu scalent NÉGATIVEMENT sur stat_attack_speed).
static func is_positive_scaling(value) -> bool:
	return (value is int or value is float) and float(value) > 0.0
