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
const BombFrag = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_frag.gd")

# --- Paramètres réglables de la troll bombe (calibrage final en jeu) ---
const TROLL_WAKE_CHANCE := 0.05   # ~5 % qu'une bombe posée se réveille (par bombe ; se cumule avec le volume de bombes)
const TROLL_WAKE_FRACTION := 0.5  # réveil à ~50 % de la mèche

# --- Paramètres réglables de la Bombe Frag (calibrage final en jeu) ---
#
# ⚠️⚠️ FRAG_SCATTER_RADIUS et FRAG_CHILD_EXPLOSION_SCALE sont LIÉS AUX DÉGÂTS des
# bomb_frag_*_stats.tres. La puissance d'une bombe vaut `dégâts × rayon²` : changer
# l'échelle d'explosion sans recalculer les dégâts par (221 / nouveau_rayon_px)² casse
# l'équilibrage AU CARRÉ. Lire « Le piège du carré » dans la spec avant d'y toucher.
const FRAG_SCATTER_RADIUS := 150.0        # rayon de la gerbe (px). Ne change PAS la puissance, seulement la forme.
const FRAG_CHILD_EXPLOSION_SCALE := 0.35  # 147,34 × 0,35 ≈ 52 px de rayon. Au-delà de ~0,5 le tapis sature et la contrepartie disparaît.
const FRAG_CHILD_SPRITE_SCALE := 0.4      # ~20 px à l'écran. PUREMENT visuel — à ne pas confondre avec l'échelle d'EXPLOSION ci-dessus.
const FRAG_CHILD_FUSE := 0.4              # mèche du fragment (s), FIXE : ni le tier ni la vitesse d'attaque ne la touchent.
const FRAG_CHILD_FUSE_JITTER := 0.15      # gigue ajoutée à la mèche du fragment (s). Voir _burst_fragments.
const FRAG_CHILD_SMOKE := 4               # fumée du fragment (la mère est à 40 : absurde et coûteux sur 52 px, × 42 fragments).
const FRAG_MOTHER_EXPLOSION_SCALE := 0.5  # l'obus qui éclate : PUREMENT visuel (0 dégât). Un souffle à 1,5 laisserait croire à une grosse explosion inoffensive.

