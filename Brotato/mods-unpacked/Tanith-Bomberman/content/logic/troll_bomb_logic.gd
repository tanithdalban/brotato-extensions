extends Reference
# Logique PURE de la troll bombe (aucune dépendance jeu) — testable headless.
# La bombe posée se "réveille" aléatoirement pendant sa mèche et devient un
# danger mobile qui poursuit le joueur le plus proche. Ici on ne décide QUE :
# le tirage du réveil, l'instant du réveil, la cible la plus proche, et le
# vecteur de déplacement. Tout le reste (scène, hitbox, explosion) est en jeu.

# Vrai si la bombe doit se réveiller. roll attendu dans [0, 1) (ex. randf()).
static func should_wake(roll: float, chance: float) -> bool:
	return roll < chance


# Instant du réveil dans la mèche : fraction (bornée [0,1]) de la durée de mèche.
static func wake_delay(fuse_seconds: float, fraction: float) -> float:
	var f := fraction
	if f < 0.0:
		f = 0.0
	if f > 1.0:
		f = 1.0
	var d := fuse_seconds * f
	if d < 0.0:
		d = 0.0
	return d


# Joueur VIVANT le plus proche.
# targets = Array de Dictionary {position: Vector2, dead: bool, index: int}.
# Retourne {found: bool, index: int, position: Vector2}.
static func nearest_target(from_pos: Vector2, targets: Array) -> Dictionary:
	var best := {"found": false, "index": -1, "position": Vector2.ZERO}
	var best_d := 0.0
	for t in targets:
		if t.get("dead", false):
			continue
		var p: Vector2 = t["position"]
		var d := from_pos.distance_squared_to(p)
		if not best["found"] or d < best_d:
			best = {"found": true, "index": t.get("index", -1), "position": p}
			best_d = d
	return best


# Vecteur de déplacement vers la cible, normé à speed. Zéro si positions confondues.
static func step_velocity(from_pos: Vector2, target_pos: Vector2, speed: float) -> Vector2:
	var delta := target_pos - from_pos
	if delta.length() < 0.0001:
		return Vector2.ZERO
	return delta.normalized() * speed
