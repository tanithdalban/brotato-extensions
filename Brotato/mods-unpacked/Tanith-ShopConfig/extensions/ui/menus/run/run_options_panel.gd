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
#
# ⚠️ IDEMPOTENCE OBLIGATOIRE : init() peut être appelée PLUSIEURS FOIS sur le
# MÊME panneau. Quand le mod Bomberman est aussi actif, il étend lui aussi
# character_selection.gd et surcharge _ready() en rappelant ._ready() (pattern
# ModLoader correct) ; combiné à l'empilement d'extensions, le _ready() vanilla
# — donc init_coop_service() -> run_options_panel.init() — s'exécute DEUX fois.
# Les widgets vanilla préexistent dans la .tscn (les rappeler ne les duplique
# pas) ; nous, on add_child() -> sans garde-fou, on obtenait deux cases.
const CHECKBOX_TEXT := "Config du magasin / Shop Config"

func init() -> void:
	.init()
	# VBox intérieur (Zone/Endless/Ban/Coop) -> son parent = VBox extérieur du panneau.
	var outer_vbox = _coop_button.get_parent().get_parent()
	# Déjà posée par un précédent appel à init() ? On ne la duplique pas.
	for child in outer_vbox.get_children():
		if child is CheckButton and child.text == CHECKBOX_TEXT:
			return
	var btn = CheckButton.new()
	btn.text = CHECKBOX_TEXT
	btn.clip_text = true
	btn.add_font_override("font", load("res://resources/fonts/actual/base/font_26.tres"))
	# Défaut = vrai : actif tant que l'utilisateur n'a pas explicitement décoché
	# (garde-fou si la case venait à ne pas s'afficher dans le panneau d'options).
	btn.pressed = ProgressData.settings.get("tanith_shopconfig_enabled", true)
	var _e = btn.connect("toggled", self, "_on_shopconfig_toggled")
	outer_vbox.add_child(btn)


func _on_shopconfig_toggled(value: bool) -> void:
	ProgressData.settings["tanith_shopconfig_enabled"] = value
