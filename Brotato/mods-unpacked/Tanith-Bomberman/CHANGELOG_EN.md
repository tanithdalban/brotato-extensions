# Bomberman — Changelog

A Brotato character mod: "Bomberto", a bomb-throwing character whose shop also
offers explosive and high-knockback melee weapons, paired with a Bomb weapon
that drops bombs on a cooldown (no targeting) and leans on explosion and
elemental/engineering scaling.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.6.0] — 2026-07-07

### Changed
- New Bomb skin: classic black bomb everywhere (icon, held weapon, placed bomb). Tier reads via the in-game rarity outline and a colored background on the shop icon.

## [1.5.1] — 2026-07-02

### Fixed
- **Rebalanced the Bomb weapon's price** (design error). Its base `value` was far
  too high: 40 at tier I, twice the priciest vanilla starting weapon (20) and
  already in tier-II price territory. All 4 tiers are brought back onto the canonical
  curve of a top-end base weapon (spear, SMG, wrench): **20 / 39 / 74 / 149**
  (instead of 40 / 56 / 78 / 106). In the shop, the tier-I Bomb now costs ~23 gold
  (like the SMG) instead of ~45. Recycling value scales down accordingly.
- **Bomberto's character-selection portrait** now tints its background based on the
  **highest danger beaten** (and gains a frame at danger 6), like vanilla characters.
  The character had no difficulty-tracking entry (`difficulties_unlocked`) because of
  the singleton load order, so the beaten danger was never recorded and the portrait
  kept its default background. Fixed by re-running the game's native unlock pass after
  the character is injected.

## [1.5.0] — 2026-07-01

### Added
- **Animated Bomberto icon** on the character-selection screen: his bomb's fuse
  burns down to an explosion (flash + orange/yellow burst, small character squash
  reaction), then the icon returns to the starting image, on a loop.

## [1.4.1] — 2026-06-30

### Fixed
- Bomb weapon: removed the "Signal already connected" log spam (on
  `killed_something`, `added_gold_on_crit`, `critically_hit_something`). The
  vanilla weapon `_ready()` reconnects the hitbox signals without an
  `is_connected` guard; when it runs again on the same bomb, Godot refused the
  duplicate connections (no effect) but flooded the log. The Bomb now clears those
  connections before the reconnect. Purely cosmetic: no gameplay impact.

## [1.4.0] — 2026-06-28

### Added
- Bomb weapon: **attack speed now shortens the fuse** (same formula as the vanilla
  cooldown, 0.5 s floor). The faster you attack, the sooner bombs go off; negative
  attack speed lengthens the fuse instead. Applies to both the normal bomb and the
  troll bomb.

### Fixed
- Bomb weapon: the **burn** now actually works in game. It was stored on
  `stats.burning_data`, a field that run serialization does not persist (the burn
  dropped to 0 on the first shop/wave round-trip). It now goes through a
  `BurningEffect` in `WeaponData.effects` (the vanilla Torch scheme), re-applied on
  every stat computation and persisted. Per-tier burn progression unchanged
  (3 dmg/3 s → 12 dmg/9 s, elemental scaling).

## [1.3.0] — 2026-06-27

### Changed
- Character renamed **Bombertoe → Bomberto**.
- Wider shop: in addition to Bombs, it now offers **explosive**-set weapons and
  **high-knockback (≥ 20) melee** weapons (Hammer, Hand, Spiky Shield, Torch, Wrench…).
- Starting weapons: you **always start with a Bomb** (forced), **plus** one weapon
  chosen from the accessible roster that has a tier-0 (Bomb, Shredder, Plank, Hand,
  Spiky Shield, Torch, Wrench). Picking the Bomb = starting with two bombs.
- Reworked buffs: **-75% damage**, **+5% explosion size per Elemental point**,
  **+5% explosion damage per Engineering point** (global effects, also apply to
  purchased explosive weapons).
- Bomb weapon: scaling **100% Engineering + 150% Elemental** (instead of 50/50).
- Bomb weapon: the explosion now **ignites** enemies (same burn as the **Torch**,
  per-tier progression: 3 dmg/3 s → 12 dmg/9 s, elemental scaling).
- Placed bomb **1.25× bigger** (visual only); the troll bomb too.

### Fixed
- The Bomb now actually benefits from the **explosion damage** bonus (the
  Engineering buff reaches it).
- **Coop**: a troll bomb can no longer **kill a teammate** — contact damage is
  capped at the minimum HP of **all** living players.

## [1.2.0] — 2026-06-27

### Added
- "Troll bomb": a placed bomb can randomly (~10%) wake up partway through its fuse,
  turn into an unstoppable roving hazard, and chase the nearest living player to
  explode in their face (hits players/allies, never enemies).
  - Wake telegraph: an alert sound plays and the troll bomb stays still briefly
    before the chase begins, and it never spawns right on top of a player.
  - Body color matches the origin bomb's tier, with an angry-face overlay.
  - Non-lethal: contact and end-of-timer AoE damage are capped so they always leave
    the player at 1 HP or more.

## [1.1.0] — 2026-06-26

### Added
- "Bombertoe" v1.1.0: potato-style character appearance, in-game icon, and packaging
  tools.
- Elemental + Engineering classes on the Bomb, with the matching scaling.
- Tier-colored bombs.

### Changed
- The shop now offers the Bomb only (the weapon pool is filtered).
- Merged the three separate appearances into a single `bomberman_appearance.tres`;
  updated the icon and bomb sprites.
- Placed bomb now uses the vanilla dynamite sprite instead of a mine.

### Fixed
- Bombs can be re-fired again (resets `_is_shooting` after dropping one).
- Stopped bombs from spawning outside of waves (upgrade phase).

## [1.0.0] — 2026-06-24

### Added
- First playable release (placeholder art): bomb-only character with explosion bonus
  and weapon bans, Bomb weapon across 4 tiers, placed-bomb entity (fuse then vanilla
  explosion), per-slot cooldown phasing for a staggered bomb train.
- FR/EN translations (in code).

### Fixed
- Explicitly unlocks weapon + character (autoload ordering).
- Non-zero `projectile_speed` on Bomb stats (avoids a division by zero).

## [0.1.0] — 2026-06-23

### Added
- Mod scaffold: loads in game, test runner, pure per-tier fuse and slot-phasing logic
  (TDD).
