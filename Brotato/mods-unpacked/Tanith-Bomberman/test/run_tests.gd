extends SceneTree
# Runner de tests autonome (pas de GUT dans le build Brotato).
# Lancer : Godot --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
# Code de sortie = nombre d'échecs (0 = tout passe).
# On ne teste QUE la logique 100 % pure (pas d'autoload ModLoader/jeu).

var _failures := 0
var _count := 0

func _init():
	print("=== Bomberman tests ===")
	# Les suites de tests seront ajoutées en T2.
	print("=== %d tests, %d échec(s) ===" % [_count, _failures])
	quit(_failures)

func _check(cond, name):
	_count += 1
	if not cond:
		_failures += 1
		print("FAIL: ", name)
	else:
		print("ok  : ", name)
