# Bombes élémentaires — Glace, Poison, Foudre (+ nouvelle icône)

Statut : **design validé**, prêt pour le plan d'implémentation.
Date : 2026-07-07. Branche cible : `feat/bombes-elementaires`.

## Objectif

Enrichir l'arsenal du **Bomberto** avec trois nouvelles armes-bombes à effet, et
remplacer l'icône jugée moche de la Bombe actuelle.

1. **Icône** : la Bombe de base adopte `bombe_normale.png` (bombe noire classique),
   constante sur tous ses tiers ; le tier se lit désormais via un **fond coloré**
   derrière l'icône (rareté).
2. **Bombe de Glace ❄️** : ralentit les ennemis (aucun dégât).
3. **Bombe de Poison ☠️** : DOT (dégâts sur la durée) scalé sur l'**ingénierie**.
4. **Bombe de Foudre ⚡** : reproduit **l'effet de l'item Tyler** (un burst d'éclairs
   en cercle), sans le comportement « tourelle ».

## Principe directeur

Les 4 bombes (normale + 3 élémentaires) **partagent** `bomb.tscn`,
`bomb_weapon.gd` et `bomb_entity.gd`. Elles ne diffèrent que par :
- leurs `.tres` (data + stats),
- leurs sprites,
- un **élément** déduit du `weapon_id`, qui pilote le sous-comportement à l'explosion.

Découverte clé du jeu décompilé : **presque tout est data-driven**.
- Le champ `speed_percent_modifier` existe déjà sur `ranged_weapon_stats.gd` → glace.
- `BurningData.scaling_stat = "stat_engineering"` = mécanique de la Tourelle
  enflammée vanilla → poison. `can_burn_enemies = 1` est un effet joueur **par
  défaut** (`player_run_data.gd:514`) → le poison brûle même en solo, sans set Feu.
- Tyler tire 10 `delayed_lightning_projectile` avec `projectile_spread = π`
  (cercle complet) → foudre, via `WeaponService.spawn_projectile` en boucle
  (même appel que `turret._spawn_projectile`).

## Règles communes aux bombes à effet (glace / poison / foudre)

- **Aucun dégât d'explosion AoE** : `_explode_args.damage = 0`. Les effets
  (brûlure l.582, slow l.605 de `unit.gd`) s'appliquent **indépendamment** des
  dégâts ; une hitbox à 0 dégât suffit.
  - *Filet de sécurité* : si un test en jeu révèle qu'un 0 dégât pose problème
    (dodge, tracking…), on passe à **1 dégât minimum**.
- **Jamais de transformation en trollbombe** : le tirage `_will_wake` est **forcé
  à `false`** pour les bombes à effet (uniquement la Bombe normale peut se réveiller).

## Détail par bombe

### Bombe normale (existante, retouchée)
- **Mécanique** : inchangée — explosion + dégâts AoE + brûlure scalée élémentaire
  + peut devenir trollbombe.
- **Visuel** : `bombe_normale.png` (constant I→IV) + fond coloré par tier.

### Bombe de Glace ❄️
- **Mécanique** : ralentissement des ennemis dans la zone, **aucun dégât**.
  `speed_percent_modifier` (négatif) est renseigné dans le `_stats.tres` ;
  `bomb_entity` le pose sur la hitbox de l'explosion **après** `explode()`
  (`instance._hitbox.speed_percent_modifier = _stats.speed_percent_modifier`).
  Le natif `add_decaying_speed` applique un slow qui se dissipe.
