extends Reference
# Logique PURE de la Bombe sangsue (drain).
# Aucune dépendance aux autoloads du jeu -> testable en headless.
#
# Le drain : à l'explosion, chaque ennemi touché tire sur le vol de vie de l'arme.
# En cas de proc, on lui RETIRE N PV et on en REND N au joueur (invariant : les deux
# montants sont toujours égaux). Un budget de PV par explosion borne le total.
#
# POURQUOI un budget : une explosion touche tous ses ennemis dans la MÊME frame.
# Sans plafond, une bombe lâchée dans une horde de fin de vague rendrait la barre
# entière. Le budget est donc la manette d'équilibrage principale de cette arme.
#
# Le budget est compté en PV, pas en procs : l'item « double vol de vie » atteint
# donc le plafond avec moins d'ennemis, mais ne le perce jamais.

# Plafond de PV volés par explosion, indexé par tier (0 = I ... 3 = IV).
const CAP_BY_TIER := [3, 4, 5, 6]


# Plafond du tier, borné (un tier hors bornes ne doit jamais indexer hors tableau).
static func cap_for_tier(tier: int) -> int:
	var i := int(clamp(tier, 0, CAP_BY_TIER.size() - 1))
	return CAP_BY_TIER[i]


# Le tirage. `roll` est INJECTÉ (randf() reste chez l'appelant) : c'est ce qui rend
# cette fonction déterministe, donc testable.
static func procs(roll: float, lifesteal: float) -> bool:
	return roll < lifesteal


# PV volés par proc : 1, ou 2 avec l'effet joueur `double_lifesteal_bonus`.
# Aligné sur le vanilla, où AUCUNE arme ne rend jamais plus d'1 PV par proc.
static func proc_amount(has_double_bonus: bool) -> int:
	return 2 if has_double_bonus else 1


# Écrêtage au budget restant. Un proc « double » sur 1 PV restant ne draine que 1.
static func granted(amount: int, remaining: int) -> int:
	if amount <= 0 or remaining <= 0:
		return 0
	return int(min(amount, remaining))


# --- Budget d'UNE explosion ---
#
# C'est un Array à UN élément : [pv_restants]. En GDScript, un Array est passé par
# RÉFÉRENCE — c'est ce qui permet à tous les ennemis d'un même souffle de partager le
# même compteur. Instancié à l'explosion et passé en bind à la connexion du signal
# `hit_something`, il donne à chaque explosion son propre budget.
#
# POURQUOI pas une classe : une classe interne devrait appeler les fonctions statiques
# de son script hôte, ce qui oblige le script à se preload lui-même -> référence
# cyclique en Godot 3. L'Array garde le module 100 % statique, donc trivialement testable.

static func new_budget(tier: int) -> Array:
	return [cap_for_tier(tier)]


static func remaining(budget: Array) -> int:
	if budget == null or budget.empty():
		return 0
	return int(budget[0])


# Accorde jusqu'à `amount` PV, décrémente le budget, et rend le montant RÉELLEMENT
# accordé (0 si le budget est épuisé ou malformé).
static func take(budget: Array, amount: int) -> int:
	var left := remaining(budget)
	var given := granted(amount, left)
	if given > 0:
		budget[0] = left - given
	return given
