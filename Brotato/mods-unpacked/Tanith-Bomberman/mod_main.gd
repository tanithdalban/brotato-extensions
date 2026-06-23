extends Node

const LOG_NAME := "Tanith-Bomberman"
const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")

func _init() -> void:
	_setup_logging()
	ModLog.info("init")
	_install_extensions()

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
	# Les extensions seront ajoutées aux tâches T5/T6.
	pass
