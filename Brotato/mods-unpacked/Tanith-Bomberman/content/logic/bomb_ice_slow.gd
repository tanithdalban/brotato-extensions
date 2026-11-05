extends Reference
# Coupe de vitesse de la Bombe de Glace — logique PURE (testable headless).
#
# Modèle "vitesse cible" NON CUMULATIF : chaque tier vise une vitesse
#   cible = max_speed × (1 − slow%/100)
# et on applique current_stats.speed = min(current_stats.speed, cible).
# Un slow plus faible arrivant après un plus fort est donc un no-op
# (la cible est plus haute que la vitesse courante) => "on garde le plus lent".
#
# La coupe est écrite dans current_stats.speed (débuff RÉEL et durable, tant que
# l'ennemi vit). Appliquée par BombWeapon.on_ice_hit via le signal hit_something
# de l'explosion. Depuis la 3.1.3, l'extension unit.gd du mod MÉMORISE le gel
# (remember) et le réapplique après chaque recalcul de vitesse du jeu : sans
# elle, la brûlure (Bombe normale, Poison) effaçait le gel.

# Le .tres porte le slow % en NÉGATIF (champ speed_percent_modifier repurposé) ;
# on renvoie sa magnitude.
static func slow_pct_for(speed_percent_modifier: int) -> float:
	return abs(speed_percent_modifier)

# Vitesse résultante après application du slow (non cumulatif). No-op si
# max_speed invalide.
static func apply(cur_speed: float, max_speed: float, slow_pct: float) -> float:
	if max_speed <= 0.0:
		return cur_speed
	var target := max_speed * (1.0 - slow_pct / 100.0)
	return min(cur_speed, target)

# Gel MÉMORISÉ sur l'ennemi (extension unit.gd) : on garde le plus fort reçu,
# cohérent avec le modèle non cumulatif ci-dessus. Il est réappliqué par apply()
# chaque fois que le jeu recalcule la vitesse (reset_speed_stat : début/fin de
# brûlure, phases d'élite, boosts), sinon ces recalculs effaceraient le gel.
static func remember(stored_pct: float, new_pct: float) -> float:
	return max(stored_pct, new_pct)
