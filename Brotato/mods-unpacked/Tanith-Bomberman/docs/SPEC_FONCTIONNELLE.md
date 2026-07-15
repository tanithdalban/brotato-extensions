# Bomberman (Bomberto) — Spec fonctionnelle

Vue d'ensemble consolidée de **tout ce que fait le mod**, feature par feature, avec pointeurs
vers le code. Sert d'index de reprise. Les specs de conception détaillées (une par
fonctionnalité, avec l'historique des décisions) vivent dans `docs/superpowers/specs/` ;
ce document en est la synthèse « état courant ».

- **Mod** : `Tanith-Bomberman`, version manifest **2.0.0**, Godot 3.7 via ModLoader 6.3.0.
- **Pitch** : *Bomberto*, un personnage qui **pose des bombes à mèche** en se déplaçant, et
  qui manie aussi les **armes explosives et de mêlée à fort knockback**.
- **Intégration** : 100 % par script extensions ModLoader (pas de hook Godot) + contenu
  `.tres` (perso, armes, défis). Extensions déclarées dans `mod_main.gd`.

---

## 1. Le personnage — Bomberto

`content/characters/bomberman/bomberman_data.tres` (`my_id = "character_bomberman"`).

**Passifs (effets du perso) :**
| Effet | Valeur | Fichier |
|---|---|---|
| Malus de dégâts | **−75 % de dégâts** (`stat_percent_damage`) | `effect_damage_malus.tres` |
| Taille d'explosion / élémentaire | **+5 taille d'explosion** par point de dégâts élémentaires | `effect_explosion_size_per_elemental.tres` |
| Dégâts d'explosion / ingénierie | **+5 dégâts d'explosion** par point d'ingénierie | `effect_explosion_damage_per_engineering.tres` |
| Bombe de départ forcée | démarre avec la **Bombe** (`weapon_bomb_1`) | `effect_starting_bomb.tres` |

- **Tag recherché** : `explosive` (les objets explosifs remontent plus souvent en boutique).
- **Armes de départ au choix** (`starting_weapons`) : les 4 bombes tier I + 6 armes de mêlée/distance
  vanilla (shredder, plank, hand, spiky_shield, torch, wrench). Le joueur démarre donc avec
  **la bombe normale forcée + une arme choisie** dans ce pool.
- **Équilibre fondateur** : le −75 % fait que la **bombe normale reste le DPS principal** (elle
  seule bénéficie du bonus « dégâts d'explosion ») ; les bombes à effet sont **utilitaires**.

---

## 2. La pose de bombes

Refonte majeure (release 2.0.0). Module pur `content/logic/bomb_placement.gd` + `bomb_timing.gd`,
appliqués dans `content/weapons/bomb/bomb_weapon.gd`.

- **Mèche** : durée interpolée par tier, **2,0 s (T1) → 1,0 s (T4)**, plancher 0,5 s
  (`bomb_timing.fuse_seconds`). Ajustée par la vitesse d'attaque avec **la même formule que le
  cooldown** (`fuse_seconds_scaled`) → la longueur de la traînée est **invariante** à la vitesse
  d'attaque (elle défile juste plus vite).
- **Cadence déterministe** : cooldown figé (75) et **suppression de la gigue aléatoire vanilla**
  (`get_next_cooldown`) → toutes les armes bombe partagent la même période. Un **déphasage par
  slot** (`slot_phase_offset`) égrène les bombes en file (« train »).
- **Placement en éventail** (`bomb_placement`) : l'azimut = slot d'arme + **angle d'or** (précession,
  règle le cas d'une seule bombe en main), projeté sur un **éventail centré derrière le joueur**.
  L'éventail se **referme en file** quand le **déplacement net** depuis la bombe précédente suffit
  à espacer (`mobility_from_travel`, seuil = N × diamètre de couronne), sinon reste **ouvert en
  couronne**. Rayon fixe `RADIUS = 64 px`.
  - ⚠️ On mesure un **déplacement NET**, pas une vitesse instantanée : un joueur qui frétille sur
    place (esquive) ne referme pas l'éventail (sinon empilement).
- ⚠️ **Contrepartie assumée** : monter en tier **n'accélère plus** la pose (rupture d'équilibrage
  → version majeure).
