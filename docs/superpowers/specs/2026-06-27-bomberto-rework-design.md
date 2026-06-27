# Bomberto — refonte v1.3.0 (design)

> Date : 2026-06-27. Mod **Tanith-Bomberman** (Brotato, Godot 3.7).
> Suite à une phase de beta testing. Branche de travail : `feat/troll-bombe`
> (la troll bombe n'est pas encore mergée ; cette refonte s'empile dessus).

## Objectif

Faire évoluer le personnage à bombes suite aux retours de beta : nouveau nom,
ouverture de la boutique aux armes explosives/knockback, refonte des buffs autour
d'un scaling **élémentaire + ingénierie**, et correction d'un bug coop de la
troll bombe. Le personnage devient un **glass-cannon explosif** : très faible en
dégâts bruts, qui se reconstruit entièrement via ses explosions.

## Contexte technique (acquis pendant le brainstorm)

- **Catégorisation des armes** : Brotato utilise des `sets` (pas de `tags` sur les
  armes). Sets pertinents : `set_explosive`, `set_blunt`, `set_heavy`. Il n'existe
  **pas** de set « knockback ».
- **Knockback** : c'est une **stat** d'arme (`knockback` dans `*_stats.tres`).
  ~45 armes en ont un peu (≥ 1) ; seules quelques-unes ont un knockback **important**
  (≥ 20) : Hand (30), Hammer (30/40/50, **tier 2 min**), Wrench (20), Torch (20),
  Spiky Shield (20), Plasma Sledgehammer. À distance, seuls Sniper/Potato Thrower
  atteignent 20 (tier 4) — exclus en filtrant sur **mêlée**.
- **Effets de scaling natifs** : l'**Artificier** (`items/characters/artificer/`) est
  le modèle exact des buffs voulus :
  - `artificer_effect_2` : `stat_percent_damage = -100` (effet `.tres` simple).
  - `artificer_effect_1b` : `gain_stat_for_every_stat_effect.gd` →
    `explosion_size +4` **par point** de `stat_elemental_damage`
    (`text_key = "EFFECT_GAIN_STAT_FOR_EVERY_STAT"`, sous-ressource `custom_arg`).
  - `artificer_effect_1` : `explosion_damage +175` (flat).
- **Formule de dégât d'explosion** (`WeaponService.get_explosion_damage`,
  `weapon_service.gd:281`) :
  `dégât × (1 + %Damage/100 + explosion_damage/100)`, **min 1**. Le `%Damage` négatif
  et le `explosion_damage` (ingé) **s'additionnent** dans le facteur.
- **`explosion_size`** est lue globalement par `player_explosion.gd:72`
  (`set_area`) via le `player_index` → s'applique à **toute** explosion du joueur.
