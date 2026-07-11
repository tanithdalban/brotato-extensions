extends Weapon
class_name BombWeapon
# Arme "Bombe" : ne vise pas. Pose une bombe à la position du joueur dès que
# le cooldown est prêt. La bombe (entité) gère sa mèche puis explose.

const BombEntity = preload("res://mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.tscn")
const BombTiming = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd")
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")
const BombElement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd")
const BombIceSlow = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_ice_slow.gd")
const BombPlacement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_placement.gd")

# Échelle d'explosion de base (équiv. landmine). Ajustable au réglage.
const EXPLOSION_SCALE := 1.5

# Couleur du contour "givré" appliqué à l'ennemi gelé (feedback visuel du slow).
# Le système d'outline vit dans entity.gd (add_outline/remove_outline, shader,
# 4 couleurs max) : il porte ici tout le signal visuel de la Bombe de Glace, ce qui
# nous permet de retirer le burning givré (et donc son DOT plancher max(1,…)).
# Non cumulatif par nature : add_outline dédoublonne par couleur.
const FROST_OUTLINE_COLOR := Color("5bc8ff")

# --- Mémoire du mouvement (pour orienter la traînée) ---
# Le joueur PEUT poser en mouvement : weapon.gd:273-283 se lit « ne tire que si immobile,
# SAUF can_attack_while_moving », mais cet effet vaut 1 PAR DÉFAUT pour tout joueur
# (player_run_data.gd:498). _current_movement est donc non nul au moment de la pose.
# On entretient quand même une mémoire, à chaque frame, pour deux raisons :
#   - LISSER : le kiting est un va-et-vient permanent ; sans lissage, l'éventail
#     claquerait du cercle complet à la file stricte à chaque freinage ;
#   - GARDER UNE DIRECTION quand le joueur est réellement à l'arrêt (_current_movement
#     vaut alors Vector2.ZERO et il n'y a plus rien à lire).
var _last_dir := Vector2.ZERO
var _mobility := 0.0

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


# Surcharge : on laisse vanilla faire son travail (décrément du cooldown, visée), puis
# on met à jour la mémoire du mouvement du joueur.
func _physics_process(delta: float) -> void:
	._physics_process(delta)
	_update_movement_memory(delta)


# Mémoire du mouvement, mise à jour CHAQUE frame (et pas seulement au moment du tir) :
# c'est ce qui lisse le va-et-vient du kiting et conserve une direction à l'arrêt.
func _update_movement_memory(delta: float) -> void:
	if not is_instance_valid(_parent):
		return

	var movement = _parent._current_movement
	var is_moving: bool = movement != Vector2.ZERO
	if is_moving:
		_last_dir = movement.normalized()

	# Cible de mobilité : « le déplacement suffit-il, à lui seul, à espacer les
	# bombes ? ». Nulle si le joueur est à l'arrêt.
	var target := 0.0
	if is_moving:
		target = BombPlacement.mobility_target(
			_parent.get_move_speed(),
			_placement_interval_seconds(),
			BombPlacement.RADIUS
		)

	_mobility = BombPlacement.mobility_step(
		_mobility,
		target,
		delta,
		BombPlacement.MOBILITY_RISE_SECONDS,
		BombPlacement.MOBILITY_FALL_SECONDS
	)


# Intervalle réel entre deux poses de bombe, TOUTES bombes confondues, en secondes.
# Les armes bombe étant entrelacées et de même période, il tombe une bombe tous les
# `cooldown / nb_bombes` frames. Le cooldown est en FRAMES (weapon.gd:193 le décrémente
# de 60 x delta), d'où la division par 60.
func _placement_interval_seconds() -> float:
	var nb := _bomb_slot_count()
	if nb <= 0:
		nb = 1
	return (current_stats.cooldown / float(nb)) / 60.0


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
	# Position sur la couronne à éventail, plutôt que sous les pieds du joueur.
	# `_nb_shots_taken` vient d'être incrémenté ci-dessus : c'est le numéro de la pose.
	bomb.global_position = _parent.global_position + BombPlacement.offset(
		_bomb_slot_index(),
		_bomb_slot_count(),
		_nb_shots_taken,
		_last_dir,
		_mobility,
		BombPlacement.RADIUS
	)
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
	# Feedback visuel du gel : contour bleu persistant (add_outline vient d'entity.gd).
	# Se nettoie tout seul à la mort de l'ennemi ; dédoublonné par couleur (non cumulatif).
	if thing_hit.has_method("add_outline"):
		thing_hit.add_outline(FROST_OUTLINE_COLOR)


