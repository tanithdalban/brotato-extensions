# Bombe de Poison (Phase 3) — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter la 3ᵉ bombe élémentaire au Bomberto — une **Bombe de Poison** (4 tiers) qui, à l'explosion, n'inflige **aucun dégât direct** mais empoisonne les ennemis touchés d'un **DOT (brûlure) scalé sur l'ingénierie**, affiché en **feu vert**.

**Architecture:** Les 4 bombes de poison partagent `bomb.tscn` / `bomb_weapon.gd` / `bomb_entity.gd` avec les autres bombes ; elles ne diffèrent que par leurs `.tres`, leur sprite (`poison.png`), et un **élément** (`poison`) déjà déduit du `weapon_id` par `bomb_element.gd`. Le DOT passe par un **`BurningEffect`** dans `WeaponData.effects` (schéma Torch / Bombe normale : la sérialisation de run ne persiste pas `stats.burning_data`, mais l'effet le reconstitue) avec `scaling_stats = [["stat_engineering", …]]`. **Aucune branche spéciale** dans `bomb_entity` : le poison est une « bombe à effet » (`is_effect` → `_explode_args.damage = 0`, jamais trollbombe) et le `burning_data` transite par le chemin existant (`bomb_entity.gd:113`). Le **feu vert** vient d'une **script extension** de `burning_particles.gd` qui surcharge `_update_color()` uniquement quand la brûlure provient d'une bombe de poison (marqueur : `burning_data.from.weapon_id`).

**Tech Stack:** Godot 3.6.2 / GDScript, ModLoader (script extensions), test-runner GDScript autonome.

## Global Constraints

- **Tout en français** : commentaires, docs, libellés de commits. Libellés UI bilingues FR/EN.
- **Aucun fichier `.tscn`** créé : la bombe réutilise `bomb.tscn` existant.
- **Chargement des sprites au runtime** (`Image.load`, hors cache d'import Godot), comme `bomb_skin.gd`. Pas de `.import`/`.stex` à générer pour `poison.png`.
- **Sprite unique constant** (I→IV) : `poison.png` (copie de `screens/Poison.png`, 150×150 RGBA, fond déjà transparent). Le tier se lit via le contour de rareté (en jeu) et le disque coloré (icône boutique).
- **Feu vert = override** `burning_particles._update_color()`, repli bleu automatique (si `burning_data.from` absent) → **n'altère jamais** la Tourelle enflammée vanilla (même scaling ingénierie, mais `from` ≠ bombe de poison).
- **Starter = OUI** : Bombe de Poison tier I ajoutée aux `starting_weapons` de Bomberto (comme Glace et Foudre).
- **Valeurs du DOT = placeholders** gradués par tier, à caler en jeu.
- **`weapon_id` du poison** : `weapon_bomb_poison` (partagé par les 4 tiers, **déjà mappé** dans `bomb_element.gd` → `POISON`, et **déjà accepté** par `shop_pool.gd` via le préfixe `weapon_bomb`). `my_id` = `weapon_bomb_poison_1..4`.
- **Runner de tests Bomberman** (≠ `./run-tests.sh` de ShopConfig) :
  ```
  "./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
  ```
  Depuis la racine du repo (Git Bash). Résultat = ligne `=== N tests, M échec(s) ===` ; viser `0 échec(s)`. Les erreurs moteur APRÈS cette ligne = teardown des autoloads, sans effet.
- Réf. décompilé : `weapon.gd:151` (`current_stats.burning_data.from = self`), `unit.gd:581-582` (explosion → `apply_burning`), `unit.gd:648` (`_burning_particles.burning_data = _burning`), `burning_particles.gd:61-69` (`_update_color`, ingé → bleu), `burning_data.gd:76-80` (`duplicate()` préserve `from`), `bomb_1_data.tres` (structure BurningEffect de la Bombe normale à mirrorer).

---

### Task 1: Skin poison — `bomb_skin.gd` + asset `poison.png`

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/poison.png` (copie de `screens/Poison.png`, 150×150 RGBA)
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Consumes: `BombSkin.element_sprite_path(element)` existant.
- Produces: `element_sprite_path("poison")` renvoie le chemin de `poison.png`.

- [ ] **Step 1: Copier l'asset**

```bash
cp screens/Poison.png Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/poison.png
```
Vérifier :
```bash
python -c "from PIL import Image; im=Image.open('Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/poison.png'); print(im.size, im.mode)"
```
Attendu : `(150, 150) RGBA`.

- [ ] **Step 2: Écrire le test qui échoue**

Dans `test/run_tests.gd`, dans la fonction `_test_bomb_skin_element()` existante (le `const BombSkin` existe déjà), ajouter :
```gdscript
	_check(BombSkin.element_sprite_path("poison").ends_with("poison.png"), "skin: poison -> poison.png")
```

- [ ] **Step 3: Lancer les tests pour vérifier l'échec**

Run : (commande runner ci-dessus)
Expected : FAIL sur "skin: poison -> poison.png" (le repli renvoie `bombe_normale.png`).

- [ ] **Step 4: Écrire l'implémentation**

Dans `content/logic/bomb_skin.gd`, dans la map `_SPRITE_PATHS`, ajouter la ligne `poison` et mettre à jour le commentaire :
```gdscript
# Clés = valeurs de BombElement (normal/ice/storm/poison).
const _SPRITE_PATHS := {
	"normal": _BOMB_DIR + "/bombe_normale.png",
	"ice": _BOMB_DIR + "/glace.png",
	"storm": _BOMB_DIR + "/storm.png",
	"poison": _BOMB_DIR + "/poison.png",
}
```

- [ ] **Step 5: Lancer les tests pour vérifier le succès**

Run : (commande runner)
Expected : `=== N tests, 0 échec(s) ===` (N += 1).

- [ ] **Step 6: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/poison.png Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): skin bombe de poison (poison.png constant)"
```

---

### Task 2: Logique du feu vert — `poison_fire.gd`

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/poison_fire.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Produces :
  - `static func is_poison_source(weapon_id: String) -> bool` — `true` ssi `weapon_id` commence par `"weapon_bomb_poison"`.
  - `static func green_gradient() -> Gradient` — dégradé principal (vert toxique → fondu).
  - `static func green_gradient_secondary() -> Gradient` — dégradé secondaire (vert clair → fondu).

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter le `const` en haut (à côté des autres `preload`) :
```gdscript
const PoisonFire = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/poison_fire.gd")
```
Ajouter la fonction de test :
```gdscript
func _test_poison_fire():
	# Marqueur de source : le weapon_id partagé des 4 tiers commence par weapon_bomb_poison.
	_check(PoisonFire.is_poison_source("weapon_bomb_poison"), "poison: weapon_bomb_poison reconnu")
	_check(PoisonFire.is_poison_source("weapon_bomb_poison_3"), "poison: variante tier reconnue")
	_check(not PoisonFire.is_poison_source("weapon_bomb"), "poison: bombe normale non reconnue")
	_check(not PoisonFire.is_poison_source("weapon_turret"), "poison: tourelle (ingé bleu) non reconnue")
	_check(not PoisonFire.is_poison_source(""), "poison: vide non reconnu")
	# Dégradés verts : Gradient à points, 1re couleur plus verte que rouge.
	var g = PoisonFire.green_gradient()
	_check(g is Gradient, "poison: green_gradient est un Gradient")
	_check(g.colors.size() >= 2, "poison: green_gradient a >= 2 points")
	_check(g.colors[0].g > g.colors[0].r, "poison: 1re couleur verdâtre (g > r)")
	var gs = PoisonFire.green_gradient_secondary()
	_check(gs is Gradient, "poison: green_gradient_secondary est un Gradient")
	_check(gs.colors[0].g > gs.colors[0].r, "poison: secondaire verdâtre (g > r)")
```
L'appeler dans `_init()` (à côté des autres `_test_...()`):
```gdscript
	_test_poison_fire()
```

- [ ] **Step 2: Lancer les tests pour vérifier l'échec**

Run : (commande runner)
Expected : échec au chargement (`poison_fire.gd` introuvable → preload error) OU FAIL sur les `_check`.

- [ ] **Step 3: Écrire l'implémentation**

Créer `content/logic/poison_fire.gd` :
```gdscript
extends Reference
# Feu vert du DOT de la Bombe de Poison — logique PURE (testable headless).
#
# Le poison est une brûlure (BurningData) scalée sur l'ingénierie ; or les
# particules vanilla colorent l'ingénierie en BLEU (burning_particles.gd:_update_color,
# = couleur Tourelle enflammée). Pour distinguer notre poison, l'extension de
# burning_particles lit burning_data.from.weapon_id : si c'est une bombe de poison,
# elle applique ces dégradés VERTS au lieu du bleu. Sinon, comportement vanilla
# inchangé (la Tourelle reste bleue).

const _POISON_PREFIX := "weapon_bomb_poison"

# Vrai ssi la brûlure vient d'une bombe de poison (weapon_id partagé des 4 tiers).
static func is_poison_source(weapon_id: String) -> bool:
	return weapon_id.begins_with(_POISON_PREFIX)

# Dégradé principal : vert toxique vif -> vert moyen -> fondu transparent.
static func green_gradient() -> Gradient:
	var g := Gradient.new()
	g.offsets = PoolRealArray([0.0, 0.5, 1.0])
	g.colors = PoolColorArray([
		Color(0.62, 1.0, 0.30, 1.0),
		Color(0.30, 0.80, 0.12, 0.85),
		Color(0.08, 0.35, 0.02, 0.0),
	])
	return g

# Dégradé secondaire (particules fines) : vert clair -> fondu.
static func green_gradient_secondary() -> Gradient:
	var g := Gradient.new()
	g.offsets = PoolRealArray([0.0, 1.0])
	g.colors = PoolColorArray([
		Color(0.80, 1.0, 0.55, 0.9),
		Color(0.20, 0.50, 0.08, 0.0),
	])
	return g
```

- [ ] **Step 4: Lancer les tests pour vérifier le succès**

Run : (commande runner)
Expected : `=== N tests, 0 échec(s) ===` (N += 9).

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/poison_fire.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): logique feu vert poison (marqueur source + dégradés verts)"
```

---

### Task 3: Données des 4 bombes de poison (`.tres`)

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_1_stats.tres` … `bomb_poison_4_stats.tres`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_1_data.tres` … `bomb_poison_4_data.tres`

**Interfaces:**
- Produces : 4 `WeaponData` (`weapon_id = "weapon_bomb_poison"`, `my_id = weapon_bomb_poison_1..4`, tiers 0..3, chaîne `upgrades_into` 1→2→3→4, set `explosive`, `BurningEffect` scalé ingénierie) + 4 `RangedWeaponStats` (`damage = 0`, cooldown gradué).

**Note test:** ces `.tres` référencent des scripts/scènes vanilla + autoloads → **non chargeables en headless**. Vérification = **checks statiques** (Step 3) + **en jeu** (Task 8). Ne PAS les `preload` dans le runner.

- [ ] **Step 1: Créer les 4 fichiers de stats**

`bomb_poison_1_stats.tres` (tier I) :
```
[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://weapons/weapon_stats/ranged_weapon_stats.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
cooldown = 90
damage = 0
accuracy = 1.0
crit_chance = 0.0
crit_damage = 1.0
min_range = 0
max_range = 500
knockback = 0
knockback_piercing = 0.0
can_have_positive_knockback = false
can_have_negative_knockback = false
effect_scale = 1.0
scaling_stats = [  ]
lifesteal = 0.0
shooting_sounds = [  ]
sound_db_mod = -5
is_healing = false
recoil = 0
recoil_duration = 0.1
additional_cooldown_every_x_shots = -1
additional_cooldown_multiplier = -1.0
speed_percent_modifier = 0
nb_projectiles = 1
projectile_spread = 0.0
piercing = 0
piercing_dmg_reduction = 0.5
bounce = 0
bounce_dmg_reduction = 0.5
can_bounce = false
projectile_speed = 3000
increase_projectile_speed_with_range = false
```
`bomb_poison_2_stats.tres` : identique mais `cooldown = 80`.
`bomb_poison_3_stats.tres` : `cooldown = 70`.
`bomb_poison_4_stats.tres` : `cooldown = 60`.

- [ ] **Step 2: Créer les 4 fichiers de data**

`bomb_poison_1_data.tres` (tier I, DOT placeholder 4 dmg / 4 s, `upgrades_into` → tier II) :
```
[gd_resource type="Resource" load_steps=11 format=2]

[ext_resource path="res://items/global/weapon_data.gd" type="Script" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=2]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn" type="PackedScene" id=3]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_1_stats.tres" type="Resource" id=4]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_2_data.tres" type="Resource" id=5]
[ext_resource path="res://items/sets/explosive/explosive_set_data.tres" type="Resource" id=6]
[ext_resource path="res://effects/weapons/burning_effect.gd" type="Script" id=7]
[ext_resource path="res://effects/burning_data.gd" type="Script" id=8]

[sub_resource type="Resource" id=1]
script = ExtResource( 8 )
chance = 1.0
damage = 4
duration = 4
spread = 0
scaling_stats = [ [ "stat_engineering", 1.0 ] ]
is_global_burn = false

[sub_resource type="Resource" id=2]
script = ExtResource( 7 )
key = "effect_burning"
text_key = ""
value = 0
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [  ]
burning_data = SubResource( 1 )

[resource]
script = ExtResource( 1 )
my_id = "weapon_bomb_poison_1"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "WEAPON_BOMB_POISON"
tier = 0
value = 20
effects = [ SubResource( 2 ) ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
weapon_id = "weapon_bomb_poison"
type = 1
sets = [ ExtResource( 6 ) ]
scene = ExtResource( 3 )
stats = ExtResource( 4 )
upgrades_into = ExtResource( 5 )
add_to_chars_as_starting = [  ]
```
`bomb_poison_2_data.tres` : idem mais `my_id = "weapon_bomb_poison_2"`, `tier = 1`, `value = 39`, sub_resource id=1 `damage = 6` / `duration = 5`, `id=4` → `bomb_poison_2_stats.tres`, `id=5` → `bomb_poison_3_data.tres`.
`bomb_poison_3_data.tres` : `my_id = "weapon_bomb_poison_3"`, `tier = 2`, `value = 74`, sub id=1 `damage = 8` / `duration = 6`, `id=4` → `bomb_poison_3_stats.tres`, `id=5` → `bomb_poison_4_data.tres`.
`bomb_poison_4_data.tres` (tier IV, **PAS** d'`upgrades_into`) — retirer l'ext_resource `id=5` et la ligne `upgrades_into`, décaler les IDs suivants, `load_steps=10` :
```
[gd_resource type="Resource" load_steps=10 format=2]

[ext_resource path="res://items/global/weapon_data.gd" type="Script" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=2]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn" type="PackedScene" id=3]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_4_stats.tres" type="Resource" id=4]
[ext_resource path="res://items/sets/explosive/explosive_set_data.tres" type="Resource" id=5]
[ext_resource path="res://effects/weapons/burning_effect.gd" type="Script" id=6]
[ext_resource path="res://effects/burning_data.gd" type="Script" id=7]

[sub_resource type="Resource" id=1]
script = ExtResource( 7 )
chance = 1.0
damage = 10
duration = 8
spread = 0
scaling_stats = [ [ "stat_engineering", 1.0 ] ]
is_global_burn = false

[sub_resource type="Resource" id=2]
script = ExtResource( 6 )
key = "effect_burning"
text_key = ""
value = 0
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [  ]
burning_data = SubResource( 1 )

[resource]
script = ExtResource( 1 )
my_id = "weapon_bomb_poison_4"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "WEAPON_BOMB_POISON"
tier = 3
value = 149
effects = [ SubResource( 2 ) ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
weapon_id = "weapon_bomb_poison"
type = 1
sets = [ ExtResource( 5 ) ]
scene = ExtResource( 3 )
stats = ExtResource( 4 )
add_to_chars_as_starting = [  ]
```

- [ ] **Step 3: Vérifs statiques**

```bash
cd Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb
grep -H "my_id\|weapon_id\|^tier\|^damage\|^duration\|scaling_stats\|upgrades_into\|load_steps" bomb_poison_*_data.tres bomb_poison_*_stats.tres
```
Attendu : `weapon_id = "weapon_bomb_poison"` dans les 4 data ; `my_id` = `weapon_bomb_poison_1..4` ; `tier` 0/1/2/3 ; DOT `damage` 4/6/8/10 et `duration` 4/5/6/8 (sub_resources) ; `scaling_stats = [ [ "stat_engineering", 1.0 ] ]` ; `damage = 0` dans les stats ; `upgrades_into` présent dans data 1/2/3 et ABSENT dans data 4 ; `load_steps=11` (data 1-3) / `10` (data 4) / `2` (stats).
Vérifier que chaque `id=N` référencé (SubResource/ExtResource) existe dans son fichier (pas de trou d'ID).

- [ ] **Step 4: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_*_data.tres Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_*_stats.tres
git commit -m "feat(bomberman): data des 4 bombes de poison (DOT ingénierie par tier)"
```

---

### Task 4: Enregistrement des 4 armes de poison — `item_service.gd`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd`

**Interfaces:**
- Consumes : `_register_bomb_weapon(path)` existant (pose l'icône par élément via `BombSkin.build_icon` + injecte).
- Produces : les 4 armes de poison injectées dans `weapons`.

- [ ] **Step 1: Ajouter les chemins des armes de poison**

Dans `item_service.gd`, après le bloc `const _BOMB_STORM_WEAPONS := [ ... ]`, ajouter :
```gdscript
const _BOMB_POISON_WEAPONS := [
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_1_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_2_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_3_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_4_data.tres",
]
```

- [ ] **Step 2: Injecter les armes de poison**

Dans `_ready()`, après la boucle `for path in _BOMB_STORM_WEAPONS:`, ajouter :
```gdscript
	for path in _BOMB_POISON_WEAPONS:
		_register_bomb_weapon(path)
```

- [ ] **Step 3: Vérif statique + non-régression**

Run : (commande runner) → `0 échec(s)` (le runner ne charge pas cette extension, mais ne doit pas régresser).
Statique :
```bash
grep -n "_BOMB_POISON_WEAPONS\|for path in _BOMB_POISON_WEAPONS" Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd
```
Attendu : la constante (4 chemins) + la boucle d'injection.

- [ ] **Step 4: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd
git commit -m "feat(bomberman): enregistre les 4 armes bombe de poison"
```

---

### Task 5: Bombe de poison en arme de départ — `bomberman_data.tres`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/bomberman_data.tres`

**Interfaces:**
- Consumes : `bomb_poison_1_data.tres` (Task 3).
- Produces : `weapon_bomb_poison_1` ajouté à `starting_weapons` (sélectionnable au départ).

- [ ] **Step 1: Ajouter l'ext_resource + l'entrée starter**

Dans `bomberman_data.tres` :

a) En tête, passer `load_steps=19` → `load_steps=20`.

b) Après la ligne `[ext_resource ... bomb_storm_1_data.tres ... id=18]`, ajouter :
```
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_1_data.tres" type="Resource" id=19]
```

c) Dans `starting_weapons`, ajouter `ExtResource( 19 )` juste après `ExtResource( 18 )` (à la suite des autres bombes élémentaires) :
```
starting_weapons = [ ExtResource( 4 ), ExtResource( 17 ), ExtResource( 18 ), ExtResource( 19 ), ExtResource( 11 ), ExtResource( 12 ), ExtResource( 13 ), ExtResource( 14 ), ExtResource( 15 ), ExtResource( 16 ) ]
```

