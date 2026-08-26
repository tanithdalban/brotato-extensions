extends Reference
# Réconciliation des bombes élémentaires avec la malédiction du DLC Abyssal Terrors.
# Logique PURE (aucun autoload) -> testable en headless.
#
# --- Le problème ---
#
# `dlcs/dlc_1/dlc_1_data.gd:curse_item()` transforme n'importe quelle WeaponData :
#   - sur `stats` : damage, scaling_stats, crit_damage, lifesteal, piercing, bounce ;
#   - sur chaque `effects[]` : la `value` est multipliée par (1 + m).
# Le modificateur m = 0.40 + 0.02 x (vague - 1, plafonné à 20) + rand(-0.30, +0.30),
# et il est retiré SÉPARÉMENT pour les stats et pour chaque effet. `curse_factor`
# retient le plus grand des tirages.
#
# Or nos paramètres d'élément ne vivent PAS là où le DLC regarde :
#   - Glace  : `stats.speed_percent_modifier` (le slow)         -> jamais boosté
#   - Frag   : `stats.nb_projectiles` (les fragments)           -> jamais boosté
#   - Foudre : `stats.nb_projectiles` (les éclairs)             -> jamais boosté
#   - Drain  : le plafond de PV est codé par TIER (BombLeech)   -> hors des données
# tandis que nos lignes d'infobulle sont des NullEffect, que le DLC boost, lui, sans
# faute. D'où deux symptômes en jeu :
#   1. l'infobulle ment (elle annonce 42 % de ralentissement pour un slow resté à 30) ;
#   2. la Bombe de Glace maudite est un MALUS PUR — son `damage` vaut 0 et ses
#      `scaling_stats` sont vides, donc _boost_weapon_stats_damage n'a littéralement
#      rien à booster : elle encaisse le +stat_curse sans la moindre contrepartie.
#
# --- Le principe ---
#
# On ne corrige jamais « en repartant de la valeur maudite » (impossible : le tirage
# aléatoire n'est pas inversible). On RECALCULE tout depuis le .tres pristine
# (`ItemService.get_element`, que curse_item ne mute jamais puisqu'il duplique) plus
# `curse_factor`. Deux conséquences précieuses :
#   - `normalize` est IDEMPOTENT, ce qui autorise à le brancher sur plusieurs points
#     d'accroche sans se soucier de l'ordre ni des doublons ;
#   - une arme NON maudite (curse_factor 0) retombe exactement sur ses valeurs de
#     base, ce qui règle au passage la perte du slow à la reprise de run (cf. plus bas).
#
# Les écritures sont conditionnelles (« seulement si différent ») : au tirage
# boutique d'une arme non maudite, `stats` est encore la ressource pristine PARTAGÉE,
# et il ne faut sous aucun prétexte écrire dedans.

const BombElement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd")

# Toutes nos armes partagent ce préfixe. La garde porte sur LUI et non sur l'élément,
# parce que BombElement.from_weapon_id replie sur NORMAL pour tout id inconnu : une
# arme vanilla passerait donc pour une bombe normale.
const _BOMB_ID_PREFIX := "weapon_bomb"


# Nombre de projectiles maudit. Reprend LITTÉRALEMENT l'idiome que le DLC applique
# déjà à `piercing`/`bounce` : min(base + 1, ceil(base x (1 + m/5))), soit +1 au
# maximum.
#
# Ce plafond n'est pas de la timidité : chaque fragment (et chaque éclair) porte le
# `damage` ENTIER de l'arme — c'est la convention vanilla des armes multi-projectiles.
# Booster le NOMBRE multiplie donc les dégâts une SECONDE fois, par-dessus le boost
# de `damage` que le DLC vient déjà d'appliquer. Un x(1+m) naïf donnerait x2.9 au
# palier haut, hors de l'échelle de tout ce que fait le DLC en vanilla.
static func boosted_count(base: int, m: float) -> int:
	return int(min(base + 1, ceil(base * (1.0 + m / 5.0))))