# Surcharge : cooldown DÉTERMINISTE (pas de rand_range).
#
# Vanilla (weapon.gd:337-354) bruite le cooldown à CHAQUE tir — jusqu'à ±33 % avec 6
# armes — pour désynchroniser des armes identiques. Chez nous, cette gigue pulvérise le
# déphasage par slot (slot_phase_offset) en quelques cycles : le « train de bombes »
# ne tient jamais. On la retire : toutes les armes bombe partagent le même cooldown
# (75) et restent donc en phase toute la vague.
#
# La seule chose qui module encore ce cooldown est la vitesse d'attaque, qui est une
# stat du JOUEUR : elle s'applique à l'identique à toutes ses armes bombe (nos .tres
# gardent attack_speed_mod = 0), donc elle ne les désynchronise pas.
#
# On ne perd rien de la logique vanilla : `is_big_reload_active` dépend de
# `additional_cooldown_every_x_shots`, qui vaut -1 (désactivé) dans tous nos .tres ; et
# le plafond `at_wave_begin` ne s'applique qu'au-delà de 180, très loin de nos 75.
func get_next_cooldown(_at_wave_begin: bool = false) -> float:
	return float(current_stats.cooldown)


# --- Déphasage par slot ("train de bombes") ---

# Liste des armes BOMBE actuellement équipées par le joueur, dans l'ordre des slots.
# `current_weapons` (player.gd:22) contient TOUTES les armes : Bomberto peut acheter des
# lance-roquettes ou des armes de mêlée à knockback. Seules les bombes s'entrelacent.
func _bomb_weapons() -> Array:
	var out := []
	if not is_instance_valid(_parent):
		return out
	for w in _parent.current_weapons:
		if w is BombWeapon:
			out.push_back(w)
	return out


# Index de CETTE arme parmi les seules armes bombe du joueur.
# Retourne -1 si introuvable (garde-fou : slot_phase_offset renverra alors 0).
func _bomb_slot_index() -> int:
	var bombs := _bomb_weapons()
	for i in bombs.size():
		if bombs[i] == self:
			return i
	return -1


# Nombre d'armes BOMBE équipées.
func _bomb_slot_count() -> int:
	return _bomb_weapons().size()


# --- DOT du poison : brûlure de STRUCTURE, pas d'arme tenue ---

# Recalcule le burning_data de la Bombe de Poison en le traitant comme une brûlure
# de STRUCTURE (mécanique "tourelle enflammée", cf. spec : le DOT scale sur
# l'ingénierie, pas sur les dégâts).
#
# Pourquoi : init_burning_data (weapon_service.gd:329-332) choisit son multiplicateur
# final selon `is_structure` —
#     is_structure  -> apply_structure_damage_bonus (Keys.structure_percent_damage)
#     sinon         -> apply_damage_bonus           (Keys.stat_percent_damage)
# Le chemin de l'arme TENUE passe is_structure = false (weapon.gd:136 ->
# init_ranged_stats -> init_base_stats(..., is_structure = false)), donc le DOT
# se prend `stat_percent_damage` en pleine figure : chez Bomberto c'est -75 %,
# soit un DOT DIVISÉ PAR 4.
#
# Or l'INFOBULLE, elle, déduit is_structure du scaling (BurningEffect.get_args :
# "premier scaling == ingénierie => structure") et affiche donc la valeur NON
# amputée. D'où l'incohérence observée en jeu : infobulle "6x17", ticks réels à 4.
#
# On réaligne le gameplay sur l'infobulle en refaisant le calcul avec
# is_structure = true. Effets de bord : aucun sur les autres bombes (garde sur
# l'élément), et pour un AUTRE personnage le DOT cesse simplement de suivre son
# % de dégâts pour suivre son % de dégâts de structure (0 par défaut) — cohérent
# avec l'identité "tourelle enflammée", et ce n'est pas un buff.
func _fix_poison_burning_scaling() -> void:
	if BombElement.from_weapon_id(weapon_id) != BombElement.POISON:
		return
	if current_stats == null:
		return

	# Le burning_data de BASE vit dans le BurningEffect des effects[] (et NON dans
	# stats.burning_data, que WeaponStats.serialize() ne persiste pas — leçon v1.4.0).
	# C'est la même source que celle lue par l'infobulle.
	var base_burning = null
	for effect in effects:
		if effect is BurningEffect:
			base_burning = effect.burning_data
			break
	if base_burning == null:
		return

	current_stats.burning_data = WeaponService.init_burning_data(base_burning, player_index, true)
	# `from` = l'arme persistante : porte l'attribution des dégâts du DOT
	# (unit.gd:694 -> on_weapon_hit_something) ET le feu VERT (l'extension
	# burning_particles lit burning_data.from.weapon_id). Le calcul ci-dessus
	# renvoie un BurningData NEUF : sans ça, `from` serait nul.
	current_stats.burning_data.from = self


# Surcharge de init_stats (Weapon) : après l'init vanilla du cooldown de début
# de vague, ajoute un déphasage par slot pour égrener les bombes ("train").
func init_stats(at_wave_begin: bool = true) -> void:
	.init_stats(at_wave_begin)
	_fix_poison_burning_scaling()
	if at_wave_begin:
		# Égrener les bombes des différents slots : décaler le 1er cooldown
		# de chaque arme selon son index, pour former une traînée nette.
		var phase = BombTiming.slot_phase_offset(
			_bomb_slot_index(),
			_bomb_slot_count(),
			get_next_cooldown(true)
		)
		_current_cooldown += phase
