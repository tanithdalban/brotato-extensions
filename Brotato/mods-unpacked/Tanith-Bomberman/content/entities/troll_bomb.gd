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
const ExplosionVisual = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/explosion_visual.gd")
const TrollBombLogic = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd")

const _FACE_PATH := "res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/skins/troll_bomb_face.png"

# Son d'alerte joué à l'éveil (phase télégraphe), préchargé.
const WAKE_SOUND := preload("res://entities/units/enemies/boss/zombie_voice_general_emote_05.wav")

# --- Paramètres réglables (calibrage final en jeu) ---
const SPEED := 120.0            # ≈ vitesse de base d'un joueur, CONSTANTE
const PURSUIT_SECONDS := 5.0    # minuteur de poursuite (plage à tester 4-6)
const BLAST_RADIUS := 120.0     # rayon de l'AoE infligée en fin de minuteur (> rayon de contact ~50)
const TELEGRAPH_SECONDS := 0.8  # éveil : son + immobile (le joueur a le temps de réagir) avant la chasse
const MIN_SPAWN_DISTANCE := 130.0  # ne pas apparaître collé au joueur

var _player_index: int = -1
var _stats: WeaponStats = null
var _tier: int = 0
var _explosion_scale: float = 1.5
var _damage_tracking_key_hash: int = Keys.empty_hash
var _base_damage: int = 1       # dégâts bruts de la bombe (avant plafond non-létal)
var _exploded: bool = false
var _telegraph_timer: Timer = null

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
	# Timer de télégraphe (créé en code, pas dans la scène) : éveil immobile.
	_telegraph_timer = Timer.new()
	_telegraph_timer.one_shot = true
	add_child(_telegraph_timer)
	var _e4 = _telegraph_timer.connect("timeout", self, "_on_telegraph_timeout")


# Appelée juste après instanciation par bomb_entity (au réveil).
func arm(p_player_index: int, p_stats: WeaponStats, p_tier: int, p_explosion_scale: float = 1.5, p_damage_tracking_key_hash: int = Keys.empty_hash) -> void:
	_player_index = p_player_index
	_stats = p_stats
	_tier = p_tier
	_explosion_scale = p_explosion_scale
	_damage_tracking_key_hash = p_damage_tracking_key_hash
	if _exploding_effect != null:
		_exploding_effect.scale = _explosion_scale

	# Corps = skin de bombe CONSTANT (sprite en jeu 48 réutilisé ; le tier ne colore que l'icône de boutique).
	var body_tex = BombSkin.build_normal_world_texture()
	if body_tex != null and is_instance_valid(_body):
		_body.texture = body_tex
	# Visage fâché en surcouche (placeholder -> art final).
	var face_tex = BombSkin._load(_FACE_PATH)
	if face_tex != null and is_instance_valid(_face):
		_face.texture = face_tex

	# Grossissement purement VISUEL : la troll bombe est volontairement IMPOSANTE
	# (~96px = presque la taille d'un ennemi de base 100×100) pour bien se voir comme
	# un danger. On scale le corps ET le visage, jamais la racine (sinon la Hitbox/
	# rayon de contact serait agrandie aussi). Le rayon d'explosion reste géré par
	# _explosion_scale. Constante à régler ici si besoin (sprite source = 48px).
	if is_instance_valid(_body):
		_body.scale = Vector2(2.0, 2.0)
	if is_instance_valid(_face):
		_face.scale = Vector2(2.0, 2.0)

	# Dégâts bruts de la bombe : plafonnés à chaque frame pour rester NON LÉTAUX.
	_base_damage = int(_stats.damage) if _stats != null else 1

	# Hitbox de contact (couche 4) : désactivée pendant le télégraphe, armée ensuite.
	if is_instance_valid(_hitbox):
		_hitbox.damage = _base_damage
		_hitbox.from = null
		_hitbox.damage_tracking_key_hash = Keys.empty_hash
		_hitbox.disable()

	# Anti "explose au visage" : ne pas démarrer collé au joueur le plus proche.
	var np = _nearest_player_node()
	if np != null:
		global_position = TrollBombLogic.keep_distance(global_position, np.global_position, MIN_SPAWN_DISTANCE)

	# Télégraphe : son d'alerte (toujours joué, plus fort) + immobile un court instant.
	SoundManager2D.play(WAKE_SOUND, global_position, 4.0, 0.0, true)
	set_physics_process(false)
	_telegraph_timer.wait_time = TELEGRAPH_SECONDS
	_telegraph_timer.start()


# Fin du télégraphe : on arme la hitbox, on lance la poursuite et le déplacement.
func _on_telegraph_timeout() -> void:
	if _exploded:
		return
	if is_instance_valid(_hitbox):
		_hitbox.enable()
	_pursuit_timer.wait_time = PURSUIT_SECONDS
	_pursuit_timer.start()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	var node = _nearest_player_node()
	if node == null:
		return
	var vel = TrollBombLogic.step_velocity(global_position, node.global_position, SPEED)
	global_position += vel * delta
	# Plafonne les dégâts de contact au PV min de tous les joueurs vivants (coop-safe).
	if is_instance_valid(_hitbox):
		_hitbox.damage = TrollBombLogic.nonlethal_damage(_base_damage, _min_hp_all_living())


# Nœud du joueur VIVANT le plus proche (ou null). Construit la liste pure puis
# délègue le choix à la logique pure, et remappe l'index vers le nœud.
func _nearest_player_node():
	var main = Utils.get_scene_node()
	if main == null or not ("_players" in main):
		return null
	var targets := []
	var nodes := []
	for p in main._players:
		if is_instance_valid(p):
			targets.append({"position": p.global_position, "dead": p.dead, "index": nodes.size()})
			nodes.append(p)
	var r = TrollBombLogic.nearest_target(global_position, targets)
	if not r["found"]:
		return null
	return nodes[r["index"]]


# Plus petit PV courant parmi les joueurs vivants dans le rayon d'explosion.
# Renvoie un très grand nombre si personne n'est à portée (dégâts non plafonnés,
# mais sans cible -> sans effet).
func _min_hp_in_blast() -> int:
	var main = Utils.get_scene_node()
	if main == null or not ("_players" in main):
		return 0x7FFFFFFF
	var min_hp := 0x7FFFFFFF
	for p in main._players:
		if is_instance_valid(p) and not p.dead:
			if global_position.distance_to(p.global_position) <= BLAST_RADIUS:
				var hp = int(p.current_stats.health)
				if hp < min_hp:
					min_hp = hp
	return min_hp


# Plus petit PV courant parmi TOUS les joueurs vivants (sans notion de rayon).
# Sert à plafonner le dégât de CONTACT pour qu'aucun joueur — pas seulement le
# poursuivi — ne puisse mourir en coop (la Hitbox couche 4 touche n'importe quel
# joueur qui la chevauche).
func _min_hp_all_living() -> int:
	var main = Utils.get_scene_node()
	if main == null or not ("_players" in main):
		return 0x7FFFFFFF
	var hps := []
	for p in main._players:
		if is_instance_valid(p) and not p.dead:
			hps.append(int(p.current_stats.health))
	return TrollBombLogic.min_living_hp(hps)


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
		# Dégâts plafonnés au plus petit PV des joueurs vivants à portée -> aucun kill.
		_hitbox.damage = TrollBombLogic.nonlethal_damage(_base_damage, _min_hp_in_blast())
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
	# Anti-épilepsie : plafonne l'opacité du sprite d'AOE (visuel seul).
	ExplosionVisual.cap_aoe_opacity(_inst)
