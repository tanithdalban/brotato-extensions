extends Node2D
# Troll bombe : bombe posée qui s'est "réveillée" et poursuit le joueur VIVANT
# le plus proche pour lui exploser au visage. Inarrêtable par les armes (aucune
# hurtbox -> ne prend pas de dégâts) ; ne disparaît qu'en explosant — au CONTACT
# d'un joueur OU en fin de minuteur de poursuite.
#
# Dégâts : via une Hitbox couche 4 (le chemin de contact des ENNEMIS) -> seules
# les hurtbox de joueurs/alliés réagissent, jamais les ennemis. damage = celui
# de la bombe d'origine. L'explosion finale est purement VISUELLE (damage 0) :
# les vrais dégâts viennent de la Hitbox de contact.
#
# Couleur du corps = tier de la bombe d'origine (sprite en jeu réutilisé) ;
# visage fâché en surcouche. Vitesse FIXE (indépendante de la stat vitesse).

const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")
const TrollBombLogic = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd")

const _FACE_PATH := "res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/skins/troll_bomb_face.png"

# --- Paramètres réglables (calibrage final en jeu) ---
const SPEED := 120.0          # ≈ vitesse de base d'un joueur, CONSTANTE
const PURSUIT_SECONDS := 5.0  # minuteur de poursuite (plage à tester 4-6)
const BLAST_RADIUS := 120.0   # rayon de l'AoE infligée en fin de minuteur (> rayon de contact ~50)

var _player_index: int = -1
var _stats: WeaponStats = null
var _tier: int = 0
var _explosion_scale: float = 1.5
var _damage_tracking_key_hash: int = Keys.empty_hash
var _exploded: bool = false

var _explosion_scene: PackedScene = preload("res://projectiles/explosion.tscn")
var _exploding_effect: ExplodingEffect = null
var _explode_args := WeaponServiceExplodeArgs.new()

onready var _body: Sprite = $Body
onready var _face: Sprite = $Face
onready var _hitbox: Hitbox = $Hitbox
onready var _pursuit_timer: Timer = $PursuitTimer
onready var _free_timer: Timer = $FreeTimer


func _ready() -> void:
	# Effet d'explosion VISUEL (équivaut au .tres landmine ; damage 0 à l'usage).
	_exploding_effect = ExplodingEffect.new()
	_exploding_effect.explosion_scene = _explosion_scene
	_exploding_effect.scale = _explosion_scale
	_exploding_effect.base_smoke_amount = 40
	_exploding_effect.sound_db_mod = -10
	var _e1 = _pursuit_timer.connect("timeout", self, "_on_pursuit_timeout")
	# La hurtbox du joueur appelle hitbox.hit_something() quand elle encaisse :
	# c'est notre signal de "contact joueur" -> on explose.
	var _e2 = _hitbox.connect("hit_something", self, "_on_hit_player")
	var _e3 = _free_timer.connect("timeout", self, "_on_free_timeout")


# Appelée juste après instanciation par bomb_entity (au réveil).
func arm(p_player_index: int, p_stats: WeaponStats, p_tier: int, p_explosion_scale: float = 1.5, p_damage_tracking_key_hash: int = Keys.empty_hash) -> void:
	_player_index = p_player_index
	_stats = p_stats
	_tier = p_tier
	_explosion_scale = p_explosion_scale
	_damage_tracking_key_hash = p_damage_tracking_key_hash
	if _exploding_effect != null:
		_exploding_effect.scale = _explosion_scale

	# Corps coloré par le tier d'origine (sprite en jeu 48 réutilisé).
	var body_tex = BombSkin.load_world_texture(p_tier)
	if body_tex != null and is_instance_valid(_body):
		_body.texture = body_tex
	# Visage fâché en surcouche (placeholder -> art final).
	var face_tex = BombSkin._load(_FACE_PATH)
	if face_tex != null and is_instance_valid(_face):
		_face.texture = face_tex

	# Hitbox de contact : inflige les dégâts de la bombe aux joueurs/alliés (couche 4).
	if is_instance_valid(_hitbox):
		_hitbox.damage = int(_stats.damage) if _stats != null else 1
		_hitbox.from = null
		_hitbox.damage_tracking_key_hash = Keys.empty_hash
		_hitbox.enable()

	_pursuit_timer.wait_time = PURSUIT_SECONDS
	_pursuit_timer.start()


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	var target = _nearest_player()
	if not target["found"]:
		return
	var vel = TrollBombLogic.step_velocity(global_position, target["position"], SPEED)
	global_position += vel * delta


# Construit la liste pure des joueurs et délègue le choix à la logique pure.
func _nearest_player() -> Dictionary:
	var main = Utils.get_scene_node()
	if main == null or not ("_players" in main):
		return {"found": false}
	var targets := []
	var idx := 0
	for p in main._players:
		if is_instance_valid(p):
			targets.append({"position": p.global_position, "dead": p.dead, "index": idx})
		idx += 1
	return TrollBombLogic.nearest_target(global_position, targets)


# Le joueur a encaissé notre Hitbox au contact -> il a déjà pris les dégâts :
# on joue juste l'explosion visuelle et on disparaît.
func _on_hit_player(_thing_hit, _damage_dealt) -> void:
	_finish(false)


# Fin du minuteur de poursuite sans contact -> AoE sur les joueurs/alliés à portée.
func _on_pursuit_timeout() -> void:
	_finish(true)


# aoe=false : contact direct (dégâts déjà infligés) -> visuel + disparition immédiate.
# aoe=true  : fin de minuteur -> agrandit la Hitbox au rayon d'explosion pour
#             toucher les joueurs/alliés à portée, puis disparaît après détection.
func _finish(aoe: bool) -> void:
	if _exploded:
		return
	_exploded = true
	set_physics_process(false)
	if aoe:
		_burst_aoe()
	else:
		if is_instance_valid(_hitbox):
			_hitbox.disable()
		_spawn_visual_explosion()
		queue_free()


# Agrandit la Hitbox (couche 4) au rayon d'explosion : les joueurs/alliés à
# portée encaissent via leur hurtbox (les ennemis ne surveillent pas la couche 4).
# On garde la Hitbox active un court instant pour laisser la physique détecter le
# chevauchement, puis on libère via FreeTimer.
func _burst_aoe() -> void:
	if is_instance_valid(_hitbox):
		var col = _hitbox.get_node("Collision") as CollisionShape2D
		if col != null:
			var shape = CircleShape2D.new()  # neuf : ne pas partager la forme entre instances
			shape.radius = BLAST_RADIUS
			col.shape = shape
		_hitbox.enable()
	_spawn_visual_explosion()
	_free_timer.wait_time = 0.12
	_free_timer.start()


func _on_free_timeout() -> void:
	if is_instance_valid(_hitbox):
		_hitbox.disable()
	queue_free()


# Explosion PUREMENT VISUELLE (damage 0, aucun effet propagé) : les dégâts
# joueur viennent de la Hitbox (couche 4). On ne propage RIEN (notamment pas
# burning_data) pour ne jamais affecter les ennemis via la hitbox couche 8 de
# l'explosion (la brûlure s'applique indépendamment des dégâts dans unit.gd).
func _spawn_visual_explosion() -> void:
	_explode_args.pos = global_position
	_explode_args.damage = 0
	_explode_args.burning_data = null
	_explode_args.scaling_stats = []
	_explode_args.from_player_index = _player_index
	_explode_args.from = null
	_explode_args.damage_tracking_key_hash = Keys.empty_hash
	var _inst = WeaponService.explode(_exploding_effect, _explode_args)
