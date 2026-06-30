extends Reference
# Store des exclusions par joueur + contexte de pioche magasin.
# Instance unique tenue par l'extension ItemService : les exclusions PERSISTENT
# toute la session de jeu (mémoire run-à-run, sans disque ; cf. CLAUDE.md). L'écran
# NE reset PLUS à l'ouverture — il pré-charge depuis le store. reset() ne sert plus
# qu'aux tests (le bouton « Tout réinitialiser » du panneau, lui, pousse juste un
# set_excluded vide au commit, sans toucher au contexte de pioche).

var _excluded_by_player := {}   # player_index -> { my_id: true }
var _shop_draw_active := false
var _shop_draw_player := -1

func reset() -> void:
	_excluded_by_player.clear()
	_shop_draw_active = false
	_shop_draw_player = -1

func set_excluded(player_index: int, excluded_ids: Dictionary) -> void:
	_excluded_by_player[player_index] = excluded_ids.duplicate()

func get_excluded(player_index: int) -> Dictionary:
	if _excluded_by_player.has(player_index):
		return _excluded_by_player[player_index]
	return {}

func has_any_available(player_index: int, total_count: int) -> bool:
	return get_excluded(player_index).size() < total_count

func begin_shop_draw(player_index: int) -> void:
	_shop_draw_active = true
	_shop_draw_player = player_index

func end_shop_draw() -> void:
	_shop_draw_active = false
	_shop_draw_player = -1

func is_shop_draw_active() -> bool:
	return _shop_draw_active

func current_shop_player() -> int:
	return _shop_draw_player
