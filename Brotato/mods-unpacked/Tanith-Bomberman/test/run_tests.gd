extends SceneTree
# Runner de tests autonome (pas de GUT dans le build Brotato).
# Lancer : Godot --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
# Code de sortie = nombre d'échecs (0 = tout passe).
# On ne teste QUE la logique 100 % pure (pas d'autoload ModLoader/jeu).

const BombTiming = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd")

var _failures := 0
var _count := 0

func _init():
	print("=== Bomberman tests ===")
	_test_fuse_seconds()
	_test_slot_phase_offset()
	print("=== %d tests, %d échec(s) ===" % [_count, _failures])
	quit(_failures)


func _approx(a, b):
	return abs(a - b) < 0.0001


func _test_fuse_seconds():
	_check(_approx(BombTiming.fuse_seconds(0), 2.0), "fuse: T1 = 2.0s")
	_check(_approx(BombTiming.fuse_seconds(3), 1.0), "fuse: T4 = 1.0s")
	_check(_approx(BombTiming.fuse_seconds(1), 2.0 - (1.0 / 3.0)), "fuse: T2 interpolé ≈ 1.667s")
	_check(_approx(BombTiming.fuse_seconds(2), 2.0 - (2.0 / 3.0)), "fuse: T3 interpolé ≈ 1.333s")
	_check(_approx(BombTiming.fuse_seconds(-5), 2.0), "fuse: clamp bas = T1")
	_check(_approx(BombTiming.fuse_seconds(99), 1.0), "fuse: clamp haut = T4")


func _test_slot_phase_offset():
	_check(_approx(BombTiming.slot_phase_offset(0, 4, 60.0), 0.0), "phase: slot 0 = 0")
	_check(_approx(BombTiming.slot_phase_offset(1, 4, 60.0), 15.0), "phase: slot 1/4 sur 60 = 15")
	_check(_approx(BombTiming.slot_phase_offset(2, 4, 60.0), 30.0), "phase: slot 2/4 sur 60 = 30")
	_check(_approx(BombTiming.slot_phase_offset(0, 1, 60.0), 0.0), "phase: slot unique = 0")
	_check(_approx(BombTiming.slot_phase_offset(3, 4, 0.0), 0.0), "phase: cooldown 0 => 0")

func _check(cond, name):
	_count += 1
	if not cond:
		_failures += 1
		print("FAIL: ", name)
	else:
		print("ok  : ", name)