- [ ] **Step 2: Vérif statique**

```bash
grep -n "load_steps\|bomb_poison_1_data\|starting_weapons" Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/bomberman_data.tres
```
Attendu : `load_steps=20` ; l'ext_resource `id=19` vers `bomb_poison_1_data.tres` ; `ExtResource( 19 )` présent dans `starting_weapons`.

- [ ] **Step 3: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/bomberman_data.tres
git commit -m "feat(bomberman): bombe de poison sélectionnable au départ de Bomberto"
```

---

### Task 6: i18n — `WEAPON_BOMB_POISON`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd`

**Interfaces:**
- Produces : clé `WEAPON_BOMB_POISON` (EN "Poison Bomb", FR "Bombe de Poison"). Le DOT s'affiche via la ligne de brûlure native du `BurningEffect` (aucune clé d'infobulle dédiée).

- [ ] **Step 1: Ajouter les messages FR/EN**

Dans `register()` :

a) Après `tr_en.add_message("WEAPON_BOMB_STORM", "Storm Bomb")` (et sa ligne `_BOLTS`), ajouter :
```gdscript
	tr_en.add_message("WEAPON_BOMB_POISON", "Poison Bomb")
```
b) Après `tr_fr.add_message("WEAPON_BOMB_STORM", "Bombe de Foudre")` (et sa ligne `_BOLTS`), ajouter :
```gdscript
	tr_fr.add_message("WEAPON_BOMB_POISON", "Bombe de Poison")
```
c) Mettre à jour le commentaire d'en-tête (liste des clés fournies) pour inclure `WEAPON_BOMB_POISON` (nom de la Bombe de Poison ; DOT affiché via la brûlure native).

