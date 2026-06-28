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


# Dégâts NON LÉTAUX : jamais plus que ce qui laisserait le joueur à 1 PV.
# raw = dégâts bruts de la bombe, hp = PV courants du joueur visé.
# Résultat dans [0, raw] et toujours <= hp-1 (donc 0 si hp <= 1, jamais de kill).
static func nonlethal_damage(raw: int, hp: int) -> int:
	var cap := hp - 1
	if cap < 0:
		cap = 0
	if raw < cap:
		return raw
	return cap


# Position de spawn repoussée à au moins min_dist du joueur (anti "explose au
# visage sans réaction"). Si déjà assez loin, renvoie spawn_pos inchangé.
static func keep_distance(spawn_pos: Vector2, player_pos: Vector2, min_dist: float) -> Vector2:
	var dir := spawn_pos - player_pos
	if dir.length() >= min_dist:
		return spawn_pos
	if dir.length() < 0.0001:
		dir = Vector2(1, 0)  # direction arbitraire si pile sur le joueur
	return player_pos + dir.normalized() * min_dist


# Plus petit PV parmi ceux fournis (PV courants des joueurs VIVANTS, déjà filtrés
# par l'appelant). Retourne un très grand nombre si la liste est vide (=> aucun
# plafond, mais sans cible le dégât n'a de toute façon pas d'effet).
static func min_living_hp(hps: Array) -> int:
	var m := 0x7FFFFFFF
	for hp in hps:
		if hp < m:
			m = hp
	return m
