# Bombe de Foudre (Phase 4) — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter la 3e bombe élémentaire au Bomberto — une **Bombe de Foudre** (4 tiers) qui, à la détonation, tire un **burst d'éclairs en cercle** (façon item Tyler) **sans explosion AoE** ; les dégâts sont portés par les projectiles.

**Architecture:** Les 4 bombes de foudre partagent `bomb.tscn` / `bomb_weapon.gd` / `bomb_entity.gd` avec les autres bombes ; elles ne diffèrent que par leurs `.tres`, leur sprite (`storm.png`, constant I→IV), et l'**élément** `storm` déduit du `weapon_id`. Toute la plomberie élément-aware existe déjà (Phase 2 Glace) : `bomb_element.gd` connaît déjà `STORM`, `shop_pool.gd` accepte déjà le préfixe `weapon_bomb`, `item_service._register_bomb_weapon()` est générique, et `bomb_weapon.gd` passe déjà l'élément + `self` (le `from` persistant) à `bomb.arm(...)`. Le seul comportement neuf : une branche `STORM` dans `bomb_entity._on_fuse_timeout()` qui **court-circuite `explode()`** et boucle `WeaponService.spawn_projectile()` (même appel que `turret._spawn_projectile`).

**Tech Stack:** Godot 3.6.2 / GDScript, ModLoader (script extensions), test-runner GDScript autonome.

## Global Constraints

