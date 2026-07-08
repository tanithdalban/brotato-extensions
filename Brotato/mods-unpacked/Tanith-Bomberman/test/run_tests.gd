extends SceneTree
# Runner de tests autonome (pas de GUT dans le build Brotato).
# Lancer : Godot --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
# Code de sortie = nombre d'échecs (0 = tout passe).
# On ne teste QUE la logique 100 % pure (pas d'autoload ModLoader/jeu).

const BombTiming = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd")
const ShopPool = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/shop_pool.gd")
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")
const TrollLogic = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd")
const AnimatedIcon = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/animated_icon.gd")
const BombElement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd")
const BombIceSlow = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_ice_slow.gd")

var _failures := 0
var _count := 0

# Faux objets minimaux pour les tests purs du filtre de pool.
class _StubSet:
	var my_id
	func _init(id):
		my_id = id

class _StubStats:
	var knockback
	func _init(kb):
		knockback = kb

class _StubWeapon:
	var weapon_id
	var sets
	var stats
	var type
	func _init(p_weapon_id = "", p_sets = [], p_knockback = 0, p_type = 1):
		weapon_id = p_weapon_id
		sets = p_sets
		stats = _StubStats.new(p_knockback)
		type = p_type

func _init():
	print("=== Bomberman tests ===")
	_test_fuse_seconds()
	_test_slot_phase_offset()
	_test_keep_allowed_weapons()
	_test_bomb_icon_background()
	_test_bomb_skin_element()
	_test_troll_should_wake()
	_test_troll_wake_delay()
	_test_troll_nearest_target()
	_test_troll_step_velocity()
	_test_troll_nonlethal_damage()
	_test_troll_min_living_hp()
	_test_troll_keep_distance()
	_test_animated_icon_helpers()
	_test_bomb_element()
	_test_bomb_ice_slow()
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
	# Mèche ajustée par la vitesse d'attaque (formule cooldown vanilla).
	_check(_approx(BombTiming.fuse_seconds_scaled(0, 0.0), 2.0), "fuse_scaled: vitesse 0 => mèche de base")
	_check(_approx(BombTiming.fuse_seconds_scaled(0, 1.0), 1.0), "fuse_scaled: +100% => moitié (2.0/2)")
	_check(_approx(BombTiming.fuse_seconds_scaled(0, 0.5), 2.0 / 1.5), "fuse_scaled: +50% => 2.0/1.5")
	_check(_approx(BombTiming.fuse_seconds_scaled(0, -0.5), 3.0), "fuse_scaled: -50% => rallonge ×1.5")
	_check(_approx(BombTiming.fuse_seconds_scaled(3, 1.0), 0.5), "fuse_scaled: T4 +100% => plancher 0.5")
	_check(_approx(BombTiming.fuse_seconds_scaled(3, 3.0), 0.5), "fuse_scaled: T4 +300% => borné au plancher 0.5")


func _test_slot_phase_offset():
	_check(_approx(BombTiming.slot_phase_offset(0, 4, 60.0), 0.0), "phase: slot 0 = 0")
	_check(_approx(BombTiming.slot_phase_offset(1, 4, 60.0), 15.0), "phase: slot 1/4 sur 60 = 15")
	_check(_approx(BombTiming.slot_phase_offset(2, 4, 60.0), 30.0), "phase: slot 2/4 sur 60 = 30")
	_check(_approx(BombTiming.slot_phase_offset(0, 1, 60.0), 0.0), "phase: slot unique = 0")
	_check(_approx(BombTiming.slot_phase_offset(3, 4, 0.0), 0.0), "phase: cooldown 0 => 0")


