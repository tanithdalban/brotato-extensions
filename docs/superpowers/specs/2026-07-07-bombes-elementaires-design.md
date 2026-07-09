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

**Décision de conception (2026-07-08, validée en session)** : on **abandonne** le
slow décroissant vanilla (`speed_percent_modifier` → `add_decaying_speed`) : sa
récupération (+300 vitesse/s, `unit.gd:161`) est **codée en dur et globale**, donc
le slow s'efface en ~0,5 s — trop bref. On veut un ralentissement **durable** mais
**strictement scopé à la bombe de glace** (pas d'effet joueur global type Ugly Tooth
`remove_speed`, ni Snail — rejetés car globaux).

- **Ralentissement — coupe de vitesse RÉELLE à l'impact, NON CUMULATIVE (modèle
  « vitesse cible »)** :
  - Inspiré d'Ugly Tooth (`items/all/ugly_tooth/`, `enemy.gd:254-256`) qui réduit
    `enemy.current_stats.speed` en % de la vitesse **max** — mais Ugly Tooth est
    **cumulatif par coup** et **joueur global**. On reproduit la coupe de vitesse
    réelle sur `current_stats.speed`, mais **scopée à la glace** et **non
    cumulative**.
  - **Non cumulatif — « on garde le plus fort »** : plusieurs bombes de glace sur
    un même ennemi **ne s'empilent PAS**. Chaque tier vise une **vitesse cible**
    `cible = max_speed × (1 − slow%/100)` ; on applique
    `current_stats.speed = min(current_stats.speed, cible)`. Un slow plus faible
    arrivant après un plus fort est donc un **no-op** (la cible est plus haute que
    la vitesse courante). Deux bombes de même tier → 2ᵉ = no-op. Fonction **pure**
    `bomb_ice_slow.gd apply(cur_speed, max_speed, slow_pct) -> float`.
  - **Application via le signal `hit_something` (AUCUNE extension de `enemy.gd`)** :
    l'explosion (`PlayerExplosion`) émet déjà un signal public
    `hit_something(thing_hit, damage_dealt)` pour **chaque** ennemi touché, émis
    **hors** du gate `deals_damage` (`unit.gd:608`) → il se déclenche **même à
    0 dégât**. `bomb_entity`, pour une bombe de glace, connecte **après**
    `explode()` ce signal à notre `BombWeapon` (persistant) :
    `instance.connect("hit_something", weapon, "on_ice_hit", [slow_pct])`
    (gardé par `is_connected`). `BombWeapon.on_ice_hit(thing_hit, damage_dealt,
    slow_pct)` applique
    `thing_hit.current_stats.speed = BombIceSlow.apply(thing_hit.current_stats.speed,
    thing_hit.max_stats.speed, slow_pct)` — **duck-typé** (`if "current_stats" in
    thing_hit and "max_stats" in thing_hit`), donc marche sur n'importe quel `Unit`
    (vanilla/DLC/autre mod) sans toucher au code ennemi.
  - **Pourquoi ce choix (risques évités)** : étendre `enemy.gd` exposerait à
    (a) un ennemi DLC avec un `_on_hurt` maison n'appelant pas son parent (pas de
    slow) ou une MAJ changeant sa signature (casse au chargement), et (b) la
    fragilité de chaînage si un autre mod étend aussi `enemy.gd` sans rappeler son
    parent. Le signal `hit_something` (stable, déjà utilisé par le vanilla pour
    brancher les armes) confine **toute** la logique dans NOTRE `bomb_weapon.gd`.
  - **Hygiène du pool** : `PlayerExplosion.end_explosion()` fait déjà
    `Utils.disconnect_all_signal_connections(self, "hit_something")` au recyclage →
    notre connexion est nettoyée à chaque fin d'explosion. **Aucune contamination,
    aucune extension `player_explosion.gd` nécessaire.**
  - **Durée** : la coupe est écrite dans `thing_hit.current_stats.speed` → elle
    **persiste** tant que l'ennemi vit (pas de régénération de la vitesse de base).
    Comportement voulu (débuff durable, non décroissant) ; le `min()` garantit
    l'absence d'empilement.
- **Slow % par tier (I→IV)** : porté par `_stats.speed_percent_modifier`
  (**repurposé** comme pourcentage de slow cible, valeurs `-30 / -40 / -50 / -60`).
  Valeurs à caler en jeu.
- **Givre visuel — contour bleu persistant (0 dégât strict)** : en plus du slow,
  l'ennemi touché reçoit un **contour bleu givré** via `entity.gd:add_outline(color)`
  (système d'outline shader natif, 4 couleurs max, déjà utilisé par les boosts /
  la malédiction des pets). Appliqué dans `BombWeapon.on_ice_hit` (même point que le
  slow, guardé par `has_method("add_outline")`). Couleur `FROST_OUTLINE_COLOR`
  (`Color("5bc8ff")`). **Non cumulatif** (add_outline dédoublonne par couleur) et
  **auto-nettoyé** à la mort de l'ennemi.
  → **Pivot vs. le plan initial (burning BLEU)** : l'approche `BurningEffect` givré
  (`damage=0` + scaling ingé pour la couleur) a été **abandonnée** car le calcul
  vanilla `apply_scaling_stats_to_damage` = `max(1.0, …)` **impose un plancher de
  1 dégât/tick** : un DOT à 0 strict est **impossible** via le burning (constaté en
  jeu). Le contour remplace donc entièrement le burning givré — plus aucun
  `BurningEffect` dans les `.tres` de glace, `burning_data` reste nul (cas déjà géré,
  comme la bombe normale).
- **Explosion** : AoE `damage = 0` (repli **1 dégât** autorisé si un test montre
  qu'un 0 pose souci) ; `_will_wake = false` (jamais de trollbombe).
- **Visuel bombe** : `glace.png` (= `Glace.png` copié dans le mod, 150×150 RGBA,
  fond déjà transparent), constant I→IV ; sprite en jeu 48×48 sans fond ; icône
  boutique avec disque coloré par tier.

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

## TODO — idées futures (hors phases planifiées)

- **Mieux gérer la dépose des bombes** pour éviter l'**empilement** et le
  **croisement des zones d'AOE** (bombes qui tombent au même endroit / AOE qui se
  chevauchent). Pistes à explorer : dispersion/offset de la position de dépose,
  espacement minimal entre bombes, ou déphasage spatial en plus du déphasage
  temporel déjà existant (`BombTiming.slot_phase_offset`). À concevoir plus tard.
