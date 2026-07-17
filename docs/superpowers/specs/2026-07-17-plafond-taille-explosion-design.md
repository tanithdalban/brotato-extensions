# Plafond de taille d'explosion des bombes — Design

**Date :** 2026-07-17
**Mod :** Tanith-Bomberman
**Statut :** spec validée en brainstorming, prête pour le plan.

## Problème

La taille d'explosion des bombes de Bomberto croît **sans borne** et finit par couvrir toute la map, voire plus.

Cause, confirmée dans le code :
- Bomberto porte un effet global « **+5 `explosion_size` par point d'élémentaire** » (`content/characters/bomberman/effect_explosion_size_per_elemental.tres` : `gain_stat_for_every_stat_effect`, `key = explosion_size`, `value = 5`, `stat_scaled = stat_elemental_damage`).
- L'explosion vanilla applique cette stat au rayon (`projectiles/player_explosion.gd:70-73`) :
  ```gdscript
  func set_area(p_area):
      var explosion_scale = max(0.1, p_area + p_area * (Utils.get_stat(Keys.explosion_size_hash, player_index) / 100.0))
      scale = Vector2(explosion_scale, explosion_scale)
  ```
  Le rayon final = `échelle_de_base × (1 + explosion_size/100)`.
- L'élémentaire monte **sans plafond** en fin de partie — notamment via l'objet vanilla « +1 élémentaire tous les 30 ennemis brûlants ». À 100 élém l'échelle est ×6, à 300 élém ×16 (toute la map).

Ça touche **toutes** nos bombes qui explosent (elles passent toutes par `set_area`), y compris chaque fragment de la Frag.

## Distinction importante (relevée au test)

Deux « zones » différentes pour la Frag, à ne pas confondre :
1. **Étalement des fragments** (où ils retombent) = `FRAG_SCATTER_RADIUS = 150 px`, **constant**, indépendant de `explosion_size`. **Non concerné par cette spec.**
2. **Rayon d'explosion de chaque bombe** (le souffle) = grossit avec `explosion_size`. **C'est l'objet du plafond.** Le principal coupable visible est la bombe **normale** (base 1,5) ; les fragments partent si petits (base 0,35) que leur grossissement passe inaperçu, mais il existe aussi.

## Objectif

Aucune explosion de bombe Bomberto ne dépasse **512 px de rayon** = **25 % de la largeur de la map de départ classique** (zone 1 = 32×24 tuiles × 64 px = 2048×1536). Le plafond est une **constante fixe** (basée sur la map classique), **pas** recalculée selon la zone courante.

Comportement voulu : **plateau**. L'élémentaire continue d'agrandir les explosions jusqu'au plafond, puis la taille cesse de croître. Prévisible et lisible.

## Approche : plafonner le FACTEUR de grossissement (pas la taille absolue)

On borne le facteur `(1 + explosion_size/100)`, commun à toutes nos bombes — et **non** chaque explosion à une taille absolue.

- **Constante** : `MAX_EXPLOSION_GROWTH = 2.32`.
  - Dérivation : la bombe normale non buffée fait **221 px** (échelle de base 1,5 × 147,34 px de rayon d'explosion vanilla à l'échelle 1). Plafond 512 px ⇒ facteur max = 512 / 221 ≈ **2,32**. Équivaut à borner l'`explosion_size` effectif à ~132.
- **Pourquoi le facteur et pas l'absolu** : comme le facteur est commun, la bombe normale (base 1,5, la plus grosse) plafonne à 512 px, et les **fragments restent proportionnellement petits** (base 0,35 → 0,35 × 2,32 × 147,34 ≈ **119 px** au maximum). Un plafond en taille absolue laisserait au contraire chaque fragment grossir jusqu'à 512 px en fin de partie → un tapis de gros cercles couvrant la map à nouveau.

### Où et comment

