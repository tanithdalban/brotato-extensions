# Bomberman — Changelog

A Brotato character mod: "Bomberto", a bomb-throwing character whose shop also
offers explosive and high-knockback melee weapons, paired with a Bomb weapon
that drops bombs on a cooldown (no targeting) and leans on explosion and
elemental/engineering scaling.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.4.0] — 2026-06-28

### Added
- Arme Bombe : la **vitesse d'attaque raccourcit la mèche** (même formule que le
  cooldown vanilla, plancher 0.5 s). Plus on attaque vite, plus les bombes
  explosent tôt ; une vitesse d'attaque négative rallonge au contraire la mèche.
  S'applique à la bombe normale comme à la troll bombe.

### Fixed
- Arme Bombe : la **brûlure** fonctionne désormais réellement en jeu. Elle était
  posée sur `stats.burning_data`, un champ que la sérialisation de run ne conserve
  pas (la brûlure retombait à 0 dès le premier passage boutique/vague). Elle passe
  maintenant par un `BurningEffect` dans `WeaponData.effects` (schéma vanilla de la
  Torch), ré-appliqué à chaque calcul de stats et persistant. Brûlure progressive
  par tier inchangée (3 dmg/3 s → 12 dmg/9 s, scaling élémentaire).

## [1.3.0] — 2026-06-27

### Changed
- Personnage renommé **Bombertoe → Bomberto**.
- Boutique élargie : en plus des Bombes, propose désormais les armes du set
  **explosive** et les armes de mêlée à **fort knockback (≥ 20)** (Hammer, Hand,
  Spiky Shield, Torch, Wrench…).
- Armes de départ : on commence **toujours avec une Bombe** (forcée), **plus** une
  arme choisie parmi le roster accessible disposant d'un tier-0 (Bombe, Shredder,
  Plank, Hand, Spiky Shield, Torch, Wrench). Choisir la Bombe = démarrer avec 2 bombes.
- Refonte des buffs : **-75 % dégâts**, **+5 % taille d'explosion par point
  d'élémentaire**, **+5 % dégâts d'explosion par point d'ingénierie** (effets globaux,
  s'appliquent aussi aux armes explosives achetées).
- Arme Bombe : scaling **100 % ingénierie + 150 % élémentaire** (au lieu de 50/50).
- Arme Bombe : l'explosion **enflamme** désormais les ennemis (même brûlure que la
  **Torch**, progressive par tier : 3 dmg/3 s → 12 dmg/9 s, scaling élémentaire).
- Bombe posée **1.25× plus grosse** (visuel uniquement) ; la troll bombe aussi.

### Fixed
- La Bombe bénéficie désormais réellement du bonus de **dégâts d'explosion**
  (le buff ingénierie l'atteint).
- **Coop** : une troll bombe ne peut plus **tuer un coéquipier** — le dégât de
  contact est plafonné au PV minimum de **tous** les joueurs vivants.

## [1.2.0] — 2026-06-27

### Added
- "Troll bomb": a placed bomb can randomly (~10%) wake up partway through its
  fuse, turn into an unstoppable roving hazard, and chase the nearest living
  player to explode in their face (hits players/allies, never enemies).
  - Wake telegraph: an alert sound plays and the troll bomb stays still briefly
    before the chase begins, and it never spawns right on top of a player.
  - Body color matches the origin bomb's tier, with an angry-face overlay.
  - Non-lethal: contact and end-of-timer AoE damage are capped so they always
    leave the player at 1 HP or more.

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
