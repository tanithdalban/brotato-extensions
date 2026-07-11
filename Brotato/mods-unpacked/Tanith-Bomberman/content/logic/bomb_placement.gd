extends Reference
# Placement des bombes — logique PURE (aucune dépendance jeu, testable en headless).
#
# Deux sources d'espacement, qui se RELAIENT automatiquement :
#   - la DISTANCE parcourue par le joueur entre deux poses ;
#   - l'ANGLE (la couronne autour de lui).
# Quand le déplacement suffit à espacer les bombes, l'éventail se referme derrière le
# joueur (belle file). Quand il ne suffit pas (joueur lent, ou beaucoup de bombes donc
# un intervalle de pose très court), l'éventail reste ouvert et c'est l'angle qui
# fournit l'espacement. Cf. docs/superpowers/specs/2026-07-11-pose-de-bombes-design.md

# Rayon de la couronne, en pixels. Constante FIXE : on ne l'indexe pas sur le rayon
# d'explosion (qui grossit avec l'élémentaire) — sinon les bombes partiraient à des
# centaines de pixels en fin de run et on perdrait la traînée.
const RADIUS := 64.0

# Angle d'or (137,5°) : PI * (3 - sqrt(5)). Il ne reboucle jamais, donc les poses
# successives d'une MÊME arme se répartissent d'elles-mêmes autour du cercle sans
# retomber au même endroit. C'est ce qui règle le cas critique d'UNE SEULE bombe en
# main, où l'index de slot ne différencie rien.
const GOLDEN_ANGLE := 2.399963229728653


# Azimut brut d'une pose, AVANT repliement vers l'arrière.
# Combine le slot de l'arme (deux armes ne visent pas le même azimut) et une
# précession par angle d'or à chaque pose.
static func raw_angle(slot_index: int, nb_slots: int, shot_index: int) -> float:
	var slots := int(max(1, nb_slots))
	var i := slot_index
	if i < 0:
		i = 0
	var slot_term := TAU * (float(i % slots) / float(slots))
	return slot_term + GOLDEN_ANGLE * float(shot_index)


# « Le déplacement suffit-il, à lui seul, à espacer les bombes ? » -> [0, 1].
#
# `travelled` = distance NETTE parcourue par le joueur depuis SA bombe précédente
# (celle de cette même arme). Avec N armes bombe entrelacées, cette arme ne tire qu'une
# fois tous les N tirs du groupe : la distance entre deux bombes CONSÉCUTIVES (toutes
# armes confondues) vaut donc travelled / N.
# On la compare à 2 x rayon, le DIAMÈTRE de la couronne, c'est-à-dire l'espacement que
# la couronne fournirait à elle seule.
#
# On mesure une distance NETTE, et non une vitesse instantanée : un joueur qui frétille
# sur place (aller-retour rapide pour esquiver) a une vitesse élevée mais un déplacement
# net nul. Se fier à la vitesse refermerait l'éventail et empilerait les bombes — c'est
# précisément le bug que ce module existe pour tuer.
static func mobility_from_travel(travelled: float, nb_bombs: int, radius: float) -> float:
	if travelled <= 0.0 or radius <= 0.0:
		return 0.0
	var n := int(max(1, nb_bombs))
	return clamp(travelled / (float(n) * 2.0 * radius), 0.0, 1.0)


# Demi-ouverture de l'éventail, centré derrière le joueur.
# Mobilité 0 -> PI (cercle entier : la couronne). Mobilité 1 -> 0 (file stricte).
static func fan_half_width(mobility: float) -> float:
	return PI * (1.0 - clamp(mobility, 0.0, 1.0))


# Décalage à appliquer à la position du joueur pour poser la bombe.
# `last_dir` = dernière direction de déplacement connue (non normalisée acceptée).
static func offset(slot_index: int, nb_slots: int, shot_index: int, last_dir: Vector2, mobility: float, radius: float) -> Vector2:
	# L'arrière du joueur. Direction nulle (début de vague) -> axe arbitraire : sans
	# conséquence, car la mobilité vaut alors 0 et l'éventail est un cercle complet.
	var rear := Vector2.RIGHT
	if last_dir.length() > 0.0001:
		rear = -last_dir.normalized()

	# On projette l'azimut brut sur l'éventail : t ∈ [-1, 1] -> +/- la demi-ouverture.
	var t := wrapf(raw_angle(slot_index, nb_slots, shot_index), -PI, PI) / PI
	var angle := rear.angle() + t * fan_half_width(mobility)
	return Vector2(cos(angle), sin(angle)) * radius