- [ ] **Step 2: Vérif statique**

```bash
grep -n "WEAPON_BOMB_POISON" Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd
```
Attendu : 2 occurrences (en + fr).

- [ ] **Step 3: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd
git commit -m "feat(bomberman): i18n WEAPON_BOMB_POISON (FR/EN)"
```

---

### Task 7: Feu vert — extension `burning_particles.gd`

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/extensions/particles/burning/burning_particles.gd`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd`

**Interfaces:**
- Consumes : `PoisonFire.is_poison_source(weapon_id)`, `PoisonFire.green_gradient()`, `PoisonFire.green_gradient_secondary()` (Task 2) ; hérite de `burning_particles.gd` (`burning_data`, `secondary_particles`, `color_ramp`, `_update_color()`).
- Produits : particules de brûlure **vertes** quand la source est une bombe de poison ; sinon comportement vanilla intact.

**Note test:** l'extension étend un script vanilla dépendant d'autoloads → **non chargeable en headless**. Vérification = **checks statiques** (Step 3) + **en jeu** (Task 8). La logique testable (prédicat + dégradés) est déjà couverte par Task 2.

- [ ] **Step 1: Créer l'extension**

Créer `extensions/particles/burning/burning_particles.gd` :
```gdscript
extends "res://particles/burning/burning_particles.gd"
# Feu VERT pour le DOT de la Bombe de Poison.
#
# Le poison est une brûlure scalée ingénierie ; _update_color() vanilla la
# colorerait en BLEU (couleur Tourelle enflammée). On surcharge _update_color :
# si la brûlure vient d'une bombe de poison (burning_data.from.weapon_id), on
# applique des dégradés VERTS ; sinon on délègue au vanilla (la Tourelle reste
# bleue, l'élémentaire reste rouge). AUCUNE régression sur les autres brûlures.
#
# burning_data.from est peuplé par weapon.gd:151 (current_stats.burning_data.from
# = self, la BombWeapon persistante) et propagé jusqu'aux particules par
# unit.apply_burning (burning_data.duplicate() préserve from). Si from est absent
# (cas non prévu), _is_poison renvoie false -> repli bleu automatique.

