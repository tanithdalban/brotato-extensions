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

func _ready() -> void:
	# Injecter nos armes dans le pool vanilla avant le recâblage des upgrades.
	for path in _BOMB_WEAPONS:
		var w = load(path)
		if w != null and not weapons.has(w):
			weapons.append(w)
			ModLog.info("arme enregistrée: " + str(w.my_id))
	# Le _ready() parent fixe upgrades_into.previous_upgrade pour toutes les armes.
	._ready()