- **`explosion_damage`** n'est appliqué que si la stat de l'arme est recalculée
  avec `is_exploding = true` (`weapon_service.gd:184-189`, déclenché par la présence
  d'un `ExplodingEffect` dans `data.effects`). Notre Bombe a `effects = []` → elle
  **ne bénéficie pas** du bonus tel quel (voir Décision 7).
- **Armes de départ** : deux mécanismes **distincts** :
  - `character.starting_weapons` = la **liste de choix** affichée à l'écran de
    sélection (`weapon_selection.gd:117-122`) ; le joueur en prend **1**.
  - `RunData.add_starting_items_and_weapons()` (`run_data.gd:1618`) ajoute les armes
    accordées par un **effet** `starting_weapon` (clé `Keys.starting_weapon_hash`),
    **en plus** du choix. Exemple : `crazy_effect_3.tres`
    (`key = "weapon_knife_1"`, `custom_key = "starting_weapon"`, `value = 1`).
- **PV courant du joueur** : `player.current_stats.health` est bien le **PV restant**
  (décrémenté à l'encaissement, `player.gd:434`) ; `max_stats.health` est le max.
  Le plafond non-létal existant lit donc la bonne valeur.

## Décisions de design

### 1. Renommage : Bombertoe → Bomberto

Changer la valeur de la clé `CHARACTER_BOMBERMAN` en **`Bomberto`** dans
`content/i18n/bomberman_translations.gd` (locales `en` et `fr`). Les identifiants
internes (`my_id = "character_bomberman"`, `weapon_id`, dossiers) restent inchangés.

### 2. Pool de la boutique élargi

Remplacer `shop_pool.gd::keep_only_bombs` par un filtre élargi. Une entrée du pool
d'armes est conservée si **au moins une** condition est vraie :

- c'est une **Bombe** (`weapon_id == "weapon_bomb"`), **OU**
- elle appartient au **`set_explosive`**, **OU**
- elle a un **knockback ≥ 20** (sur la stat de l'entrée) **ET** est de type **mêlée**
  (`type == MELEE`).

Roster attendu (indicatif, dépend des déblocages) :
- **Bombe** (tous tiers)
- **Explosive** : Dextroyer, Fireball, Nuclear Launcher, Plank, Plasma Sledgehammer,
  Power Fist, Rocket Launcher, Shredder
- **Knockback ≥ 20 (mêlée)** : Hammer (tier 2+), Hand, Spiky Shield, Torch, Wrench

Le filtrage reste **borné au contexte de tirage boutique** d'un joueur Bomberto
(drapeau `_shop_draw_player`, déjà en place dans `extensions/singletons/item_service.gd`).

**Identité « set » et « knockback »** : la logique pure de `shop_pool.gd` doit pouvoir
lire l'appartenance au set (`item.sets` → `my_id == "set_explosive"`), le knockback
(`item.stats.knockback`) et le type (`item.type`). Les helpers restent testables en
isolant la donnée d'entrée (pas d'accès autoload dans la logique pure).

### 3. Armes de départ : bombe forcée + 1 arme choisie

- `bomberman_data.tres` → `starting_weapons` = le **roster accessible en tier 1** :
  Bombe, Rocket Launcher, Nuclear Launcher, Fireball, Dextroyer, Shredder, Plank,
  Power Fist, Hand, Spiky Shield, Torch, Wrench. *(Hammer et Plasma Sledgehammer
  n'ont pas de version tier 1 → absents du choix de départ, mais toujours achetables
  en boutique.)* La **Bombe reste dans la liste** : un joueur peut donc démarrer avec
  **2 bombes** s'il le souhaite.
- Ajouter un **effet `starting_weapon`** sur le perso (nouveau `.tres`, modèle
  `crazy_effect_3.tres`) accordant `weapon_bomb_1` (`value = 1`). Il force **toujours**
  une Bombe au démarrage, **en plus** du choix de l'écran de sélection.

Résultat : départ garanti avec une Bombe **+** une arme choisie dans le pool accessible.

### 4. Buffs du personnage (remplacent l'effet actuel)

Supprimer l'effet actuel `bomberman_explosion_effect.tres`
(`explosion_damage +30` flat) et le remplacer par **trois effets natifs** (modèle
Artificier), référencés dans `bomberman_data.tres::effects` :

| Effet | Type / script | Détail |
|---|---|---|
| **-75 % dégâts** | `effect.gd` | `key = "stat_percent_damage"`, `value = -75`, `effect_sign = 3` |
| **+5 % taille d'explosion / point d'élémentaire** | `gain_stat_for_every_stat_effect.gd` | `key = "explosion_size"`, `value = 5`, `stat_scaled = "stat_elemental_damage"`, `text_key = "EFFECT_GAIN_STAT_FOR_EVERY_STAT"`, `custom_args = [ custom_arg ]` (cf. `artificer_effect_1b.tres`) |
| **+5 % dégâts d'explosion / point d'ingénierie** | `gain_stat_for_every_stat_effect.gd` | idem mais `key = "explosion_damage"`, `stat_scaled = "stat_engineering"` |

Ces effets sont **globaux** : ils s'appliquent à la Bombe **et** aux armes explosives
achetées en boutique (lance-roquettes, nucléaire…). C'est voulu (cohérent avec le thème
et avec le fonctionnement de l'Artificier).

**Intention d'équilibrage** : le -75 % met le facteur de base à `0.25` ; l'ingénierie
recompose via `explosion_damage` (ex. 30 ingé × 5 % = +150 % → facteur ≈ 1.75) et
l'élémentaire via la taille d'explosion + le scaling 150 % de l'arme (Décision 5).
Les deux stats sont donc essentielles et complémentaires.

### 5. Scaling de l'arme Bombe

Dans les **4** fichiers `content/weapons/bomb/bomb_{1..4}_stats.tres`,
`scaling_stats` passe de :

```
[ [ "stat_elemental_damage", 0.5 ], [ "stat_engineering", 0.5 ] ]
```

à :

```
[ [ "stat_engineering", 1.0 ], [ "stat_elemental_damage", 1.5 ] ]
```

(100 % ingénierie + 150 % élémentaire sur le dégât de base de la Bombe.)

### 6. Taille visuelle de l'entité bombe

Agrandir le **sprite de la bombe posée** d'un facteur **×1.25**, purement
**cosmétique**. N'affecte **pas** le rayon d'explosion (qui dépend de
`explosion_size` / `_explosion_scale`). À appliquer dans `bomb_entity.gd` (scale du
nœud `Sprite`, ou de l'entité sans toucher à l'`ExplodingEffect.scale`). La troll
bombe peut suivre le même facteur pour rester cohérente (à confirmer en jeu).

### 7. Fix : faire bénéficier la Bombe du bonus `explosion_damage`

Notre Bombe a `effects = []` → le jeu ne la considère pas comme « exploding » et le
bonus `explosion_damage` (donc le buff ingé de la Décision 4) **ne l'atteint pas**.

**Correction** : router le calcul du dégât de la bombe via
`WeaponService.get_explosion_damage(stats_base, player_index)` (qui applique
`scaling_stats` + `%Damage` + `explosion_damage`, min 1), au lieu de poser
`_explode_args.damage = _stats.damage` brut dans `bomb_entity.gd::_on_fuse_timeout`.

- L'argument `stats_base` doit être la **stat de base** de l'arme (le `.tres` de stats),
  pas la `current_stats` déjà recomposée, pour éviter un double comptage du `%Damage`.
- À vérifier en jeu : la valeur affichée/infligée correspond bien au facteur attendu
  (≈ ×1.75 dans l'exemple ci-dessus), et la Bombe reste cohérente avec les explosions
  vanilla (landmine).
- La troll bombe (chemin de dégât séparé, via Hitbox de contact) **n'est pas concernée**
  par ce point (elle plafonne déjà ses dégâts ; voir Décision 8).

### 8. Fix coop : troll bombe non-létale pour tous

**Bug** : sur le chemin **contact** (`troll_bomb.gd::_physics_process`), la Hitbox
couche 4 touche **n'importe quel joueur** dont la hurtbox la chevauche, mais le dégât
est plafonné **uniquement aux PV du joueur poursuivi** (le plus proche) :

```
_hitbox.damage = nonlethal_damage(_base_damage, nearest_player.current_stats.health)
```

En coop, un **coéquipier** plus bas en PV qui touche la bombe peut donc **mourir**.
(L'AoE de fin de minuteur est déjà safe : elle plafonne au PV minimum de tous les
joueurs à portée via `_min_hp_in_blast()`.)

**Correction** : sur le chemin contact, plafonner le dégât au **PV minimum de TOUS les
joueurs vivants** (pas seulement le poursuivi), comme le fait déjà l'AoE. Cela garantit
qu'aucun joueur ne meurt, quel que soit celui qui touche la bombe.

- Le ciblage (poursuite du joueur **le plus proche**, coéquipiers inclus) reste
  **inchangé** : la coop assume le chaos, seul le caractère létal est corrigé.
- Réutiliser/centraliser le calcul du « PV min des joueurs vivants » (le `_min_hp_in_blast`
  actuel est borné au rayon d'explosion ; pour le contact, on veut le min **global**).
  La sélection du minimum reste de la **logique pure** testable
  (`troll_bomb_logic.gd`), l'accès aux nœuds joueurs restant côté entité.

## Découpage en unités

- **Logique pure (testable headless)** :
  - `shop_pool.gd` : filtre élargi (bombe / set explosive / knockback≥20 mêlée) à partir
    de données d'entrée injectées.
  - `troll_bomb_logic.gd` : `nonlethal_damage` (inchangé) + sélection du **PV min global**
    des joueurs vivants (entrée = liste de PV).
- **Données (`.tres`)** :
  - `bomberman_data.tres` : `starting_weapons` (roster T1), `effects` (3 nouveaux),
    nouvel effet `starting_weapon`.
  - 3 effets buff + 1 effet `starting_weapon` (nouveaux `.tres`).
  - `bomb_{1..4}_stats.tres` : `scaling_stats`.
  - Suppression de l'usage de `bomberman_explosion_effect.tres`.
- **Entités (code)** :
  - `bomb_entity.gd` : dégât via `get_explosion_damage` (Décision 7), scale sprite ×1.25.
  - `troll_bomb.gd` : plafond contact au PV min global (Décision 8), scale cohérente.
- **i18n** : `bomberman_translations.gd` (renommage).
- **Extension boutique** : `extensions/singletons/item_service.gd` — inchangée dans son
  principe ; vérifier que le filtre élargi s'y branche comme avant.

## Tests & vérification

- **Headless (logique pure)** : filtre du pool élargi (cas bombe / explosive /
  knockback≥20 mêlée / à distance exclu / knockback<20 exclu) ; PV min global non-létal
  (aucun kill, 0 si un joueur à 1 PV). Lancer via `./run-tests.sh`.
- **En jeu** (non couvrable en headless) :
  - Renommage affiché « Bomberto ».
  - Boutique propose le roster attendu ; sélection de départ = pool accessible T1 ;
    départ garanti avec une Bombe + l'arme choisie (et 2 bombes si Bombe choisie).
  - Buffs : -75 % dégâts visibles ; explosions plus grosses avec l'élémentaire ;
    plus de dégât d'explosion avec l'ingénierie ; la **Bombe** bénéficie bien du bonus
    ingé (Décision 7).
  - Entité bombe visiblement plus grosse (×1.25) sans changement de rayon.
  - Coop : une troll bombe ne **tue jamais** un coéquipier (test avec allié à bas PV).

## Versioning

- Bump du mod en **v1.3.0** (`manifest.json` + `CHANGELOG.md`).

## Hors périmètre (YAGNI)

- Pas de refonte de l'art (sprites bombe/visage) au-delà du scale ×1.25.
- Pas de modification du ban natif / item boxes / pool d'items (seulement le pool d'ARMES
  de la boutique et la sélection de départ).
- Pas de changement du ciblage de la troll bombe (reste « le plus proche »).
