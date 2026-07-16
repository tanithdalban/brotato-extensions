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
const PoisonFire = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/poison_fire.gd")
const BombPlacement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_placement.gd")
const BombChallenges = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd")
const BombLeech = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_leech.gd")
const BombFrag = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_frag.gd")

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
	_test_poison_fire()
	_test_bomb_placement()
	_test_bomb_challenges()
	_test_bomb_leech()
	_test_bomb_frag()
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
	_check(ShopPool.is_allowed(_StubWeapon.new("weapon_bomb_storm", [], 0, 1)), "pool: weapon_bomb_storm accepté (préfixe)")

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
	var storm_path = BombSkin.element_sprite_path("storm")
	_check(storm_path.ends_with("storm.png"), "skin: storm -> storm.png")
	_check(BombSkin.element_sprite_path("poison").ends_with("poison.png"), "skin: poison -> poison.png")
	_check(BombSkin.element_sprite_path("leech").ends_with("sangsue.png"), "skin: leech -> sangsue.png")


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
	_check(BombElement.from_weapon_id("weapon_bomb_leech") == BombElement.LEECH, "element: weapon_bomb_leech => leech")
	_check(BombElement.from_weapon_id("weapon_bomb_frag") == BombElement.FRAG, "element: weapon_bomb_frag => frag")

	# ⚠️ FRAG_CHILD est un élément INTERNE : aucun weapon_id ne doit le produire.
	# C'est ce qui garde la garde anti-récursion STRUCTURELLE.
	_check(BombElement.from_weapon_id("weapon_bomb_frag_child") == BombElement.NORMAL,
		"element: frag_child n'a PAS de weapon_id (élément interne)")

	# --- deals_explosion_damage : qui inflige des dégâts d'explosion ? ---
	_check(BombElement.deals_explosion_damage(BombElement.NORMAL), "dégâts: la normale en fait")
	_check(BombElement.deals_explosion_damage(BombElement.FRAG_CHILD), "dégâts: le FRAGMENT en fait (il porte tout le dégât de la Frag)")
	_check(not BombElement.deals_explosion_damage(BombElement.FRAG), "dégâts: l'OBUS Frag n'en fait PAS (simple vecteur)")
	_check(not BombElement.deals_explosion_damage(BombElement.ICE), "dégâts: la glace n'en fait pas")
	_check(not BombElement.deals_explosion_damage(BombElement.POISON), "dégâts: le poison n'en fait pas")
	_check(not BombElement.deals_explosion_damage(BombElement.STORM), "dégâts: la foudre n'en fait pas (ses éclairs les portent)")
	_check(not BombElement.deals_explosion_damage(BombElement.LEECH), "dégâts: la sangsue n'en fait pas")

	# --- can_troll : la troll bombe reste la signature EXCLUSIVE de la normale. ---
	_check(BombElement.can_troll(BombElement.NORMAL), "troll: la normale peut troller")
	_check(not BombElement.can_troll(BombElement.FRAG), "troll: la Frag ne troll jamais")
	_check(not BombElement.can_troll(BombElement.FRAG_CHILD), "troll: un fragment ne troll jamais")
	_check(not BombElement.can_troll(BombElement.ICE), "troll: la glace ne troll pas")
	_check(not BombElement.can_troll(BombElement.POISON), "troll: le poison ne troll pas")
	_check(not BombElement.can_troll(BombElement.STORM), "troll: la foudre ne troll pas")
	_check(not BombElement.can_troll(BombElement.LEECH), "troll: la sangsue ne troll pas")

	# --- is_cluster : qui se scinde ? ---
	_check(BombElement.is_cluster(BombElement.FRAG), "cluster: la Frag se scinde")
	# ⚠️ LE test de la garde anti-récursion : un fragment n'est PAS un cluster, donc il
	# ne peut pas se scinder à son tour. La garde est structurelle, pas conditionnelle.
	_check(not BombElement.is_cluster(BombElement.FRAG_CHILD), "cluster: un FRAGMENT ne se scinde PAS (garde anti-récursion structurelle)")
	_check(not BombElement.is_cluster(BombElement.NORMAL), "cluster: la normale ne se scinde pas")
	_check(not BombElement.is_cluster(BombElement.ICE), "cluster: la glace ne se scinde pas")
	_check(not BombElement.is_cluster(BombElement.POISON), "cluster: le poison ne se scinde pas")
	_check(not BombElement.is_cluster(BombElement.STORM), "cluster: la foudre ne se scinde pas")
	_check(not BombElement.is_cluster(BombElement.LEECH), "cluster: la sangsue ne se scinde pas")

	# --- Les 3 prédicats sont FAUX pour un élément inconnu : jamais de crash. ---
	_check(not BombElement.is_cluster("inconnu"), "prédicats: élément inconnu => pas un cluster")
	_check(not BombElement.can_troll("inconnu"), "prédicats: élément inconnu => ne troll pas")
	_check(not BombElement.deals_explosion_damage("inconnu"), "prédicats: élément inconnu => pas de dégâts")


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


