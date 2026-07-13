extends Node2D
# Bombe posée au sol. Modèle : landmine.gd (placée puis WeaponService.explode).
# Aucun auto-dégât joueur : l'explosion vanilla n'affecte pas le joueur.

const BombTiming = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd")
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")
const ExplosionVisual = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/explosion_visual.gd")
const TrollBomb = preload("res://mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.tscn")
const TrollBombLogic = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd")
const BombElement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd")
const BombIceSlow = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_ice_slow.gd")
const BombLeech = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_leech.gd")

# --- Paramètres réglables de la troll bombe (calibrage final en jeu) ---
const TROLL_WAKE_CHANCE := 0.05   # ~5 % qu'une bombe posée se réveille (par bombe ; se cumule avec le volume de bombes)
const TROLL_WAKE_FRACTION := 0.5  # réveil à ~50 % de la mèche
# Le son d'alerte est joué par la troll bombe elle-même (phase télégraphe).

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
var _explosion_damage_override: int = -1  # dégât d'explosion pré-calculé (-1 = non fourni)
var _element: String = BombElement.NORMAL  # élément de la bombe (pilote le sous-comportement)
var _weapon = null                          # arme source (persistante) : cible du signal de slow glace

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
func arm(p_player_index: int, p_stats: WeaponStats, p_tier: int, p_explosion_scale: float = 1.75, p_damage_tracking_key_hash: int = Keys.empty_hash, p_explosion_damage: int = -1, p_element: String = BombElement.NORMAL, p_weapon = null) -> void:
	_player_index = p_player_index
	_stats = p_stats
	_explosion_scale = p_explosion_scale
	_damage_tracking_key_hash = p_damage_tracking_key_hash
	_explosion_damage_override = p_explosion_damage
	_element = p_element
	_weapon = p_weapon
	if _exploding_effect != null:
		_exploding_effect.scale = _explosion_scale
	# Skin de bombe CONSTANT (sprite en jeu 48×48, chargé au runtime ; le tier ne colore que l'icône de boutique).
	var skin = BombSkin.build_world_texture(_element)
	if skin != null and is_instance_valid(_sprite):
		_sprite.texture = skin
	# Grossissement purement VISUEL de la bombe posée (n'affecte pas le rayon
	# d'explosion, géré par _explosion_scale / explosion_size).
	if is_instance_valid(_sprite):
		_sprite.scale = Vector2(1.25, 1.25)
	_tier = p_tier
	# Tirage unique du réveil. Si elle se réveille, la "mèche" sert de délai
	# avant la bascule en troll bombe (instant = fraction de la mèche) ; sinon
	# c'est la mèche normale qui mène à l'explosion.
	# Seule la Bombe normale peut se transformer en trollbombe ; les bombes à
	# effet (glace/poison/foudre) ne se réveillent jamais.
	if BombElement.is_effect(_element):
		_will_wake = false
	else:
		_will_wake = TrollBombLogic.should_wake(randf(), TROLL_WAKE_CHANCE)
	# La vitesse d'attaque raccourcit la mèche (même formule que le cooldown
	# vanilla) : vitesse combinée joueur + arme, en fraction (+50% = 0.5).
	var atk_speed_mod := 0.0
	if _player_index >= 0:
		atk_speed_mod = Utils.get_stat(Keys.stat_attack_speed_hash, _player_index) / 100.0
	if _stats != null:
		atk_speed_mod += _stats.attack_speed_mod / 100.0
	var fuse := BombTiming.fuse_seconds_scaled(p_tier, atk_speed_mod)
	if _will_wake:
		_fuse_timer.wait_time = TrollBombLogic.wake_delay(fuse, TROLL_WAKE_FRACTION)
	else:
		_fuse_timer.wait_time = fuse
	_fuse_timer.start()

