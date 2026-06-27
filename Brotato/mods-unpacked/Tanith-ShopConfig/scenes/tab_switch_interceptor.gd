extends Node
# Intercepteur d'entree clavier pour le changement d'onglet en COOP.
#
# En coop, chaque joueur navigue via un FocusEmulator qui CONSOMME les touches de
# deplacement (ui_left/right/up/down) avant le reste de l'arbre. Or A = ui_left
# dans Brotato : sans cet intercepteur, A serait mange par le focus coop et notre
# panneau ne la verrait jamais (E = ui_select et L1/R1 passent, eux, c'est pourquoi
# ils marchent deja).
#
# Astuce : ce noeud est ajoute en DERNIER enfant de l'ecran. Godot delivre _input
# en ordre INVERSE de l'arbre, donc on recoit l'evenement AVANT les FocusEmulator.
# On route alors A/E vers le panneau du joueur au clavier et on consomme l'event
# pour que le deplacement ne le recupere pas.

var panels = []   # player_shop_config_panel (rempli par l'ecran)


func _input(event) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# On matche le CARACTERE tape (suit la disposition clavier), repli sur scancode.
	var ch = char(event.unicode).to_lower()
	var dir = 0
	if ch == "a" or event.scancode == KEY_A:
		dir = -1
	elif ch == "e" or event.scancode == KEY_E:
		dir = 1
	if dir == 0:
		return
	var handled = false
	for panel in panels:
		# Seul le panneau du joueur au clavier reagit (en coop, les autres sont a la
		# manette et utilisent L1/R1).
		if not CoopService.is_player_using_gamepad(panel.get_player_index()):
			panel.switch_tab(dir)
			handled = true
	if handled:
		get_tree().set_input_as_handled()