# ⚠️ load() À L'EXÉCUTION, PAS preload() : un fragment EST une BombEntity, donc ce
# script devrait précharger la scène qui porte CE script — c'est une RÉFÉRENCE
# CYCLIQUE, et en Godot 3 elle produit une Compile Error qui invalide TOUT le fichier
# (plus aucune bombe en jeu). Le mod s'est déjà fait avoir deux fois par des cycles de
# ce genre, et les tests ne les voient PAS. load() résout à l'exécution : pas de cycle
# au parse. ResourceLoader met en cache, donc le coût est nul après le premier appel.
const _FRAG_SCENE_PATH := "res://mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.tscn"
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
	# L'obus Frag n'explose que pour la forme (0 dégât) : un souffle à 1,5 laisserait
	# croire à une énorme explosion inoffensive. On le réduit à un éclatement d'obus.
	if BombElement.is_cluster(_element):
		_explosion_scale = FRAG_MOTHER_EXPLOSION_SCALE
	if _exploding_effect != null:
		_exploding_effect.scale = _explosion_scale
		# Fumée coupée sur les fragments : 40 est le réglage d'une bombe pleine taille,
		# absurde et coûteux sur un fragment de 52 px — et il peut y en avoir 42 à
		# l'écran en même temps.
		if _element == BombElement.FRAG_CHILD:
			_exploding_effect.base_smoke_amount = FRAG_CHILD_SMOKE
	# Skin de bombe CONSTANT (sprite en jeu 48×48, chargé au runtime ; le tier ne colore que l'icône de boutique).
	var skin = BombSkin.build_world_texture(_element)
	if skin != null and is_instance_valid(_sprite):
		_sprite.texture = skin
	# Grossissement purement VISUEL de la bombe posée (n'affecte pas le rayon
	# d'explosion, géré par _explosion_scale / explosion_size).
	if is_instance_valid(_sprite):
		if _element == BombElement.FRAG_CHILD:
			# ~20 px : compromis entre la grammaire visuelle du mod (la normale est une
			# bille de 60 px pour un souffle de 442 — un rapport de 1 à 7, c'est lui qui
			# donne l'impression de puissance) et la lisibilité (la proportion stricte
			# donnerait 14 px, un grain de poussière invisible dans la mêlée, et on
			# perdrait le télégraphe qui justifie de vraies petites bombes).
			_sprite.scale = Vector2(FRAG_CHILD_SPRITE_SCALE, FRAG_CHILD_SPRITE_SCALE)
		else:
			_sprite.scale = Vector2(1.25, 1.25)
	_tier = p_tier
	# Tirage unique du réveil. Si elle se réveille, la "mèche" sert de délai
	# avant la bascule en troll bombe (instant = fraction de la mèche) ; sinon
	# c'est la mèche normale qui mène à l'explosion.
	# Seule la Bombe normale peut se transformer en trollbombe : c'est sa signature
	# exclusive. Ni les bombes à effet, ni la Frag, ni ses fragments ne se réveillent.
	if BombElement.can_troll(_element):
		_will_wake = TrollBombLogic.should_wake(randf(), TROLL_WAKE_CHANCE)
	else:
		_will_wake = false
	# La vitesse d'attaque raccourcit la mèche (même formule que le cooldown
	# vanilla) : vitesse combinée joueur + arme, en fraction (+50% = 0.5).
	var atk_speed_mod := 0.0
	if _player_index >= 0:
		atk_speed_mod = Utils.get_stat(Keys.stat_attack_speed_hash, _player_index) / 100.0
	if _stats != null:
		atk_speed_mod += _stats.attack_speed_mod / 100.0
	var fuse: float
	if _element == BombElement.FRAG_CHILD:
		# Mèche COURTE et FIXE : ni le tier ni la vitesse d'attaque ne la touchent. Elle
		# démarre à la détonation de la mère et meurt 0,4 s plus tard.
		#
		# ⭐ La GIGUE règle trois problèmes d'un coup, et n'est PAS cosmétique :
		# 1. ANTI-SCINTILLEMENT — sans elle les 7 fragments détonent dans la MÊME frame.
		#    Le plafond d'opacité ne protège pas d'une SYNCHRONISATION : 7 sprites à
		#    20 % qui se superposent se composent (1-0.8^n) et remontent à ~50 %
		#    d'opacité instantanée. C'est le NOMBRE SIMULTANÉ qui fait le stroboscope,
		#    pas la brillance de chacun.
		# 2. PERFORMANCE — étale la quarantaine de spawns d'explosion sur plusieurs
		#    frames au lieu d'un pic sur une seule.
		# 3. SENSATION — une munition à fragmentation crépite (pop-pop-pop), elle ne
		#    fait pas « boum ». C'est le son signature du cluster.
		#
		# ⚠️⚠️ LA GIGUE EST STRICTEMENT CONFINÉE ICI. Ne JAMAIS en remettre sur le
		# cooldown ni sur la mèche de la bombe MÈRE : on a retiré celle du vanilla lors
		# de la refonte de la pose précisément pour que toutes les armes bombe partagent
		# la même période, donc pour que le déphasage par slot tienne et que la traînée
		# reste propre. La réintroduire annulerait toute cette refonte.
		fuse = FRAG_CHILD_FUSE + rand_range(0.0, FRAG_CHILD_FUSE_JITTER)
	else:
		fuse = BombTiming.fuse_seconds_scaled(p_tier, atk_speed_mod)
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
	# Qui blesse, qui ne blesse pas. Les bombes à effet sont à 0 par design (leurs
	# effets — slow, givre, drain — s'appliquent indépendamment ; deals_damage reste
	# true, donc les hits sont émis quand même). L'OBUS Frag est à 0 lui aussi : il
	# n'est qu'un vecteur, ce sont ses fragments qui portent tout le dégât.
	if BombElement.deals_explosion_damage(_element):
		_explode_args.damage = _explosion_damage_override if _explosion_damage_override >= 0 else _stats.damage
	else:
		_explode_args.damage = 0
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
	# Plafond de TAILLE : borne l'inflation de l'explosion par la stat explosion_size
	# (élémentaire de Bomberto, Pot de miel…), qui autrement fait couvrir toute la map.
	# player_explosion.set_area a posé _inst.scale = _explosion_scale * (1 + explosion_size/100) ;
	# on reclampe au facteur max. Contrairement au plafond d'opacité, ce clamp réduit
	# AUSSI la zone de dégâts (la hitbox suit l'échelle de la racine) — c'est voulu, c'est
	# bien la TAILLE de l'explosion qu'on borne. _explosion_scale porte la base de CETTE
	# bombe (1.5 normale, 0.5 obus Frag, 0.35 fragment), donc le plafond reste proportionnel.
	if _inst != null:
		_inst.scale = ExplosionVisual.cap_growth_scale(_inst.scale, _explosion_scale)
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
	# Frag : l'obus vient d'éclater à 0 dégât (deals_explosion_damage(FRAG) est faux :
	# l'explosion mère n'est qu'un vecteur — repère visuel et son). On projette
	# maintenant les fragments, qui portent TOUT le dégât.
	if BombElement.is_cluster(_element):
		_burst_fragments()
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