func _on_fuse_timeout() -> void:
	if _will_wake:
		_wake_into_troll()
		return
	if _stats == null:
		queue_free()
		return
	# Foudre : pas d'explosion AoE. On tire un burst d'éclairs en cercle (façon
	# item Tyler) puis la bombe disparaît ; les dégâts sont portés par les
	# projectiles, pas par une zone d'explosion.
	if _element == BombElement.STORM:
		_burst_lightning()
		queue_free()
		return
	_explode_args.pos = global_position
	# Bombes à effet : AUCUN dégât d'explosion AoE (les effets — slow, givre —
	# s'appliquent indépendamment ; deals_damage reste true donc les hits sont émis).
	if BombElement.is_effect(_element):
		_explode_args.damage = 0
	else:
		_explode_args.damage = _explosion_damage_override if _explosion_damage_override >= 0 else _stats.damage
	_explode_args.accuracy = _stats.accuracy
	_explode_args.crit_chance = _stats.crit_chance
	_explode_args.crit_damage = _stats.crit_damage
	_explode_args.burning_data = _stats.burning_data
	_explode_args.scaling_stats = _stats.scaling_stats
	_explode_args.from_player_index = _player_index
	_explode_args.from = null  # pas d'auto-attribution à un noeud qui va disparaître
	_explode_args.damage_tracking_key_hash = _damage_tracking_key_hash
	var _inst = WeaponService.explode(_exploding_effect, _explode_args)
	# Anti-épilepsie : plafonne l'opacité du sprite d'AOE (ne touche pas les dégâts).
	ExplosionVisual.cap_aoe_opacity(_inst)
	# Suivi des dégâts "façon arme tenue" : on attribue les dégâts de l'explosion à
	# notre BombWeapon via son on_weapon_hit_something héritée de Weapon
	# (-> RunData.add_weapon_dmg_dealt(weapon_pos)), pour que l'infobulle affiche les
	# "dégâts infligés (dernière vague)" comme n'importe quelle arme. Le hitbox bindé
	# est null (on_weapon_hit_something sort après l'ajout si hitbox == null : aucune
	# logique d'attack_id/combo n'est déclenchée). Connexion nettoyée par
	# PlayerExplosion.end_explosion (disconnect_all hit_something).
	if _inst != null and is_instance_valid(_weapon):
		if not _inst.is_connected("hit_something", _weapon, "on_weapon_hit_something"):
			_inst.connect("hit_something", _weapon, "on_weapon_hit_something", [null])
	# Glace : coupe de vitesse réelle sur les ennemis touchés, via le signal
	# public hit_something de l'explosion (émis même à 0 dégât, unit.gd:608) →
	# notre BombWeapon (persistant). AUCUNE extension de enemy.gd. La connexion
	# est nettoyée par PlayerExplosion.end_explosion (disconnect_all hit_something).
	if _element == BombElement.ICE and _inst != null and is_instance_valid(_weapon) and _stats != null:
		var slow_pct = BombIceSlow.slow_pct_for(_stats.speed_percent_modifier)
		if not _inst.is_connected("hit_something", _weapon, "on_ice_hit"):
			_inst.connect("hit_something", _weapon, "on_ice_hit", [slow_pct])
	# Sangsue : draine les ennemis touchés, via le même signal public hit_something de
	# l'explosion que la glace (émis même à 0 dégât, unit.gd:608) -> notre BombWeapon
	# (persistant). Le budget n'est PLUS instancié ici (correctif d'équilibrage, revue
	# finale) : c'est désormais un SEUL seau à jetons par JOUEUR, partagé par toutes ses
	# bombes sangsue et rechargé dans le temps (cf. bomb_leech.gd) — sinon plusieurs
	# sangsues cumuleraient chacune leur propre budget par explosion, dépassant le
	# plafond vanilla de 10 PV/s. On se contente de passer le TIER de CETTE bombe : le
	# BombWeapon en déduit le plafond (BombLeech.cap_for_tier) et résout le seau partagé
	# du joueur. La connexion est nettoyée par PlayerExplosion.end_explosion
	# (disconnect_all hit_something).
	if _element == BombElement.LEECH and _inst != null and is_instance_valid(_weapon):
		if not _inst.is_connected("hit_something", _weapon, "on_leech_hit"):
			_inst.connect("hit_something", _weapon, "on_leech_hit", [_tier])
	queue_free()

# Réveil : instancie la troll bombe à la place de l'explosion et se libère sans
# exploser. La troll bombe prend le relais (télégraphe + son + poursuite + explosion).
func _wake_into_troll() -> void:
	var troll = TrollBomb.instance()
	Utils.get_scene_node().add_child(troll)
	troll.global_position = global_position
	troll.arm(_player_index, _stats, _tier, _explosion_scale, _damage_tracking_key_hash)
	queue_free()

# Foudre : tire _stats.nb_projectiles projectiles "delayed_lightning" en cercle
# complet (spread ≈ π) depuis la position de la bombe, via le même appel que
# turret._spawn_projectile (WeaponService.spawn_projectile). from = _weapon
# (l'arme persistante) pour l'attribution des dégâts + le player_index. Aucune
# structure ni cooldown de tourelle : un unique burst, puis la bombe se libère.
func _burst_lightning() -> void:
	if _stats == null or not is_instance_valid(_weapon):
		return
	var args := WeaponServiceSpawnProjectileArgs.new()
	args.from_player_index = _player_index
	args.damage_tracking_key_hash = _damage_tracking_key_hash
	# Orientation de base aléatoire : avec spread ≈ π, chaque tir couvre déjà tout
	# le cercle ; la base ne fait que décorréler les bursts successifs.
	var base := randf() * TAU
	for _i in range(int(_stats.nb_projectiles)):
		var rot := rand_range(base - _stats.projectile_spread, base + _stats.projectile_spread)
		args.knockback_direction = Vector2(cos(rot), sin(rot))
		var proj = WeaponService.spawn_projectile(global_position, _stats, rot, _weapon, args)
		# Suivi des dégâts façon arme tenue : connecter hit_something de l'éclair à
		# on_weapon_hit_something (Weapon -> add_weapon_dmg_dealt(weapon_pos)), comme
		# ranged_weapon.on_projectile_shot. Le flag + la déconnexion sont gérés par
		# projectile.gd au recyclage (pas de contamination inter-armes).
		if is_instance_valid(proj) and ("hit_something_connected" in proj) and not proj.hit_something_connected:
			var _c = proj.connect("hit_something", _weapon, "on_weapon_hit_something", [proj._hitbox])
			proj.hit_something_connected = true
