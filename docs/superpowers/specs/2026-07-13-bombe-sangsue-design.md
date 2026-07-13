# Bombe sangsue — design

**Date** : 2026-07-13
**Mod** : Tanith-Bomberman
**Statut** : validé, prêt pour le plan d'implémentation

## Intention

Une **5ᵉ bombe**, la **Bombe sangsue** (`weapon_bomb_leech`) : elle ne fait pas de
dégâts d'explosion, elle **draine**. Chaque ennemi pris dans le souffle peut se voir
retirer des PV, qui sont **transférés au joueur**.

C'est une arme de **survie**, pas de DPS, et une arme **de build** : sa puissance est
pilotée par la stat **vol de vie** du joueur, donc elle récompense un investissement
que rien d'autre dans le mod ne récompensait.

## Le vol de vie vanilla (état des lieux)

Compris avant de concevoir, parce que ça contraint tout le reste.

- La stat `stat_lifesteal` est convertie en **chance de proc par coup porté** :
  `weapon_service.gd:259-260` fait `new_stats.lifesteal += Utils.get_stat(...) / 100.0`,
  **et seulement si `not is_structure`**. 1 point de stat = 1 % de chance.
- À chaque hit, `RunData.manage_life_steal()` (`run_data.gd:1375`) tire `randf() < lifesteal`.
  En cas de succès : **1 PV** (2 avec l'effet `double_lifesteal_bonus`). Le soin est
  **forfaitaire**, jamais proportionnel aux dégâts.
- Le soin passe par `player.gd:734`, gardé par le `LifestealTimer` (**0,1 s**, one-shot) :
  tout proc qui tombe pendant que le timer tourne est **jeté** (pas de file d'attente).
  D'où le plafond réel de **10 PV/s** — et le « 10 » codé en dur dans l'infobulle
  (`item_service.gd:840`).
- Aucune arme vanilla ne rend jamais **plus d'1 PV par proc**. Ce qui varie d'une arme à
  l'autre, c'est uniquement le `lifesteal` de base : pistolet médical 50 % → 65 %,
  ciseaux 40 % → 60 %, scie circulaire 60 % en T4, faux 100 % en T4.

**La conséquence décisive** : une explosion touche tous ses ennemis **dans la même frame**.
Réutiliser le vol de vie vanilla tel quel ferait donc rendre **1 PV maximum par explosion**,
quel que soit le nombre d'ennemis — le timer de 0,1 s jetterait tous les autres procs. Le
fantasme « je fais péter une nuée et je me régénère » serait mort-né. Notre bombe doit donc
faire son propre soin.

## Mécanique

À l'explosion, pour **chaque ennemi touché** (signal `hit_something` de l'explosion, qui est
émis **même à 0 dégât** — c'est déjà ce qui fait marcher le slow de la glace) :

1. **Tirage** : `randf() < _stats.lifesteal`. Cette valeur porte **déjà**
   `vol de vie de base de la bombe + stat du joueur / 100`, calculée par le vanilla sur le
   chemin de l'arme **tenue** (`is_structure = false`, cf. `bomb_weapon.gd:217-218`, qui passe
   `current_stats` à `bomb.arm()`). **Rien à recalculer.**
2. **Drain** : en cas de proc, on retire N PV à l'ennemi via
   `take_damage(N, args)` avec `TakeDamageArgs.new(player_index, null)`,
   `armor_applied = false` et `dodgeable = false`. L'armure ne mange pas le drain
   (`unit.gd:502` : `result.value = dmg_value` si `armor_applied` est faux) ; le `hitbox = null`
   neutralise crit et recul. **Drain sec.**
3. **Soin** : on rend **les mêmes N PV** au joueur, par notre propre appel de soin — donc
   **sans** passer par le `LifestealTimer`, qui sinon écraserait tous les procs de la frame
   sauf un.
4. **Budget** : on décrémente un **budget de PV par explosion**. Budget épuisé → les ennemis
   suivants du même souffle ne sont plus drainés.

**N vaut 1** (2 si le joueur a `double_lifesteal_bonus`), aligné sur le vanilla. Le budget étant
compté **en PV** et non en procs, l'item « double vol de vie » fait atteindre le plafond avec
moins d'ennemis mais **ne le perce pas**.

**Écrêtage** : N est toujours **borné par le budget restant**. Si le budget restant est de 1 PV
et qu'un proc « double » vaudrait 2, alors on draine **1** (1 PV volé à l'ennemi, 1 PV rendu au
joueur). Le drain infligé et le soin reçu sont **toujours égaux** — c'est l'invariant du design.

**Conséquence assumée** : *1 PV volé = 1 dégât infligé*. La bombe sangsue inflige donc des
dégâts dérisoires (~5 sur une explosion pleine). C'est voulu : elle reste cohérente avec la
convention des bombes à effet, et le canal de dégâts du drain **ne passe ni par
`explosion_damage`, ni par les crits, ni par les bonus de Bomberto** — seule la stat de vol de
vie le fait grandir. C'est le garde-fou d'équilibrage central de ce design.