Dans `content/entities/bomb_entity.gd`, **juste après** `WeaponService.explode(...)` (là où on plafonne déjà l'opacité via `ExplosionVisual.cap_aoe_opacity`), clamper l'échelle de l'instance d'explosion :

```
_inst.scale = min(_inst.scale, _explosion_scale × MAX_EXPLOSION_GROWTH)  (par composante)
```

`_explosion_scale` est la base de CETTE bombe (déjà un membre de `bomb_entity` : 1,5 normale, 0,5 obus Frag, 0,35 fragment). Après `set_area`, `_inst.scale = _explosion_scale × (1 + explosion_size/100)` ; clamper à `_explosion_scale × MAX_EXPLOSION_GROWTH` revient exactement à borner le facteur.

### Logique pure testable

Le calcul du clamp part en **helper pur** dans `content/logic/explosion_visual.gd` (à côté de `cap_aoe_opacity`), pour rester testable en headless comme le reste du mod :

- `ExplosionVisual.cap_growth_scale(current_scale: Vector2, base_scale: float) -> Vector2`
  - retourne `Vector2(min(current_scale.x, base_scale × MAX_EXPLOSION_GROWTH), min(current_scale.y, base_scale × MAX_EXPLOSION_GROWTH))`.
  - `MAX_EXPLOSION_GROWTH` = constante du module.
- `bomb_entity` appelle ce helper sur `_inst.scale` après l'explosion (comme il appelle déjà `cap_aoe_opacity`).

⚠️ **Contrôle obligatoire** : les tests ne chargent jamais `bomb_entity.gd` → après modif, grep de la sortie du runner sur `parse error|compile error|cyclic|bomb_entity` doit être vide.

## Portée

- **Concernées** : toutes nos bombes qui explosent — normale, glace, poison, sangsue, obus Frag, fragments. Les bombes à effet font 0 dégât mais appliquent leurs effets (slow, DOT, drain) **dans la zone d'explosion** : un champ grand comme la map serait tout aussi cassé, donc les borner est voulu.
- **Non concernées** : la **foudre** (pas d'explosion, tire des éclairs). L'**étalement des fragments** (150 px, constant).
- **Intouché** : les explosions vanilla (autres persos, DLC) et la **stat globale `explosion_size` du joueur** (elle continue de servir partout ailleurs). On ne clampe que l'échelle de NOS instances d'explosion.

## Réglage

- `MAX_EXPLOSION_GROWTH = 2.32` — la seule valeur d'équilibrage. La monter agrandit le plafond ; la descendre le resserre.
- Repères : facteur 2,32 → 512 px (normale) / 119 px (fragment). Sans plafond, la normale atteignait plusieurs milliers de px.
- **Seuil en jeu** : le plateau est atteint à `explosion_size = 132`, soit **~27 points d'élémentaire** (Bomberto gagne +5 `explosion_size`/élém ; tout objet donnant de l'`explosion_size` à plat abaisse ce seuil). C'est assez tôt en fin de partie, mais assumé : l'élémentaire au-delà continue de booster le reste (DOT poison, dégâts foudre…), et on n'a pas toujours l'objet qui fait exploser l'élémentaire.
- **Sources d'`explosion_size` couvertes** : le plafond agit sur le facteur **total**, quelle que soit l'origine de l'`explosion_size`. Il couvre donc AUSSI les objets qui en donnent à plat — notamment le **Pot de miel** (`items/all/honey` : +5 `explosion_size` par copie, en plus de +10 `explosion_damage`). Chaque copie de Pot de miel = +5 `explosion_size` = l'équivalent d'1 point d'élémentaire pour la taille (5 copies → plateau à ~21 élém au lieu de 27). Son `explosion_damage` touche les dégâts, pas la taille : hors périmètre, et sans effet sur le rayon.

## Hors périmètre

- Modifier l'effet `explosion_size`-par-élémentaire lui-même (on le laisse, il sert au ressenti jusqu'au plafond).
- Recalculer le plafond selon la zone/map courante (on fige sur la map classique, choix utilisateur).
- Toucher à l'étalement des fragments.
