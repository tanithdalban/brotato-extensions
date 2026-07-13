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
const BombLeech = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_leech.gd")

# Échelle d'explosion de base (équiv. landmine). Ajustable au réglage.
const EXPLOSION_SCALE := 1.5

# Couleur du contour "givré" appliqué à l'ennemi gelé (feedback visuel du slow).
# Le système d'outline vit dans entity.gd (add_outline/remove_outline, shader,
# 4 couleurs max) : il porte ici tout le signal visuel de la Bombe de Glace, ce qui
# nous permet de retirer le burning givré (et donc son DOT plancher max(1,…)).
# Non cumulatif par nature : add_outline dédoublonne par couleur.
const FROST_OUTLINE_COLOR := Color("5bc8ff")

# Position du joueur au moment où CETTE arme a posé sa bombe précédente. Elle sert à
# mesurer le déplacement NET depuis lors (cf. BombPlacement.mobility_from_travel), qui
# porte à la fois la DIRECTION de la traînée et son écartement.
#
# Pourquoi un déplacement NET, mesuré d'une bombe à l'autre, plutôt qu'une vitesse suivie
# à chaque frame : un joueur qui frétille sur place (aller-retour rapide pour esquiver) a
# une vitesse élevée mais ne parcourt AUCUNE distance nette. Se fier à la vitesse
# refermerait l'éventail et empilerait les bombes au même endroit.
var _last_shot_pos := Vector2.ZERO
var _has_last_shot_pos := false

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
	# Position sur la couronne à éventail, plutôt que sous les pieds du joueur.
	#
	# Le déplacement NET depuis la bombe précédente de cette arme porte TOUT : sa
	# DIRECTION centre l'éventail à l'opposé (la traînée part derrière le joueur), et sa
	# LONGUEUR décide de l'ouverture (l'éventail se referme quand la distance parcourue
	# suffit déjà à espacer les bombes ; il reste ouvert sinon, et c'est alors l'angle qui
	# les espace).
	var nb := _bomb_slot_count()
	if nb <= 0:
		nb = 1
	var travel := Vector2.ZERO
	if _has_last_shot_pos:
		travel = _parent.global_position - _last_shot_pos
	var mobility := BombPlacement.mobility_from_travel(travel.length(), nb, BombPlacement.RADIUS)
	# `_nb_shots_taken` vient d'être incrémenté ci-dessus : c'est le numéro de la pose.
	# `offset` normalise `travel` lui-même et retombe sur un axe arbitraire s'il est nul.
	bomb.global_position = _parent.global_position + BombPlacement.offset(
		_bomb_slot_index(),
		nb,
		_nb_shots_taken,
		travel,
		mobility,
		BombPlacement.RADIUS
	)
	_last_shot_pos = _parent.global_position
	_has_last_shot_pos = true
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


# Cible du signal hit_something de l'explosion d'une bombe SANGSUE (connecté par
# bomb_entity, avec un budget FRAIS par explosion). Draine l'ennemi touché : on lui
# RETIRE N PV et on rend au joueur exactement ce que le budget vient d'accorder (N),
# vanilla clampant lui-même le retrait à ce qu'il reste de PV sur un coup fatal.
# Duck-typé : ne touche que des unités ayant current_stats + take_damage (marche
# vanilla/DLC/autre mod, sans étendre enemy.gd).
#
# POURQUOI notre propre soin, et pas RunData.manage_life_steal : le vol de vie vanilla
# est gardé par le LifestealTimer du joueur (0,1 s, player.gd:734), qui JETTE tout proc
# arrivant pendant qu'il tourne. Or une explosion touche tous ses ennemis dans la MÊME
# frame : passer par le vanilla rendrait 1 PV par explosion, quel que soit le nombre
# d'ennemis. On ne contourne ce timer que sur NOTRE chemin ; il reste intact pour toutes
# les autres armes.
func on_leech_hit(thing_hit, _damage_dealt, budget: Array) -> void:
	if BombLeech.remaining(budget) <= 0:
		return
	if not is_instance_valid(thing_hit):
		return
	if not ("current_stats" in thing_hit) or thing_hit.current_stats == null:
		return
	if not thing_hit.has_method("take_damage"):
		return
	# ENNEMIS UNIQUEMENT : Neutral (arbres, caisses, rochers) hérite lui aussi de
	# Unit et possède donc current_stats + take_damage — il passe les deux gardes
	# ci-dessus. Or l'explosion touche bien les neutres (Hitbox calque 8, hurtbox
	# Neutral masque 1032 = 8 + 1024) : sans cette garde, un joueur planté à côté
	# d'un arbre drainait le budget complet à CHAQUE bombe, à l'infini (sustain
	# gratuit). `Enemy` couvre aussi `Boss` (Boss extends Enemy).
	if not (thing_hit is Enemy):
		return
	if current_stats == null:
		return

	# current_stats.lifesteal porte DÉJÀ « base de l'arme + stat du joueur / 100 »
	# (weapon_service.gd:260, branche not is_structure). Ne rien recalculer.
	if not BombLeech.procs(randf(), current_stats.lifesteal):
		return

	var amount: int = BombLeech.take(budget, BombLeech.proc_amount(_has_double_lifesteal()))
	if amount <= 0:
		return

	# Le drain, retiré à l'ennemi : armor_applied = false -> l'armure ne le mange pas
	# (unit.gd:502) ; hitbox = null -> ni crit ni recul. Un drain sec.
	var args := TakeDamageArgs.new(player_index, null)
	args.armor_applied = false
	args.dodgeable = false
	var _dmg = thing_hit.take_damage(amount, args)

	# ... et rendu au joueur, à l'identique. on_healing_effect clampe aux PV max.
	if is_instance_valid(_parent) and _parent.has_method("on_healing_effect"):
		var _healed = _parent.on_healing_effect(amount)


