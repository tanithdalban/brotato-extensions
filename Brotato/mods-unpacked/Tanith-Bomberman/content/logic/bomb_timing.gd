extends Reference
# Logique PURE de la Bombe (aucune dépendance jeu) — testable en headless.
# Tiers : 0..3 correspondent à I..IV.

const _FUSE_T1 := 2.0  # mèche tier I (s)
const _FUSE_T4 := 1.0  # mèche tier IV (s)
const _MAX_TIER := 3
const _MIN_FUSE := 0.5  # plancher de mèche (s) — évite des explosions quasi instantanées

# Durée de mèche par tier, interpolée linéairement de T1 (2.0s) à T4 (1.0s).
static func fuse_seconds(tier: int) -> float:
	var t := tier
	if t < 0:
		t = 0
	if t > _MAX_TIER:
		t = _MAX_TIER
	var ratio := float(t) / float(_MAX_TIER)  # 0.0 en T1, 1.0 en T4
	return _FUSE_T1 + (_FUSE_T4 - _FUSE_T1) * ratio

# Mèche ajustée par la vitesse d'attaque, MÊME formule que le cooldown vanilla
# (weapon_service.apply_attack_speed_mod_to_cooldown) : vitesse positive raccourcit
# (fuse / (1 + v)), vitesse négative rallonge (fuse * (1 + |v|)).
# `attack_speed_mod` est une fraction (ex. +50% = 0.5). Borné en bas à _MIN_FUSE.
static func fuse_seconds_scaled(tier: int, attack_speed_mod: float) -> float:
	var base := fuse_seconds(tier)
	var scaled: float
	if attack_speed_mod < 0.0:
		scaled = base * (1.0 + abs(attack_speed_mod))
	else:
		scaled = base / (1.0 + attack_speed_mod)
	return max(_MIN_FUSE, scaled)

# Décalage initial de cooldown pour égrener les bombes en file ("train").
# Répartit régulièrement les slots sur [0, cooldown). slot 0 -> 0.
static func slot_phase_offset(slot_index: int, nb_slots: int, cooldown: float) -> float:
	if nb_slots <= 1 or cooldown <= 0.0 or slot_index <= 0:
		return 0.0
	var i := slot_index % nb_slots
	return cooldown * (float(i) / float(nb_slots))
