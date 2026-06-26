extends Reference
# Skin de bombe par tier : une couleur par niveau d'arme, façon "legacy"
# (couleurs alignées sur la rareté Brotato). Tiers 0..3 = I..IV.
#
# Le mapping tier -> couleur -> chemin est PUR (testable en headless).
# Le chargement de texture (load_texture) lit le PNG au RUNTIME via Image.load :
# on contourne ainsi le cache d'import Godot (.import/.stex), ce qui évite la
# passe éditeur pour ces sprites. flags=0 -> pas de filtre = pixel-art net.

const _SKINS_DIR := "res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/skins"

# T1 commun -> gray, T2 -> blue, T3 -> purple, T4 légendaire -> red.
const _COLORS := ["gray", "blue", "purple", "red"]
const _MAX_TIER := 3

# Couleur de la bombe pour un tier donné (bornée à [0, 3]).
static func color_for_tier(tier: int) -> String:
	var t := tier
	if t < 0:
		t = 0
	if t > _MAX_TIER:
		t = _MAX_TIER
	return _COLORS[t]

# Chemin res:// de l'ICÔNE 96×96 (boutique/inventaire) pour un tier donné.
static func texture_path(tier: int) -> String:
	return "%s/bomb_%s.png" % [_SKINS_DIR, color_for_tier(tier)]

# Chemin res:// du sprite EN JEU 48×48 (arme tenue + bombe posée) — plus petit
# que l'icône pour ne pas dominer la scène.
static func world_texture_path(tier: int) -> String:
	return "%s/bomb_%s_48.png" % [_SKINS_DIR, color_for_tier(tier)]

# Charge l'icône 96×96 au runtime (hors cache d'import). Null si introuvable.
static func load_texture(tier: int) -> Texture:
	return _load(texture_path(tier))

# Charge le sprite en jeu 48×48 au runtime. Null si introuvable.
static func load_world_texture(tier: int) -> Texture:
	return _load(world_texture_path(tier))

# Charge un PNG en texture, hors cache d'import. flags=0 : ni filtre ni mipmap = net.
static func _load(path: String) -> Texture:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	var tex := ImageTexture.new()
	tex.create_from_image(img, 0)
	return tex