func _test_keep_allowed_weapons():
	var SET_EXPLOSIVE = [_StubSet.new("set_explosive")]
	var SET_HEAVY = [_StubSet.new("set_heavy")]
	# weapon_id, sets, knockback, type (0=MELEE, 1=RANGED)
	var bomb = _StubWeapon.new("weapon_bomb", [], 0, 1)
	var rocket = _StubWeapon.new("weapon_rocket_launcher", SET_EXPLOSIVE, 0, 1)
	var hammer = _StubWeapon.new("weapon_hammer", SET_HEAVY, 30, 0)
	var hand = _StubWeapon.new("weapon_hand", [], 30, 0)
	var pistol = _StubWeapon.new("weapon_pistol", [], 15, 1)
	var sword = _StubWeapon.new("weapon_sword", [], 2, 0)
	var sniper = _StubWeapon.new("weapon_sniper", [], 20, 1)

	_check(ShopPool.is_allowed(bomb), "pool: bombe autorisée")
	_check(ShopPool.is_allowed(rocket), "pool: set explosive autorisé")
	_check(ShopPool.is_allowed(hammer), "pool: knockback 30 mêlée autorisé")
	_check(ShopPool.is_allowed(hand), "pool: hand (kb 30 mêlée) autorisé")
	_check(ShopPool.is_allowed(_StubWeapon.new("weapon_wrench", [], 20, 0)), "pool: knockback 20 mêlée (borne) autorisé")
	_check(not ShopPool.is_allowed(pistol), "pool: pistolet (kb 15 distance) refusé")
	_check(not ShopPool.is_allowed(sword), "pool: épée (kb 2) refusée")
	_check(not ShopPool.is_allowed(sniper), "pool: sniper (kb 20 mais distance) refusé")
	_check(not ShopPool.is_allowed(null), "pool: null refusé")

	var pool = [sword, bomb, pistol, rocket, hand]
	var kept = ShopPool.keep_allowed_weapons(pool)
	_check(kept.size() == 3, "pool: garde 3 sur 5 (bombe, rocket, hand)")
	_check(kept[0] == bomb and kept[1] == rocket and kept[2] == hand, "pool: conserve l'ordre")
	_check(pool.size() == 5, "pool: n'altère pas la liste d'entrée")
	_check(ShopPool.keep_allowed_weapons([]).size() == 0, "pool: vide => vide")

	# Préfixe weapon_bomb : la glace passe même sans set explosive.
	_check(ShopPool.is_allowed(_StubWeapon.new("weapon_bomb_ice", [], 0, 1)), "pool: weapon_bomb_ice accepté (préfixe)")
	_check(ShopPool.is_allowed(_StubWeapon.new("weapon_bomb", [], 0, 1)), "pool: weapon_bomb accepté (préfixe)")
	_check(not ShopPool.is_allowed(_StubWeapon.new("weapon_smg", [], 0, 1)), "pool: weapon_smg rejeté")

func _test_bomb_icon_background():
	# Repli gris quand la couleur de rareté vaut blanc (tier commun).
	_check(BombSkin.icon_background_color(Color.white) == BombSkin.COMMON_BG, "icone: fond blanc (commun) -> gris")
	# Sinon, on conserve la couleur de rareté du jeu telle quelle.
	var red := Color(1.0, 0.231, 0.231, 1.0)
	_check(BombSkin.icon_background_color(red) == red, "icone: fond rareté conservé (rouge)")
	var purple := Color(0.678, 0.353, 1.0, 1.0)
	_check(BombSkin.icon_background_color(purple) == purple, "icone: fond rareté conservé (violet)")


func _test_bomb_skin_element():
	var normal_path = BombSkin.element_sprite_path("normal")
	var ice_path = BombSkin.element_sprite_path("ice")
	_check(normal_path.ends_with("bombe_normale.png"), "skin: normal -> bombe_normale.png")
	_check(ice_path.ends_with("glace.png"), "skin: ice -> glace.png")
	# Élément inconnu => repli sur normal (pas de crash).
	_check(BombSkin.element_sprite_path("inconnu").ends_with("bombe_normale.png"), "skin: inconnu -> repli normal")


func _test_troll_should_wake():
	_check(TrollLogic.should_wake(0.0, 0.1) == true, "troll: roll 0.0 < 0.1 => réveil")
	_check(TrollLogic.should_wake(0.05, 0.1) == true, "troll: roll 0.05 < 0.1 => réveil")
	_check(TrollLogic.should_wake(0.1, 0.1) == false, "troll: roll 0.1 pas < 0.1 => non")
	_check(TrollLogic.should_wake(0.5, 0.0) == false, "troll: chance 0 => jamais")
	_check(TrollLogic.should_wake(0.99, 1.0) == true, "troll: chance 1 => toujours")