- **Tout en français** : commentaires, docs, libellés de commits. Libellés UI bilingues FR/EN.
- **Aucun fichier `.tscn`** créé : la foudre réutilise `bomb.tscn` existant.
- **Chargement des sprites au runtime** (`Image.load`, hors cache d'import Godot), comme `bomb_skin.gd`. Pas de `.import`/`.stex` à générer pour `storm.png`.
- **Aucune nouvelle extension de code vanilla** : on garde uniquement les extensions existantes. Le burst passe par l'autoload public `WeaponService.spawn_projectile()`.
- **`weapon_id` de la foudre** : `weapon_bomb_storm` (partagé par les 4 tiers) ; `my_id` = `weapon_bomb_storm_1..4`.
- **Clés i18n** : `WEAPON_BOMB_STORM` (nom) + `WEAPON_BOMB_STORM_BOLTS` (ligne d'infobulle « nb éclairs »).
- **Skin constant I→IV** : un seul sprite `storm.png` (= `stormbomb_4.png`, 150×150 RGBA déjà carré). Le tier se lit via le disque coloré (icône boutique) + le contour vanilla (arme tenue) — **pas** de sprite par tier.
- **Détonation = éclairs SEULS** : pas d'explosion visuelle, pas de boom AoE, pas de dégât de zone. Décision validée en session (2026-07-09).
- **Valeurs d'équilibrage (nb_projectiles, damage, value, cooldown) = PLACEHOLDERS à caler en jeu.** Point de départ : base item Tyler graduée par tier. L'utilisateur équilibrera pendant les tests.
- **Réf. décompilé** : `entities/structures/turret/turret.gd:88-118` (patron `shoot()` / `_spawn_projectile` : boucle `for i in stats.nb_projectiles`, `rand_range(rot ± spread)`), `singletons/weapon_service.gd:366` (`spawn_projectile(pos, stats, direction, from, args)`), `entities/structures/turret/tyler/tyler_stats.tres` (nb=10, spread=3.142, piercing=2, can_bounce, proj_speed=2000, scaling ingé 0.9 + élém 0.9, `projectile_scene=delayed_lightning_projectile.tscn`), `effects/weapons/null_effect.gd` (effet d'affichage pur, sans gameplay).
- **Runner de tests Bomberman** (≠ `./run-tests.sh` de ShopConfig) :
  ```
  "./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
  ```
  Depuis la racine du repo (Git Bash). Résultat = ligne `=== N tests, M échec(s) ===` ; viser `0 échec(s)`. Les erreurs moteur APRÈS cette ligne = teardown des autoloads, sans effet.

---

### Task 1: Asset `storm.png` + chemin skin par élément

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/storm.png` (copie de `screens/stormbomb_4.png`, 150×150 RGBA)
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Consumes: `BombSkin.element_sprite_path(element: String) -> String` (existant), `ShopPool.is_allowed(weapon)` (existant, accepte déjà le préfixe `weapon_bomb`).
- Produces: `element_sprite_path("storm")` renvoie le chemin de `storm.png`.

- [ ] **Step 1: Copier l'asset**

```bash
cp screens/stormbomb_4.png Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/storm.png
```
Vérifier: `python -c "from PIL import Image; im=Image.open('Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/storm.png'); print(im.size, im.mode)"` → attendu `(150, 150) RGBA`.

- [ ] **Step 2: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, fonction existante `_test_bomb_skin_element()` (vers la ligne 133), ajouter avant sa dernière ligne :
```gdscript
	var storm_path = BombSkin.element_sprite_path("storm")
	_check(storm_path.ends_with("storm.png"), "skin: storm -> storm.png")
```
Et dans la fonction de test du pool (celle qui contient `"pool: weapon_bomb_ice accepté (préfixe)"`, vers la ligne 119), ajouter :
```gdscript
	_check(ShopPool.is_allowed(_StubWeapon.new("weapon_bomb_storm", [], 0, 1)), "pool: weapon_bomb_storm accepté (préfixe)")
```
(Le mapping élément `weapon_bomb_storm => STORM` est **déjà** testé dans `_test_bomb_element()`, ligne 225 — ne rien y ajouter.)

- [ ] **Step 3: Lancer les tests pour vérifier l'échec**

Run: `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected: FAIL sur `"skin: storm -> storm.png"` (l'élément `storm` retombe sur le repli `bombe_normale.png`). Le test pool storm passe déjà (préfixe) — c'est un filet de non-régression.

- [ ] **Step 4: Écrire l'implémentation**

Dans `content/logic/bomb_skin.gd`, dans la constante `_SPRITE_PATHS`, ajouter la ligne `storm` :
```gdscript
const _SPRITE_PATHS := {
	"normal": _BOMB_DIR + "/bombe_normale.png",
	"ice": _BOMB_DIR + "/glace.png",
	"storm": _BOMB_DIR + "/storm.png",
}
```
Et mettre à jour le commentaire juste au-dessus (`# Poison/foudre viendront aux phases suivantes.`) pour retirer « foudre » (il ne reste que le poison).

- [ ] **Step 5: Lancer les tests pour vérifier le succès**

Run: (même commande qu'au Step 3)
Expected: `=== N tests, 0 échec(s) ===` (N = ancien total + 2).

- [ ] **Step 6: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/storm.png Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): skin bombe de foudre (storm.png) + tests headless storm"
```

---

### Task 2: i18n — `WEAPON_BOMB_STORM` + `WEAPON_BOMB_STORM_BOLTS`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd`

**Interfaces:**
- Produces: clés de traduction `WEAPON_BOMB_STORM` (nom d'arme) et `WEAPON_BOMB_STORM_BOLTS` (ligne d'infobulle, `{0}` = nb d'éclairs) en EN et FR. Consommées par les `.tres` de la Task 3 (`name` + `NullEffect.text_key`).

- [ ] **Step 1: Ajouter les messages EN**

Dans `register()`, après `tr_en.add_message("WEAPON_BOMB_ICE_SLOW", "Slows enemies by {0}%")` :
```gdscript
	tr_en.add_message("WEAPON_BOMB_STORM", "Storm Bomb")
	tr_en.add_message("WEAPON_BOMB_STORM_BOLTS", "Strikes with {0} lightning bolts")
```

- [ ] **Step 2: Ajouter les messages FR**

Après `tr_fr.add_message("WEAPON_BOMB_ICE_SLOW", "Ralentit les ennemis de {0}%")` :
```gdscript
	tr_fr.add_message("WEAPON_BOMB_STORM", "Bombe de Foudre")
	tr_fr.add_message("WEAPON_BOMB_STORM_BOLTS", "Frappe en {0} éclairs")
```

- [ ] **Step 3: Mettre à jour le commentaire d'en-tête**

Dans le bloc de commentaire « Clés fournies » (haut du fichier), après la ligne `WEAPON_BOMB_ICE_SLOW`, ajouter :
```
#   WEAPON_BOMB_STORM       — nom de la Bombe de Foudre
#   WEAPON_BOMB_STORM_BOLTS — ligne d'infobulle « nb éclairs » (via NullEffect,
#                             {0} = nb_projectiles du tier)
```

- [ ] **Step 4: Vérif statique**

```bash
grep -n "WEAPON_BOMB_STORM" Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd
```
Attendu : 4 occurrences (STORM en+fr, STORM_BOLTS en+fr).

- [ ] **Step 5: Non-régression**

Run: `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected: `0 échec(s)` (inchangé vs Task 1 — le runner ne charge pas ce fichier, mais ne doit pas régresser).

- [ ] **Step 6: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd
git commit -m "feat(bomberman): i18n WEAPON_BOMB_STORM (+ ligne éclairs) FR/EN"
```

---

### Task 3: Données des 4 bombes de foudre (`.tres`)

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_1_stats.tres` … `bomb_storm_4_stats.tres`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_1_data.tres` … `bomb_storm_4_data.tres`

**Interfaces:**
- Consumes: `WEAPON_BOMB_STORM` / `WEAPON_BOMB_STORM_BOLTS` (Task 2), la scène vanilla `delayed_lightning_projectile.tscn`.
- Produces: 4 `WeaponData` (`weapon_id = "weapon_bomb_storm"`, `my_id = weapon_bomb_storm_1..4`, tiers 0..3, chaîne `upgrades_into` 1→2→3→4, set `explosive`, effet d'affichage `NullEffect` = nb éclairs) + 4 `RangedWeaponStats` (`projectile_scene = delayed_lightning_projectile.tscn`, `nb_projectiles`/`damage` gradués, `projectile_spread = 3.142`). Consommés par `item_service.gd` (Task 5) et `bomb_entity.gd` (Task 4).

**Note test:** ces `.tres` référencent des scripts/scènes vanilla + autoloads → **non chargeables en headless**. Vérification = **checks statiques** (Step 3) + **en jeu** (Task 6). Ne PAS les `preload` dans le runner.

**Tableau des valeurs (PLACEHOLDERS à caler en jeu — base Tyler graduée) :**

| tier | fichier | `tier` | `value` | `cooldown` | `damage` | `nb_projectiles` |
|------|---------|--------|---------|------------|----------|------------------|
| I    | `bomb_storm_1` | 0 | 20  | 90 | 8  | 6  |
| II   | `bomb_storm_2` | 1 | 39  | 80 | 10 | 7  |
| III  | `bomb_storm_3` | 2 | 74  | 70 | 12 | 8  |
| IV   | `bomb_storm_4` | 3 | 149 | 60 | 14 | 10 |

Constants sur les 4 tiers : `projectile_spread = 3.142`, `piercing = 2`, `can_bounce = true`, `projectile_speed = 2000`, `crit_damage = 2.0`, `scaling_stats = [ [ "stat_engineering", 0.9 ], [ "stat_elemental_damage", 0.9 ] ]`, `speed_percent_modifier = 0`.

- [ ] **Step 1: Créer les 4 fichiers de stats**

`bomb_storm_1_stats.tres` (tier I) :
```
[gd_resource type="Resource" load_steps=3 format=2]

[ext_resource path="res://weapons/weapon_stats/ranged_weapon_stats.gd" type="Script" id=1]
[ext_resource path="res://projectiles/bullet_lightning/delayed_lightning_projectile.tscn" type="PackedScene" id=2]

[resource]
script = ExtResource( 1 )
cooldown = 90
damage = 8
accuracy = 1.0
crit_chance = 0.0
crit_damage = 2.0
min_range = 0
max_range = 500
knockback = 0
knockback_piercing = 0.0
can_have_positive_knockback = false
can_have_negative_knockback = false
effect_scale = 1.0
scaling_stats = [ [ "stat_engineering", 0.9 ], [ "stat_elemental_damage", 0.9 ] ]
lifesteal = 0.0
shooting_sounds = [  ]
sound_db_mod = -5
is_healing = false
recoil = 0
recoil_duration = 0.1
additional_cooldown_every_x_shots = -1
additional_cooldown_multiplier = -1.0
speed_percent_modifier = 0
nb_projectiles = 6
projectile_spread = 3.142
piercing = 2
piercing_dmg_reduction = 0.0
bounce = 0
bounce_dmg_reduction = 0.0
can_bounce = true
projectile_speed = 2000
increase_projectile_speed_with_range = false
projectile_scene = ExtResource( 2 )
```
`bomb_storm_2_stats.tres` : identique mais `cooldown = 80`, `damage = 10`, `nb_projectiles = 7`.
`bomb_storm_3_stats.tres` : `cooldown = 70`, `damage = 12`, `nb_projectiles = 8`.
`bomb_storm_4_stats.tres` : `cooldown = 60`, `damage = 14`, `nb_projectiles = 10`.

- [ ] **Step 2: Créer les 4 fichiers de data**

`bomb_storm_1_data.tres` (tier I, `upgrades_into` → tier II) :
```
[gd_resource type="Resource" load_steps=9 format=2]

[ext_resource path="res://items/global/weapon_data.gd" type="Script" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=2]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn" type="PackedScene" id=3]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_1_stats.tres" type="Resource" id=4]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_2_data.tres" type="Resource" id=5]
[ext_resource path="res://items/sets/explosive/explosive_set_data.tres" type="Resource" id=6]
[ext_resource path="res://effects/weapons/null_effect.gd" type="Script" id=7]

[sub_resource type="Resource" id=1]
script = ExtResource( 7 )
key = "stat_elemental_damage"
text_key = "WEAPON_BOMB_STORM_BOLTS"
value = 6
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [  ]

[resource]
script = ExtResource( 1 )
my_id = "weapon_bomb_storm_1"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "WEAPON_BOMB_STORM"
tier = 0
value = 20
effects = [ SubResource( 1 ) ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
weapon_id = "weapon_bomb_storm"
type = 1
sets = [ ExtResource( 6 ) ]
scene = ExtResource( 3 )
stats = ExtResource( 4 )
upgrades_into = ExtResource( 5 )
add_to_chars_as_starting = [  ]
```
`bomb_storm_2_data.tres` : idem mais `my_id = "weapon_bomb_storm_2"`, `tier = 1`, `value = 39`, `NullEffect value = 7`, `id=4` → `bomb_storm_2_stats.tres`, `id=5` → `bomb_storm_3_data.tres`.
`bomb_storm_3_data.tres` : `my_id = "weapon_bomb_storm_3"`, `tier = 2`, `value = 74`, `NullEffect value = 8`, `id=4` → `bomb_storm_3_stats.tres`, `id=5` → `bomb_storm_4_data.tres`.

`bomb_storm_4_data.tres` (tier IV, **PAS** d'`upgrades_into`) — retirer l'ext_resource `id=5` (data suivant), décaler les IDs suivants (explosive_set → `id=5`, null_effect → `id=6`), `load_steps=8` :
```
[gd_resource type="Resource" load_steps=8 format=2]

[ext_resource path="res://items/global/weapon_data.gd" type="Script" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=2]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn" type="PackedScene" id=3]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_4_stats.tres" type="Resource" id=4]
[ext_resource path="res://items/sets/explosive/explosive_set_data.tres" type="Resource" id=5]
[ext_resource path="res://effects/weapons/null_effect.gd" type="Script" id=6]

[sub_resource type="Resource" id=1]
script = ExtResource( 6 )
key = "stat_elemental_damage"
text_key = "WEAPON_BOMB_STORM_BOLTS"
value = 10
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [  ]

[resource]
script = ExtResource( 1 )
my_id = "weapon_bomb_storm_4"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "WEAPON_BOMB_STORM"
tier = 3
value = 149
effects = [ SubResource( 1 ) ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
weapon_id = "weapon_bomb_storm"
type = 1
sets = [ ExtResource( 5 ) ]
scene = ExtResource( 3 )
stats = ExtResource( 4 )
add_to_chars_as_starting = [  ]
```

- [ ] **Step 3: Vérifs statiques**

```bash
cd Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb
grep -H "my_id\|weapon_id\|^tier\|^damage\|nb_projectiles\|projectile_scene\|upgrades_into\|load_steps\|projectile_spread" bomb_storm_*_data.tres bomb_storm_*_stats.tres
```
Attendu :
- `weapon_id = "weapon_bomb_storm"` dans les 4 data ; `my_id` = `weapon_bomb_storm_1..4` ; `tier` 0/1/2/3.
- `damage` 8/10/12/14 et `nb_projectiles` 6/7/8/10 dans les stats ; `projectile_spread = 3.142` partout ; `projectile_scene` présent dans les 4 stats.
- `upgrades_into` présent dans data 1/2/3, **ABSENT** dans data 4 ; `load_steps=9` (data 1-3) / `8` (data 4) / `3` (stats).
- Chaque `id=N` référencé (SubResource/ExtResource) existe bien dans son fichier (pas de trou d'ID). Vérifier en particulier que data 4 pointe `sets = [ ExtResource( 5 ) ]` (explosive), `stats = ExtResource( 4 )`, et que le `NullEffect` = `SubResource( 1 )` avec `script = ExtResource( 6 )`.

- [ ] **Step 4: Non-régression headless**

Run: `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected: `0 échec(s)` (inchangé — le runner ne charge pas ces `.tres`).

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_*_data.tres Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_*_stats.tres
git commit -m "feat(bomberman): data des 4 bombes de foudre (éclairs Tyler par tier)"
```

---

### Task 4: Burst d'éclairs dans `bomb_entity.gd`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd`

**Interfaces:**
- Consumes: `BombElement.STORM` (existant), `_stats` (RangedWeaponStats avec `nb_projectiles`/`projectile_spread`/`projectile_scene`/`projectile_speed`, Task 3), `_weapon` (BombWeapon persistante, déjà passée via `arm()`), `_player_index`, `_damage_tracking_key_hash` (existants). L'autoload `WeaponService.spawn_projectile(pos, stats, direction, from, args)` et la classe globale `WeaponServiceSpawnProjectileArgs`.
- Produces: à la détonation d'une bombe `STORM`, `bomb_entity` tire `_stats.nb_projectiles` éclairs en cercle puis se libère, **sans** appeler `WeaponService.explode()`.

- [ ] **Step 1: Brancher STORM dans `_on_fuse_timeout()`**

Dans `content/entities/bomb_entity.gd`, fonction `_on_fuse_timeout()`, juste **après** le garde `if _stats == null:` (le bloc qui `queue_free()` et `return`) et **avant** la ligne `_explode_args.pos = global_position`, insérer :
```gdscript
	# Foudre : pas d'explosion AoE. On tire un burst d'éclairs en cercle (façon
	# item Tyler) puis la bombe disparaît ; les dégâts sont portés par les
	# projectiles, pas par une zone d'explosion.
	if _element == BombElement.STORM:
		_burst_lightning()
		queue_free()
		return
```

- [ ] **Step 2: Ajouter la méthode `_burst_lightning()`**

À la fin de `bomb_entity.gd` (après `_wake_into_troll()`), ajouter :
```gdscript
# Foudre : tire _stats.nb_projectiles projectiles "delayed_lightning" en cercle
# complet (spread ≈ π) depuis la position de la bombe, via le même appel que
# turret._spawn_projectile (WeaponService.spawn_projectile). from = _weapon
# (l'arme persistante) pour l'attribution des dégâts + le player_index. Aucune
# structure ni cooldown de tourelle : un unique burst, puis la bombe se libère.
func _burst_lightning() -> void:
	if _stats == null or not is_instance_valid(_weapon):
		return
	var args := WeaponServiceSpawnProjectileArgs.new()
	args.from_player_index = _player_index
	args.damage_tracking_key_hash = _damage_tracking_key_hash
	# Orientation de base aléatoire : avec spread ≈ π, chaque tir couvre déjà tout
	# le cercle ; la base ne fait que décorréler les bursts successifs.
	var base := randf() * TAU
	for _i in range(int(_stats.nb_projectiles)):
		var rot := rand_range(base - _stats.projectile_spread, base + _stats.projectile_spread)
		args.knockback_direction = Vector2(cos(rot), sin(rot))
		WeaponService.spawn_projectile(global_position, _stats, rot, _weapon, args)
```

- [ ] **Step 3: Vérif statique + parse non-régression**

Le runner ne charge pas `bomb_entity.gd` (dépendances autoloads), mais ne doit pas régresser.
Run: `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected: `0 échec(s)` (inchangé vs Task 3).
Statique :
```bash
grep -n "BombElement.STORM\|_burst_lightning\|spawn_projectile\|WeaponServiceSpawnProjectileArgs" Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd
```
Attendu : la branche STORM dans `_on_fuse_timeout()` (avant le bloc `_explode_args`) + la définition `_burst_lightning()` avec l'appel `WeaponService.spawn_projectile(...)`.

- [ ] **Step 4: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd
git commit -m "feat(bomberman): bomb_entity foudre = burst d'éclairs en cercle (façon Tyler)"
```

---

### Task 5: Enregistrement des 4 armes de foudre — `item_service.gd`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd`

**Interfaces:**
- Consumes: `_register_bomb_weapon(path)` (existant, générique — pose l'icône `(élément, tier)` et injecte l'arme), les `.tres` de foudre (Task 3).
- Produces: les 4 armes de foudre injectées dans `weapons` avec icône `storm` sur disque de rareté.

- [ ] **Step 1: Ajouter la liste des chemins**

Dans `extensions/singletons/item_service.gd`, juste après le bloc `const _BOMB_ICE_WEAPONS := [ ... ]` (vers la ligne 37), ajouter :
```gdscript
const _BOMB_STORM_WEAPONS := [
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_1_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_2_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_3_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_4_data.tres",
]
```

- [ ] **Step 2: Enregistrer les armes de foudre**

Dans `_ready()`, juste après la boucle `for path in _BOMB_ICE_WEAPONS: _register_bomb_weapon(path)`, ajouter :
```gdscript
	for path in _BOMB_STORM_WEAPONS:
		_register_bomb_weapon(path)
```

- [ ] **Step 3: Vérif statique + non-régression**

Run: `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected: `0 échec(s)` (le runner ne charge pas cette extension, mais ne doit pas régresser).
Statique :
```bash
grep -n "_BOMB_STORM_WEAPONS\|_register_bomb_weapon" Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd
```
Attendu : la const `_BOMB_STORM_WEAPONS` (4 chemins) + une 3e boucle `for path in _BOMB_STORM_WEAPONS`.

- [ ] **Step 4: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd
git commit -m "feat(bomberman): enregistre les 4 armes bombe de foudre"
```

---

### Task 6: Vérification EN JEU (humain) + notes

**Files:** aucun (checklist de validation manuelle — les sous-agents ne lancent pas Brotato).

**Setup :** symlinker/copier le dossier du mod dans `mods-unpacked/` à côté du `.pck`, activer `Tanith-DevUnlockAll` si besoin de forcer le perso, lancer Brotato en Bomberto.

- [ ] **FAISABILITÉ CRITIQUE — `from` = arme** : le point le moins sûr du design. Vérifier que `WeaponService.spawn_projectile(pos, _stats, rot, _weapon, args)` avec `_weapon` = la BombWeapon (au lieu d'une tourelle) **spawn bien** les `delayed_lightning_projectile`, qu'ils **infligent des dégâts** attribués au bon joueur, et **ne crashent pas** hors contexte tourelle. Si problème d'attribution, tester une variante (`args.from_player_index` déjà posé ; en dernier recours, passer un autre `from` valide).
- [ ] **Boutique** : la Bombe de Foudre apparaît (icône = `storm.png` sur disque coloré à la rareté ; nom « Bombe de Foudre »/« Storm Bomb ») ; infobulle affiche la ligne « Frappe en N éclairs » ; le pool magasin reste borné au roster Bomberto.
- [ ] **Équipement** : sprite tenu = `storm.png`, constant tous tiers ; contour coloré par tier (highlight vanilla).
- [ ] **Pose + détonation** : la bombe posée = sprite storm ; à la fin de la mèche → **burst d'éclairs en cercle** (pas d'explosion/nuage AoE, pas de dégât de zone) ; **jamais** de trollbombe.
- [ ] **Éclairs** : ~`nb_projectiles` éclairs rayonnent dans toutes les directions ; ils infligent des dégâts scalés (ingé/élém, kit Bomberto) ; montée en puissance sensible I→IV.
- [ ] **Montée en tiers** : upgrade I→IV fonctionne (fusion boutique).
- [ ] **Coop** : chaque joueur voit sa foudre ; dégâts attribués au bon joueur ; pas de contamination entre joueurs.
- [ ] **Anti-épilepsie (éclairs)** : le réglage `explosion_opacity` ne touche PAS les éclairs (projectiles distincts). Si leur clignotement gêne, calibrage ultérieur (baisser `nb_projectiles` ou le `modulate` du projectile) — **hors périmètre de ce plan**.
- [ ] **Équilibrage** : ajuster `damage` / `nb_projectiles` / `value` / `cooldown` dans les `.tres` de la Task 3 selon le ressenti (l'utilisateur équilibrera pendant les tests).

**Après validation en jeu :** mettre à jour la mémoire `brotato-bomberman-sdd-status.md` (Phase 4 Foudre code-complète + validée), puis prévoir la release (bump manifest + changelog) + packaging Workshop.

---

## Notes de portée

- **Poison** : Phase 3 (non traitée ici), son propre plan/session. Ce plan et la Phase 2 Glace ont posé toute la plomberie réutilisable (`bomb_element`, mode bombe à effet de `bomb_entity`, skin par élément, préfixe de pool, `_register_bomb_weapon`, tooltip NullEffect).
- **Double-scaling éventuel** : `_stats` passé au burst est le `current_stats` de l'arme (déjà influencé par les stats joueur), et les `scaling_stats` sont ré-appliqués au hitbox du projectile — même schéma que la Glace pour `explode()`. Si le ressenti en jeu montre un sur-scaling, ajuster les facteurs `scaling_stats` des `.tres` (calibrage, pas un défaut de plomberie).
- **Empilement/croisement des zones de bombes** : idée future déjà notée dans la spec globale, hors périmètre.