- **Valeurs par tier (I→IV)** : `-20 / -30 / -40 / -50 %` (plafond 50 %, c'est un
  debuff d'ennemi).
- **Visuel** : `Glace.png` (constant I→IV, fond déjà transparent) + fond par tier.

### Bombe de Poison ☠️
- **Mécanique** : DOT, **aucun dégât d'explosion direct**. `BurningData` avec
  `scaling_stats = [["stat_engineering", …]]` porté par le `_stats.tres` (ou un
  effet burning) ; `bomb_entity` passe déjà `burning_data` à `explode()`.
  Profite du kit ingénierie du Bomberto (`explosion_damage_per_engineering`).
- **Valeurs par tier** : dégâts/durée du DOT calqués et gradués sur la brûlure
  élémentaire actuelle de la Bombe (à caler en jeu).
- **Visuel — icône** : `poisonbomb_1..4.png` (un sprite par tier) + fond par tier.
- **Visuel — DOT sur l'ennemi (feu vert)** : les particules de brûlure vanilla
  se colorent déjà selon le stat de scaling (`burning_particles.gd:_update_color`) :
  élémentaire → **rouge/orange**, ingénierie → **bleu** (couleur Tourelle
  enflammée). Sans intervention, notre poison ingé s'afficherait donc **en bleu**
  (peu lisible, et proche de la foudre). Pour obtenir le **feu vert** voulu :
  **script extension** sur `burning_particles.gd` surchargeant `_update_color()`
  pour appliquer un **dégradé vert** (créé en code) **uniquement** quand la
  brûlure provient d'une bombe de poison (marqueur : `burning_data.from` dont le
  `weapon_id` commence par `weapon_bomb_poison`) ; comportement vanilla (rouge/bleu)
  conservé sinon → **n'altère pas** la Tourelle enflammée.
  - *Repli* : si l'override s'avère capricieux, on garde le bleu ingé vanilla.

### Bombe de Foudre ⚡
- **Mécanique** : reproduit **uniquement l'effet Tyler** (pas la tourelle). À
  l'« explosion », `bomb_entity` tire un **burst unique** de ~10
  `delayed_lightning_projectile` en **cercle complet** (spread ≈ π) depuis la
  position de la bombe, via `WeaponService.spawn_projectile` en boucle sur
  `nb_projectiles` (patron `turret.shoot()` / `_spawn_projectile`). Puis la bombe
  disparaît. **Pas de structure persistante, pas de ciblage en boucle, pas de
  cooldown de tourelle.**
- **Dégâts** : portés par les éclairs (scaling ingé/élém, comme Tyler),
  **pas** par une explosion AoE.
- **Paramètres** (dans `_stats.tres`, type `RangedWeaponStats`) :
  `projectile_scene = delayed_lightning_projectile.tscn`, `nb_projectiles` (~10),
  `projectile_spread = π`, `piercing`, `can_bounce`, `damage`, `scaling_stats`,
  gradués par tier.
- **`from`** : `bomb_weapon` transmet une référence valide (l'arme équipée, qui
  persiste) pour l'attribution des dégâts et le `player_index`.
- **Visuel** : `stormbomb_1..4.png` (renommés depuis `icebomb_1..4.png`) + fond
  par tier.

## Visuels & icônes

- **Source des assets** : dans `screens/` (à copier dans le mod). Utilisés :
  `bombe_normale.png`, `Glace.png`, `poisonbomb_1..4.png`,
  `stormbomb_1..4.png` (= `icebomb_1..4.png` renommés).
  **Ignorés** (tests) : `Simple.png`, `Glace`/`Poison` génériques hors liste,
  `Gemini_Generated_*.png`.
  - `icebomb_2.png` fait 270×280 (les autres 150×150) → **normaliser** tous les
    sprites sur un canvas carré à la génération.
- **Fond par tier** : disque/halo coloré composité **par programme** derrière le
  sprite, couleurs de rareté `["gray","blue","purple","red"]` (I→IV, réutilise le
  mapping de `bomb_skin.gd`). **Uniquement sur l'icône** boutique/inventaire.
- **Sprite en jeu** (bombe tenue + posée au sol) : **sans fond** (le disque
  coloré jurerait sur le champ de bataille) ; juste la bombe (constante pour
  normale/glace, par tier pour poison/foudre).