func _test_poison_fire():
	# Marqueur de source : le weapon_id partagé des 4 tiers commence par weapon_bomb_poison.
	_check(PoisonFire.is_poison_source("weapon_bomb_poison"), "poison: weapon_bomb_poison reconnu")
	_check(PoisonFire.is_poison_source("weapon_bomb_poison_3"), "poison: variante tier reconnue")
	_check(not PoisonFire.is_poison_source("weapon_bomb"), "poison: bombe normale non reconnue")
	_check(not PoisonFire.is_poison_source("weapon_turret"), "poison: tourelle (ingé bleu) non reconnue")
	_check(not PoisonFire.is_poison_source(""), "poison: vide non reconnu")
	# Dégradés verts : Gradient à points, 1re couleur plus verte que rouge.
	var g = PoisonFire.green_gradient()
	_check(g is Gradient, "poison: green_gradient est un Gradient")
	_check(g.colors.size() >= 2, "poison: green_gradient a >= 2 points")
	_check(g.colors[0].g > g.colors[0].r, "poison: 1re couleur verdâtre (g > r)")
	var gs = PoisonFire.green_gradient_secondary()
	_check(gs is Gradient, "poison: green_gradient_secondary est un Gradient")
	_check(gs.colors[0].g > gs.colors[0].r, "poison: secondaire verdâtre (g > r)")


func _test_bomb_placement():
	# --- raw_angle : deux sources d'unicité ---
	# Deux SLOTS différents visent des azimuts différents.
	_check(not _approx(BombPlacement.raw_angle(0, 4, 0), BombPlacement.raw_angle(1, 4, 0)), "placement: slots différents => angles différents")
	# Deux POSES successives d'un MÊME slot visent des azimuts différents.
	# C'est le cas critique : une seule bombe en main (le slot ne différencie rien).
	_check(not _approx(BombPlacement.raw_angle(0, 1, 0), BombPlacement.raw_angle(0, 1, 1)), "placement: poses successives (1 seule bombe) => angles différents")
	_check(not _approx(BombPlacement.raw_angle(0, 1, 1), BombPlacement.raw_angle(0, 1, 2)), "placement: angle d'or ne reboucle pas")
	# Garde-fous : pas de division par zéro. nb_slots 0 est ramené à 1, donc le terme de
	# slot vaut 0 ; avec shot_index 0, l'angle brut vaut exactement 0.
	_check(_approx(BombPlacement.raw_angle(0, 0, 0), 0.0), "placement: nb_slots 0 => ramené à 1, angle 0 (pas de division par zéro)")
	_check(_approx(BombPlacement.raw_angle(-3, 4, 0), BombPlacement.raw_angle(0, 4, 0)), "placement: slot négatif => traité comme 0")

	# --- mobility_from_travel : « le déplacement NET suffit-il à espacer les bombes ? » ---
	# 1 bombe, déplacement net = 2 x RAYON (le diamètre de la couronne) => mobilité pleine.
	_check(_approx(BombPlacement.mobility_from_travel(128.0, 1, 64.0), 1.0), "mobilité: 1 bombe, 2xRAYON parcourus => 1.0")
	# Moitié du seuil => moitié de la mobilité.
	_check(_approx(BombPlacement.mobility_from_travel(64.0, 1, 64.0), 0.5), "mobilité: 1 bombe, RAYON parcouru => 0.5")
	# FRÉTILLEMENT SUR PLACE : déplacement net nul => l'éventail RESTE ouvert (couronne).
	# C'est exactement le cas que la mesure en distance NETTE existe pour attraper : une
	# vitesse instantanée serait élevée et refermerait l'éventail, empilant les bombes.
	_check(_approx(BombPlacement.mobility_from_travel(0.0, 1, 64.0), 0.0), "mobilité: déplacement net nul => 0.0 (couronne, pas d'empilement)")
	# Plus de bombes => elles se relaient, donc chacune doit parcourir N fois plus pour
	# obtenir la même mobilité.
	var m_1 = BombPlacement.mobility_from_travel(64.0, 1, 64.0)
	var m_6 = BombPlacement.mobility_from_travel(64.0, 6, 64.0)
	_check(m_1 < 1.0, "mobilité: le cas de référence n'est pas saturé (test discriminant)")
	_check(_approx(m_6, m_1 / 6.0), "mobilité: 6 bombes => mobilité divisée par 6")
	# Bornes et garde-fous.
	_check(_approx(BombPlacement.mobility_from_travel(99999.0, 1, 64.0), 1.0), "mobilité: bornée à 1.0")
	_check(_approx(BombPlacement.mobility_from_travel(100.0, 1, 0.0), 0.0), "mobilité: rayon 0 => 0.0 (pas de division par zéro)")
	_check(_approx(BombPlacement.mobility_from_travel(100.0, 0, 64.0), BombPlacement.mobility_from_travel(100.0, 1, 64.0)), "mobilité: nb_bombs 0 => ramené à 1")

	# --- fan_half_width : l'éventail se referme quand la mobilité monte ---
	_check(_approx(BombPlacement.fan_half_width(0.0), PI), "éventail: mobilité 0 => cercle entier (PI)")
	_check(_approx(BombPlacement.fan_half_width(1.0), 0.0), "éventail: mobilité 1 => file stricte (0)")
	_check(BombPlacement.fan_half_width(0.5) < PI and BombPlacement.fan_half_width(0.5) > 0.0, "éventail: mobilité 0.5 => intermédiaire")

	# --- offset : le décalage final ---
	var rayon := 64.0
	var dir := Vector2(1, 0)  # le joueur va vers la DROITE => l'arrière est à GAUCHE
	# La norme du décalage vaut toujours le rayon.
	var o = BombPlacement.offset(0, 1, 0, dir, 0.0, rayon)
	_check(_approx(o.length(), rayon), "placement: norme du décalage = rayon")
	# Mobilité 1 (pleine course) => la bombe part STRICTEMENT derrière (à gauche).
	var arriere = BombPlacement.offset(0, 1, 7, dir, 1.0, rayon)
	_check(_approx(arriere.x, -rayon) and _approx(arriere.y, 0.0), "placement: mobilité 1 => strictement derrière")
	# ... et ce, quel que soit le numéro de pose (l'éventail est fermé).
	var arriere2 = BombPlacement.offset(2, 4, 13, dir, 1.0, rayon)
	_check(_approx(arriere2.x, -rayon) and _approx(arriere2.y, 0.0), "placement: mobilité 1 => derrière, quels que soient slot et pose")
	# Mobilité 0 (à l'arrêt) => les poses successives balaient le cercle : deux poses
	# successives donnent des décalages nettement différents.
	var c0 = BombPlacement.offset(0, 1, 0, dir, 0.0, rayon)
	var c1 = BombPlacement.offset(0, 1, 1, dir, 0.0, rayon)
	_check((c0 - c1).length() > rayon * 0.5, "placement: mobilité 0 => poses successives bien écartées")
	# Direction nulle (début de vague, aucun mouvement mémorisé) : pas de crash.
	var od = BombPlacement.offset(0, 1, 0, Vector2.ZERO, 0.0, rayon)
	_check(_approx(od.length(), rayon), "placement: direction nulle => pas de crash, norme conservée")