func _test_troll_wake_delay():
	_check(_approx(TrollLogic.wake_delay(2.0, 0.5), 1.0), "troll: réveil à 50% de 2.0s = 1.0s")
	_check(_approx(TrollLogic.wake_delay(1.0, 0.5), 0.5), "troll: réveil à 50% de 1.0s = 0.5s")
	_check(_approx(TrollLogic.wake_delay(2.0, 0.0), 0.0), "troll: fraction 0 => 0")
	_check(_approx(TrollLogic.wake_delay(2.0, 2.0), 2.0), "troll: fraction clamp haut => mèche pleine")
	_check(_approx(TrollLogic.wake_delay(2.0, -1.0), 0.0), "troll: fraction clamp bas => 0")


func _test_troll_nearest_target():
	var from = Vector2(0, 0)
	var p_far = {"position": Vector2(100, 0), "dead": false, "index": 0}
	var p_near = {"position": Vector2(10, 0), "dead": false, "index": 1}
	var r = TrollLogic.nearest_target(from, [p_far, p_near])
	_check(r["found"] and r["index"] == 1, "troll: cible = joueur le plus proche")
	var p_dead_near = {"position": Vector2(5, 0), "dead": true, "index": 2}
	var r2 = TrollLogic.nearest_target(from, [p_dead_near, p_far])
	_check(r2["found"] and r2["index"] == 0, "troll: ignore le joueur mort")
	var r3 = TrollLogic.nearest_target(from, [])
	_check(not r3["found"], "troll: liste vide => aucune cible")
	var r4 = TrollLogic.nearest_target(from, [p_dead_near])
	_check(not r4["found"], "troll: tous morts => aucune cible")


func _test_troll_step_velocity():
	var v = TrollLogic.step_velocity(Vector2(0, 0), Vector2(10, 0), 100.0)
	_check(_approx(v.x, 100.0) and _approx(v.y, 0.0), "troll: déplacement vers la droite = (100,0)")
	_check(_approx(v.length(), 100.0), "troll: norme du déplacement = vitesse")
	var z = TrollLogic.step_velocity(Vector2(5, 5), Vector2(5, 5), 100.0)
	_check(z == Vector2.ZERO, "troll: positions confondues => zéro")


func _test_troll_nonlethal_damage():
	_check(TrollLogic.nonlethal_damage(10, 100) == 10, "troll: dégâts < PV => inchangés")
	_check(TrollLogic.nonlethal_damage(50, 30) == 29, "troll: dégâts >= PV => laisse à 1 PV (PV-1)")
	_check(TrollLogic.nonlethal_damage(50, 50) == 49, "troll: dégâts == PV => laisse à 1 PV")
	_check(TrollLogic.nonlethal_damage(10, 1) == 0, "troll: 1 PV => 0 dégât (pas de kill)")
	_check(TrollLogic.nonlethal_damage(10, 0) == 0, "troll: 0 PV => 0 dégât")
	_check(TrollLogic.nonlethal_damage(0, 100) == 0, "troll: 0 dégât brut => 0")


func _test_troll_min_living_hp():
	_check(TrollLogic.min_living_hp([30, 10, 50]) == 10, "troll: min PV = 10")
	_check(TrollLogic.min_living_hp([5]) == 5, "troll: un seul joueur => son PV")
	_check(TrollLogic.min_living_hp([]) == 0x7FFFFFFF, "troll: aucun joueur => très grand (pas de plafond)")
	_check(TrollLogic.min_living_hp([1, 100]) == 1, "troll: prend le plus bas (1)")


func _test_troll_keep_distance():
	# Déjà assez loin => inchangé.
	var far = TrollLogic.keep_distance(Vector2(200, 0), Vector2(0, 0), 100.0)
	_check(far == Vector2(200, 0), "troll: spawn déjà loin => inchangé")
	# Trop proche => repoussé à exactement min_dist sur le même axe.
	var near = TrollLogic.keep_distance(Vector2(10, 0), Vector2(0, 0), 100.0)
	_check(_approx(near.x, 100.0) and _approx(near.y, 0.0), "troll: spawn proche => repoussé à min_dist")
	# Pile sur le joueur => direction arbitraire, à min_dist.
	var on = TrollLogic.keep_distance(Vector2(5, 5), Vector2(5, 5), 80.0)
	_check(_approx((on - Vector2(5, 5)).length(), 80.0), "troll: spawn pile sur joueur => repoussé à min_dist")


