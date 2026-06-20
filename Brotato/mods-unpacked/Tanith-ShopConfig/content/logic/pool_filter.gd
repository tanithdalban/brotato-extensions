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
