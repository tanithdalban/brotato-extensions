extends "res://particles/burning/burning_particles.gd"
# Feu VERT pour le DOT de la Bombe de Poison.
#
# Le poison est une brûlure scalée ingénierie ; _update_color() vanilla la
# colorerait en BLEU (couleur Tourelle enflammée). On surcharge _update_color :
# si la brûlure vient d'une bombe de poison (burning_data.from.weapon_id), on
# applique des dégradés VERTS ; sinon on délègue au vanilla (la Tourelle reste
# bleue, l'élémentaire reste rouge). AUCUNE régression sur les autres brûlures.
#
# burning_data.from est peuplé par weapon.gd:151 (current_stats.burning_data.from
# = self, la BombWeapon persistante) et propagé jusqu'aux particules par
# unit.apply_burning (burning_data.duplicate() préserve from). Si from est absent
# (cas non prévu), _is_poison renvoie false -> repli bleu automatique.

const PoisonFire = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/poison_fire.gd")

# Dégradés verts construits une seule fois (réutilisés à chaque start_emitting).
var _green: Gradient = null
var _green_secondary: Gradient = null

func _update_color() -> void:
	if burning_data != null and _is_poison(burning_data):
		if _green == null:
			_green = PoisonFire.green_gradient()
			_green_secondary = PoisonFire.green_gradient_secondary()
		color_ramp = _green
		if secondary_particles != null:
			secondary_particles.color_ramp = _green_secondary
		return
	._update_color()

# Vrai si la brûlure provient d'une bombe de poison (duck-typé sur from.weapon_id).
func _is_poison(bd) -> bool:
	var from = bd.from
	if not is_instance_valid(from):
		return false
	if not ("weapon_id" in from):
		return false
	return PoisonFire.is_poison_source(from.weapon_id)
