extends Reference
# Fonction pure de filtrage du pool. Aucune dépendance au jeu.

# Garde les candidats dont `my_id` n'est pas clé de `excluded_ids` (ensemble {id: true}).
static func filter(candidates: Array, excluded_ids: Dictionary) -> Array:
	var result := []
	for candidate in candidates:
		if not excluded_ids.has(candidate.my_id):
			result.append(candidate)
	return result
