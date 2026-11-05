extends "res://singletons/item_service.gd"
# Enregistre le contenu du mod Bomberman dans les pools du jeu :
# on ajoute nos armes aux tableaux exportés AVANT de recâbler les
# upgrades, en appelant le _ready() parent après injection.

const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")
const ShopPool = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/shop_pool.gd")
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")
const AnimatedIcon = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/animated_icon.gd")
const BombElement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd")
const BombCurse = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_curse.gd")

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

# Garde-fou d'idempotence de register_bomberman_content() : l'injection est appelée
# deux fois volontairement (cf. la doc de la méthode), et rejouer les chargements
# d'images ne coûterait que du temps de démarrage.
var _bomberman_content_registered := false

# Les 24 armes-bombes inscrites par register_bomberman_content(), dans l'ordre.
# init_unlocked_pool() les reverse dans les pools du magasin (cf. sa doc).
var _bomberman_bomb_weapons := []

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

const _BOMB_FRAG_WEAPONS := [
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_frag_1_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_frag_2_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_frag_3_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_frag_4_data.tres",
]

const _BOMBERMAN_CHAR := "res://mods-unpacked/Tanith-Bomberman/content/characters/bomberman/bomberman_data.tres"

func _ready() -> void:
	register_bomberman_content()

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


# Injecte armes + perso du mod dans les pools de ItemService. IDEMPOTENT, et appelé
# DEUX fois volontairement :
#   1. depuis l'extension ProgressData (load_game_file), AVANT que la sauvegarde de
#      la run en cours soit désérialisée — c'est le point qui compte ;
#   2. depuis notre _ready() ci-dessus, en filet de sécurité si (1) ne passait pas.
#
# ⚠️ POURQUOI (1) : ProgressData est l'autoload #9 et ItemService le #11
# (project.godot). ProgressData._ready() charge la run sauvegardée, et
# PlayerRunData.deserialize() résout perso/armes/objets par my_id contre les
# tableaux de ItemService en jetant SILENCIEUSEMENT tout id introuvable. Sans
# injection préalable, reprendre une partie après avoir quitté le jeu rendait un
# Bomberto sans perso ni bombes — et réécrivait la sauvegarde ainsi amputée, donc
# la perte était définitive. Détail complet dans extensions/singletons/progress_data.gd.
func register_bomberman_content() -> void:
	if _bomberman_content_registered:
		return
	_bomberman_content_registered = true

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
	for path in _BOMB_FRAG_WEAPONS:
		_register_bomb_weapon(path)

	# Enregistrer le personnage Bomberman dans le pool de personnages.
	# ⚠️ Toujours passer par get_characters()/get_weapons(), JAMAIS par le nom nu.
	# Depuis Brotato 1.2, `characters`/`weapons`/`items` sont des propriétés
	# `setget` paresseuses (caches `_characters`… reconstruits depuis
	# update_data_list). En Godot 3, un accès nu depuis le script (ou une
	# extension de celui-ci) CONTOURNE le getter et lit la variable brute, qui
	# reste `null`. Le getter rend le tableau cache par référence : y ajouter
	# persiste, le vanilla n'invalidant jamais ces caches.
	var character = load(_BOMBERMAN_CHAR)
	if character != null and not get_characters().has(character):
		get_characters().append(character)
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
	if not _bomberman_bomb_weapons.has(w):
		_bomberman_bomb_weapons.append(w)
	if not get_weapons().has(w):
		get_weapons().append(w)
		ModLog.info("arme enregistrée: " + str(w.my_id))


# --- Bombes dans les pools du magasin (Brotato >= 1.2) ---
#
# POURQUOI : en 1.1, init_unlocked_pool() remplissait les pools par tier
# (_tiers_data, d'où le magasin, les caisses et get_pool tirent) en parcourant
# `weapons` — où register_bomberman_content() inscrit nos bombes. Depuis la 1.2,
# il parcourt les PAQUETS de contenu (base_game_item_set + mises à jour/DLC
# actifs, item_service.gd:225-254) : nos bombes, inscrites seulement dans
# get_weapons(), n'entraient plus jamais en boutique. Elles restaient visibles à
# l'écran de choix d'arme (qui lit get_weapons()), d'où un bug discret : aucune
# bombe en boutique, et une boutique SANS ARME pour un Bomberto restreint aux
# bombes via ShopConfig.
#
# On laisse le parent reconstruire les pools (il les remet à zéro à chaque
# appel), puis on y reverse nos bombes avec ses propres règles (lootable +
# débloquée, cf. ShopPool.weapons_to_add_to_tiers). Pas d'ajout au paquet du jeu
# de base : il alimente aussi d'autres écrans, et ce correctif reste borné au
# magasin.
func init_unlocked_pool() -> void:
	.init_unlocked_pool()
	_bomberman_add_bombs_to_tiers()


func _bomberman_add_bombs_to_tiers() -> void:
	var weapon_pools := []
	for tier_data in _tiers_data:
		weapon_pools.append(tier_data[TierData.WEAPONS])
	var to_add = ShopPool.weapons_to_add_to_tiers(
		_bomberman_bomb_weapons, ProgressData.weapons_unlocked, weapon_pools
	)
	for weapon in to_add:
		_tiers_data[weapon.tier][TierData.ALL_ITEMS].push_back(weapon)
		_tiers_data[weapon.tier][TierData.WEAPONS].push_back(weapon)
	ModLog.info("bombes versées dans les pools du magasin : %d" % to_add.size())


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


# Réaligne une bombe que le DLC Abyssal Terrors vient de maudire.
#
# apply_item_effect_modifications (item_service.gd:511-518) est l'endroit précis où
# `curse_item()` s'applique à un élément tiré du pool. En corrigeant juste derrière,
# l'infobulle de la boutique dit déjà la vérité AVANT l'achat, et l'instance achetée
# est la même que celle affichée.
#
# Ce n'est PAS le seul chemin : base_shop.gd:691 (fusion/upgrade) et :879 (objets
# verrouillés) appellent `curse_item()` en direct et court-circuitent cette méthode.
# C'est l'extension de RunData.add_weapon qui les rattrape — normalize étant
# idempotent, une arme qui passe par les deux n'est corrigée qu'une fois.
func apply_item_effect_modifications(item: ItemParentData, player_index: int) -> ItemParentData:
	var result = .apply_item_effect_modifications(item, player_index)
	if result != null:
		BombCurse.normalize(result, get_element_safe(get_weapons(), result.my_id))
	return result


func _is_bomberman(player_index: int) -> bool:
	var character = RunData.get_player_character(player_index)
	return character != null and character.my_id == _BOMBERMAN_ID
