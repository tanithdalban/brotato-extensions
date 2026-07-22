extends Node

const LOG_NAME := "Tanith-Bomberman"
const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")
const BombermanTranslations = preload("res://mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd")

func _init() -> void:
	_setup_logging()
	ModLog.info("init")
	_install_extensions()
	BombermanTranslations.register()
	ModLog.info("traductions enregistrées")

func _setup_logging() -> void:
	var enabled := false
	var conf = null
	if ModLoaderConfig.get_current_config_name(LOG_NAME) != "":
		conf = ModLoaderConfig.get_current_config(LOG_NAME)
	else:
		conf = ModLoaderConfig.get_default_config(LOG_NAME)
	if conf != null and conf.data is Dictionary:
		enabled = bool(conf.data.get("debug_log", false))
	ModLog.set_enabled(enabled)

func _install_extensions() -> void:
	# progress_data en premier : c'est le point d'accroche le PLUS TÔT du mod
	# (il injecte notre contenu avant que la sauvegarde de run soit désérialisée).
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-Bomberman/extensions/singletons/progress_data.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-Bomberman/extensions/particles/burning/burning_particles.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-Bomberman/extensions/singletons/challenge_service.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-Bomberman/extensions/singletons/run_data.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-Bomberman/extensions/ui/menus/run/character_selection.gd")
