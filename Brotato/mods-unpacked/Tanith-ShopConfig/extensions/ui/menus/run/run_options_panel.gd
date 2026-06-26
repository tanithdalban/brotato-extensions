extends "res://ui/menus/run/run_options_panel.gd"
# Ajoute un CheckButton "Config du magasin" dans le panneau d'options de run.
# La valeur est persistée dans ProgressData.settings.
#
# Placement : on l'ajoute au VBox *extérieur* du panneau (en-tête + groupe
# d'options), tout en bas de la zone, et NON dans le VBox intérieur qui liste
# Zone/Endless/Ban/Coop. Les DLC (ex. Abyssal Terrors) insèrent leur propre
# CheckButton dans ce VBox intérieur ; y ajouter le nôtre les faisait se
# chevaucher (notre case cachée par celle du DLC). En le sortant dans le VBox
# extérieur, il reste isolé et toujours visible en bas du panneau.

func init() -> void:
	.init()
	var btn = CheckButton.new()
	btn.text = "Config du magasin / Shop Config"
	btn.clip_text = true
	btn.add_font_override("font", load("res://resources/fonts/actual/base/font_26.tres"))
	# Défaut = vrai : actif tant que l'utilisateur n'a pas explicitement décoché
	# (garde-fou si la case venait à ne pas s'afficher dans le panneau d'options).
	btn.pressed = ProgressData.settings.get("tanith_shopconfig_enabled", true)
	var _e = btn.connect("toggled", self, "_on_shopconfig_toggled")
	# VBox intérieur (Zone/Endless/Ban/Coop) -> son parent = VBox extérieur du panneau.
	var outer_vbox = _coop_button.get_parent().get_parent()
	outer_vbox.add_child(btn)


func _on_shopconfig_toggled(value: bool) -> void:
	ProgressData.settings["tanith_shopconfig_enabled"] = value
