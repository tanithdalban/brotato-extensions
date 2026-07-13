extends "res://singletons/item_service.gd"
# Enregistre le contenu du mod Bomberman dans les pools du jeu :
# on ajoute nos armes aux tableaux exportés AVANT de recâbler les
# upgrades, en appelant le _ready() parent après injection.

const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")
const ShopPool = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/shop_pool.gd")
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")
const AnimatedIcon = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/animated_icon.gd")
const BombElement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd")

const _BOMBERMAN_ID := "character_bomberman"

# Icône ANIMÉE de Bomberto (sélection de perso) : mèche -> explosion -> boucle.
const _ICON_ANIM_DIR := "res://mods-unpacked/Tanith-Bomberman/content/characters/bomberman/icon_anim"
const _ICON_ANIM_FRAMES := 18
const _ICON_ANIM_FPS := 12.0

# Index du joueur dont on tire actuellement la boutique (-1 = aucun tirage).
# Le tirage du magasin (get_player_shop_items) tire armes ET items via get_pool ;
# on s'en sert pour ne filtrer le pool d'ARMES QUE pendant ce contexte et QUE
# pour le bon joueur (coop : un seul des joueurs peut être Bomberman).
var _shop_draw_player := -1

const _BOMB_WEAPONS := [
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_1_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_2_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_3_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_4_data.tres",
]

const _BOMB_ICE_WEAPONS := [
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_1_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_2_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_3_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_4_data.tres",
]

const _BOMB_STORM_WEAPONS := [
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_1_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_2_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_3_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_4_data.tres",
]

const _BOMB_POISON_WEAPONS := [
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_1_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_2_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_3_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_4_data.tres",
]

const _BOMB_LEECH_WEAPONS := [
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_leech_1_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_leech_2_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_leech_3_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_leech_4_data.tres",
]

const _BOMBERMAN_CHAR := "res://mods-unpacked/Tanith-Bomberman/content/characters/bomberman/bomberman_data.tres"

func _ready() -> void:
	# Injecter nos armes dans le pool vanilla avant le recâblage des upgrades.
	for path in _BOMB_WEAPONS:
		_register_bomb_weapon(path)
	for path in _BOMB_ICE_WEAPONS:
		_register_bomb_weapon(path)
	for path in _BOMB_STORM_WEAPONS:
		_register_bomb_weapon(path)
	for path in _BOMB_POISON_WEAPONS:
		_register_bomb_weapon(path)
	for path in _BOMB_LEECH_WEAPONS:
		_register_bomb_weapon(path)

	# Enregistrer le personnage Bomberman dans le pool de personnages.
	var character = load(_BOMBERMAN_CHAR)
	if character != null and not characters.has(character):
		characters.append(character)
		ModLog.info("perso enregistré: " + str(character.my_id))

	# Icône ANIMÉE dans la sélection de perso : mèche -> explosion -> boucle.
	# AnimatedTexture hérite de Texture -> drop-in dans le TextureRect de l'écran,
	# qui anime et boucle tout seul. Frames chargées au runtime (hors cache
	# d'import, comme bomb_skin). Si rien ne charge, build() rend null et on
	# garde l'icône statique du .tres (dégradation propre).
	if character != null:
		var anim_paths := []
		for i in _ICON_ANIM_FRAMES:
			anim_paths.append("%s/frame_%02d.png" % [_ICON_ANIM_DIR, i])
		var anim = AnimatedIcon.build(anim_paths, _ICON_ANIM_FPS)
		if anim != null:
			character.icon = anim
			ModLog.info("icône animée posée sur Bomberto (%d frames)" % _ICON_ANIM_FRAMES)

	# Rejouer le passage de déblocage natif APRÈS notre injection.
	# ProgressData est un autoload déclaré AVANT ItemService (project.godot),
	# donc ProgressData._ready() -> add_unlocked_by_default() s'exécute AVANT ce
	# _ready() : nos armes/perso injectés ici échappent au passage natif. On le
	# rejoue nous-mêmes (il est idempotent : toutes ses écritures sont gardées
	# anti-doublon). Il répare DEUX symptômes :
	#   1. weapons_unlocked/characters_unlocked -> sans ça, l'écran de sélection
	#      d'arme (qui filtre les armes de départ par ProgressData.weapons_unlocked)
	#      affiche une liste VIDE -> run bloquée. (Le perso n'apparaissait que grâce
	#      au mod de test DevUnlockAll, qui ne débloque que les personnages,
	#      masquant le même bug côté arme.)
	#   2. difficulties_unlocked -> crée l'entrée de suivi de difficulté de notre
	#      perso. Sans elle, get_character_difficulty_info() renvoie un objet jetable
	#      à la victoire (run_data.gd apply_run_won) : le danger battu n'est jamais
	#      persisté et la vignette de sélection garde le fond par défaut (pas de
	#      couleur par danger max, pas de cadre au danger 6).
	ProgressData.add_unlocked_by_default()

	# Le _ready() parent fixe upgrades_into.previous_upgrade pour toutes les armes.
	._ready()


# Charge une arme-bombe, pose son icône (bombe de l'élément sur disque de rareté)
# et l'injecte dans le pool. Idempotent. Icône runtime (null en headless => on
# garde l'icône du .tres).
func _register_bomb_weapon(path: String) -> void:
	var w = load(path)
	if w == null:
		return
	var element = BombElement.from_weapon_id(w.weapon_id)
	var skin = BombSkin.build_icon(element, get_color_from_tier(w.tier))
	if skin != null:
		w.icon = skin
	if not weapons.has(w):
		weapons.append(w)
		ModLog.info("arme enregistrée: " + str(w.my_id))


# --- Magasin « roster Bomberto : bombe + explosive + knockback mêlée » ---
#
# POURQUOI un override : le jeu vanilla ne sait pas bannir une arme du magasin
# par ID. Dans _get_rand_item_for_wave(), character.banned_items n'est consulté
# QUE dans la branche ITEMS ; la branche ARMES ne filtre que par
# players_data[i].banned_items (jetons de ban en run), effets no_melee/no_ranged
# et biais de set — jamais par ID d'arme. La liste banned_items du perso est donc
# ignorée pour les armes. On filtre nous-mêmes le pool d'armes.
#
# get_player_shop_items tire armes ET items ; on pose un drapeau (joueur courant)
# pendant ce tirage, et get_pool ne garde que le roster Bomberto quand le pool
# d'ARMES est tiré pour un joueur Bomberto. Compatible avec l'empilement
# d'extensions (ShopConfig surcharge aussi get_pool/get_player_shop_items) via `.` (appel parent).
func get_player_shop_items(wave: int, player_index: int, args) -> Array:
	var previous = _shop_draw_player
	_shop_draw_player = player_index
	var result = .get_player_shop_items(wave, player_index, args)
	_shop_draw_player = previous
	return result


func get_pool(item_tier: int, type: int) -> Array:
	var pool = .get_pool(item_tier, type)
	if type == TierData.WEAPONS and _shop_draw_player >= 0 and _is_bomberman(_shop_draw_player):
		pool = ShopPool.keep_allowed_weapons(pool)
	return pool


func _is_bomberman(player_index: int) -> bool:
	var character = RunData.get_player_character(player_index)
	return character != null and character.my_id == _BOMBERMAN_ID
