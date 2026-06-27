extends Node

const LOG_NAME := "Tanith-ShopConfig"
const ModLog = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/mod_log.gd")

func _init() -> void:
	_setup_logging()
	ModLog.info("init")
	_install_extensions()

func _setup_logging() -> void:
	var enabled := false
	# Config courante si l'utilisateur en a choisi une, sinon la config par défaut
	# (générée depuis le config_schema). On évite get_current_config avec un nom vide.
	var conf = null
	if ModLoaderConfig.get_current_config_name(LOG_NAME) != "":
		conf = ModLoaderConfig.get_current_config(LOG_NAME)
	else:
		conf = ModLoaderConfig.get_default_config(LOG_NAME)
	if conf != null and conf.data is Dictionary:
		enabled = bool(conf.data.get("debug_log", false))
	ModLog.set_enabled(enabled)

func _install_extensions() -> void:
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/run_options_panel.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-ShopConfig/extensions/singletons/item_service.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd")