func _test_bomb_challenges() -> void:
	# ⚠️ Signature du helper existant : _check(cond, name) — la CONDITION d'abord.

	# La chaîne : chaque bombe au tier IV débloque la suivante.
	_check(BombChallenges.challenge_for("weapon_bomb", 3) == "chal_bomb_ice",
		"défis: Bombe IV -> défi glace")
	_check(BombChallenges.challenge_for("weapon_bomb_ice", 3) == "chal_bomb_storm",
		"défis: Glace IV -> défi foudre")
	_check(BombChallenges.challenge_for("weapon_bomb_storm", 3) == "chal_bomb_poison",
		"défis: Foudre IV -> défi poison")

	# Fin de chaîne : le poison ne débloque rien.
	_check(BombChallenges.challenge_for("weapon_bomb_poison", 3) == "",
		"défis: Poison IV ne complète rien (fin de chaîne)")

	# Seul le tier IV compte.
	_check(BombChallenges.challenge_for("weapon_bomb", 2) == "",
		"défis: Bombe III ne complète rien")
	_check(BombChallenges.challenge_for("weapon_bomb", 0) == "",
		"défis: Bombe I ne complète rien")

	# Une arme étrangère ne complète rien.
	_check(BombChallenges.challenge_for("weapon_pistol", 3) == "",
		"défis: arme non-bombe ne complète rien")

	# ⚠️ "weapon_bomb" est un préfixe des autres : la correspondance doit être EXACTE.
	# Ce test échoue si l'implémentation utilise begins_with().
	_check(BombChallenges.challenge_for("weapon_bomb_ice", 3) != "chal_bomb_ice",
		"défis: correspondance exacte, pas par préfixe")

	# Cohérence interne : toute récompense de la chaîne est une bombe connue.
	var coherent := true
	for weapon_id in BombChallenges.CHAIN:
		var chal_id = BombChallenges.CHAIN[weapon_id]
		if not BombChallenges.REWARD.has(chal_id):
			coherent = false
	_check(coherent, "défis: chaque défi de la chaîne a une récompense")

	# Migration : bombes possédées mais non gagnées.
	_check(BombChallenges.unearned_bombs([], []).empty(),
		"migration: rien de possédé => rien à proposer")
	_check(BombChallenges.unearned_bombs(["weapon_bomb_ice"], []) == ["weapon_bomb_ice"],
		"migration: glace possédée et non gagnée => à proposer")
	_check(BombChallenges.unearned_bombs(["weapon_bomb_ice"], ["chal_bomb_ice"]).empty(),
		"migration: glace possédée ET gagnée => rien à proposer")
	_check(BombChallenges.unearned_bombs(
			["weapon_bomb_ice", "weapon_bomb_storm", "weapon_bomb_poison"], []).size() == 3,
		"migration: les trois possédées => les trois à proposer")
	_check(BombChallenges.unearned_bombs(["weapon_bomb"], []).empty(),
		"migration: la bombe normale n'est jamais concernée")

	# --- Bombe sangsue : débloquée par la COLLECTION, pas par un tier IV. ---
	# Le poison reste la fin de CHAIN : sa montée en tier IV ne débloque toujours rien.
	_check(BombChallenges.challenge_for("weapon_bomb_poison", 3) == "",
		"sangsue: Poison IV ne complète toujours rien (la sangsue n'est pas dans CHAIN)")

	# Les 4 bombes en inventaire, tous tiers confondus => défi complété.
	_check(BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb_ice", "weapon_bomb_storm", "weapon_bomb_poison"]),
		"sangsue: les 4 bombes => déblocage")
	# L'ordre ne compte pas.
	_check(BombChallenges.unlocks_leech(
			["weapon_bomb_poison", "weapon_bomb", "weapon_bomb_storm", "weapon_bomb_ice"]),
		"sangsue: ordre indifférent")
	# Une arme étrangère en plus ne gêne pas (inventaire réel : 6 slots).
	_check(BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb_ice", "weapon_bomb_storm", "weapon_bomb_poison", "weapon_pistol"]),
		"sangsue: armes étrangères en plus => déblocage quand même")

	# 3 bombes seulement => pas de déblocage.
	_check(not BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb_ice", "weapon_bomb_storm"]),
		"sangsue: 3 bombes sur 4 => pas de déblocage")
	# ⚠️ Le piège : des DOUBLONS ne remplacent pas une bombe manquante.
	_check(not BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb", "weapon_bomb", "weapon_bomb"]),
		"sangsue: 4x la même bombe => PAS de déblocage")
	_check(not BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb_ice", "weapon_bomb_ice", "weapon_bomb_storm"]),
		"sangsue: doublon de glace au lieu du poison => pas de déblocage")
	_check(not BombChallenges.unlocks_leech([]),
		"sangsue: inventaire vide => pas de déblocage")

	# La sangsue est une récompense connue (le popup de migration itère sur REWARD).
	_check(BombChallenges.REWARD.has("chal_bomb_leech"),
		"sangsue: chal_bomb_leech est dans REWARD (couvert par la migration)")
	_check(BombChallenges.REWARD["chal_bomb_leech"] == "weapon_bomb_leech",
		"sangsue: chal_bomb_leech récompense weapon_bomb_leech")
	_check(BombChallenges.unearned_bombs(["weapon_bomb_leech"], []) == ["weapon_bomb_leech"],
		"migration: sangsue possédée et non gagnée => à proposer")

	# --- Bombe Frag : le maillon terminal, débloqué par la Sangsue IV. ---
	_check(BombChallenges.challenge_for("weapon_bomb_leech", 3) == "chal_bomb_frag",
		"frag: Sangsue IV -> défi frag")
	# Seul le tier IV compte, ici comme partout.
	_check(BombChallenges.challenge_for("weapon_bomb_leech", 2) == "",
		"frag: Sangsue III ne complète rien")
	_check(BombChallenges.challenge_for("weapon_bomb_leech", 0) == "",
		"frag: Sangsue I ne complète rien")
	# La Frag est la FIN de la chaîne : elle ne débloque rien à son tour.
	_check(BombChallenges.challenge_for("weapon_bomb_frag", 3) == "",
		"frag: Frag IV ne complète rien (fin de chaîne)")

	# La Frag est une récompense connue (le popup de migration itère sur REWARD, donc
	# il la couvre gratuitement).
	_check(BombChallenges.REWARD.has("chal_bomb_frag"),
		"frag: chal_bomb_frag est dans REWARD (couvert par la migration)")
	_check(BombChallenges.REWARD["chal_bomb_frag"] == "weapon_bomb_frag",
		"frag: chal_bomb_frag récompense weapon_bomb_frag")
	_check(BombChallenges.unearned_bombs(["weapon_bomb_frag"], []) == ["weapon_bomb_frag"],
		"migration: frag possédée et non gagnée => à proposer")
	_check(BombChallenges.unearned_bombs(["weapon_bomb_frag"], ["chal_bomb_frag"]).empty(),
		"migration: frag possédée ET gagnée => rien à proposer")

	# ⚠️ La Frag n'entre PAS dans le défi de la sangsue : celui-ci exige les 4 bombes
	# d'ORIGINE. Sinon l'avertissement du carnet (« chaque bombe ajoutée mange un slot
	# pendant la tentative ») s'appliquerait et le défi deviendrait ingérable.
	_check(not BombChallenges.LEECH_REQUIRED.has("weapon_bomb_frag"),
		"frag: la Frag n'est PAS requise pour débloquer la sangsue")
	_check(BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb_ice", "weapon_bomb_storm", "weapon_bomb_poison"]),
		"frag: les 4 bombes d'origine suffisent toujours pour la sangsue")