const PoisonFire = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/poison_fire.gd")

# Dégradés verts construits une seule fois (réutilisés à chaque start_emitting).
var _green: Gradient = null
var _green_secondary: Gradient = null

func _update_color() -> void:
	if burning_data != null and _is_poison(burning_data):
		if _green == null:
			_green = PoisonFire.green_gradient()
			_green_secondary = PoisonFire.green_gradient_secondary()
		color_ramp = _green
		if secondary_particles != null:
			secondary_particles.color_ramp = _green_secondary
		return
	._update_color()

# Vrai si la brûlure provient d'une bombe de poison (duck-typé sur from.weapon_id).
func _is_poison(bd) -> bool:
	var from = bd.from
	if not is_instance_valid(from):
		return false
	if not ("weapon_id" in from):
		return false
	return PoisonFire.is_poison_source(from.weapon_id)
```

- [ ] **Step 2: Déclarer l'extension dans `mod_main.gd`**

Dans `mod_main.gd`, fonction `_install_extensions()`, après la ligne `install_script_extension(... item_service.gd)`, ajouter :
```gdscript
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-Bomberman/extensions/particles/burning/burning_particles.gd")
```

- [ ] **Step 3: Vérif statique + non-régression**

Run : (commande runner) → `0 échec(s)` (inchangé ; le runner ne charge pas l'extension).
Statique :
```bash
grep -n "burning_particles" Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd
grep -n "_update_color\|_is_poison\|PoisonFire" Brotato/mods-unpacked/Tanith-Bomberman/extensions/particles/burning/burning_particles.gd
```
Attendu : la déclaration dans `mod_main.gd` ; l'override + le prédicat dans l'extension.

- [ ] **Step 4: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/extensions/particles/burning/burning_particles.gd Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd
git commit -m "feat(bomberman): feu vert du poison (override burning_particles._update_color)"
```

