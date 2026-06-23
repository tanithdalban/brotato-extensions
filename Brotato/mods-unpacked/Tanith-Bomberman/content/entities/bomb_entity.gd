extends Node2D
# Bombe posée au sol. Modèle : landmine.gd (placée puis WeaponService.explode).
# Aucun auto-dégât joueur : l'explosion vanilla n'affecte pas le joueur.

const BombTiming = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd")

# Scène d'explosion vanilla réutilisée (dégâts de zone + lecture explosion_damage/size).
var _explosion_scene: PackedScene = preload("res://projectiles/explosion.tscn")

var _player_index: int = -1
var _stats: WeaponStats = null
var _explosion_scale: float = 1.75  # cf. landmine (scale par défaut)
var _explode_args := WeaponServiceExplodeArgs.new()
var _exploding_effect: ExplodingEffect = null
# Clé de tracking fournie par l'arme (T4) ; défaut = non tracké (empty_hash = pas de stats/défis).
var _damage_tracking_key_hash: int = Keys.empty_hash

onready var _fuse_timer: Timer = $FuseTimer

func _ready() -> void:
	# Construit l'effet d'explosion (équivaut au .tres d'effet du landmine).
	_exploding_effect = ExplodingEffect.new()
	_exploding_effect.explosion_scene = _explosion_scene
	_exploding_effect.scale = _explosion_scale
	_exploding_effect.base_smoke_amount = 40
	_exploding_effect.sound_db_mod = -10
	var _e = _fuse_timer.connect("timeout", self, "_on_fuse_timeout")

# Appelée juste après instanciation par l'arme.
func arm(p_player_index: int, p_stats: WeaponStats, p_tier: int, p_explosion_scale: float = 1.75, p_damage_tracking_key_hash: int = Keys.empty_hash) -> void:
	_player_index = p_player_index
	_stats = p_stats
	_explosion_scale = p_explosion_scale
	_damage_tracking_key_hash = p_damage_tracking_key_hash
	if _exploding_effect != null:
		_exploding_effect.scale = _explosion_scale
	_fuse_timer.wait_time = BombTiming.fuse_seconds(p_tier)
	_fuse_timer.start()

func _on_fuse_timeout() -> void:
	if _stats == null:
		queue_free()
		return
	_explode_args.pos = global_position
	_explode_args.damage = _stats.damage
	_explode_args.accuracy = _stats.accuracy
	_explode_args.crit_chance = _stats.crit_chance
	_explode_args.crit_damage = _stats.crit_damage
	_explode_args.burning_data = _stats.burning_data
	_explode_args.scaling_stats = _stats.scaling_stats
	_explode_args.from_player_index = _player_index
	_explode_args.from = null  # pas d'auto-attribution à un noeud qui va disparaître
	_explode_args.damage_tracking_key_hash = _damage_tracking_key_hash
	var _inst = WeaponService.explode(_exploding_effect, _explode_args)
	queue_free()
