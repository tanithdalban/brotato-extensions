extends "res://ui/menus/run/run_options_panel.gd"
# Ajoute un CheckButton "Config du magasin" dans le panneau d'options de run,
# sous CoopButton. La valeur est persistée dans ProgressData.settings.

func init() -> void:
	.init()
	var btn = CheckButton.new()
	btn.text = "Config du magasin / Shop Config"
	btn.clip_text = true
	btn.add_font_override("font", load("res://resources/fonts/actual/base/font_26.tres"))
	btn.pressed = ProgressData.settings.get("tanith_shopconfig_enabled", false)
	var _e = btn.connect("toggled", self, "_on_shopconfig_toggled")
	_coop_button.get_parent().add_child(btn)


func _on_shopconfig_toggled(value: bool) -> void:
	ProgressData.settings["tanith_shopconfig_enabled"] = value