# L'item « double vol de vie » fait passer les procs à 2 PV (cf. run_data.gd:1378).
func _has_double_lifesteal() -> bool:
	var effects = RunData.get_player_effects(player_index)
	if not effects.has(Keys.stat_double_lifesteal_bonus_hash):
		return false
	return RunData.get_player_effect_bool(Keys.stat_double_lifesteal_bonus_hash, player_index)


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

# Préfixe partagé par les 4 armes bombe (normale, glace, poison, foudre).
# Même convention que content/logic/shop_pool.gd.
const _BOMB_ID_PREFIX := "weapon_bomb"


# Index de CETTE arme parmi les seules armes BOMBE du joueur (0 = la première).
# Nombre d'armes BOMBE équipées par le joueur.
#
# ⚠️ On lit les DONNÉES de run, PAS les nœuds d'armes (_parent.current_weapons).
# player.gd:387-389 fait add_child(instance) PUIS current_weapons.push_back(instance),
# et add_child déclenche _ready() -> init_stats() SYNCHRONEMENT : au moment où l'on
# calcule le déphasage, l'arme n'est pas encore dans current_weapons. Scanner les
# nœuds renvoyait donc "introuvable" et le déphasage valait 0 pour TOUTES les bombes,
# qui tiraient alors exactement la même frame, au même pixel.
# RunData, lui, est complet avant le spawn ; et weapon_pos est posé (player.gd:374)
# avant add_child, donc il est fiable ici.
func _bomb_slot_index() -> int:
	var weapons = RunData.get_player_weapons_ref(player_index)
	var i := 0
	var limit: int = int(min(weapon_pos, weapons.size()))
	for pos in range(limit):
		if weapons[pos].weapon_id.begins_with(_BOMB_ID_PREFIX):
			i += 1
	return i


func _bomb_slot_count() -> int:
	var n := 0
	for w in RunData.get_player_weapons_ref(player_index):
		if w.weapon_id.begins_with(_BOMB_ID_PREFIX):
			n += 1
	return n


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


# Surcharge de init_stats (Weapon) : déphase le premier cooldown pour égrener les bombes
# ("train") — une bombe toutes les cooldown/N frames.
#
# On POSE une valeur ABSOLUE (cooldown - phase) : l'opération est donc IDEMPOTENTE. Une
# application cumulative (`-= phase`) ferait dériver les phases à chaque recalcul de stat
# en cours de vague — init_stats(false) est rappelée à chaque montée de niveau, objet ou
# stat temporaire — jusqu'à resynchroniser toutes les bombes, voire les faire tirer en
# rafale une fois la soustraction devenue plus grande que le cooldown restant.
#
# On SOUSTRAIT la phase au lieu de l'ajouter : la valeur reste ainsi <= cooldown, sinon
# reset_cooldown() (weapon.gd:332-334) la raboterait par son min(_current_cooldown,
# cooldown). C'est ce clamp qui écrasait l'ancien déphasage additif — lequel n'a donc
# JAMAIS fonctionné depuis l'origine du mod.
#
# Quand l'applique-t-on ? Au début de vague (vanilla n'y repose le cooldown que dans ce
# cas, weapon.gd:161-162), et aussi lorsque reset_cooldown() vient de RABOTER notre
# valeur : un cooldown qui diminue en cours de vague (vitesse d'attaque) aplatit toutes
# les bombes sur la même valeur, il faut alors les re-déphaser.
func init_stats(at_wave_begin: bool = true) -> void:
	var before := _current_cooldown
	.init_stats(at_wave_begin)
	_fix_poison_burning_scaling()
	if at_wave_begin or _current_cooldown < before:
		var cd := get_next_cooldown(at_wave_begin)
		var phase = BombTiming.slot_phase_offset(
			_bomb_slot_index(),
			_bomb_slot_count(),
			cd
		)
		_current_cooldown = max(1.0, cd - phase)