- Chargement runtime (hors cache d'import Godot), comme l'actuel `bomb_skin.gd`.

## Accessibilité — anti-épilepsie

- L'**opacité du sprite d'AOE** de **nos** explosions (toutes nos bombes) est
  réglable via la **config du mod** (`explosion_opacity`, **défaut 0.2 = 20 %**,
  même mécanisme que `debug_log`).
- Appliquée **après** `explode()` sur le `%Sprite` de l'instance d'explosion
  (`instance.get_node("%Sprite").modulate.a = opacity`).
- **Portée strictement limitée à nos bombes** : n'altère ni les explosions
  vanilla, ni le réglage global `ProgressData.settings.explosion_opacity`.
- N'affecte **que le visuel** : ni la zone d'effet, ni les dégâts, ni les effets.
- Les **éclairs** de la foudre sont des projectiles distincts (pas le sprite
  d'AOE) : hors périmètre de ce réglage. Si leur clignotement pose souci en jeu,
  calibrage ultérieur (baisser `nb_projectiles` ou leur `modulate`).

## Plomberie / intégration

- **Nouveaux `.tres`** : 3 éléments × 4 tiers × (data + stats) = **24 fichiers**,
  plus les sous-ressources d'effet (burning poison, stats projectile foudre).
  Chaînes `upgrades_into` I→IV par élément.
- **`bomb_entity.gd`** : mode « bombe à effet » à 3 sous-comportements
  (slow / DOT / burst d'éclairs), `damage = 0` AoE, `_will_wake = false`.
  L'élément est transmis par l'arme (déduit du `weapon_id`).
- **`bomb_weapon.gd`** : détermine l'élément et le passe à `bomb.arm(...)` ;
  transmet aussi une réf `from` valide (pour les éclairs de la foudre).
- **`extensions/particles/burning/burning_particles.gd`** (nouveau) : surcharge
  `_update_color()` pour le feu vert du poison (voir section Poison). Déclarée
  dans `mod_main.gd` via `install_script_extension`.
- **`bomb_skin.gd`** : refonte pour indexer par **(élément, tier)** au lieu de
  (tier) seul ; compositing du fond coloré pour l'icône.
- **`shop_pool.gd`** : accepter les nouveaux `weapon_id`. Sécuriser par **préfixe
  `weapon_bomb`** (`weapon_bomb_ice`, `weapon_bomb_poison`, `weapon_bomb_storm`) —
  elles passent déjà via le set `explosive`, mais le préfixe est plus robuste.
- **`item_service.gd`** : enregistrer les **12** nouvelles armes dans
  `_BOMB_WEAPONS` ; poser l'icône (élément, tier) au chargement.
- **i18n** (`bomberman_translations.gd`) : `WEAPON_BOMB_ICE`,
  `WEAPON_BOMB_POISON`, `WEAPON_BOMB_STORM` (FR/EN).
- **Tooltips** : lignes d'effet lisibles (slow % pour la glace, DOT pour le
  poison, éclairs pour la foudre) construites depuis `effects[]`.

## Tests

- **Headless (logique pure)** :
  - mapping `(élément, tier) → chemin de sprite` ;
  - mapping `weapon_id → élément` ;
  - filtrage du pool (`shop_pool` accepte les 3 nouveaux préfixes, rejette le
    hors-thème) ;
  - clamp des valeurs de slow par tier.
- **En jeu (non testable en headless)** : application effective du slow, du DOT
  ingé, du burst d'éclairs, l'opacité d'AOE réduite, l'apparence des icônes/fond,
  l'équilibrage.
- Runner : celui du **Bomberman** (≠ `./run-tests.sh` de ShopConfig — commande
  exacte dans la note mémoire du mod).

## Hors périmètre / à caler en jeu

- Équilibrage fin (dégâts DOT, nb éclairs, valeurs de slow, prix/`value`).
- Déploiement Steam Workshop (item existant) — après validation en jeu.
- Un éventuel réglage d'opacité pour les éclairs (si besoin au calibrage).
