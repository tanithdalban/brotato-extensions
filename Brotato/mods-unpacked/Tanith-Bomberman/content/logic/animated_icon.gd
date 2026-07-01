extends Reference
# Construit une AnimatedTexture bouclée pour l'icône animée d'un perso.
# Partie PURE (clamp_fps / usable_frame_count) testable headless ; l'assemblage
# build() charge les PNG au runtime (cf. bomb_skin) -> vérifié EN JEU.

const MIN_FPS := 1.0
const MAX_FRAMES := 256  # limite dure d'AnimatedTexture en Godot 3.x
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")

# fps borné en bas à MIN_FPS (un fps <= 0 figerait l'animation).
static func clamp_fps(fps: float) -> float:
	return fps if fps > MIN_FPS else MIN_FPS

# Nombre de frames réellement posables sur une AnimatedTexture, borné [0, 256].
static func usable_frame_count(n: int) -> int:
	if n < 0:
		return 0
	if n > MAX_FRAMES:
		return MAX_FRAMES
	return n

# Construit une AnimatedTexture bouclée à partir d'une liste de chemins PNG.
# Chaque frame est chargée au runtime via bomb_skin._load (Image.load, hors
# cache d'import). Les chemins introuvables sont ignorés. Retourne null si
# aucune frame n'a pu être chargée (l'appelant garde alors l'icône statique).
static func build(frame_paths: Array, fps: float) -> AnimatedTexture:
	var textures := []
	for path in frame_paths:
		var tex = BombSkin._load(path)
		if tex != null:
			textures.append(tex)
	var count := usable_frame_count(textures.size())
	if count == 0:
		return null
	var anim := AnimatedTexture.new()
	anim.frames = count
	anim.fps = clamp_fps(fps)
	for i in count:
		anim.set_frame_texture(i, textures[i])
	return anim
