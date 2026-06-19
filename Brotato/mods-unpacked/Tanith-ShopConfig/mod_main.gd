extends Node

const LOG_NAME := "Tanith-ShopConfig"
const ModLog = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/mod_log.gd")

func _init() -> void:
	_setup_logging()
	ModLog.info("init")
	_install_extensions()

func _setup_logging() -> void:
	var enabled := false
	var conf = ModLoaderConfig.get_current_config("Tanith-ShopConfig")
	if conf != null and conf.data is Dictionary:
		enabled = bool(conf.data.get("debug_log", false))
	ModLog.set_enabled(enabled)

func _install_extensions() -> void:
	# Les extensions sont ajoutées au fur et à mesure (Tasks 4.1, 5.4).
	pass
