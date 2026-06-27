extends Node2D
# Bombe posée au sol. Modèle : landmine.gd (placée puis WeaponService.explode).
# Aucun auto-dégât joueur : l'explosion vanilla n'affecte pas le joueur.

const BombTiming = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd")
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")
const TrollBomb = preload("res://mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.tscn")
const TrollBombLogic = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd")

# --- Paramètres réglables de la troll bombe (calibrage final en jeu) ---
const TROLL_WAKE_CHANCE := 0.10   # ~10 % qu'une bombe posée se réveille
const TROLL_WAKE_FRACTION := 0.5  # réveil à ~50 % de la mèche
const TROLL_WAKE_SOUND := "res://entities/units/enemies/pursuer/sci-fi_code_fail_08.wav"

# Scène d'explosion vanilla réutilisée (dégâts de zone + lecture explosion_damage/size).
var _explosion_scene: PackedScene = preload("res://projectiles/explosion.tscn")

var _player_index: int = -1
var _stats: WeaponStats = null
var _explosion_scale: float = 1.75  # cf. landmine (scale par défaut)
var _explode_args := WeaponServiceExplodeArgs.new()
var _exploding_effect: ExplodingEffect = null
# Clé de tracking fournie par l'arme (T4) ; défaut = non tracké (empty_hash = pas de stats/défis).
var _damage_tracking_key_hash: int = Keys.empty_hash
var _tier: int = 0           # tier de la bombe (pour la couleur de la troll bombe)
var _will_wake: bool = false # tirage du réveil, décidé à l'armement

onready var _fuse_timer: Timer = $FuseTimer
onready var _sprite: Sprite = $Sprite

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
	# Skin coloré selon le tier de l'arme (sprite en jeu 48×48, chargé au runtime).
	var skin = BombSkin.load_world_texture(p_tier)
	if skin != null and is_instance_valid(_sprite):
		_sprite.texture = skin
	_tier = p_tier
	# Tirage unique du réveil. Si elle se réveille, la "mèche" sert de délai
	# avant la bascule en troll bombe (instant = fraction de la mèche) ; sinon
	# c'est la mèche normale qui mène à l'explosion.
	_will_wake = TrollBombLogic.should_wake(randf(), TROLL_WAKE_CHANCE)
	if _will_wake:
		_fuse_timer.wait_time = TrollBombLogic.wake_delay(BombTiming.fuse_seconds(p_tier), TROLL_WAKE_FRACTION)
	else:
		_fuse_timer.wait_time = BombTiming.fuse_seconds(p_tier)
	_fuse_timer.start()

func _on_fuse_timeout() -> void:
	if _will_wake:
		_wake_into_troll()
		return
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

# Réveil : joue un son, instancie la troll bombe à la place de l'explosion, et
# se libère sans exploser. La troll bombe prend le relais (poursuite + explosion).
func _wake_into_troll() -> void:
	var snd = load(TROLL_WAKE_SOUND)
	if snd != null:
		SoundManager2D.play(snd, global_position, -6.0)
	var troll = TrollBomb.instance()
	Utils.get_scene_node().add_child(troll)
	troll.global_position = global_position
	troll.arm(_player_index, _stats, _tier, _explosion_scale, _damage_tracking_key_hash)
	queue_free()
