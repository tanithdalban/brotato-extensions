extends "res://entities/units/unit/unit.gd"
# Gel de la Bombe de Glace qui SURVIT aux recalculs de vitesse du jeu.
#
# POURQUOI : le gel est écrit dans current_stats.speed (cf. bomb_ice_slow.gd).
# Or le jeu recalcule cette vitesse depuis la base dans reset_speed_stat(), appelé
# à chaque début ET fin de brûlure (set_burning, unit.gd:884), aux changements de
# phase de certaines élites/boss et aux boosts d'ennemis. La Bombe normale et la
# Bombe de Poison enflamment : avec elles, l'ennemi gelé (contour bleu toujours
# affiché) reprenait toute sa vitesse au premier contact du feu.
#
# On mémorise donc le gel le plus fort reçu et on le réapplique derrière chaque
# reset_speed_stat(). Effacé à respawn() : les ennemis sont recyclés, et
# enemy.respawn() appelle .respawn() AVANT init_current_stats() (enemy.gd:99-109).
#
# Limite connue : les classes qui surchargent reset_speed_stat() SANS appeler le
# parent (pet.gd, evil_mob.gd de la zone Crash) ne passent pas par ici. Les
# familiers ne sont jamais touchés par nos explosions ; le mob maléfique perdra
# son gel s'il brûle, comme avant ce correctif.
#
# Symboles préfixés « bomberman » : unit.gd peut être étendu par d'autres mods.

const BombermanIceSlow = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_ice_slow.gd")

# Gel le plus fort reçu (en %), 0 = aucun.
var bomberman_ice_slow_pct := 0.0


# Appelé par BombWeapon.on_ice_hit : mémorise puis applique le gel.
func bomberman_apply_ice_slow(slow_pct: float) -> void:
	bomberman_ice_slow_pct = BombermanIceSlow.remember(bomberman_ice_slow_pct, slow_pct)
	_bomberman_reapply_ice_slow()


func reset_speed_stat(percent_modifier: int = 0) -> void:
	.reset_speed_stat(percent_modifier)
	_bomberman_reapply_ice_slow()


func respawn() -> void:
	bomberman_ice_slow_pct = 0.0
	.respawn()


func _bomberman_reapply_ice_slow() -> void:
	if bomberman_ice_slow_pct <= 0.0:
		return
	if current_stats == null or max_stats == null:
		return
	current_stats.speed = BombermanIceSlow.apply(
		current_stats.speed, max_stats.speed, bomberman_ice_slow_pct
	)
