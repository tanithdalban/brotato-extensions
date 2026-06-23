extends Reference
# Logger propre au mod, désactivable. Godot 3 n'a pas de static var :
# le drapeau est stocké en méta globale sur Engine.

const LOG_NAME := "Tanith-Bomberman"
const _META := "tanith_bomberman_log_enabled"

static func set_enabled(value: bool) -> void:
	Engine.set_meta(_META, value)

static func is_enabled() -> bool:
	return Engine.has_meta(_META) and Engine.get_meta(_META)

static func info(msg: String) -> void:
	if is_enabled():
		ModLoaderLog.info(msg, LOG_NAME)

static func error(msg: String) -> void:
	ModLoaderLog.error(msg, LOG_NAME)
