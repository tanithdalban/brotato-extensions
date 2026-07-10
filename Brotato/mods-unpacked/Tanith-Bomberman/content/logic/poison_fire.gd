extends Reference
# Feu vert du DOT de la Bombe de Poison — logique PURE (testable headless).
#
# Le poison est une brûlure (BurningData) scalée sur l'ingénierie ; or les
# particules vanilla colorent l'ingénierie en BLEU (burning_particles.gd:_update_color,
# = couleur Tourelle enflammée). Pour distinguer notre poison, l'extension de
# burning_particles lit burning_data.from.weapon_id : si c'est une bombe de poison,
# elle applique ces dégradés VERTS au lieu du bleu. Sinon, comportement vanilla
# inchangé (la Tourelle reste bleue).

const _POISON_PREFIX := "weapon_bomb_poison"

# Vrai ssi la brûlure vient d'une bombe de poison (weapon_id partagé des 4 tiers).
static func is_poison_source(weapon_id: String) -> bool:
	return weapon_id.begins_with(_POISON_PREFIX)

# Dégradé principal : vert toxique vif -> vert moyen -> fondu transparent.
static func green_gradient() -> Gradient:
	var g := Gradient.new()
	g.offsets = PoolRealArray([0.0, 0.5, 1.0])
	g.colors = PoolColorArray([
		Color(0.62, 1.0, 0.30, 1.0),
		Color(0.30, 0.80, 0.12, 0.85),
		Color(0.08, 0.35, 0.02, 0.0),
	])
	return g

# Dégradé secondaire (particules fines) : vert clair -> fondu.
static func green_gradient_secondary() -> Gradient:
	var g := Gradient.new()
	g.offsets = PoolRealArray([0.0, 1.0])
	g.colors = PoolColorArray([
		Color(0.80, 1.0, 0.55, 0.9),
		Color(0.20, 0.50, 0.08, 0.0),
	])
	return g
