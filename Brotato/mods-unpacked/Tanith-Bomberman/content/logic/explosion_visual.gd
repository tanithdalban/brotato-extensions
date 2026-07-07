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
