extends "res://singletons/item_service.gd"
# Enregistre le contenu du mod Bomberman dans les pools du jeu :
# on ajoute nos armes aux tableaux exportés AVANT de recâbler les
# upgrades, en appelant le _ready() parent après injection.

const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")

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
