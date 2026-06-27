extends Weapon
class_name BombWeapon
# Arme "Bombe" : ne vise pas. Pose une bombe à la position du joueur dès que
# le cooldown est prêt. La bombe (entité) gère sa mèche puis explose.

const BombEntity = preload("res://mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.tscn")
const BombTiming = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd")
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")

# Échelle d'explosion de base (équiv. landmine). Ajustable au réglage.
const EXPLOSION_SCALE := 1.5

# Surcharge : applique le skin coloré du tier au sprite tenu AVANT le _ready()
# vanilla, qui capture `sprite.texture` dans `_original_sprite` (ligne 74) et
# s'en sert pour l'outline. `tier` est déjà renseigné à ce stade (vanilla
# weapon.gd l'utilise dans update_highlighting() appelé par son _ready()).
func _ready() -> void:
	var skin = BombSkin.load_world_texture(tier)
	if skin != null:
		sprite.texture = skin
	._ready()


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
	bomb.arm(player_index, current_stats, tier, EXPLOSION_SCALE, Keys.empty_hash, explosion_damage)
	_current_cooldown = get_next_cooldown()
	# La bombe n'a pas d'animation de tir : on a "fini de tirer" dès qu'elle est posée.
	# Sans ce reset, `_is_shooting` resterait `true` à vie (vanilla weapon.gd:201 le pose,
	# mais seul le ShootingBehavior — qu'on n'utilise pas — le remet à `false`), ce qui
	# gèlerait le cooldown (weapon.gd:192) et bloquerait should_shoot() : une seule bombe
	# par partie. On reproduit donc le `set_shooting(false)` de fin d'animation vanilla.
	set_shooting(false)


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
