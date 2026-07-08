extends Reference
# Skin de la Bombe : un seul visuel (bombe_normale.png), constant sur tous les
# tiers. En jeu, le tier reste lisible via le CONTOUR coloré que le jeu applique
# déjà à l'arme tenue (weapon.gd:update_highlighting -> ItemService.get_color_from_tier).
# Sur l'ICÔNE de boutique, on ajoute un disque de fond coloré à la rareté du tier.
#
# - icon_background_color(tier_color) -> couleur du disque (repli gris si blanc).
# - build_icon(element, tier_color)   -> icône = sprite élément sur disque coloré.
# - build_world_texture(element)      -> sprite EN JEU (tenu / posé / troll), sans fond.
# - build_normal_icon(tier_color)     -> délégation pour rétro-compat (normal).
# - build_normal_world_texture()      -> délégation pour rétro-compat (normal).
# - element_sprite_path(element)      -> chemin du PNG par élément (repli normal).
# - _load(path)                       -> loader runtime générique (réutilisé ailleurs).
#
# Chargement runtime (Image.load) : contourne le cache d'import Godot. Textures
# créées avec FILTER+MIPMAPS pour un rendu lisse (sprite cartoon non pixel-art).

const _BOMB_DIR := "res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb"
# Clés = valeurs de BombElement (normal/ice/...). Poison/foudre viendront aux
# phases suivantes.
const _SPRITE_PATHS := {
	"normal": _BOMB_DIR + "/bombe_normale.png",
	"ice": _BOMB_DIR + "/glace.png",
}
# Rétro-compat interne (anciens sites).
const _NORMAL_ICON_PATH := _BOMB_DIR + "/bombe_normale.png"
const _WORLD_SIZE := 48  # taille du sprite en jeu (ancienne taille des skins colorés)

# Repli quand la couleur de rareté vaut blanc (tier commun) : gris clair lisible.
const COMMON_BG := Color(0.72, 0.72, 0.72, 1.0)

# Chemin du sprite d'un élément (repli sur normal si élément inconnu).
static func element_sprite_path(element: String) -> String:
	return _SPRITE_PATHS.get(element, _SPRITE_PATHS["normal"])

# Couleur du disque de fond de l'icône : la couleur de rareté fournie par le jeu
# (ItemService.get_color_from_tier), avec repli gris si elle vaut blanc.
static func icon_background_color(tier_color: Color) -> Color:
	if tier_color == Color.white:
		return COMMON_BG
	return tier_color

# Icône de boutique : sprite de l'élément composé sur un disque coloré.
static func build_icon(element: String, tier_color: Color) -> Texture:
	return _compose_icon(element_sprite_path(element), tier_color)

# Sprite EN JEU : sprite de l'élément, 48×48, SANS fond.
static func build_world_texture(element: String) -> Texture:
	return _compose_world(element_sprite_path(element))

# --- Rétro-compat : la Bombe normale (troll bombe, etc.). ---
static func build_normal_icon(tier_color: Color) -> Texture:
	return build_icon("normal", tier_color)

static func build_normal_world_texture() -> Texture:
	return build_world_texture("normal")

# Composition icône (disque coloré + sprite). Null si l'asset ne charge pas.
static func _compose_icon(path: String, tier_color: Color) -> Texture:
	var sprite_img := _load_image(path)
	if sprite_img == null:
		return null
	var w := sprite_img.get_width()
	var h := sprite_img.get_height()
	var bg := _make_disc(w, h, icon_background_color(tier_color))
	bg.blend_rect(sprite_img, Rect2(0, 0, w, h), Vector2(0, 0))
	var tex := ImageTexture.new()
	tex.create_from_image(bg, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS)
	return tex

# Composition sprite en jeu (48×48, sans fond). Null si l'asset ne charge pas.
static func _compose_world(path: String) -> Texture:
	var img := _load_image(path)
	if img == null:
		return null
	if img.get_width() != _WORLD_SIZE or img.get_height() != _WORLD_SIZE:
		img.resize(_WORLD_SIZE, _WORLD_SIZE, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS)
	return tex

# Loader runtime générique -> Texture (rétro-compat : animated_icon, face troll).
static func _load(path: String) -> Texture:
	var img := _load_image(path)
	if img == null:
		return null
	var tex := ImageTexture.new()
	tex.create_from_image(img, 0)
	return tex

# Charge un PNG en Image RGBA (hors cache d'import). Null si introuvable.
static func _load_image(path: String) -> Image:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img

# Disque plein centré de la couleur donnée (rayon = 92% du demi-côté),
# reste transparent. Image RGBA de w×h.
static func _make_disc(w: int, h: int, color: Color) -> Image:
	var img := Image.new()
	img.create(w, h, false, Image.FORMAT_RGBA8)
	img.lock()
	var cx := w / 2.0
	var cy := h / 2.0
	var r := min(w, h) * 0.5 * 0.92
	var r2 := r * r
	var transparent := Color(0, 0, 0, 0)
	for y in range(h):
		for x in range(w):
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, transparent)
	img.unlock()
	return img