- 📌 **TODO équilibrage connu** (en attente de retours) : au **danger 5**, les ennemis rapides
  traversent la zone avant que la mèche n'arrive à terme. Analyse dans la note de statut ; décision
  actuelle = **ne rien changer**.

---

## 3. Les 5 bombes

L'élément est déduit du `weapon_id` partagé par les 4 tiers (`content/logic/bomb_element.gd`).
La **Bombe normale** fait dégâts AoE + brûlure + peut « troller » ; les 4 autres sont des
**bombes à effet** : **0 dégât d'explosion**, jamais de troll bombe. Entité commune :
`content/entities/bomb_entity.gd`.

### 3.1 Bombe (normale) — `weapon_bomb`
- Dégâts d'explosion réels + **brûlure**. Seule bombe à profiter du bonus « dégâts d'explosion »
  (via `get_explosion_damage`, scalé sur l'ingénierie ≈ ×2,5 en fin de run).
- `EXPLOSION_SCALE = 1.5`.
- C'est **le DPS** de Bomberto ; peut se transformer en **troll bombe** (§4).

### 3.2 Bombe de Glace — `weapon_bomb_ice`
- **Ralentit** les ennemis touchés (`content/logic/bomb_ice_slow.gd`).
- Modèle **vitesse cible NON cumulatif** : `speed = min(speed, max_speed × (1 − slow%/100))`
  → « on garde le plus lent ». Débuff **réel et durable** (écrit dans `current_stats.speed`,
  tient jusqu'à la mort de l'ennemi).
- Slow par tier : **30 / 45 / 60 / 75 %**. ⚠️ **Deux champs à synchroniser à la main** par tier :
  `..._stats.tres` `speed_percent_modifier` (négatif = gameplay) ET `..._data.tres` NullEffect
  (= ligne d'infobulle).

### 3.3 Bombe de Foudre — `weapon_bomb_storm`
- À l'explosion, projette **plusieurs éclairs** en étoile (**≈ 6 → 10** selon le tier).
- **Knockback = 20** constant sur les 4 tiers (la montée vient du nombre d'éclairs). ⚠️ Exige
  `knockback` **ET** `can_have_positive_knockback = true` (sinon clampé à 0).
- ⚠️ Souffre le plus de l'**armure ennemie** (retranchée à *chaque* éclair de faible valeur) ;
  encaisse le −75 % sans compensation (décision assumée).

### 3.4 Bombe de Poison — `weapon_bomb_poison`
- Applique un **DOT (brûlure)** scalé sur l'**ingénierie**. Fin de la chaîne de défis.
- La brûlure **ignore l'armure** (seul mécanisme du jeu qui la perce) → arme d'usure anti-blindés.
- Dégâts DOT figés à **5 / 7 / 9 / 12** (scaling ingé 1.2), durées 4/5/6/8.
- **Feu VERT** au lieu du bleu-tourelle : `content/logic/poison_fire.gd` + extension
  `burning_particles.gd` (recoloration seulement si `burning_data.from` est une bombe de poison).
- Infobulle « dégâts de poison » via `text_key` posé sur le `BurningEffect` existant.
- ⚠️ **Correctif clé** (`bomb_weapon._fix_poison_burning_scaling`) : le −75 % de Bomberto écrasait
  le DOT (le chemin « arme tenue » passe `is_structure=false` → prenait `stat_percent_damage`).
  On recalcule `burning_data` avec `is_structure=true` et on réassigne `.from = self`.

### 3.5 Bombe sangsue — `weapon_bomb_leech` *(en cours, branche `feat/bombe-sangsue`)*
- **0 dégât d'explosion** : elle **DRAINE**. À l'explosion, chaque ennemi touché tire sur le vol
  de vie de l'arme ; en cas de proc, on lui **retire N PV** (drain « sec », armure ignorée) et on
  **rend au joueur** le montant réellement retiré. Logique pure `content/logic/bomb_leech.gd`.
- **Ne draine QUE les ennemis** (`thing_hit is Enemy` ; Boss inclus, **jamais** les neutres
  arbres/caisses — sinon soin infini). Reliquat non consommé **remboursé** au budget.
- **Plafond = un seul « seau à jetons » PAR JOUEUR**, partagé par toutes ses sangsues, **rechargé
  dans le temps** : capacité = plafond du tier (**3/4/5/6** PV), recharge = capacité **par seconde**.
  Empiler des sangsues rend le soin **régulier**, pas plus **gros** (garde-fou vs le plafond
  vanilla de ~10 PV/s). Seau stocké en **méta sur le nœud joueur** (per-joueur en coop, meurt avec
  la run). PV volés par proc : 1 (2 avec `double_lifesteal_bonus`).
- **Pourquoi un soin maison** : le vol de vie vanilla rend **1 PV par proc** et un `LifestealTimer`
  de 0,1 s **jette** les procs simultanés → une explosion (tous ses ennemis dans la même frame)
  n'aurait rendu qu'1 PV. On contourne ce timer sur notre seul chemin.

---

## 4. La troll bombe

`content/entities/troll_bomb.gd` + logique pure `content/logic/troll_bomb_logic.gd`. Uniquement
sur la **Bombe normale**.

- Pendant sa mèche, la bombe **se réveille aléatoirement** (`should_wake`, tirage) et devient un
  **danger mobile** qui **poursuit le joueur le plus proche** (`nearest_target`, `step_velocity`).
- **Non létale** : dégâts plafonnés pour **laisser le joueur à ≥ 1 PV** (`nonlethal_damage`, borné
  par `min_living_hp` de **tous** les vivants).
- **Anti « explose au visage »** : spawn repoussé à ≥ `MIN_SPAWN_DISTANCE` (`keep_distance`).
- Réveil télégraphié à ~50 % de la mèche.
- 🐛 **BUG CONNU non corrigé** : `keep_distance` ne prend qu'**un** `player_pos` → en **coop**,
  écarter la bombe du joueur le plus proche peut la pousser **sur un coéquipier**. Fix symétrique
  à faire (itérer sur tous les vivants).

---

## 5. Chaîne de défis & déblocages

`content/logic/bomb_challenges.gd` ; injection via extension `challenge_service.gd` ; détection
via extension `run_data.gd → add_weapon()` (l'entonnoir unique de toute acquisition).

- **Verrouillage 100 % natif** : `unlocked_by_default = false` sur les 12 `.tres` d'armes bombe
  concernées. Déblocage effectif **à la run suivante** (comportement vanilla).
- **CHAÎNE** (monter une bombe au **tier IV** débloque la suivante) :
  **Bombe IV → Glace**, **Glace IV → Foudre**, **Foudre IV → Poison** (fin de chaîne).
- **COLLECTION** : détenir les **4 bombes EN MÊME TEMPS** (tiers indifférents) → débloque la
  **Bombe sangsue** (`unlocks_leech`). Immobilise 4 des 6 slots = sacrifice de build délibéré.
- ⚠️ **Aucun succès Steam** possible (déclarés côté éditeur) → tout passe par le `ChallengeService`
  interne, `complete_challenge(hash, false)` (le `false` coupe l'appel plateforme).
- **Migration** (le mod écrit dans la **sauvegarde permanente**) : pour un joueur qui possédait
  déjà les bombes avant l'ajout des défis, un **popup maison** (`content/ui/bomb_migration_popup.gd`)
  propose **en SOLO uniquement** de les reverrouiller (vivre la chaîne) ou de les garder (marque les
  défis comme complétés). Câblé dans l'extension `character_selection.gd`, en écoutant le signal
  `coop_initialized` du bouton coop. Choix **définitif**.

---

## 6. Le magasin filtré (roster Bomberto)

`content/logic/shop_pool.gd` ; appliqué via extension `item_service.gd`.

Le vanilla ne sait pas bannir une **arme** par ID (`banned_items` ne vaut que pour les objets) → on
filtre nous-mêmes le pool d'armes de la boutique de Bomberto. Une arme est **conservée** si :
1. son `weapon_id` commence par `weapon_bomb` (bombes standard + élémentaires), **OU**
2. elle appartient au set `set_explosive`, **OU**
3. c'est une arme de **mêlée** avec **knockback ≥ 20** (les armes à distance à fort knockback —
   sniper, lance-patates — sont **exclues**, hors thème).

---

## 7. Points d'intégration technique

Extensions ModLoader déclarées dans `mod_main.gd` :

| Script vanilla étendu | Rôle |
|---|---|
| `singletons/item_service.gd` | filtre le pool d'armes boutique (§6) ; expose le contenu du mod |
| `singletons/challenge_service.gd` | injecte les `ChallengeData` de la chaîne (§5) |
| `singletons/run_data.gd` | détecte l'acquisition d'armes (`add_weapon`) pour les défis (§5) |
| `ui/menus/run/character_selection.gd` | popup de migration (§5) |
| `particles/burning/burning_particles.gd` | feu vert du poison (§3.4) |

⚠️ **Collision avec ShopConfig** : ShopConfig étend AUSSI `character_selection.gd`. Deux pièges
attrapés : (a) un `const` homonyme entre extensions casse le mod chargé en second (d'où
`BombermanModLog`) ; (b) l'empilement fait tourner le `_ready()` vanilla **deux fois** → tout ajout
additif doit être idempotent.

---

## 8. Architecture — index de la logique pure

Tout ce qui est **testable en headless** est isolé sans dépendance aux autoloads (`extends
Reference`, temps/hasard **injectés**). Le test-runner ne charge **jamais** `bomb_weapon.gd`
→ après toute modif de ce fichier, vérifier qu'aucune « parse/compile error » ne sort du runner.

| Module (`content/logic/`) | Responsabilité |
|---|---|
| `bomb_element.gd` | élément d'une bombe d'après son `weapon_id` ; normal vs « à effet » |
| `bomb_timing.gd` | durée de mèche par tier, scaling vitesse d'attaque, déphasage par slot |
| `bomb_placement.gd` | angle d'or + éventail refermable, mobilité par déplacement net |
| `bomb_ice_slow.gd` | vitesse cible non cumulative (glace) |
| `poison_fire.gd` | détection source poison + dégradés de feu verts |
| `bomb_leech.gd` | drain + seau à jetons par joueur (sangsue) |
| `bomb_challenges.gd` | chaîne (tier IV) + collection (4 bombes) + bombes non gagnées |
| `troll_bomb_logic.gd` | réveil, cible, déplacement, dégâts non létaux, anti-visage |
| `shop_pool.gd` | roster d'armes autorisées en boutique |
| `bomb_skin.gd` / `animated_icon.gd` / `explosion_visual.gd` | habillage visuel |
| `mod_log.gd` | logger désactivable (`debug_log`, défaut `false`) |

---

## Statut de release

- **Workshop public** : item `3752197886`, version **2.0.0** (refonte de la pose). Le TEST COOP
  reste le grand manquant du mod.
- **Historique** : v1.4.0 mergée dans `master` ; lignée bombes élémentaires (1.7→1.9) + pose (2.0)
  publiée mais **non mergée** dans `master`.
- **En cours** : **Bombe sangsue** (branche `feat/bombe-sangsue`), code-complète, en test en jeu.