func _test_animated_icon_helpers():
	# clamp_fps : plancher à MIN_FPS, sinon inchangé.
	_check(_approx(AnimatedIcon.clamp_fps(12.0), 12.0), "anim: fps 12 inchangé")
	_check(_approx(AnimatedIcon.clamp_fps(0.0), AnimatedIcon.MIN_FPS), "anim: fps 0 => plancher")
	_check(_approx(AnimatedIcon.clamp_fps(-5.0), AnimatedIcon.MIN_FPS), "anim: fps négatif => plancher")
	# usable_frame_count : borné [0, MAX_FRAMES].
	_check(AnimatedIcon.usable_frame_count(18) == 18, "anim: 18 frames inchangé")
	_check(AnimatedIcon.usable_frame_count(0) == 0, "anim: 0 frame => 0")
	_check(AnimatedIcon.usable_frame_count(-3) == 0, "anim: négatif => 0")
	_check(AnimatedIcon.usable_frame_count(300) == AnimatedIcon.MAX_FRAMES, "anim: au-delà de 256 => 256")


func _test_bomb_element():
	_check(BombElement.from_weapon_id("weapon_bomb") == BombElement.NORMAL, "element: weapon_bomb => normal")
	_check(BombElement.from_weapon_id("weapon_bomb_ice") == BombElement.ICE, "element: weapon_bomb_ice => ice")
	_check(BombElement.from_weapon_id("weapon_bomb_poison") == BombElement.POISON, "element: poison")
	_check(BombElement.from_weapon_id("weapon_bomb_storm") == BombElement.STORM, "element: storm")
	_check(BombElement.from_weapon_id("weapon_smg") == BombElement.NORMAL, "element: inconnu => normal (repli)")
	_check(BombElement.from_weapon_id("") == BombElement.NORMAL, "element: vide => normal")
	_check(BombElement.is_effect(BombElement.ICE), "element: ice est un effet")
	_check(not BombElement.is_effect(BombElement.NORMAL), "element: normal n'est pas un effet")


func _test_bomb_ice_slow():
	# slow_pct_for : magnitude du champ (négatif dans le .tres).
	_check(_approx(BombIceSlow.slow_pct_for(-30), 30.0), "ice: slow_pct_for(-30) = 30")
	_check(_approx(BombIceSlow.slow_pct_for(-60), 60.0), "ice: slow_pct_for(-60) = 60")
	# apply : coupe vers la vitesse cible (max_speed=100, slow 30% => cible 70).
	_check(_approx(BombIceSlow.apply(100.0, 100.0, 30.0), 70.0), "ice: 100 -> cible 70 (slow 30%)")
	# non cumulatif : déjà à 70, re-slow 30% => cible 70 => no-op.
	_check(_approx(BombIceSlow.apply(70.0, 100.0, 30.0), 70.0), "ice: non cumulatif (même tier = no-op)")
	# slow plus fort écrase : à 70, slow 50% => cible 50.
	_check(_approx(BombIceSlow.apply(70.0, 100.0, 50.0), 50.0), "ice: slow plus fort écrase (70 -> 50)")
	# slow plus faible après plus fort = no-op : à 50, slow 30% => cible 70 > 50 => reste 50.
	_check(_approx(BombIceSlow.apply(50.0, 100.0, 30.0), 50.0), "ice: slow plus faible = no-op (garde le plus lent)")
	# garde-fou max_speed 0 => inchangé.
	_check(_approx(BombIceSlow.apply(42.0, 0.0, 50.0), 42.0), "ice: max_speed 0 => inchangé")


func _check(cond, name):
	_count += 1
	if not cond:
		_failures += 1
		print("FAIL: ", name)
	else:
		print("ok  : ", name)
