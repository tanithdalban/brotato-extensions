extends "res://singletons/item_service.gd"
# Enregistre le contenu du mod Bomberman dans les pools du jeu :
# on ajoute nos armes aux tableaux exportés AVANT de recâbler les
# upgrades, en appelant le _ready() parent après injection.

const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")
const ShopPool = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/shop_pool.gd")
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")

const _BOMBERMAN_ID := "character_bomberman"

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

const _BOMBERMAN_CHAR := "res://mods-unpacked/Tanith-Bomberman/content/characters/bomberman/bomberman_data.tres"

func _ready() -> void:
	# Injecter nos armes dans le pool vanilla avant le recâblage des upgrades.
	for path in _BOMB_WEAPONS:
		var w = load(path)
		if w != null:
			# Icône colorée par tier (chargée au runtime, hors cache d'import).
			# On mute la WeaponData partagée : le magasin/inventaire lit son icon.
			var skin = BombSkin.load_texture(w.tier)
			if skin != null:
				w.icon = skin
		if w != null and not weapons.has(w):
			weapons.append(w)
			ModLog.info("arme enregistrée: " + str(w.my_id))

	# Enregistrer le personnage Bomberman dans le pool de personnages.
	var character = load(_BOMBERMAN_CHAR)
	if character != null and not characters.has(character):
		characters.append(character)
		ModLog.info("perso enregistré: " + str(character.my_id))

	# Débloquer explicitement nos contenus.
	# ProgressData est un autoload déclaré AVANT ItemService (project.godot),
	# donc ProgressData._ready() -> add_unlocked_by_default() s'exécute AVANT ce
	# _ready() : nos armes/perso injectés ici échappent au passage de déblocage
	# par défaut. Sans ça, l'écran de sélection d'arme (qui filtre les armes de
	# départ par ProgressData.weapons_unlocked) affiche une liste VIDE -> run
	# bloquée. (Le perso n'apparaissait que grâce au mod de test DevUnlockAll,
	# qui ne débloque que les personnages, masquant le même bug côté arme.)
	_unlock_modded_content()

	# Le _ready() parent fixe upgrades_into.previous_upgrade pour toutes les armes.
	._ready()


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
# d'extensions (ShopConfig surcharge aussi get_pool/get_player_shop_items) via `.
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


# Ajoute nos armes/perso (unlocked_by_default) aux listes de déblocage de
# ProgressData, manquées par le passage vanilla à cause de l'ordre des autoloads.
# Idempotent (gardes anti-doublon) ; reproduit la logique de
# ProgressData.add_unlocked_by_default() bornée à notre contenu.
func _unlock_modded_content() -> void:
	for path in _BOMB_WEAPONS:
		var w = load(path)
		if w == null:
			continue
		w._generate_hashes()
		if w.unlocked_by_default and not ProgressData.weapons_unlocked.has(w.weapon_id_hash):
			ProgressData.weapons_unlocked.push_back(w.weapon_id_hash)
			ModLog.info("arme débloquée: " + str(w.my_id))

	var character = load(_BOMBERMAN_CHAR)
	if character != null:
		character._generate_hashes()
		if character.unlocked_by_default and not ProgressData.characters_unlocked.has(character.my_id_hash):
			ProgressData.characters_unlocked.push_back(character.my_id_hash)
			ModLog.info("perso débloqué: " + str(character.my_id))