---

### Task 8: Vérification EN JEU (humain) + notes

**Files:** aucun (checklist de validation manuelle — les sous-agents ne lancent pas Brotato).

**Setup :** builder/déposer le mod (`tools/build-bomberman.ps1`) ou symlinker le dossier dans `mods-unpacked/`, activer `Tanith-DevUnlockAll` si besoin, lancer Brotato en Bomberto.

- [ ] **Boutique** : la Bombe de Poison apparaît (icône = `poison.png` sur disque coloré à la rareté ; nom « Bombe de Poison »/« Poison Bomb ») ; le pool magasin reste borné au roster Bomberto.
- [ ] **Départ** : la Bombe de Poison tier I est proposée comme arme de départ (à côté de la Glace et de la Foudre).
- [ ] **Équipement** : sprite tenu = `poison.png`, constant tous tiers ; contour coloré par tier (highlight vanilla).
- [ ] **Pose + explosion** : bombe posée = sprite poison ; explosion AoE **0 dégât direct** (pas de perte de PV à l'impact) ; **jamais** de trollbombe.
- [ ] **DOT** : les ennemis touchés perdent des PV **sur la durée** (brûlure) ; l'intensité monte avec le tier et avec l'**ingénierie** du joueur.
- [ ] **Feu vert** : les ennemis empoisonnés « fument » en **VERT** (pas bleu). **Non-régression** : une Tourelle enflammée (si dispo) reste **bleue** ; une brûlure élémentaire reste **rouge/orange**.
- [ ] **Montée en tiers** : upgrade I→IV fonctionne (fusion boutique).
- [ ] **Coop** : DOT + feu vert corrects pour chaque joueur ; pas de contamination (une explosion d'une autre arme n'empoisonne pas / ne verdit pas).
- [ ] **Suivi des dégâts (info)** : le DOT de brûlure n'est **pas** attribué au `weapon_pos` (comportement vanilla des brûlures) → l'infobulle « dégâts infligés » peut afficher 0 pour le poison. **À décider en jeu** : acceptable (comme les autres brûlures) ou chantier de suivi ultérieur (hors périmètre de cette phase).
- [ ] **Équilibrage** : caler `damage`/`duration` du DOT par tier, cooldowns, prix.

**Après validation en jeu :**
- Mettre à jour la mémoire `brotato-bomberman-sdd-status.md` (Phase 3 code-complète + validée) et `MEMORY.md`.
- Release : bump `manifest.json` (1.8.0 → 1.9.0) + entrées `CHANGELOG_FR.md` / `CHANGELOG_EN.md` (Ajouté : Bombe de Poison, DOT ingénierie, feu vert, starter).
- Packaging Workshop : `powershell -File tools/build-bomberman.ps1` (⚠️ supprimer d'abord les `*.png.import` regénérés par l'éditeur pour `poison.png`, comme pour glace/storm) ; upload MANUEL (item `3752197886`).

---

## Notes de portée

- **`bomb_entity.gd` / `bomb_weapon.gd` / `bomb_element.gd` / `shop_pool.gd` : AUCUN changement.** Le poison est déjà mappé (`bomb_element.from_weapon_id("weapon_bomb_poison") == POISON`), déjà accepté par le pool (préfixe `weapon_bomb`), et déjà géré comme « bombe à effet » (`is_effect` → 0 dégât AoE, pas de troll) avec passage du `burning_data` par le chemin existant (`bomb_entity.gd:113`).
- **Feu vert et Tourelle enflammée** : les deux scalent l'ingénierie (bleu vanilla), mais seule la bombe de poison a un `burning_data.from.weapon_id` en `weapon_bomb_poison` → l'override ne verdit que le poison, jamais la Tourelle.
- **Suivi des dégâts du DOT** : non traité ici (les brûlures vanilla ne s'attribuent pas au `weapon_pos`). Éventuel chantier ultérieur si souhaité après test.
