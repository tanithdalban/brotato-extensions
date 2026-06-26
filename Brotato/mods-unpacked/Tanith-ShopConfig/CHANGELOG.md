# ShopConfig — Changelog

A per-player shop pool configuration screen for Brotato, inserted between
character selection and weapon selection. Players exclude items/weapons so they
never show up in *their own* shop for the run.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

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