func _test_bomb_leech() -> void:
	# ⚠️ Signature du helper existant : _check(cond, name) — la CONDITION d'abord.

	# --- cap_for_tier : le plafond de PV par explosion, par tier (spec) ---
	_check(BombLeech.cap_for_tier(0) == 3, "sangsue: plafond T1 = 3 PV")
	_check(BombLeech.cap_for_tier(1) == 4, "sangsue: plafond T2 = 4 PV")
	_check(BombLeech.cap_for_tier(2) == 5, "sangsue: plafond T3 = 5 PV")
	_check(BombLeech.cap_for_tier(3) == 6, "sangsue: plafond T4 = 6 PV")
	# Garde-fous : tier hors bornes => clampé (pas de crash, pas d'index négatif).
	_check(BombLeech.cap_for_tier(-5) == 3, "sangsue: tier négatif => clamp T1")
	_check(BombLeech.cap_for_tier(99) == 6, "sangsue: tier trop grand => clamp T4")

	# --- procs : tirage, dé INJECTÉ (déterminisme, pas de randf() dans le pur) ---
	_check(BombLeech.procs(0.0, 0.4) == true, "sangsue: dé 0.0 < 40% => proc")
	_check(BombLeech.procs(0.39, 0.4) == true, "sangsue: dé 0.39 < 40% => proc")
	_check(BombLeech.procs(0.4, 0.4) == false, "sangsue: dé 0.4 pas < 40% => pas de proc")
	_check(BombLeech.procs(0.9, 0.4) == false, "sangsue: dé 0.9 => pas de proc")
	_check(BombLeech.procs(0.5, 0.0) == false, "sangsue: 0% de vol de vie => jamais")
	_check(BombLeech.procs(0.99, 1.0) == true, "sangsue: 100% de vol de vie => toujours")
	# Au-delà de 100 % (stat joueur très haute) : toujours, jamais d'erreur.
	_check(BombLeech.procs(0.99, 2.5) == true, "sangsue: vol de vie > 100% => toujours")

	# --- proc_amount : 1 PV, 2 avec l'item double vol de vie (aligné vanilla) ---
	_check(BombLeech.proc_amount(false) == 1, "sangsue: proc normal = 1 PV")
	_check(BombLeech.proc_amount(true) == 2, "sangsue: proc avec bonus double = 2 PV")

	# --- granted : écrêtage au budget restant ---
	_check(BombLeech.granted(1, 3) == 1, "sangsue: 1 PV demandé sur 3 restants => 1")
	_check(BombLeech.granted(2, 3) == 2, "sangsue: 2 PV demandés sur 3 restants => 2")
	# LE cas de la spec : un proc « double » ne perce pas le plafond.
	_check(BombLeech.granted(2, 1) == 1, "sangsue: proc double sur 1 PV restant => écrêté à 1")
	_check(BombLeech.granted(2, 0) == 0, "sangsue: budget épuisé => 0")
	_check(BombLeech.granted(1, -1) == 0, "sangsue: restant négatif => 0 (pas de soin fantôme)")
	_check(BombLeech.granted(-3, 5) == 0, "sangsue: montant négatif => 0")

	# --- Seau à jetons PARTAGÉ PAR JOUEUR (correctif d'équilibrage, revue finale) ---
	#
	# L'ANCIEN modèle (un budget frais PAR EXPLOSION) ne bornait rien PAR SECONDE :
	# 6 sangsues en T4 (cooldown ≈ 1s) auraient fait 6 budgets indépendants, soit
	# ~36 PV/s. Le nouveau modèle : un seul seau par joueur, qui se RECHARGE dans le
	# temps (capacité = plafond du tier qui draine, recharge = capacité/seconde).
	# Le temps est INJECTÉ (`now`, en ms) : jamais d'OS.get_ticks_msec() ici.
	var t0 := 1000

	# Un seau neuf démarre PLEIN (un joueur qui n'a pas drainé récemment profite du
	# plein régime dès sa première bombe).
	var fresh = BombLeech.new_bucket()
	_check(BombLeech.remaining(fresh, 3, t0) == 3, "sangsue: seau neuf démarre plein (T1 = 3 PV)")

	# Le vider, puis une 2e explosion AU MÊME INSTANT ne doit RIEN accorder : c'est
	# exactement le cas que l'ancien modèle (budget par explosion) ratait — sous
	# l'ancien modèle, cette 2e explosion aurait eu son propre budget frais.
	var bucket = BombLeech.new_bucket()
	_check(BombLeech.take(bucket, 3, 3, t0) == 3, "sangsue: 1re explosion draine tout le plafond (3 PV)")
	_check(BombLeech.take(bucket, 3, 1, t0) == 0, "sangsue: 2e explosion AU MÊME INSTANT => 0 (le seau ne s'est pas rechargé)")
	_check(BombLeech.remaining(bucket, 3, t0) == 0, "sangsue: seau toujours vide au même instant")

	# Recharge complète après 1s (recharge = capacité/seconde).
	var bucket_full_refill = BombLeech.new_bucket()
	var _gA = BombLeech.take(bucket_full_refill, 4, 4, t0)  # T2 => 4 PV, vidé
	_check(BombLeech.remaining(bucket_full_refill, 4, t0 + 1000) == 4, "sangsue: 1s plus tard => seau plein reconstitué (T2 = 4 PV)")

	# Recharge à MOITIÉ après 0.5s, avec troncature (pas de PV en deux morceaux) :
	# plafond 3, 0.5s de recharge = 1.5 jeton => 1 PV accordable, pas 1.5.
	var bucket_half_refill = BombLeech.new_bucket()
	var _gB = BombLeech.take(bucket_half_refill, 3, 3, t0)  # T1 => 3 PV, vidé
	_check(BombLeech.remaining(bucket_half_refill, 3, t0 + 500) == 1, "sangsue: 0.5s plus tard sur plafond 3 => 1 PV (1.5 tronqué)")

	# Le seau ne dépasse JAMAIS sa capacité, quelle que soit l'attente.
	var bucket_no_overflow = BombLeech.new_bucket()
	var _gC = BombLeech.take(bucket_no_overflow, 4, 4, t0)
	_check(BombLeech.remaining(bucket_no_overflow, 4, t0 + 999999) == 4, "sangsue: attente énorme => plafonné à 4, jamais plus")
	_check(BombLeech.remaining(BombLeech.new_bucket(), 4, t0 + 999999) == 4, "sangsue: seau jamais utilisé, longtemps après => toujours plafonné")

	# Les jetons ne deviennent jamais négatifs.
	var bucket_no_negative = BombLeech.new_bucket()
	_check(BombLeech.take(bucket_no_negative, 3, 3, t0) == 3, "sangsue: vidage initial (3 PV)")
	_check(BombLeech.take(bucket_no_negative, 3, 5, t0) == 0, "sangsue: seau vide => prise suivante = 0 (jamais négatif)")
	_check(BombLeech.remaining(bucket_no_negative, 3, t0) == 0, "sangsue: remaining reste à 0, jamais négatif")

	# Le partage par RÉFÉRENCE est ce qui fait tenir le plafond entre deux bombes du
	# même joueur : si le seau était copié, chacune aurait le sien.
	var shared = BombLeech.new_bucket()
	var alias = shared
	var _g = BombLeech.take(alias, 3, 3, t0)
	_check(BombLeech.remaining(shared, 3, t0) == 0, "sangsue: seau partagé par référence (pas copié)")

	# Empiler les sangsues ne MULTIPLIE plus le soin : 6 bombes qui explosent à la
	# MÊME seconde sur un seul seau partagé ne rendent jamais plus que LE plafond
	# (6 PV en T4), pas 6x le plafond (36 PV) comme sous l'ancien modèle.
	var stacked = BombLeech.new_bucket()
	var total_stacked := 0
	for _i in range(6):
		total_stacked += BombLeech.take(stacked, 6, 6, t0)
	_check(total_stacked == 6, "sangsue: 6 bombes à la même seconde => 6 PV max (pas 36) — la régularité remplace la multiplication")

	# Le plafond tient aussi face à une horde au sein d'UNE explosion (20 ennemis,
	# tous procs, même instant).
	var b2 = BombLeech.new_bucket()
	var total := 0
	for _i in range(20):
		total += BombLeech.take(b2, 6, 1, t0)  # T4 => 6 PV
	_check(total == 6, "sangsue: 20 ennemis, tous procs => exactement le plafond T4 (6 PV)")

	# Le bonus double atteint le plafond avec MOINS d'ennemis, mais ne le perce pas.
	var b3 = BombLeech.new_bucket()
	var total3 := 0
	for _i in range(20):
		total3 += BombLeech.take(b3, 6, 2, t0)  # T4 => 6 PV
	_check(total3 == 6, "sangsue: bonus double => même plafond (6 PV), atteint plus vite")

	# Garde-fous : un seau malformé ne draine rien et ne plante pas.
	_check(BombLeech.take([], 3, 1, t0) == 0, "sangsue: seau vide/malformé => 0 (pas de crash)")
	_check(BombLeech.remaining([], 3, t0) == 0, "sangsue: remaining d'un seau malformé => 0")

	# --- Cas critique : double proc avec petit seau, écrêtage END-TO-END via take() ---
	# Plafond 3. Un proc double draine 2, il en reste 1. Le prochain proc double (même
	# instant, pas de recharge) ne peut drainer que 1 (clamped), puis le seau est exact
	# à 0. C'est l'invariant de spec : « un double proc sur 1 PV restant ne doit jamais
	# drainer 2 ».
	var b_crit = BombLeech.new_bucket()
	var drain_1 = BombLeech.take(b_crit, 3, 2, t0)  # 1er proc double => 2 PV
	var drain_2 = BombLeech.take(b_crit, 3, 2, t0)  # 2e proc double => écrêté à 1 PV
	_check(drain_1 == 2, "sangsue: 1er proc double sur plafond 3 => 2 PV accordés")
	_check(drain_2 == 1, "sangsue: 2e proc double sur plafond 3 => écrêté à 1 PV (pas 2)")
	_check(BombLeech.remaining(b_crit, 3, t0) == 0, "sangsue: après 2 procs, seau exact à 0")
	_check(drain_1 + drain_2 == 3, "sangsue: total drainé = plafond (3 PV)")

	# --- Horloge qui recule / instant identique : jamais de PV gratuits, jamais de crash ---
	var bucket_backwards = BombLeech.new_bucket()
	var _gD = BombLeech.take(bucket_backwards, 3, 3, t0)  # vidé à t0
	_check(BombLeech.remaining(bucket_backwards, 3, t0 - 500) == 0, "sangsue: horloge qui recule => pas de PV gratuits, pas de crash")
	_check(BombLeech.remaining(bucket_backwards, 3, t0) == 0, "sangsue: now == dernier instant => pas de recharge")

	# --- Finding 2 : une bombe de tier INFÉRIEUR ne doit jamais DÉTRUIRE des jetons ---
	#
	# Bug initial : la recharge BORNAIT (clampait) le seau à la capacité de la bombe
	# qui drane EN CE MOMENT, y compris VERS LE BAS. Un joueur avec une Sangsue I
	# (plafond 3) ET une Sangsue IV (plafond 6) sur un seau à 6 jetons voyait donc
	# 3 jetons DÉTRUITS dès que la Sangsue I explosait en premier -- un build en cours
	# de montée en tier devenait ainsi PIRE que la bombe T1 seule, ce qui est absurde.
	# Correctif : la recharge ne fait qu'AJOUTER des jetons (borné par la capacité de
	# la bombe qui drane), elle n'en RETIRE jamais.
	var mixed := BombLeech.new_bucket()
	_check(BombLeech.remaining(mixed, 6, t0) == 6, "sangsue mixte: seau neuf plein au plafond T4 (6 PV)")
	_check(BombLeech.remaining(mixed, 3, t0) == 6, "sangsue mixte: interrogé ensuite par une bombe T1 (plafond 3) au MÊME instant => garde ses 6 jetons, pas clampé à 3")
	_check(BombLeech.take(mixed, 6, 6, t0) == 6, "sangsue mixte: une bombe T4 peut alors dépenser les 6 jetons intacts")

	# Même invariant avec un vrai écart de temps : le passage d'une bombe T1 ne doit
	# pas non plus AMPUTER un surplus déjà accumulé par une bombe T4.
	var mixed_time := BombLeech.new_bucket()
	var _gE = BombLeech.take(mixed_time, 6, 0, t0)  # force juste l'initialisation à 6 jetons (T4)
	_check(BombLeech.remaining(mixed_time, 3, t0 + 10000) == 6, "sangsue mixte: bombe T1 interrogeant 10s plus tard => toujours 6 jetons, jamais amputé à 3")

	# --- refund : rembourse les jetons non réellement consommés (Finding 2) ---
	var bucket_refund = BombLeech.new_bucket()
	var g9 := BombLeech.take(bucket_refund, 3, 2, t0)
	_check(g9 == 2, "sangsue: refund - prise initiale de 2 PV")
	BombLeech.refund(bucket_refund, 3, 1)
	_check(BombLeech.remaining(bucket_refund, 3, t0) == 2, "sangsue: refund - rend le jeton non utilisé")
	BombLeech.refund(bucket_refund, 3, 100)
	_check(BombLeech.remaining(bucket_refund, 3, t0) == 3, "sangsue: refund - jamais au-delà de la capacité")
	BombLeech.refund(bucket_refund, 3, -5)
	_check(BombLeech.remaining(bucket_refund, 3, t0) == 3, "sangsue: refund - montant négatif => no-op (pas de crash)")


