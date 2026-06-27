extends SceneTree
# Runner de tests autonome (pas de GUT dans le build Brotato).
# Lancer : Godot --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
# Code de sortie = nombre d'échecs (0 = tout passe).
# On ne teste QUE la logique 100 % pure (pas d'autoload ModLoader/jeu).

const BombTiming = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd")
const ShopPool = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/shop_pool.gd")
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")

var _failures := 0
var _count := 0

# Faux WeaponData minimal pour les tests purs du filtre de pool.
class _StubWeapon:
	var weapon_id
	func _init(id):
		weapon_id = id

func _init():
	print("=== Bomberman tests ===")
	_test_fuse_seconds()
	_test_slot_phase_offset()
	_test_keep_only_bombs()
	_test_bomb_skin()
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


func _test_keep_only_bombs():
	var bomb1 = _StubWeapon.new("weapon_bomb")
	var bomb2 = _StubWeapon.new("weapon_bomb")
	var sword = _StubWeapon.new("weapon_sword_2")
	var pistol = _StubWeapon.new("weapon_pistol_1")
	var pool = [sword, bomb1, pistol, bomb2]

	var kept = ShopPool.keep_only_bombs(pool)
	_check(kept.size() == 2, "shop: garde 2 bombes sur 4")
	_check(kept.size() == 2 and kept[0] == bomb1 and kept[1] == bomb2, "shop: ne garde que les bombes, dans l'ordre")
	_check(pool.size() == 4, "shop: n'altère pas la liste d'entrée")
	_check(ShopPool.keep_only_bombs([]).size() == 0, "shop: pool vide => vide")
	_check(ShopPool.keep_only_bombs([sword, pistol]).size() == 0, "shop: aucune bombe => vide")

func _test_bomb_skin():
	# Mapping tier -> couleur (rareté Brotato).
	_check(BombSkin.color_for_tier(0) == "gray", "skin: T1 = gray")
	_check(BombSkin.color_for_tier(1) == "blue", "skin: T2 = blue")
	_check(BombSkin.color_for_tier(2) == "purple", "skin: T3 = purple")
	_check(BombSkin.color_for_tier(3) == "red", "skin: T4 = red")
	# Clamps.
	_check(BombSkin.color_for_tier(-3) == "gray", "skin: clamp bas = gray")
	_check(BombSkin.color_for_tier(99) == "red", "skin: clamp haut = red")
	# Chemins construits : icône 96 vs sprite en jeu 48.
	_check(BombSkin.texture_path(2).ends_with("/skins/bomb_purple.png"), "skin: icône T3 = bomb_purple.png")
	_check(BombSkin.world_texture_path(2).ends_with("/skins/bomb_purple_48.png"), "skin: en jeu T3 = bomb_purple_48.png")
	_check(BombSkin.world_texture_path(0).ends_with("/skins/bomb_gray_48.png"), "skin: en jeu T1 = bomb_gray_48.png")


func _check(cond, name):
	_count += 1
	if not cond:
		_failures += 1
		print("FAIL: ", name)
	else:
		print("ok  : ", name)
