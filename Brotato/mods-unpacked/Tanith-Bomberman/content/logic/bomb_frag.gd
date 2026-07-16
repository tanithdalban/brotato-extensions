extends Reference
# Logique PURE de la Bombe Frag : où tombent les fragments.
# Aucune dépendance aux autoloads du jeu -> testable en headless.
#
# À la détonation, l'obus éclate SANS dégâts (l'explosion mère n'est qu'un vecteur :
# repère visuel + son) et projette N fragments à des positions ALÉATOIRES dans un
# disque. Ce sont eux qui portent TOUS les dégâts. Ce module ne calcule QUE ces
# positions.
#
# ⭐ Il n'y a RIEN à partager entre les fragments : le `damage` du .tres est le dégât
# PAR FRAGMENT, pas un total à répartir. C'est la convention VANILLA des armes
# multi-projectiles (la Foudre porte `damage = 8` avec `nb_projectiles = 6`, et les 8
# sont par éclair). Le dégât d'explosion calculé à la pose est donc passé TEL QUEL à
# chaque fragment — d'où l'absence totale de fonction de partage ici.
#
# Le hasard est INJECTÉ (`randoms`) : jamais de randf() dans ce module, pour rester
# déterministe et testable en headless — même principe que le temps injecté dans
# bomb_leech.gd.

# Tirages consommés par fragment : un pour l'angle, un pour la distance.
const RANDOMS_PER_FRAGMENT := 2


# N décalages (depuis le centre de l'obus) répartis UNIFORMÉMENT dans le disque de
# rayon `radius`.
#
# `randoms` : flottants dans [0,1) fournis par l'appelant, RANDOMS_PER_FRAGMENT par
# fragment. S'il en manque, on complète par 0.0 : dégradation propre, jamais de crash
# ni d'index hors bornes, et surtout AUCUN fragment perdu (un fragment manquant, ce
# sont des dégâts qui disparaissent en silence).
#
# ⚠️ PIÈGE DE MATHS — LA RACINE CARRÉE EST OBLIGATOIRE. Tirer l'angle ET la distance
# uniformément ENTASSE les fragments au centre : la surface d'une couronne croît avec
# son rayon, donc une distance uniforme sur-représente massivement le centre. Pour une
# gerbe HOMOGÈNE il faut `r = radius * sqrt(u)`. Sans ça, la dispersion réelle serait
# bien plus concentrée que les 46 % de couverture calculés dans la spec, et tout
# l'équilibrage (qui repose sur les trous du tapis) tomberait à côté.
static func scatter_offsets(n: int, radius: float, randoms: Array) -> Array:
	var result := []
	if n <= 0:
		return result
	var r := max(0.0, radius)
	for i in range(n):
		var angle_idx := i * RANDOMS_PER_FRAGMENT
		var dist_idx := angle_idx + 1
		var u_angle: float = randoms[angle_idx] if angle_idx < randoms.size() else 0.0
		var u_dist: float = randoms[dist_idx] if dist_idx < randoms.size() else 0.0
		var angle := u_angle * TAU
		var dist := r * sqrt(clamp(u_dist, 0.0, 1.0))
		result.append(Vector2(cos(angle), sin(angle)) * dist)
	return result
