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

# Constantes de temps du lissage de la mobilité. La descente est plus lente que la
# montée : elle laisse le joueur freiner, tourner et repartir sans que la traînée se
# retransforme en couronne au moindre à-coup du kiting.
const MOBILITY_RISE_SECONDS := 0.2
const MOBILITY_FALL_SECONDS := 0.5

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
# Seuil = 2 x rayon (le DIAMÈTRE de la couronne, soit l'espacement qu'elle fournirait
# à elle seule). Retourne 0 si un paramètre est nul (pas de division par zéro).
static func mobility_target(move_speed: float, interval_seconds: float, radius: float) -> float:
	if move_speed <= 0.0 or interval_seconds <= 0.0 or radius <= 0.0:
		return 0.0
	var travelled := move_speed * interval_seconds
	return clamp(travelled / (2.0 * radius), 0.0, 1.0)


# Lissage temporel de la mobilité vers sa cible. Montée et descente ont des constantes
# de temps distinctes. Borné dans [0, 1]. delta = 0 -> inchangé.
static func mobility_step(current: float, target: float, delta: float, rise_seconds: float, fall_seconds: float) -> float:
	if delta <= 0.0:
		return clamp(current, 0.0, 1.0)
	var seconds := rise_seconds if target > current else fall_seconds
	if seconds <= 0.0:
		return clamp(target, 0.0, 1.0)
	var t := clamp(delta / seconds, 0.0, 1.0)
	return clamp(current + (target - current) * t, 0.0, 1.0)


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
