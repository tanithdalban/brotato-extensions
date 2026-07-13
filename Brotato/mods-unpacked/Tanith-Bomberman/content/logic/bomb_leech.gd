extends Reference
# Logique PURE de la Bombe sangsue (drain).
# Aucune dépendance aux autoloads du jeu -> testable en headless.
#
# Le drain : à l'explosion, chaque ennemi touché tire sur le vol de vie de l'arme.
# En cas de proc, on lui RETIRE jusqu'à N PV et on en REND au joueur le montant
# RÉELLEMENT retiré (l'ennemi peut avoir moins de N PV, ou être déjà en train de
# mourir cette frame — cf. bomb_weapon.gd:on_leech_hit). Le reliquat non consommé
# est remboursé au seau (`refund`) : le budget ne se dégrade jamais pour un montant
# qui n'a servi à personne.
#
# --- Correctif d'équilibrage (revue finale) : seau à jetons PAR JOUEUR ---
#
# Un plafond PAR EXPLOSION ne borne rien PAR SECONDE : rien n'empêche un joueur de
# garder plusieurs sangsues (6 en T4, cooldown ≈ 1s, auraient fait 6 budgets
# indépendants -> ~36 PV/s, très au-delà du plafond vanilla de 10 PV/s que le
# LifestealTimer, qu'on contourne, existe pour imposer). Le budget est donc UN SEUL
# par joueur, partagé par toutes ses bombes sangsue, et il se RECHARGE dans le temps
# (seau à jetons) :
#   - capacité = le plafond du TIER de la bombe qui draine EN CE MOMENT (3/4/5/6) ;
#   - recharge = la capacité PAR SECONDE (un seau plein se reconstitue en 1 s).
# Empiler les sangsues ne multiplie donc plus le soin : ça le rend seulement plus
# RÉGULIER (le seau se vide plus vite, il ne se remplit pas plus).
#
# Le temps est INJECTÉ (`now`, en millisecondes) : jamais d'OS.get_ticks_msec() dans
# ce module, pour rester déterministe et testable en headless.

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


# --- Seau à jetons PARTAGÉ PAR JOUEUR ---
#
# C'est un Array à DEUX éléments : [jetons, dernier_instant_ms]. En GDScript, un
# Array est passé par RÉFÉRENCE — c'est ce qui permet à toutes les bombes sangsue
# d'un même joueur de partager le même seau (stocké en méta sur le nœud joueur,
# cf. bomb_weapon.gd:_get_leech_bucket -> il meurt avec la run, ne fuite jamais
# entre runs ni entre joueurs de la coop).
#
# `jetons` est un FLOAT : les fractions de jeton s'accumulent en continu au fil de
# la recharge ; seule la RÉSERVE DISPONIBLE (via `remaining`) est tronquée vers
# l'entier de PV réellement accordable — un jeton ne se dépense jamais en morceau.
#
# `dernier_instant_ms == -1` signale un seau JAMAIS UTILISÉ : au premier appel, il
# se remplit à PLEINE capacité plutôt que de partir de 0 (un joueur qui n'a pas
# drainé récemment profite du plein régime dès sa première bombe).
#
# POURQUOI pas une classe : une classe interne devrait appeler les fonctions statiques
# de son script hôte, ce qui oblige le script à se preload lui-même -> référence
# cyclique en Godot 3. L'Array garde le module 100 % statique, donc trivialement testable.

static func new_bucket() -> Array:
	return [0.0, -1]


# Recharge le seau selon le temps écoulé depuis le dernier appel, puis borne
# l'AJOUT à `capacity` (le plafond du TIER de la bombe qui draine EN CE MOMENT : des
# bombes de tiers différents partagent le même seau mais pas forcément le même
# plafond d'un appel à l'autre — c'est voulu, cf. spec).
#
# Compromis délibéré : le plafond ne retire JAMAIS des jetons déjà acquis. Si le
# seau contient déjà PLUS que `capacity` (une bombe de tier supérieur a rechargé
# avant), une bombe de tier INFÉRIEUR qui draine ensuite ne doit pas AMPUTER ce
# surplus — sinon une build en cours de montée en tier serait strictement PIRE que
# le bas tier seul. Seul ce qui vient d'être ajouté par CETTE recharge est écrêté à
# `capacity`. D'où le plafond effectif = max(capacity, solde d'avant).
#
# Une horloge qui RECULE (now <= dernier instant) ne doit ni planter ni accorder de
# jetons gratuits : on ignore alors la recharge (aucun ajout) SANS reculer
# `dernier_instant_ms`, pour ne pas fausser le calcul d'écart la prochaine fois que
# le temps redevient croissant.
static func _refill(bucket: Array, capacity: int, now: int) -> void:
	if bucket[1] < 0:
		bucket[0] = float(capacity)
		bucket[1] = now
	else:
		var elapsed: int = now - int(bucket[1])
		if elapsed > 0:
			var before: float = bucket[0]
			bucket[0] += (float(elapsed) / 1000.0) * float(capacity)
			bucket[1] = now
			var ceiling: float = max(float(capacity), before)
			if bucket[0] > ceiling:
				bucket[0] = ceiling
	if bucket[0] < 0.0:
		bucket[0] = 0.0


# PV entiers actuellement disponibles dans le seau (recharge d'abord, tronque
# ensuite : les jetons fractionnaires ne sont jamais accordés en partie).
static func remaining(bucket: Array, capacity: int, now: int) -> int:
	if bucket == null or bucket.size() < 2:
		return 0
	_refill(bucket, capacity, now)
	return int(floor(bucket[0]))


# Recharge puis accorde jusqu'à `amount` PV, décrémente le seau, et rend le montant
# RÉELLEMENT accordé (0 si vide ou malformé). Réutilise `granted` pour l'écrêtage.
static func take(bucket: Array, capacity: int, amount: int, now: int) -> int:
	if bucket == null or bucket.size() < 2:
		return 0
	_refill(bucket, capacity, now)
	var left := int(floor(bucket[0]))
	var given := granted(amount, left)
	if given > 0:
		bucket[0] -= given
	return given


# Rembourse au seau des jetons NON réellement consommés (ex. le drain effectif s'est
# avéré plus faible que prévu — écrêté par la vie restante de l'ennemi, ou l'ennemi
# était déjà en train de mourir cette frame, cf. bomb_weapon.gd:on_leech_hit). Ne
# recharge pas le temps ; ne dépasse jamais `capacity`.
static func refund(bucket: Array, capacity: int, amount: int) -> void:
	if bucket == null or bucket.size() < 2 or amount <= 0:
		return
	bucket[0] = min(float(capacity), bucket[0] + amount)
