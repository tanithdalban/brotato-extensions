extends Reference
# Réglage visuel de l'AOE de NOS explosions (anti-épilepsie). Le Bomberto pose
# BEAUCOUP de bombes : les flashs d'explosion à répétition sont un risque
# d'épilepsie. On réduit donc l'opacité du sprite d'explosion de NOS bombes
# (bombe posée + troll bombe), sans jamais toucher les explosions vanilla.
#
# N'affecte QUE le visuel : ni la zone d'effet, ni les dégâts, ni les effets.
# Phase 2 rendra ce plafond configurable (config du mod `explosion_opacity`) ;
# pour l'instant il est fixé à 20 %.

const AOE_OPACITY_CAP := 0.2  # 20 % d'opacité max pour l'AOE de nos bombes

# Plafonne l'opacité du sprite d'AOE de l'explosion fournie à AOE_OPACITY_CAP.
# `min` : ne remonte jamais l'opacité au-dessus d'un réglage joueur déjà plus bas
# (le jeu a posé `modulate.a = ProgressData.settings.explosion_opacity` au spawn).
# No-op sûr si l'instance ou son sprite est absent (dégradation propre).
static func cap_aoe_opacity(explosion: Node) -> void:
	if explosion == null:
		return
	var sprite = explosion.get_node_or_null("Sprite")
	if sprite == null:
		return
	sprite.modulate.a = min(sprite.modulate.a, AOE_OPACITY_CAP)


# --- Plafond de TAILLE de nos explosions (borne l'inflation par explosion_size) ---
#
# La stat joueur `explosion_size` gonfle le rayon dans player_explosion.set_area :
#   scale = base * (1 + explosion_size/100).
# Chez Bomberto elle monte SANS borne (+5 par point d'élémentaire, + le Pot de miel,
# + tout objet à explosion_size) et l'explosion finit par couvrir toute la map. On
# plafonne le FACTEUR de grossissement, PAS la taille absolue : la borne s'exprime
# `base * MAX_EXPLOSION_GROWTH`, donc elle reste PROPORTIONNELLE à la taille de base de
# chaque bombe. La normale (base 1.5) plafonne à 512 px ; un fragment (base 0.35) à
# ~119 px — les fragments ne deviennent jamais un tapis de gros cercles couvrant la map.
#
# 2.32 = 512 px (25 % de la map de départ classique, 2048 de large) / 221 px (rayon de
# la bombe normale NON buffée, échelle 1.5). Seule valeur d'équilibrage : la monter
# agrandit le plafond, la descendre le resserre.
const MAX_EXPLOSION_GROWTH := 2.32


# Échelle d'explosion plafonnée : chaque composante clampée à base_scale * MAX_EXPLOSION_GROWTH.
# `base_scale` = l'échelle de BASE de la bombe (avant l'inflation par explosion_size),
# soit le _explosion_scale que bomb_entity a passé à l'effet. Pur, testable en headless.
static func cap_growth_scale(current_scale: Vector2, base_scale: float) -> Vector2:
	var cap := base_scale * MAX_EXPLOSION_GROWTH
	return Vector2(min(current_scale.x, cap), min(current_scale.y, cap))
