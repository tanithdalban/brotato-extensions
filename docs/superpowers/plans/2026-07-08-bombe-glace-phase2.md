# Bombe de Glace (Phase 2) — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter la 1re bombe élémentaire au Bomberto — une **Bombe de Glace** (4 tiers) qui, à l'explosion, ralentit durablement les ennemis (coupe de vitesse réelle, non cumulative) et les couvre d'un givre bleu sans dégât.

**Architecture:** Les 4 bombes de glace partagent `bomb.tscn` / `bomb_weapon.gd` / `bomb_entity.gd` avec la Bombe normale ; elles ne diffèrent que par leurs `.tres`, leur sprite (`glace.png`), et un **élément** déduit du `weapon_id`. Le ralentissement est appliqué **sans étendre `enemy.gd`** : `bomb_entity` connecte le signal `hit_something` de l'explosion à notre `BombWeapon` (persistant), qui coupe la vitesse réelle de l'ennemi (`current_stats.speed`) selon un modèle « vitesse cible » non cumulatif. Le givre bleu vient d'un `BurningEffect` du `.tres` (scaling ingénierie facteur 0.0 → particules bleues, 0 dégât).

**Tech Stack:** Godot 3.6.2 / GDScript, ModLoader (script extensions), test-runner GDScript autonome.

## Global Constraints