# Plafond du ralentissement. BombIceSlow.apply vise une VITESSE CIBLE :
#   cible = max_speed x (1 - slow/100),  puis  speed = min(speed, cible)
# À 100 la cible vaut 0 (ennemi figé) et au-delà elle passe SOUS ZÉRO. La
# non-cumulativité du modèle ne protège de rien ici : c'est la magnitude d'un
# seul coup qui sort de l'échelle. Constaté en jeu sur la glace tier 4 maudite,
# qui immobilisait complètement la vague.
const MAX_SLOW_PCT := 95


# Ralentissement maudit : magnitude x(1 + m), bornée par MAX_SLOW_PCT.
# La glace tier 4 part de 75 : sans borne, elle dépasse 100 dès m > 0.34, or m
# vaut au moins 0.40 passé les premières vagues. Contrairement au nombre de
# projectiles, le slow n'est pas quadratique (il ne multiplie aucun dégât) — le
# seul risque est ce plafond d'immobilisation, d'où une simple borne plutôt que
# l'idiome « +1 » du DLC.
# `base_magnitude` est POSITIF ; le .tres, lui, porte le slow en négatif.
static func boosted_slow(base_magnitude: int, m: float) -> int:
	var boosted: int = int(round(base_magnitude * (1.0 + m)))
	# Le plafond ne doit jamais RABAISSER la valeur de base : `normalize` sert
	# aussi de restauration à la reprise de run (m = 0), où il doit rendre le
	# .tres à l'identique — y compris si un tier futur dépassait le plafond.
	return int(max(base_magnitude, min(MAX_SLOW_PCT, boosted)))


# Ce que la ligne d'infobulle (un NullEffect, purement décoratif) doit afficher pour
# rester synchrone avec le comportement réel.
#
# Le drain est le cas à part : sa valeur affichée est un PLAFOND de PV volés, codé en
# dur par tier dans BombLeech.CAP_BY_TIER, donc totalement insensible à la
# malédiction. On la restaure telle quelle. Son vrai bonus de malédiction est
# ailleurs, sur `stats.lifesteal` (la chance de proc), que le DLC boost déjà
# correctement et auquel on ne touche pas.
static func tooltip_value(element: String, base_value: int, m: float) -> int:
	if element == BombElement.ICE:
		return boosted_slow(base_value, m)
	if element == BombElement.FRAG or element == BombElement.STORM:
		return boosted_count(base_value, m)
	return base_value


# Réaligne `weapon_data` (une bombe possiblement maudite) sur son `pristine`.
# No-op silencieux sur tout le reste : objets sans `weapon_id`, armes vanilla,
# bombes normale et poison (leur BurningEffect est déjà correctement traité par le
# DLC), pristine introuvable.
#
# ⚠️ `normalize` sert AUSSI de restauration à la reprise de run. `speed_percent_modifier`
# n'est pas dans WeaponStats.serialize(), et deserialize_and_merge repart d'un
# RangedWeaponStats.new() (défaut 0) : sans ce passage, TOUTE Bombe de Glace perd son
# slow au rechargement d'une run — maudite ou non. C'est un bug antérieur au DLC.
static func normalize(weapon_data, pristine) -> void:
	if weapon_data == null or pristine == null:
		return
	if not ("weapon_id" in weapon_data) or not weapon_data.weapon_id.begins_with(_BOMB_ID_PREFIX):
		return
	if weapon_data.stats == null or pristine.stats == null:
		return

	var element: String = BombElement.from_weapon_id(weapon_data.weapon_id)
	if element != BombElement.ICE and element != BombElement.FRAG \
			and element != BombElement.STORM and element != BombElement.LEECH:
		return

	var m: float = weapon_data.curse_factor

	if element == BombElement.ICE:
		var slow: int = - boosted_slow(int(abs(pristine.stats.speed_percent_modifier)), m)
		if weapon_data.stats.speed_percent_modifier != slow:
			weapon_data.stats.speed_percent_modifier = slow
	elif element == BombElement.FRAG or element == BombElement.STORM:
		var count: int = boosted_count(pristine.stats.nb_projectiles, m)
		if weapon_data.stats.nb_projectiles != count:
			weapon_data.stats.nb_projectiles = count

	if weapon_data.effects.size() > 0 and pristine.effects.size() > 0:
		var wanted: int = tooltip_value(element, pristine.effects[0].value, m)
		if weapon_data.effects[0].value != wanted:
			weapon_data.effects[0].value = wanted
