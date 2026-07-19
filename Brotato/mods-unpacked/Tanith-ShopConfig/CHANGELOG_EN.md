# ShopConfig — Changelog

A per-player shop pool configuration screen for Brotato, inserted between
character selection and weapon selection. Players exclude items/weapons so they
never show up in *their own* shop for the run.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] — 2026-07-19

### Changed
- **The screen now matches the base game's visual style**: the vanilla theme
  (rounded panels, Brotato fonts, styled buttons) instead of the default grey
  skin, and the shop's textured background instead of the flat black one — panels
  and buttons finally stand out. The tier/class filters get the native skin too.
- **Responsive item/weapon grid**: the number of columns adapts to the available
  width and fills the panel instead of leaving empty space on the right.
- More readable, compact filter and action bar: full labels when there's room,
  tightened in 3-4 player setups so nothing overflows the screen.

### Fixed
- Keyboard navigation in the grid now **scrolls** to follow focus (solo case with
  no gamepad).

## [1.0.1] — 2026-07-15

### Fixed
- The **"Shop Config"** toggle no longer appears **twice** in the options panel
  when another mod extends the same character selection screen (seen with the
  Bomberman mod, which re-runs the vanilla `_ready()`). The checkbox is now
  added idempotently.

## [1.0.0] — 2026-06-29

First stable release: all known issues are fixed.

### Fixed
- **Coop**: gamepad/keyboard navigation no longer "bleeds" across players when
  opening a filter (tier or class). The filters were native dropdowns whose
  popup menu was *globally modal* — it froze/hijacked the other player. They are
  now custom in-panel dropdown lists (real buttons navigable within each player's
  focus, no native popup): all values stay visible and navigation stays scoped
  to each player.

## [0.4.3] — 2026-06-27

### Changed
- The "Shop config" toggle now defaults to **on** (was off). The screen is
  active unless the player explicitly unchecks it — a safety net in case the
  checkbox fails to show up in the run options panel.

## [0.4.2] — 2026-06-27

### Fixed
- An excluded item could still leak into the shop through the vanilla draw
  fallback. When the shop is restricted to a single item (e.g. a Bomb-only
  build), the second slot emptied the anti-duplicate pool and the game fell back
  to a direct, unfiltered tier lookup that `get_pool` cannot intercept. The
  random draw is now wrapped: if the drawn item is excluded, it is replaced by an
  allowed one (same type first, otherwise the other type), tolerating a duplicate
  for the single-item shop case.

## [0.4.1] — 2026-06-26

### Added
- Optional toggle to enable/disable the shop-config screen (off by default).

### Changed
- Moved the "Shop config" toggle to the bottom of the options panel.

## [0.4.0] — 2026-06-20

### Added
- Session-memory persistence of exclusions (carried over from run to run, no
  disk file; cleared automatically on game close).

### Changed
- Bigger Ready button and a green validation check mark (coop-friendly).
- Adjusted the size of the key-hint icons.

## [0.3.0] — 2026-06-20

### Added
- Beta feedback #2: quick actions, key/button hints, keyboard/gamepad tabs.
- Promoted quick actions, `ui_info` popup, deduplicated weapons, and a
  "keep at least a few items" safety guard.

## [0.2.0] — 2026-06-20

### Changed
- Reworked the screen into a standalone full-screen scene (horizontal split,
  exit via `change_scene`); removed the old overlay hacks.
- Entry now happens through a manual scene swap.

### Added
- Per-player coop navigation via a dedicated `FocusEmulator` per panel.
- Objects/Weapons tabs as focusable, gamepad-navigable buttons.

## [0.1.0] — 2026-06-19

### Added
- Initial release: pure logic units (`pool_filter`, store), toggleable logger.
- `ItemService` extension filtering the draw pool, scoped strictly to the shop.
- Full UI (tooltip, tier/class filters, back) and insertion into the run flow.
