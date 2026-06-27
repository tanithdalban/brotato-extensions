# Bomberman — Changelog

A Brotato character mod: "Bombertoe", a bomb-only character paired with a Bomb
weapon that drops bombs on a cooldown (no targeting) and leans on explosion and
elemental/engineering scaling.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] — 2026-06-26

### Added
- "Bombertoe" v1.1.0: potato-style character appearance, in-game icon, and
  packaging tools.
- Elemental + Engineering classes on the Bomb, with the matching scaling.
- Tier-colored bombs.

### Changed
- The shop now offers the Bomb only (the weapon pool is filtered).
- Merged the three separate appearances into a single
  `bomberman_appearance.tres`; updated the icon and bomb sprites.
- Placed bomb now uses the vanilla dynamite sprite instead of a mine.

### Fixed
- Bombs can be re-fired again (resets `_is_shooting` after dropping one).
- Stopped bombs from spawning outside of waves (upgrade phase).

## [1.0.0] — 2026-06-24

### Added
- First playable release (placeholder art): bomb-only character with explosion
  bonus and weapon bans, Bomb weapon across 4 tiers, placed-bomb entity (fuse
  then vanilla explosion), per-slot cooldown phasing for a staggered bomb train.
- FR/EN translations (in code).

### Fixed
- Explicitly unlocks weapon + character (autoload ordering).
- Non-zero `projectile_speed` on Bomb stats (avoids a division by zero).

## [0.1.0] — 2026-06-23

### Added
- Mod scaffold: loads in game, test runner, pure per-tier fuse and slot-phasing
  logic (TDD).