## Chiffres

| Tier | Vol de vie de base | Plafond PV / explosion |
|---|---|---|
| I | 40 % | 3 |
| II | 50 % | 4 |
| III | 55 % | 5 |
| IV | 65 % | 6 |

Base calée sur le pistolet médical (50 % → 65 %). À T4 sans aucun item de vol de vie, une
explosion sur ~9 ennemis atteint le plafond de 6 PV.

Le plafond par explosion est la **manette d'équilibrage principale**, parce que notre bombe est
un cas que le vanilla n'a jamais eu : elle ne proc pas *dans le temps* (pistolet médical ≈ 0,9 PV/s),
elle proc **N fois d'un coup**. Sans plafond, une explosion sur une horde de fin de vague avec une
build vol de vie rendrait la barre entière.

## Déblocage

La Bombe sangsue est la **récompense de la collection**, pas un maillon de la chaîne des tiers :
le défi `chal_bomb_leech` se complète dès que l'inventaire d'un joueur contient **simultanément
les 4 bombes** (normale, glace, foudre, poison), **quel que soit leur niveau**.

Tenir les 4 bombes immobilise **4 des 6 slots d'arme** : c'est un sacrifice de build délibéré.

- Le **Poison reste la fin de `CHAIN`** (sa montée en tier IV ne débloque rien).
- On ajoute `chal_bomb_leech → weapon_bomb_leech` à **`REWARD`**, ce qui suffit pour que le popup
  de migration (`unearned_bombs`, qui itère sur `REWARD`) la couvre sans code supplémentaire.
- Le point d'accroche reste **`add_weapon`** (entonnoir unique : fusion, achat direct d'un tier IV,
  arme de départ). Après l'appel parent, on relit `players_data[player_index].weapons` et on vérifie
  la présence des 4 `weapon_id`.

### Extension prévue (hors périmètre)

Une **6ᵉ et dernière bombe** viendra plus tard, débloquée par **Sangsue IV**. Rien à coder
maintenant : `CHAIN` est déjà le mécanisme exact pour ça (il suffira d'y ajouter une entrée
`"weapon_bomb_leech"`). Ce design ne ferme pas cette porte.

## Découpage du code

- **`content/logic/bomb_leech.gd`** *(nouveau, pur, testé)* : tirage, montant par proc, budget
  d'explosion. Aucune dépendance aux autoloads → testable en headless. Toute la logique décidable
  vit ici.
- **`content/logic/bomb_element.gd`** : constante `LEECH` + entrée dans `_BY_WEAPON_ID`.
  `is_effect()` → vrai, donc **0 dégât d'explosion AoE et jamais de troll bombe**.
- **`content/entities/bomb_entity.gd`** : une connexion de plus dans `_on_fuse_timeout`, calquée sur
  celle de la glace, en passant un **budget frais à chaque explosion**.
- **`content/weapons/bomb/bomb_weapon.gd`** : `on_leech_hit(thing_hit, _damage_dealt, budget)`, voisin
  de `on_ice_hit` — même **duck-typing** (`current_stats`/`max_stats` présents), donc compatible
  vanilla/DLC/autres mods **sans étendre `enemy.gd`**.
- **`content/logic/bomb_challenges.gd`** : `LEECH_REQUIRED` + `unlocks_leech(weapon_ids) -> bool` ;
  entrée dans `REWARD`.
- **Extension `singletons/run_data.gd`** : `_try_complete_bomb_challenge` appelle `unlocks_leech` en
  plus de `challenge_for`.
- **Contenu** : les 4 `.tres` de tiers, le skin, l'entrée au pool de boutique, les traductions FR/EN.

## Ce qu'on ne touche pas

Aucune extension de `enemy.gd`, `unit.gd`, `player.gd`, ni du vol de vie vanilla. Le `LifestealTimer`
du jeu reste **intact pour toutes les autres armes** : on ne le contourne que dans notre propre chemin
de soin, pour notre bombe.

## Tests

Le runner ne charge jamais `bomb_weapon.gd` (⚠️ après toute modif, vérifier qu'aucune « parse/compile
error » ne sort du runner). Les tests couvrent donc le **pur** :

- `bomb_leech.gd` : proc et non-proc avec un **dé injecté** (déterminisme), montant par proc (1, et 2
  avec le bonus double), décrément du budget, **plafond jamais dépassé**, budget à 0 → plus aucun drain.
- `bomb_challenges.gd` : `unlocks_leech` → 4 bombes = vrai ; 3 bombes = faux ; **doublons de la même
  bombe = faux** ; tiers mélangés = vrai. Et le Poison ne complète toujours rien via `CHAIN`.

Le reste — drain réel sur l'ennemi, soin effectif, feedback visuel, équilibrage — se vérifie **en jeu**.
