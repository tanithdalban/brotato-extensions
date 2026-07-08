extends Weapon
class_name BombWeapon
# Arme "Bombe" : ne vise pas. Pose une bombe à la position du joueur dès que
# le cooldown est prêt. La bombe (entité) gère sa mèche puis explose.

const BombEntity = preload("res://mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.tscn")
const BombTiming = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd")
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")
const BombElement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd")
const BombIceSlow = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_ice_slow.gd")

# Échelle d'explosion de base (équiv. landmine). Ajustable au réglage.
const EXPLOSION_SCALE := 1.5

# Surcharge : applique le skin de bombe (déterminé par l'élément) au sprite tenu
# AVANT le _ready() vanilla, qui capture `sprite.texture` dans `_original_sprite` (ligne 74)
# et s'en sert pour l'outline coloré par tier (update_highlighting). Le sprite en
# jeu dépend de l'élément (normal/glace/…) mais reste constant entre les tiers d'une
# même arme ; le tier ne colore que l'icône de boutique.
func _ready() -> void:
	var skin = BombSkin.build_world_texture(BombElement.from_weapon_id(weapon_id))
	if skin != null:
		sprite.texture = skin
	# Garde anti-double-branchement : le _ready() vanilla (weapon.gd) rebranche les
	# signaux de la hitbox SANS is_connected (lignes 87/104/107). Quand ce _ready
	# repasse sur la même Bombe (re-init d'arme), Godot loggue « already connected »
	# (refus inoffensif mais bruyant). On repart d'une hitbox propre : au 1er passage
	# rien n'est branché (no-op) ; aux suivants on déconnecte avant le rebranchement.
	_clear_hitbox_signal_dupes()
	._ready()


# Déconnecte (si présents) les signaux que le _ready() vanilla va rebrancher, pour
# éviter les erreurs « already connected » quand _ready repasse sur le même nœud.
# is_connected garde chaque cas : au 1er passage tout est faux -> aucune action.
func _clear_hitbox_signal_dupes() -> void:
	if _hitbox == null:
		return
	var pairs = [
		["critically_hit_something", "_on_weapon_critically_hit_something"],
		["one_shot_something", "on_one_shot_something"],
		["killed_something", "on_killed_something"],
		["added_gold_on_crit", "on_added_gold_on_crit"],
	]
	for p in pairs:
		if _hitbox.is_connected(p[0], self, p[1]):
			_hitbox.disconnect(p[0], self, p[1])


# Surcharge : tirer dès que le cooldown est prêt, SANS exiger de cible/portée.
# Respecte la règle de mouvement vanilla (immobile, sauf effet "attaque en bougeant").
func should_shoot() -> bool:
	if not RunData.wave_in_progress:
		return false
	if _is_shooting:
		return false
	if _current_cooldown > 0:
		return false
	var can_move_attack = RunData.get_player_effect(Keys.can_attack_while_moving_hash, player_index)
	if _parent._current_movement != Vector2.ZERO and not can_move_attack:
		return false
	return true

# Surcharge : poser une bombe à la position du joueur (pas de projectile dirigé).
func shoot() -> void:
	_nb_shots_taken += 1
	var bomb = BombEntity.instance()
	Utils.get_scene_node().add_child(bomb)
	bomb.global_position = _parent.global_position
	# Utilise `tier` directement (membre de Weapon) — `data` n'existe pas dans weapon.gd.
	# Dégât d'explosion calculé depuis les stats de BASE (pas current_stats) pour
	# inclure le bonus explosion_damage (buff ingé) sans double-compter le %Damage.
	# La Bombe n'a pas d'ExplodingEffect dans ses `effects`, donc current_stats
	# ne porte pas ce bonus.
	var explosion_damage = WeaponService.get_explosion_damage(stats, player_index)
	bomb.arm(player_index, current_stats, tier, EXPLOSION_SCALE, Keys.empty_hash, explosion_damage, BombElement.from_weapon_id(weapon_id), self)
	_current_cooldown = get_next_cooldown()
	# La bombe n'a pas d'animation de tir : on a "fini de tirer" dès qu'elle est posée.
	# Sans ce reset, `_is_shooting` resterait `true` à vie (vanilla weapon.gd:201 le pose,
	# mais seul le ShootingBehavior — qu'on n'utilise pas — le remet à `false`), ce qui
	# gèlerait le cooldown (weapon.gd:192) et bloquerait should_shoot() : une seule bombe
	# par partie. On reproduit donc le `set_shooting(false)` de fin d'animation vanilla.
	set_shooting(false)


# Cible du signal hit_something de l'explosion d'une bombe de GLACE (connecté par
# bomb_entity). Applique une coupe de vitesse RÉELLE et NON CUMULATIVE à l'ennemi
# touché (cf. bomb_ice_slow). Duck-typé : ne touche que des unités ayant
# current_stats/max_stats (marche vanilla/DLC/autre mod, sans étendre enemy.gd).
func on_ice_hit(thing_hit, _damage_dealt, slow_pct: float) -> void:
	if not is_instance_valid(thing_hit):
		return
	if not ("current_stats" in thing_hit) or not ("max_stats" in thing_hit):
		return
	if thing_hit.current_stats == null or thing_hit.max_stats == null:
		return
	thing_hit.current_stats.speed = BombIceSlow.apply(
		thing_hit.current_stats.speed,
		thing_hit.max_stats.speed,
		slow_pct
	)


# --- Déphasage par slot ("train de bombes") ---

# Index de ce slot d'arme parmi les armes du joueur.
# `weapon_pos` est assigné par player.gd:add_weapon(weapon, pos) avant _ready().
# Retourne -1 si non initialisé (garde-fou : slot_phase_offset renverra 0).
func _bomb_slot_index() -> int:
	return weapon_pos


# Nombre d'armes actuellement équipées par le joueur.
# Retourne 0 si _parent n'est pas encore disponible (garde-fou).
func _bomb_slot_count() -> int:
	if not is_instance_valid(_parent):
		return 0
	return _parent.get_nb_weapons()


# Surcharge de init_stats (Weapon) : après l'init vanilla du cooldown de début
# de vague, ajoute un déphasage par slot pour égrener les bombes ("train").
func init_stats(at_wave_begin: bool = true) -> void:
	.init_stats(at_wave_begin)
	if at_wave_begin:
		# Égrener les bombes des différents slots : décaler le 1er cooldown
		# de chaque arme selon son index, pour former une traînée nette.
		var phase = BombTiming.slot_phase_offset(
			_bomb_slot_index(),
			_bomb_slot_count(),
			get_next_cooldown(true)
		)
		_current_cooldown += phase
