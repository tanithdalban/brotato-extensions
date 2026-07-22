# Bomberman — Changelog

A Brotato character mod: "Bomberto", a bomb-throwing character whose shop also
offers explosive and high-knockback melee weapons, paired with a Bomb weapon
that drops bombs on a cooldown (no targeting) and leans on explosion and
elemental/engineering scaling.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [3.0.1] — 2026-07-22

### Fixed
- **Resuming a run after closing the game no longer loses Bomberto and his bombs.** Leaving a run in progress and restarting the game brought the run back with a character holding **no weapon** — and the save was immediately rewritten in that stripped state, making the loss permanent. The mod's content is now registered **before** the game reads the run in progress back. Mod items and weapons sitting in the pending shop are preserved too.

  > **Technical note — this flaw isn't ours alone.** It comes from Brotato's
  > autoload order: the in-progress run is read back by `ProgressData` **before**
  > `ItemService` has received any mod content, and every id the game doesn't
  > recognise is dropped **silently**.
  > The authors of [Brotato-ContentLoader](https://github.com/BrotatoMods/Brotato-ContentLoader)
  > — the framework most content mods are built on — had identified the very same
  > cause and fixed it in **6.2.2** (“*so ItemService is populated with all modded
  > data before ProgressData deserializes the save data*”), only to **revert** that
  > fix in **6.2.3** because hooking in that early broke Danger progress for modded
  > characters. Their registration therefore moved back into `ItemService._ready()`,
  > i.e. *after* the run is read back: **Brotato content mods are, to this day,
  > still exposed to it.** Our fix hooks later than theirs — inside
  > `ProgressData.load_game_file()` itself, right before deserialization — which
  > avoids their regression.

## [3.0.0] — 2026-07-17

Two new bombs, a rework of how the elemental bombs are **unlocked** — they must now
be **earned** — and a **cap** on explosion size.

### Added
- **Leech Bomb** — a 5th bomb that deals no explosion damage but **drains enemies** in its blast: it removes HP from them and returns it to you. The healing is capped and shared, per second, across all your Leech Bombs (stacking them makes the healing steady, not bigger). It unlocks by holding the **four original bombs** (Bomb, Ice, Storm, Poison) at the same time.
- **Frag Bomb** — a 6th, cluster bomb: the shell bursts without damage and scatters **4 to 7 fragments** at random, each detonating for real. Devastating on a dense swarm, more of a gamble on a lone target. It unlocks by taking a **Leech Bomb to tier IV**.
- **Bomb challenge chain** — the Ice, Storm and Poison bombs are no longer handed out for free. Take a bomb to **tier IV** to unlock the next one: Bomb → Ice → Storm → Poison, then Leech IV → Frag. If you already owned these bombs, you're offered a **choice** on the selection screen (solo only): play through the progression, or keep them.

### Changed
- **Explosion size is now capped.** Elemental scaling — and items such as the Jar of Honey — could grow explosions until they covered the whole map. They now cap at roughly **a quarter of the map**, no matter the investment; fragments stay proportionally small. The rest of your elemental keeps boosting poison, lightning, and so on.
- **The troll bomb** now chases for **3 seconds** (down from 5) before exploding, and its explosion is capped like the others.

## [2.0.0] — 2026-07-11

A complete rework of **how bombs are dropped**. Until now they all landed under the
player's feet, on the very same pixel, at an erratic pace. They now lay down a
**readable trail** behind Bomberto.

### Changed
- **Bombs no longer drop at your feet.** Each bomb is now placed on a **ring** around the player, at a fixed distance. How wide that ring opens adapts to the way you play: **while running it closes up behind you**, and the bombs form a trail along your escape route; **while standing still it opens into a full circle**, and the bombs surround you. In between, the transition is continuous — no abrupt switch. The mod looks at the distance **actually travelled** between two drops: if running is enough to space the bombs out, it lets running do the work; if it isn't (slow character, or six bombs landing back to back), it spaces them out by angle instead.
- **Steady, predictable drop rate.** Every bomb weapon now shares the same period, and the mod strips out the **random jitter** the game normally adds to each shot (±33% with six weapons). With N bombs equipped, one lands at a constant interval, indefinitely.
- ⚠️ **A deliberate trade-off: tiers no longer speed up the drop rate.** The rhythm is the same from tier I to tier IV. Progression now runs entirely through everything else: damage, shorter fuse, stronger poison, more bolts, harsher slow.

### Fixed
- **The offset between two equipped bombs did not work** — and in fact had **never** worked since the mod was created. Two bombs in hand could therefore drop at the same time, in the same spot. They now take proper turns.

## [1.9.0] — 2026-07-11

### Added
- **New weapon: the Poison Bomb** (4 tiers), offered in Bomberto's shop and selectable as a starting weapon. It deals **no explosion damage** but **poisons the enemies it hits**: damage over time that **ignores armor** and scales with **engineering**, much like a burning turret. Its flames are **green**, and its tooltip reads "poison damage" rather than a generic burn.

### Fixed
- **Poison damage is no longer cut to a quarter.** Bomberto's damage penalty (-75%) was being applied to the poison when it shouldn't have been: the tooltip showed the correct value (17 per tick, say) but enemies only took a quarter of it (4). The poison now actually deals what it advertises.

### Changed
- **Storm Bomb bolts now knock enemies back.** Since the bolts fly outward in a full circle, enemies caught in the burst are blown away from the blast: the Storm Bomb becomes a genuine **crowd control** weapon, where the Ice Bomb slows. The scattering grows with tier, as the number of bolts increases (6 to 10).
- **Ice Bomb slow increased**: 30 / 45 / 60 / **75%** by tier (up from 30 / 40 / 50 / 60%).
- **Bomb rebalance.** The regular Bomb remains Bomberto's main damage source, but its scaling is down to 90% (engineering and elemental); the Storm Bomb is up to 100%; the Poison Bomb's poison is stronger. The four bombs keep distinct roles: the regular one hits hard, ice slows, storm scatters, poison eats through armor.

## [1.8.0] — 2026-07-09

### Added
- **New weapon: the Storm Bomb** (4 tiers), offered in Bomberto's shop and selectable as a starting weapon. On detonation it releases a **burst of lightning bolts in a full circle** (like the Tyler item) that carry the damage — **with no area explosion**. The number of bolts and the damage increase with tier, with engineering and elemental scaling.

### Fixed
- **Bomb damage is now tracked** in the weapon tooltip ("damage dealt" for the last wave), like other weapons. Previously, because bombs hit away from the weapon (explosion / bolts), their damage wasn't attributed and the counter stayed at 0.

## [1.7.0] — 2026-07-09

### Added
- **New weapon: the Ice Bomb** (4 tiers), offered in Bomberto's shop and selectable as a starting weapon. It deals **no explosion damage** but **permanently slows the enemies it hits** — the slow does not stack (the strongest one is kept) — and marks them with a **blue frost outline**. Its tooltip shows the slow percentage, increasing with tier (30 / 40 / 50 / 60%).

## [1.6.0] — 2026-07-07

### Changed
- New Bomb skin: classic black bomb everywhere (icon, held weapon, placed bomb). Tier reads via the in-game rarity outline and a colored background on the shop icon.
- Troll bomb enlarged (≈ a basic enemy's size) so it reads more clearly as a threat.
- Bomb explosions are less flashy: the area-of-effect opacity is reduced (~20%) to limit repeated flashes (visual comfort / epilepsy). Does not affect the hit area or damage.

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
