extends Control
# Popup de migration des bombes, construit EN CODE au thème du jeu.
#
# POURQUOI PAS un ConfirmationDialog : c'est une WindowDialog, donc une fenêtre au
# CHROME NATIF de Godot (barre de titre claire, croix de fermeture, boutons par
# défaut). Sans thème, ça jure violemment avec Brotato ; et le chrome lui-même n'est
# pas rhabillable proprement (le titre est dessiné par la fenêtre, pas par un Label
# qu'on pourrait styler, d'où le titre tronqué qui débordait par le haut).
# On reconstruit donc le dialogue avec les briques du jeu : PanelContainer +
# base_theme.tres, Labels et Buttons ordinaires. Aucun chrome, aucune croix.
#
# ⚠️ PAS de croix de fermeture, VOLONTAIREMENT : les deux réponses écrivent dans la
# sauvegarde permanente. On veut un choix, pas une fermeture accidentelle. `ui_cancel`
# reste un échappatoire (= ne rien persister, la question sera reposée), c'est le
# comportement sûr.
#
# Confinement du focus : les deux boutons sont VOISINS l'un de l'autre dans les quatre
# directions (set_focus_neighbour). Sans ça, la manette peut sortir du popup et aller
# focaliser les vignettes de personnages DERRIÈRE lui — ce popup n'est pas modal au
# sens de Godot (ce n'est plus une fenêtre). Même parade que les listes déroulantes
# maison de ShopConfig.

signal relock_chosen  # « Vivre la progression » : reverrouiller les bombes
signal keep_chosen    # « Garder mes bombes »
signal dismissed      # fermé sans choisir (ui_cancel)

const _THEME := preload("res://resources/themes/base_theme.tres")
const _FONT_TITLE := preload("res://resources/fonts/actual/base/font_26_outline.tres")
const _FONT_TEXT := preload("res://resources/fonts/actual/base/font_22.tres")

const _PANEL_WIDTH := 760
const _DIM_COLOR := Color(0, 0, 0, 0.65)

var _keep_button: Button = null


# Construit et renseigne le popup. Les textes sont déjà traduits par l'appelant.
func setup(title: String, text: String, relock_label: String, keep_label: String) -> void:
	theme = _THEME
	# Plein écran : le voile assombri doit couvrir l'écran de sélection, et intercepter
	# les clics pour qu'on ne puisse pas cliquer « à travers » le popup.
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = _DIM_COLOR
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# CenterContainer : le panneau se dimensionne sur son contenu et reste centré,
	# quelle que soit la longueur du texte traduit (FR et EN n'ont pas la même).
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.rect_min_size = Vector2(_PANEL_WIDTH, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_constant_override("margin_" + side, 32)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_constant_override("separation", 20)
	margin.add_child(rows)

	var title_label := Label.new()
	title_label.text = title
	title_label.align = Label.ALIGN_CENTER
	title_label.autowrap = true
	title_label.add_font_override("font", _FONT_TITLE)
	rows.add_child(title_label)

	var text_label := Label.new()
	text_label.text = text
	text_label.autowrap = true
	text_label.add_font_override("font", _FONT_TEXT)
	rows.add_child(text_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGN_CENTER
	buttons.add_constant_override("separation", 24)
	rows.add_child(buttons)

	var relock_button := Button.new()
	relock_button.text = relock_label
	var _r = relock_button.connect("pressed", self, "_on_relock_pressed")
	buttons.add_child(relock_button)

	_keep_button = Button.new()
	_keep_button.text = keep_label
	var _k = _keep_button.connect("pressed", self, "_on_keep_pressed")
	buttons.add_child(_keep_button)

	_confine_focus(relock_button, _keep_button)


# Le focus ne doit jamais quitter le popup : chaque bouton pointe sur l'autre dans les
# quatre directions. Sans ça, la manette irait focaliser l'écran de sélection derrière.
func _confine_focus(a: Button, b: Button) -> void:
	for pair in [[a, b], [b, a]]:
		var from: Button = pair[0]
		var to: Button = pair[1]
		var path := to.get_path()
		from.focus_mode = Control.FOCUS_ALL
		from.set_focus_neighbour(MARGIN_LEFT, path)
		from.set_focus_neighbour(MARGIN_RIGHT, path)
		from.set_focus_neighbour(MARGIN_TOP, path)
		from.set_focus_neighbour(MARGIN_BOTTOM, path)
		from.focus_next = path
		from.focus_previous = path


func _ready() -> void:
	# ⚠️ Le défaut est l'option SÛRE. « Vivre la progression » REVERROUILLE les bombes :
	# c'est destructif et irréversible. Un joueur qui enchaîne les menus en martelant A
	# effacerait ses bombes sans avoir rien lu.
	if _keep_button != null:
		_keep_button.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_released("ui_cancel"):
		get_tree().set_input_as_handled()
		emit_signal("dismissed")


func _on_relock_pressed() -> void:
	emit_signal("relock_chosen")


func _on_keep_pressed() -> void:
	emit_signal("keep_chosen")