# Frag : projette _stats.nb_projectiles fragments à des positions ALÉATOIRES dans le
# disque de FRAG_SCATTER_RADIUS autour de l'obus.
#
# Chaque fragment est une vraie petite BombEntity d'élément FRAG_CHILD, ce qui lui donne
# gratuitement tout le cycle de vie existant : sprite, mèche, explosion vanilla POOLÉE,
# et surtout l'ATTRIBUTION DES DÉGÂTS à l'arme (on transmet `_weapon`, donc le signal
# hit_something de son explosion remonte à on_weapon_hit_something ->
# RunData.add_weapon_dmg_dealt(weapon_pos), et l'infobulle « dégâts infligés » compte
# juste sans une ligne de plus).
#
# ⭐ Le dégât est passé TEL QUEL, sans rien partager : le `damage` du .tres est déjà le
# dégât PAR FRAGMENT (convention vanilla des armes multi-projectiles — la Foudre porte
# damage 8 + nb_projectiles 6). _explosion_damage_override porte la valeur déjà mise à
# l'échelle par la pose (avec le -75 % de Bomberto ET le bonus d'ingénierie).
#
# ⭐ La garde anti-récursion est STRUCTURELLE : les fragments sont armés en FRAG_CHILD,
# or is_cluster(FRAG_CHILD) est faux — ils ne peuvent donc pas se scinder à leur tour.
# Aucune condition à écrire, aucun compteur de profondeur : c'est impossible par
# construction.
func _burst_fragments() -> void:
	if _stats == null:
		return
	var n := int(_stats.nb_projectiles)
	if n <= 0:
		return
	# Le hasard est tiré ICI et INJECTÉ dans le module pur, qui reste déterministe et
	# testable en headless (même principe que le temps injecté dans BombLeech).
	var randoms := []
	for _i in range(n * BombFrag.RANDOMS_PER_FRAGMENT):
		randoms.append(randf())
	var offsets := BombFrag.scatter_offsets(n, FRAG_SCATTER_RADIUS, randoms)
	var scene = load(_FRAG_SCENE_PATH)
	if scene == null:
		return
	for off in offsets:
		var frag = scene.instance()
		Utils.get_scene_node().add_child(frag)
		frag.global_position = global_position + off
		frag.arm(
			_player_index,
			_stats,
			_tier,
			FRAG_CHILD_EXPLOSION_SCALE,
			_damage_tracking_key_hash,
			_explosion_damage_override,
			BombElement.FRAG_CHILD,
			_weapon
		)