- **Tout en français** : commentaires, docs, libellés de commits. Libellés UI bilingues FR/EN.
- **Aucun fichier `.tscn`** créé pour l'écran/bombe : la bombe réutilise `bomb.tscn` existant.
- **Chargement des sprites au runtime** (`Image.load`, hors cache d'import Godot), comme `bomb_skin.gd` actuel. Pas de `.import`/`.stex` à générer pour `glace.png`.
- **Zéro extension de code vanilla ajoutée** pour ce plan (on garde uniquement l'extension existante `item_service.gd`). Le slow passe par le signal public `hit_something` (`unit.gd:608`, émis même à 0 dégât car hors du gate `deals_damage`).
- **Runner de tests Bomberman** (≠ `./run-tests.sh` de ShopConfig) :
  ```
  "./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
  ```
  Depuis la racine du repo (Git Bash). Résultat = ligne `=== N tests, M échec(s) ===` ; viser `0 échec(s)`. Les erreurs moteur APRÈS cette ligne = teardown des autoloads, sans effet.
- **Slow % par tier (I→IV)** : `-30 / -40 / -50 / -60` (porté par `_stats.speed_percent_modifier`, repurposé comme pourcentage de slow cible).
- **Non cumulatif** : `current_stats.speed = min(current_stats.speed, max_speed × (1 − slow%/100))` — un slow plus faible arrivant après un plus fort est un no-op.
- **`weapon_id` de la glace** : `weapon_bomb_ice` (partagé par les 4 tiers) ; `my_id` = `weapon_bomb_ice_1..4`.
- **Nom i18n** : clé `WEAPON_BOMB_ICE`.
- Réf. décompilé : `hitbox.gd:10` (`deals_damage` flag défaut `true`), `unit.gd:608` (`hit_something` hors gate), `burning_particles.gd:_update_color` (ingé→bleu), `player_explosion.gd:end_explosion` (déconnecte `hit_something` au recyclage).

---

### Task 1: Logique d'élément — `bomb_element.gd`

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Produces:
  - `const NORMAL := "normal"`, `const ICE := "ice"`, `const POISON := "poison"`, `const STORM := "storm"`
  - `static func from_weapon_id(weapon_id: String) -> String`
  - `static func is_effect(element: String) -> bool` (true pour ice/poison/storm)

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter le `const` en haut (à côté des autres `const ... = preload(...)`):
```gdscript
const BombElement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd")
```
Ajouter une fonction de test (n'importe où parmi les `func _test_*`):
```gdscript
func _test_bomb_element():
	_check(BombElement.from_weapon_id("weapon_bomb") == BombElement.NORMAL, "element: weapon_bomb => normal")
	_check(BombElement.from_weapon_id("weapon_bomb_ice") == BombElement.ICE, "element: weapon_bomb_ice => ice")
	_check(BombElement.from_weapon_id("weapon_bomb_poison") == BombElement.POISON, "element: poison")
	_check(BombElement.from_weapon_id("weapon_bomb_storm") == BombElement.STORM, "element: storm")
	_check(BombElement.from_weapon_id("weapon_smg") == BombElement.NORMAL, "element: inconnu => normal (repli)")
	_check(BombElement.from_weapon_id("") == BombElement.NORMAL, "element: vide => normal")
	_check(BombElement.is_effect(BombElement.ICE), "element: ice est un effet")
	_check(not BombElement.is_effect(BombElement.NORMAL), "element: normal n'est pas un effet")
```
Et l'appeler dans `_init()` (à côté des autres `_test_...()`):
```gdscript
	_test_bomb_element()
```

- [ ] **Step 2: Lancer les tests pour vérifier l'échec**

Run: `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected: échec au chargement (`bomb_element.gd` introuvable → parse/preload error) OU FAIL sur les nouveaux `_check`.

- [ ] **Step 3: Écrire l'implémentation minimale**

Créer `content/logic/bomb_element.gd`:
```gdscript
extends Reference
# Élément d'une bombe, déduit du weapon_id partagé par ses 4 tiers.
# Pilote le sous-comportement à l'explosion (normal = dégâts+brûlure+troll ;
# glace/poison/foudre = "bombes à effet" : 0 dégât AoE, jamais de trollbombe).

const NORMAL := "normal"
const ICE := "ice"
const POISON := "poison"
const STORM := "storm"

const _BY_WEAPON_ID := {
	"weapon_bomb_ice": ICE,
	"weapon_bomb_poison": POISON,
	"weapon_bomb_storm": STORM,
}

# Élément d'une arme d'après son weapon_id. Repli NORMAL (dont "weapon_bomb").
static func from_weapon_id(weapon_id: String) -> String:
	return _BY_WEAPON_ID.get(weapon_id, NORMAL)

# Vrai pour les bombes "à effet" (pas la Bombe normale) : 0 dégât AoE, pas de troll.
static func is_effect(element: String) -> bool:
	return element != NORMAL
```

- [ ] **Step 4: Lancer les tests pour vérifier le succès**

Run: (même commande qu'au Step 2)
Expected: `=== N tests, 0 échec(s) ===` (N = ancien total + 8).

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): logique d'élément de bombe (weapon_id -> élément)"
```

---

### Task 2: Logique de slow — `bomb_ice_slow.gd`

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_ice_slow.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Produces:
  - `static func slow_pct_for(speed_percent_modifier: int) -> float` — renvoie `abs(speed_percent_modifier)` (le `.tres` porte le slow % en négatif).
  - `static func apply(cur_speed: float, max_speed: float, slow_pct: float) -> float` — modèle « vitesse cible » non cumulatif : `min(cur_speed, max_speed × (1 − slow_pct/100))` ; no-op si `max_speed <= 0`.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter le `const`:
```gdscript
const BombIceSlow = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_ice_slow.gd")
```
Ajouter la fonction de test:
```gdscript
func _test_bomb_ice_slow():
	# slow_pct_for : magnitude du champ (négatif dans le .tres).
	_check(_approx(BombIceSlow.slow_pct_for(-30), 30.0), "ice: slow_pct_for(-30) = 30")
	_check(_approx(BombIceSlow.slow_pct_for(-60), 60.0), "ice: slow_pct_for(-60) = 60")
	# apply : coupe vers la vitesse cible (max_speed=100, slow 30% => cible 70).
	_check(_approx(BombIceSlow.apply(100.0, 100.0, 30.0), 70.0), "ice: 100 -> cible 70 (slow 30%)")
	# non cumulatif : déjà à 70, re-slow 30% => cible 70 => no-op.
	_check(_approx(BombIceSlow.apply(70.0, 100.0, 30.0), 70.0), "ice: non cumulatif (même tier = no-op)")
	# slow plus fort écrase : à 70, slow 50% => cible 50.
	_check(_approx(BombIceSlow.apply(70.0, 100.0, 50.0), 50.0), "ice: slow plus fort écrase (70 -> 50)")
	# slow plus faible après plus fort = no-op : à 50, slow 30% => cible 70 > 50 => reste 50.
	_check(_approx(BombIceSlow.apply(50.0, 100.0, 30.0), 50.0), "ice: slow plus faible = no-op (garde le plus lent)")
	# garde-fou max_speed 0 => inchangé.
	_check(_approx(BombIceSlow.apply(42.0, 0.0, 50.0), 42.0), "ice: max_speed 0 => inchangé")
```
L'appeler dans `_init()`:
```gdscript
	_test_bomb_ice_slow()
```

- [ ] **Step 2: Lancer les tests pour vérifier l'échec**

Run: (commande runner)
Expected: échec au chargement (fichier absent) OU FAIL sur les `_check`.

- [ ] **Step 3: Écrire l'implémentation minimale**

Créer `content/logic/bomb_ice_slow.gd`:
```gdscript
extends Reference
# Coupe de vitesse de la Bombe de Glace — logique PURE (testable headless).
#
# Modèle "vitesse cible" NON CUMULATIF : chaque tier vise une vitesse
#   cible = max_speed × (1 − slow%/100)
# et on applique current_stats.speed = min(current_stats.speed, cible).
# Un slow plus faible arrivant après un plus fort est donc un no-op
# (la cible est plus haute que la vitesse courante) => "on garde le plus lent".
#
# La coupe est écrite dans current_stats.speed (débuff RÉEL et durable, tant que
# l'ennemi vit). Appliquée par BombWeapon.on_ice_hit via le signal hit_something
# de l'explosion — AUCUNE extension de enemy.gd (cf. spec, section Glace).

# Le .tres porte le slow % en NÉGATIF (champ speed_percent_modifier repurposé) ;
# on renvoie sa magnitude.
static func slow_pct_for(speed_percent_modifier: int) -> float:
	return abs(speed_percent_modifier)

# Vitesse résultante après application du slow (non cumulatif). No-op si
# max_speed invalide.
static func apply(cur_speed: float, max_speed: float, slow_pct: float) -> float:
	if max_speed <= 0.0:
		return cur_speed
	var target := max_speed * (1.0 - slow_pct / 100.0)
	return min(cur_speed, target)
```

- [ ] **Step 4: Lancer les tests pour vérifier le succès**

Run: (commande runner)
Expected: `=== N tests, 0 échec(s) ===` (N += 7).

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_ice_slow.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): logique de slow glace (vitesse cible non cumulative)"
```

---

### Task 3: Filtre de pool — préfixe `weapon_bomb` dans `shop_pool.gd`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/shop_pool.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Consumes: `_StubWeapon` du runner (a `weapon_id`, `sets`, `stats`, `type`).
- Produces: `ShopPool.is_allowed(weapon)` accepte désormais tout `weapon_id` commençant par `weapon_bomb` (donc `weapon_bomb_ice`), en plus des règles existantes (set explosive, knockback mêlée).

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, repérer la fonction qui teste `ShopPool` (ex. `_test_shop_pool` / `_test_pool_filter`). Ajouter ces `_check` dedans (les `_StubWeapon(p_weapon_id, p_sets, p_knockback, p_type)` existent déjà dans le runner) :
```gdscript
	# Préfixe weapon_bomb : la glace passe même sans set explosive.
	_check(ShopPool.is_allowed(_StubWeapon.new("weapon_bomb_ice", [], 0, 1)), "pool: weapon_bomb_ice accepté (préfixe)")
	_check(ShopPool.is_allowed(_StubWeapon.new("weapon_bomb", [], 0, 1)), "pool: weapon_bomb accepté (préfixe)")
	_check(not ShopPool.is_allowed(_StubWeapon.new("weapon_smg", [], 0, 1)), "pool: weapon_smg rejeté")
```

- [ ] **Step 2: Lancer les tests pour vérifier l'échec**

Run: (commande runner)
Expected: FAIL sur "weapon_bomb_ice accepté (préfixe)" (l'égalité stricte actuelle `== "weapon_bomb"` le rejette).

- [ ] **Step 3: Écrire l'implémentation minimale**

Dans `content/logic/shop_pool.gd`, remplacer le test d'égalité stricte par un test de **préfixe**. Fonction `is_allowed`, ligne actuelle :
```gdscript
	if ("weapon_id" in weapon) and weapon.weapon_id == BOMB_WEAPON_ID:
		return true
```
la remplacer par :
```gdscript
	if ("weapon_id" in weapon) and (weapon.weapon_id as String).begins_with(BOMB_WEAPON_ID):
		return true
```
`BOMB_WEAPON_ID` vaut déjà `"weapon_bomb"` → `weapon_bomb`, `weapon_bomb_ice`, `weapon_bomb_poison`, `weapon_bomb_storm` passent tous. Mettre à jour le commentaire d'en-tête pour dire « préfixe `weapon_bomb` » au lieu de « c'est une Bombe ».

- [ ] **Step 4: Lancer les tests pour vérifier le succès**

Run: (commande runner)
Expected: `=== N tests, 0 échec(s) ===` (N += 3).

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/shop_pool.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): pool magasin accepte le préfixe weapon_bomb (bombes élémentaires)"
```

---

### Task 4: Skin par élément — `bomb_skin.gd` + asset `glace.png`

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/glace.png` (copie de `screens/Glace.png`, 150×150 RGBA, fond transparent)
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Produces:
  - `static func element_sprite_path(element: String) -> String` — chemin du PNG par élément (repli normal).
  - `static func build_icon(element: String, tier_color: Color) -> Texture` — sprite de l'élément sur disque coloré (icône boutique).
  - `static func build_world_texture(element: String) -> Texture` — sprite de l'élément 48×48 sans fond (en jeu).
  - Conserve `build_normal_icon(tier_color)` / `build_normal_world_texture()` (délèguent à la version générique) pour les appelants existants (`troll_bomb`, etc.).

- [ ] **Step 1: Copier l'asset**

```bash
cp screens/Glace.png Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/glace.png
```
Vérifier: `python -c "from PIL import Image; im=Image.open('Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/glace.png'); print(im.size, im.mode)"` → attendu `(150, 150) RGBA`.

- [ ] **Step 2: Écrire les tests qui échouent**

Dans `test/run_tests.gd` (le `const BombSkin` existe déjà), ajouter/étendre une fonction de test:
```gdscript
func _test_bomb_skin_element():
	var normal_path = BombSkin.element_sprite_path("normal")
	var ice_path = BombSkin.element_sprite_path("ice")
	_check(normal_path.ends_with("bombe_normale.png"), "skin: normal -> bombe_normale.png")
	_check(ice_path.ends_with("glace.png"), "skin: ice -> glace.png")
	# Élément inconnu => repli sur normal (pas de crash).
	_check(BombSkin.element_sprite_path("inconnu").ends_with("bombe_normale.png"), "skin: inconnu -> repli normal")
```
L'appeler dans `_init()`:
```gdscript
	_test_bomb_skin_element()
```

- [ ] **Step 3: Lancer les tests pour vérifier l'échec**

Run: (commande runner)
Expected: échec au chargement (`element_sprite_path` inconnue) OU FAIL.

- [ ] **Step 4: Écrire l'implémentation**

Dans `content/logic/bomb_skin.gd` :

a) Remplacer la constante de chemin unique par une map par élément. Remplacer :
```gdscript
const _NORMAL_ICON_PATH := "res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bombe_normale.png"
```
par :
```gdscript
const _BOMB_DIR := "res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb"
# Clés = valeurs de BombElement (normal/ice/...). Poison/foudre viendront aux
# phases suivantes.
const _SPRITE_PATHS := {
	"normal": _BOMB_DIR + "/bombe_normale.png",
	"ice": _BOMB_DIR + "/glace.png",
}
# Rétro-compat interne (anciens sites).
const _NORMAL_ICON_PATH := _BOMB_DIR + "/bombe_normale.png"

# Chemin du sprite d'un élément (repli sur normal si élément inconnu).
static func element_sprite_path(element: String) -> String:
	return _SPRITE_PATHS.get(element, _SPRITE_PATHS["normal"])
```

b) Ajouter les versions génériques et faire déléguer les fonctions `normal` existantes. Remplacer le corps de `build_normal_icon` et `build_normal_world_texture` par des délégations, et factoriser la composition dans deux helpers `_compose_icon` / `_compose_world` :
```gdscript
# Icône de boutique : sprite de l'élément composé sur un disque coloré.
static func build_icon(element: String, tier_color: Color) -> Texture:
	return _compose_icon(element_sprite_path(element), tier_color)

# Sprite EN JEU : sprite de l'élément, 48×48, SANS fond.
static func build_world_texture(element: String) -> Texture:
	return _compose_world(element_sprite_path(element))

# --- Rétro-compat : la Bombe normale (troll bombe, etc.). ---
static func build_normal_icon(tier_color: Color) -> Texture:
	return build_icon("normal", tier_color)

static func build_normal_world_texture() -> Texture:
	return build_world_texture("normal")

# Composition icône (disque coloré + sprite). Null si l'asset ne charge pas.
static func _compose_icon(path: String, tier_color: Color) -> Texture:
	var sprite_img := _load_image(path)
	if sprite_img == null:
		return null
	var w := sprite_img.get_width()
	var h := sprite_img.get_height()
	var bg := _make_disc(w, h, icon_background_color(tier_color))
	bg.blend_rect(sprite_img, Rect2(0, 0, w, h), Vector2(0, 0))
	var tex := ImageTexture.new()
	tex.create_from_image(bg, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS)
	return tex

# Composition sprite en jeu (48×48, sans fond). Null si l'asset ne charge pas.
static func _compose_world(path: String) -> Texture:
	var img := _load_image(path)
	if img == null:
		return null
	if img.get_width() != _WORLD_SIZE or img.get_height() != _WORLD_SIZE:
		img.resize(_WORLD_SIZE, _WORLD_SIZE, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS)
	return tex
```
Supprimer les anciens corps de `build_normal_icon`/`build_normal_world_texture` (remplacés par les délégations + helpers). Conserver `icon_background_color`, `_load`, `_load_image`, `_make_disc`, `COMMON_BG`, `_WORLD_SIZE`.

- [ ] **Step 5: Lancer les tests pour vérifier le succès**

Run: (commande runner)
Expected: `=== N tests, 0 échec(s) ===` (N += 3). Les anciens tests de `bomb_skin` restent verts.

- [ ] **Step 6: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/glace.png Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): skin de bombe indexé par élément (+ asset glace.png)"
```

---

### Task 5: Données des 4 bombes de glace (`.tres`)

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_1_data.tres` … `bomb_ice_4_data.tres`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_1_stats.tres` … `bomb_ice_4_stats.tres`

**Interfaces:**
- Produces: 4 `WeaponData` (`weapon_id = "weapon_bomb_ice"`, `my_id = weapon_bomb_ice_1..4`, tiers 0..3, chaîne `upgrades_into` 1→2→3→4, set `explosive`, `BurningEffect` givre bleu) + 4 `RangedWeaponStats` (`damage = 0`, `speed_percent_modifier = -30/-40/-50/-60`).

**Note test:** ces `.tres` référencent des scripts/scènes vanilla + autoloads → **non chargeables en headless** (le runner ne les charge pas). Vérification = **checks statiques** (Step 3) + **en jeu** (checklist finale). Ne PAS les `preload` dans le runner.

- [ ] **Step 1: Créer les 4 fichiers de stats**

`bomb_ice_1_stats.tres` (tier I) :
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
speed_percent_modifier = -30
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
`bomb_ice_2_stats.tres` : identique mais `cooldown = 80` et `speed_percent_modifier = -40`.
`bomb_ice_3_stats.tres` : `cooldown = 70`, `speed_percent_modifier = -50`.
`bomb_ice_4_stats.tres` : `cooldown = 60`, `speed_percent_modifier = -60`.

- [ ] **Step 2: Créer les 4 fichiers de data**

`bomb_ice_1_data.tres` (tier I, `upgrades_into` → tier II) :
```
[gd_resource type="Resource" load_steps=11 format=2]

[ext_resource path="res://items/global/weapon_data.gd" type="Script" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=2]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn" type="PackedScene" id=3]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_1_stats.tres" type="Resource" id=4]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_2_data.tres" type="Resource" id=5]
[ext_resource path="res://items/sets/explosive/explosive_set_data.tres" type="Resource" id=6]
[ext_resource path="res://effects/weapons/burning_effect.gd" type="Script" id=7]
[ext_resource path="res://effects/burning_data.gd" type="Script" id=8]

[sub_resource type="Resource" id=1]
script = ExtResource( 8 )
chance = 1.0
damage = 0
duration = 4
spread = 0
scaling_stats = [ [ "stat_engineering", 0.0 ] ]
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
my_id = "weapon_bomb_ice_1"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "WEAPON_BOMB_ICE"
tier = 0
value = 20
effects = [ SubResource( 2 ) ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
weapon_id = "weapon_bomb_ice"
type = 1
sets = [ ExtResource( 6 ) ]
scene = ExtResource( 3 )
stats = ExtResource( 4 )
upgrades_into = ExtResource( 5 )
add_to_chars_as_starting = [  ]
```
`bomb_ice_2_data.tres` : idem mais `my_id = "weapon_bomb_ice_2"`, `tier = 1`, `value = 39`, `id=4` → `bomb_ice_2_stats.tres`, `id=5` → `bomb_ice_3_data.tres`.
`bomb_ice_3_data.tres` : `my_id = "weapon_bomb_ice_3"`, `tier = 2`, `value = 74`, `id=4` → `bomb_ice_3_stats.tres`, `id=5` → `bomb_ice_4_data.tres`.
`bomb_ice_4_data.tres` (tier IV, **PAS** d'`upgrades_into`) — retirer l'ext_resource `id=5` et la ligne `upgrades_into`, décaler les IDs suivants, `load_steps=10` :
```
[gd_resource type="Resource" load_steps=10 format=2]

[ext_resource path="res://items/global/weapon_data.gd" type="Script" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=2]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn" type="PackedScene" id=3]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_4_stats.tres" type="Resource" id=4]
[ext_resource path="res://items/sets/explosive/explosive_set_data.tres" type="Resource" id=5]
[ext_resource path="res://effects/weapons/burning_effect.gd" type="Script" id=6]
[ext_resource path="res://effects/burning_data.gd" type="Script" id=7]

[sub_resource type="Resource" id=1]
script = ExtResource( 7 )
chance = 1.0
damage = 0
duration = 4
spread = 0
scaling_stats = [ [ "stat_engineering", 0.0 ] ]
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
my_id = "weapon_bomb_ice_4"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "WEAPON_BOMB_ICE"
tier = 3
value = 149
effects = [ SubResource( 2 ) ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
weapon_id = "weapon_bomb_ice"
type = 1
sets = [ ExtResource( 5 ) ]
scene = ExtResource( 3 )
stats = ExtResource( 4 )
add_to_chars_as_starting = [  ]
```

- [ ] **Step 3: Vérifs statiques**

```bash
cd Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb
grep -H "my_id\|weapon_id\|^tier\|speed_percent_modifier\|^damage\|upgrades_into\|load_steps" bomb_ice_*_data.tres bomb_ice_*_stats.tres
```
Attendu : `weapon_id = "weapon_bomb_ice"` dans les 4 data ; `my_id` = `weapon_bomb_ice_1..4` ; `tier` 0/1/2/3 ; `speed_percent_modifier` -30/-40/-50/-60 ; `damage = 0` dans les stats ; `upgrades_into` présent dans data 1/2/3 et ABSENT dans data 4 ; `load_steps=11` (data 1-3) / `10` (data 4) / `2` (stats).
Vérifier aussi que chaque `id=N` référencé (SubResource/ExtResource) existe bien dans son fichier (pas de trou d'ID).

- [ ] **Step 4: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_*_data.tres Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_*_stats.tres
git commit -m "feat(bomberman): data des 4 bombes de glace (slow par tier + givre bleu)"
```

---

### Task 6: Mode « bombe à effet » dans `bomb_entity.gd`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd`

**Interfaces:**
- Consumes: `BombElement` (Task 1), `BombIceSlow` (Task 2).
- Produces: nouvelle signature
  `arm(p_player_index, p_stats, p_tier, p_explosion_scale=1.75, p_damage_tracking_key_hash=Keys.empty_hash, p_explosion_damage=-1, p_element=BombElement.NORMAL, p_weapon=null)`.
  Comportement bombe à effet : `damage AoE = 0`, `_will_wake = false`, et (glace) connexion du signal `hit_something` de l'explosion vers `p_weapon.on_ice_hit` avec le slow % du tier. La Bombe normale reste inchangée (rétro-compat : `troll_bomb`/appelants qui ne passent pas `p_element` → NORMAL).

- [ ] **Step 1: Ajouter les preloads + champs**

En haut de `bomb_entity.gd`, après les `const ... = preload(...)` existants, ajouter :
```gdscript
const BombElement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd")
const BombIceSlow = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_ice_slow.gd")
```
Près des autres `var _...`, ajouter :
```gdscript
var _element: String = BombElement.NORMAL  # élément de la bombe (pilote le sous-comportement)
var _weapon = null                          # arme source (persistante) : cible du signal de slow glace
```

- [ ] **Step 2: Étendre `arm()`**

Remplacer la signature et le corps de `arm(...)` : ajouter les 2 paramètres et l'usage du skin par élément + `_will_wake` conditionnel.

Signature :
```gdscript
func arm(p_player_index: int, p_stats: WeaponStats, p_tier: int, p_explosion_scale: float = 1.75, p_damage_tracking_key_hash: int = Keys.empty_hash, p_explosion_damage: int = -1, p_element: String = BombElement.NORMAL, p_weapon = null) -> void:
```
Dans le corps, juste après `_explosion_damage_override = p_explosion_damage` :
```gdscript
	_element = p_element
	_weapon = p_weapon
```
Remplacer le chargement du skin :
```gdscript
	var skin = BombSkin.build_normal_world_texture()
```
par :
```gdscript
	var skin = BombSkin.build_world_texture(_element)
```
Remplacer le tirage du réveil :
```gdscript
	_will_wake = TrollBombLogic.should_wake(randf(), TROLL_WAKE_CHANCE)
```
par :
```gdscript
	# Seule la Bombe normale peut se transformer en trollbombe ; les bombes à
	# effet (glace/poison/foudre) ne se réveillent jamais.
	if BombElement.is_effect(_element):
		_will_wake = false
	else:
		_will_wake = TrollBombLogic.should_wake(randf(), TROLL_WAKE_CHANCE)
```

- [ ] **Step 3: Étendre `_on_fuse_timeout()` (0 dégât + connexion slow)**

Dans `_on_fuse_timeout()`, remplacer la ligne :
```gdscript
	_explode_args.damage = _explosion_damage_override if _explosion_damage_override >= 0 else _stats.damage
```
par :
```gdscript
	# Bombes à effet : AUCUN dégât d'explosion AoE (les effets — slow, givre —
	# s'appliquent indépendamment ; deals_damage reste true donc les hits sont émis).
	if BombElement.is_effect(_element):
		_explode_args.damage = 0
	else:
		_explode_args.damage = _explosion_damage_override if _explosion_damage_override >= 0 else _stats.damage
```
Puis, juste après `ExplosionVisual.cap_aoe_opacity(_inst)` et AVANT `queue_free()`, ajouter :
```gdscript
	# Glace : coupe de vitesse réelle sur les ennemis touchés, via le signal
	# public hit_something de l'explosion (émis même à 0 dégât, unit.gd:608) →
	# notre BombWeapon (persistant). AUCUNE extension de enemy.gd. La connexion
	# est nettoyée par PlayerExplosion.end_explosion (disconnect_all hit_something).
	if _element == BombElement.ICE and _inst != null and is_instance_valid(_weapon) and _stats != null:
		var slow_pct = BombIceSlow.slow_pct_for(_stats.speed_percent_modifier)
		if not _inst.is_connected("hit_something", _weapon, "on_ice_hit"):
			_inst.connect("hit_something", _weapon, "on_ice_hit", [slow_pct])
```
(Le `var _inst = WeaponService.explode(...)` existe déjà ; ne pas le redéclarer.)

- [ ] **Step 4: Vérif de non-régression pure (parse) + statique**

Run: (commande runner) — le runner ne charge pas `bomb_entity.gd` (autoloads), mais il ne doit PAS régresser. Expected: `=== N tests, 0 échec(s) ===` (inchangé vs Task 5).
Statique : `grep -n "build_world_texture\|is_effect\|on_ice_hit\|_element\|_weapon" bomb_entity.gd` → confirme les branchements.

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd
git commit -m "feat(bomberman): bomb_entity en mode bombe à effet (glace : 0 dégât + slow via signal)"
```

---

### Task 7: `bomb_weapon.gd` — élément, skin tenu, `on_ice_hit`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd`

**Interfaces:**
- Consumes: `BombElement` (Task 1), `BombIceSlow` (Task 2), la nouvelle signature `bomb.arm(..., p_element, p_weapon)` (Task 6).
- Produces: méthode publique `on_ice_hit(thing_hit, damage_dealt, slow_pct)` (cible du signal `hit_something` connecté par `bomb_entity`).

- [ ] **Step 1: Ajouter les preloads**

En haut de `bomb_weapon.gd`, après les `const ... = preload(...)` existants :
```gdscript
const BombElement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd")
const BombIceSlow = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_ice_slow.gd")
```

- [ ] **Step 2: Skin tenu par élément dans `_ready()`**

Dans `_ready()`, remplacer :
```gdscript
	var skin = BombSkin.build_normal_world_texture()
```
par :
```gdscript
	var skin = BombSkin.build_world_texture(BombElement.from_weapon_id(weapon_id))
```
(`weapon_id` est posé par `player.gd:add_weapon` AVANT `_ready()` — cf. `player.gd:376`.)

- [ ] **Step 3: Passer élément + arme à `arm()` dans `shoot()`**

Dans `shoot()`, remplacer :
```gdscript
	bomb.arm(player_index, current_stats, tier, EXPLOSION_SCALE, Keys.empty_hash, explosion_damage)
```
par :
```gdscript
	bomb.arm(player_index, current_stats, tier, EXPLOSION_SCALE, Keys.empty_hash, explosion_damage, BombElement.from_weapon_id(weapon_id), self)
```

- [ ] **Step 4: Ajouter `on_ice_hit`**

Ajouter une méthode (par ex. après `shoot()`):
```gdscript
# Cible du signal hit_something de l'explosion d'une bombe de GLACE (connecté par
# bomb_entity). Applique une coupe de vitesse RÉELLE et NON CUMULATIVE à l'ennemi
# touché (cf. bomb_ice_slow). Duck-typé : ne touche que des unités ayant
# current_stats/max_stats (marche vanilla/DLC/autre mod, sans étendre enemy.gd).
func on_ice_hit(thing_hit, _damage_dealt, slow_pct: float) -> void:
	if not is_instance_valid(thing_hit):
		return
	if not ("current_stats" in thing_hit) or not ("max_stats" in thing_hit):
		return
	if thing_hit.current_stats == null or thing_hit.max_stats == null:
		return
	thing_hit.current_stats.speed = BombIceSlow.apply(
		thing_hit.current_stats.speed,
		thing_hit.max_stats.speed,
		slow_pct
	)
```

- [ ] **Step 5: Vérif statique + non-régression**

Run: (commande runner) → `0 échec(s)` (inchangé).
Statique : `grep -n "from_weapon_id\|on_ice_hit\|build_world_texture\|bomb.arm" bomb_weapon.gd` → confirme les 4 branchements.

- [ ] **Step 6: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd
git commit -m "feat(bomberman): bomb_weapon élément-aware + on_ice_hit (coupe de vitesse glace)"
```

---

### Task 8: Enregistrement des 4 armes de glace — `item_service.gd`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd`

**Interfaces:**
- Consumes: `BombElement` (Task 1), `BombSkin.build_icon(element, tier_color)` (Task 4), les `.tres` de glace (Task 5).
- Produces: les 4 armes de glace injectées dans `weapons`, avec icône (élément, tier).

- [ ] **Step 1: Ajouter le preload d'élément**

En haut de `item_service.gd`, après les `const ... = preload(...)` :
```gdscript
const BombElement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd")
```

- [ ] **Step 2: Ajouter les chemins des armes de glace**

Après le bloc `const _BOMB_WEAPONS := [ ... ]`, ajouter :
```gdscript
const _BOMB_ICE_WEAPONS := [
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_1_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_2_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_3_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_4_data.tres",
]
```

- [ ] **Step 3: Injecter les armes de glace (icône par élément)**

Dans `_ready()`, la boucle actuelle sur `_BOMB_WEAPONS` pose l'icône via `BombSkin.build_normal_icon(...)`. La rendre élément-aware et l'appliquer aussi à la glace. Remplacer la boucle existante :
```gdscript
	for path in _BOMB_WEAPONS:
		var w = load(path)
		if w != null:
			var skin = BombSkin.build_normal_icon(get_color_from_tier(w.tier))
			if skin != null:
				w.icon = skin
		if w != null and not weapons.has(w):
			weapons.append(w)
			ModLog.info("arme enregistrée: " + str(w.my_id))
```
par une version factorisée qui traite les deux listes :
```gdscript
	for path in _BOMB_WEAPONS:
		_register_bomb_weapon(path)
	for path in _BOMB_ICE_WEAPONS:
		_register_bomb_weapon(path)
```
Et ajouter la fonction helper (par ex. juste avant `func get_player_shop_items`):
```gdscript
# Charge une arme-bombe, pose son icône (bombe de l'élément sur disque de rareté)
# et l'injecte dans le pool. Idempotent. Icône runtime (null en headless => on
# garde l'icône du .tres).
func _register_bomb_weapon(path: String) -> void:
	var w = load(path)
	if w == null:
		return
	var element = BombElement.from_weapon_id(w.weapon_id)
	var skin = BombSkin.build_icon(element, get_color_from_tier(w.tier))
	if skin != null:
		w.icon = skin
	if not weapons.has(w):
		weapons.append(w)
		ModLog.info("arme enregistrée: " + str(w.my_id))
```

- [ ] **Step 4: Vérif statique + non-régression**

Run: (commande runner) → `0 échec(s)` (le runner ne charge pas cette extension, mais ne doit pas régresser).
Statique : `grep -n "_BOMB_ICE_WEAPONS\|_register_bomb_weapon\|build_icon" extensions/singletons/item_service.gd`.

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd
git commit -m "feat(bomberman): enregistre les 4 armes bombe de glace (icône par élément)"
```

---

### Task 9: i18n — `WEAPON_BOMB_ICE`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd`

- [ ] **Step 1: Ajouter les messages FR/EN**

Dans `register()`, ajouter aux blocs `tr_en` et `tr_fr` :
```gdscript
	tr_en.add_message("WEAPON_BOMB_ICE", "Ice Bomb")
```
(après `tr_en.add_message("WEAPON_BOMB", "Bomb")`) et
```gdscript
	tr_fr.add_message("WEAPON_BOMB_ICE", "Bombe de Glace")
```
(après `tr_fr.add_message("WEAPON_BOMB", "Bombe")`). Mettre à jour le commentaire d'en-tête (liste des clés) pour inclure `WEAPON_BOMB_ICE`.

- [ ] **Step 2: Vérif statique**

`grep -n "WEAPON_BOMB_ICE" content/i18n/bomberman_translations.gd` → 2 occurrences (en + fr).

- [ ] **Step 3: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd
git commit -m "feat(bomberman): i18n WEAPON_BOMB_ICE (FR/EN)"
```

---

### Task 10: Vérification EN JEU (humain) + notes

**Files:** aucun (checklist de validation manuelle — les sous-agents ne lancent pas Brotato).

**Setup :** symlinker/copier le dossier du mod dans `mods-unpacked/` à côté du `.pck`, activer `Tanith-DevUnlockAll` si besoin de forcer le perso, lancer Brotato en Bomberto.

- [ ] **Boutique** : la Bombe de Glace apparaît (icône = bombe sur disque coloré à la rareté ; nom « Bombe de Glace »/« Ice Bomb ») ; le pool magasin reste borné au roster Bomberto.
- [ ] **Équipement** : sprite tenu = bombe de glace (`glace.png`), constant tous tiers ; outline coloré par tier (highlight vanilla).
- [ ] **Pose + explosion** : la bombe posée = sprite glace ; explosion AoE **0 dégât** (les ennemis ne perdent pas de PV) ; **jamais** de trollbombe.
- [ ] **Slow** : les ennemis touchés **ralentissent durablement** (vitesse réelle réduite) ; plus fort aux tiers élevés (30/40/50/60 %) ; **non cumulatif** (2 bombes de même tier ne cumulent pas ; un tier plus haut écrase, un plus bas ne fait rien).
- [ ] **Givre bleu** : les ennemis touchés « fument » en **bleu** (particules), **sans** perdre de PV.
- [ ] **Montée en tiers** : upgrade I→IV fonctionne (fusion boutique).
- [ ] **Coop** : slow + givre corrects pour chaque joueur ; pas de contamination des explosions d'autres armes (une explosion vanilla/normale ne ralentit PAS).
- [ ] **Repli 0→1 dégât** : si un test montre qu'un 0 dégât AoE empêche le hit d'enregistrer (pas de slow/givre), passer `_explode_args.damage` des bombes à effet à **1** (autorisé par l'utilisateur) et re-tester.

**Après validation en jeu :** mettre à jour la mémoire `brotato-bomberman-sdd-status.md` (Phase 2 code-complète + validée), et prévoir la release (bump manifest + changelog) + packaging Workshop avec la Phase 1 (purge des skins colorés orphelins) au moment du déploiement.

---

## Notes de portée

- **Opacité d'AOE configurable** (`explosion_opacity` en config de mod, aujourd'hui en dur à 0.2 dans `explosion_visual.gd`) : évoquée pour la Phase 2 dans la mémoire, mais **indépendante** de la Bombe de Glace → **hors périmètre de ce plan** ; à traiter séparément (petit chantier config).
- **Poison & Foudre** : Phases 3 et 4, chacune son plan/session. Ce plan pose déjà la plomberie réutilisable (`bomb_element`, mode bombe à effet de `bomb_entity`, skin par élément, préfixe de pool, `_register_bomb_weapon`).