func _test_bomb_frag() -> void:
	# ⚠️ Signature du helper existant : _check(cond, name) — la CONDITION d'abord.

	# --- Le compte : un fragment par demande, ni plus ni moins. ---
	var r7 := []
	for _i in range(7 * BombFrag.RANDOMS_PER_FRAGMENT):
		r7.append(0.5)
	_check(BombFrag.scatter_offsets(7, 150.0, r7).size() == 7, "frag: 7 demandés => 7 offsets")
	_check(BombFrag.scatter_offsets(4, 150.0, r7).size() == 4, "frag: 4 demandés => 4 offsets")

	# --- Tous DANS le disque : aucun fragment ne part hors de la gerbe. ---
	var inside := true
	var many := []
	for i in range(7 * BombFrag.RANDOMS_PER_FRAGMENT):
		many.append(float(i) / float(7 * BombFrag.RANDOMS_PER_FRAGMENT))
	for off in BombFrag.scatter_offsets(7, 150.0, many):
		if off.length() > 150.0 + 0.0001:
			inside = false
	_check(inside, "frag: tous les offsets sont dans le disque de 150")

	# --- ⚠️ LE TEST DISCRIMINANT : la racine carrée. ---
	# Tirer l'angle ET la distance uniformément ENTASSE les fragments au centre (la
	# surface d'une couronne croît avec le rayon). Il faut r = radius * sqrt(u).
	# Avec u = 0.25 : sqrt => 0.5 * 100 = 50. Sans sqrt (linéaire) => 25.
	# CE TEST ÉCHOUE si l'implémentation oublie la racine carrée.
	var quarter = BombFrag.scatter_offsets(1, 100.0, [0.0, 0.25])
	_check(_approx(quarter[0].length(), 50.0), "frag: distance = rayon * sqrt(u) — u=0.25 => 50, PAS 25 (racine carrée obligatoire)")
	var half = BombFrag.scatter_offsets(1, 100.0, [0.0, 0.5])
	_check(_approx(half[0].length(), 100.0 * sqrt(0.5)), "frag: u=0.5 => rayon * sqrt(0.5) ≈ 70.7")

	# --- L'angle : u_angle = 0 => plein est ; u_dist = 1 => bord du disque. ---
	var east = BombFrag.scatter_offsets(1, 100.0, [0.0, 1.0])
	_check(_approx(east[0].x, 100.0) and _approx(east[0].y, 0.0), "frag: angle 0 + distance max => (100, 0)")
	# u_angle = 0.5 => un demi-tour => plein ouest.
	var west = BombFrag.scatter_offsets(1, 100.0, [0.5, 1.0])
	_check(_approx(west[0].x, -100.0), "frag: angle 0.5 (demi-tour) => plein ouest")
	# u_dist = 0 => pile au centre.
	var center = BombFrag.scatter_offsets(1, 100.0, [0.3, 0.0])
	_check(_approx(center[0].length(), 0.0), "frag: distance 0 => au centre")

	# --- Déterminisme : mêmes tirages => mêmes positions (hasard INJECTÉ). ---
	var seed_vals := [0.1, 0.2, 0.3, 0.4]
	var a = BombFrag.scatter_offsets(2, 80.0, seed_vals)
	var b = BombFrag.scatter_offsets(2, 80.0, seed_vals)
	_check(a[0] == b[0] and a[1] == b[1], "frag: déterministe à tirages égaux")

	# --- Chaque fragment consomme SES PROPRES tirages (pas tous au même endroit). ---
	var distinct = BombFrag.scatter_offsets(2, 100.0, [0.0, 1.0, 0.5, 1.0])
	_check(distinct[0] != distinct[1], "frag: deux fragments, tirages différents => positions différentes")

	# --- Garde-fous : jamais de crash, jamais d'index hors bornes. ---
	_check(BombFrag.scatter_offsets(0, 150.0, r7).size() == 0, "frag: 0 demandé => aucun offset")
	_check(BombFrag.scatter_offsets(-3, 150.0, r7).size() == 0, "frag: nombre négatif => aucun offset")
	# Tirages MANQUANTS : on complète par 0.0, on ne plante pas et on ne perd AUCUN
	# fragment (sinon des dégâts disparaîtraient silencieusement).
	_check(BombFrag.scatter_offsets(7, 150.0, []).size() == 7, "frag: aucun tirage fourni => 7 fragments quand même (dégradation propre)")
	_check(BombFrag.scatter_offsets(7, 150.0, [0.5]).size() == 7, "frag: tirages incomplets => 7 fragments quand même")
	# Rayon nul ou négatif : tous au centre, mais TOUS présents (pas de dégât perdu).
	var zero_r = BombFrag.scatter_offsets(3, 0.0, r7)
	_check(zero_r.size() == 3 and zero_r[0] == Vector2.ZERO, "frag: rayon 0 => 3 fragments au centre (aucun perdu)")
	var neg_r = BombFrag.scatter_offsets(3, -50.0, r7)
	_check(neg_r.size() == 3 and neg_r[0] == Vector2.ZERO, "frag: rayon négatif => 3 fragments au centre, pas de crash")


func _check(cond, name):
	_count += 1
	if not cond:
		_failures += 1
		print("FAIL: ", name)
	else:
		print("ok  : ", name)
