# Troll bombe — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter la « troll bombe » au mod Bomberman : aléatoirement (~10 %), une bombe posée se réveille pendant sa mèche et devient un danger mobile inarrêtable qui poursuit le joueur le plus proche pour lui exploser au visage.

**Architecture:** Entité maison dédiée (`troll_bomb`, un `Node2D` autonome, hors du système d'ennemis vanilla) instanciée par `bomb_entity` quand le dé du réveil réussit. Dégâts au joueur via une `Hitbox` couche 4 (le chemin de contact des ennemis) → touche joueurs/alliés, pas les ennemis. Toute la décision (dé, instant de réveil, cible la plus proche, vecteur de déplacement) vit dans un module de **logique pure** testable headless ; le comportement de scène est vérifié en jeu par l'humain.

**Tech Stack:** Godot 3.6.2 (GDScript), ModLoader (script extensions), runner de tests GDScript autonome du mod.

## Global Constraints

- Tout en **français** : commentaires, docs, libellés de commit.
- Logique pure uniquement dans `content/logic/` (aucune dépendance jeu/autoload) ; c'est le **seul** code testable headless. Le reste se vérifie **en jeu** (humain).
- Sprites chargés au **runtime** (`Image.load` → `ImageTexture`, `flags=0` = pixel-art net) pour contourner le cache `.import`/`.stex` — réutiliser `BombSkin._load(path)`.
- Couleur du corps de la troll bombe = **tier de la bombe d'origine** (réutiliser `BombSkin.load_world_texture(tier)` ; mapping gris/bleu/violet/rouge déjà en place).
- Dégâts de la troll bombe = `stats.damage` de la bombe (montée en puissance par tier).
- `OptionButton`/identité d'élément : sans objet ici.
- Tests : runner `res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd` ; **code de sortie = nombre d'échecs (0 = vert)**. Les erreurs moteur affichées APRÈS la ligne « N tests, M échec(s) » (fermeture des autoloads) n'affectent pas le résultat.
- Commande de test (depuis la racine du repo) :
  `./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
- Spec de référence : `docs/superpowers/specs/2026-06-27-troll-bombe-design.md`.
- Branche de travail : `feat/troll-bombe` (déjà créée).

---

## Fichiers (création / modification)

- **Create** `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd` — logique pure (dé, instant de réveil, cible la plus proche, déplacement).
- **Modify** `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd` — enregistre les tests de la logique pure.
- **Create** `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/skins/troll_bomb_face.png` — overlay « visage fâché » (placeholder).
- **Create** `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.tscn` — scène de l'entité.
- **Create** `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.gd` — comportement de l'entité.
- **Modify** `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd` — dé du réveil + bascule en troll bombe + son.

---

## Task 1: Logique pure `troll_bomb_logic.gd` (+ tests)

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Produces (utilisé par les Tasks 2 et 3) :
  - `static func should_wake(roll: float, chance: float) -> bool`
  - `static func wake_delay(fuse_seconds: float, fraction: float) -> float`
  - `static func nearest_target(from_pos: Vector2, targets: Array) -> Dictionary` — `targets` = `Array` de `Dictionary {position: Vector2, dead: bool, index: int}` ; retourne `{found: bool, index: int, position: Vector2}`.
  - `static func step_velocity(from_pos: Vector2, target_pos: Vector2, speed: float) -> Vector2`

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter le `const` de preload en tête (à côté des autres consts existants, après la ligne `const BombSkin = ...`) :

```gdscript
const TrollLogic = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd")
```

Dans `func _init()`, ajouter les appels des 4 nouvelles suites APRÈS `_test_bomb_skin()` et AVANT la ligne `print("=== %d tests...`:

```gdscript
	_test_troll_should_wake()
	_test_troll_wake_delay()
	_test_troll_nearest_target()
	_test_troll_step_velocity()
```

Ajouter les 4 fonctions de test à la fin du fichier (avant `func _check`) :

```gdscript
func _test_troll_should_wake():
	_check(TrollLogic.should_wake(0.0, 0.1) == true, "troll: roll 0.0 < 0.1 => réveil")
	_check(TrollLogic.should_wake(0.05, 0.1) == true, "troll: roll 0.05 < 0.1 => réveil")
	_check(TrollLogic.should_wake(0.1, 0.1) == false, "troll: roll 0.1 pas < 0.1 => non")
	_check(TrollLogic.should_wake(0.5, 0.0) == false, "troll: chance 0 => jamais")
	_check(TrollLogic.should_wake(0.99, 1.0) == true, "troll: chance 1 => toujours")


func _test_troll_wake_delay():
	_check(_approx(TrollLogic.wake_delay(2.0, 0.5), 1.0), "troll: réveil à 50% de 2.0s = 1.0s")
	_check(_approx(TrollLogic.wake_delay(1.0, 0.5), 0.5), "troll: réveil à 50% de 1.0s = 0.5s")
	_check(_approx(TrollLogic.wake_delay(2.0, 0.0), 0.0), "troll: fraction 0 => 0")
	_check(_approx(TrollLogic.wake_delay(2.0, 2.0), 2.0), "troll: fraction clamp haut => mèche pleine")
	_check(_approx(TrollLogic.wake_delay(2.0, -1.0), 0.0), "troll: fraction clamp bas => 0")


func _test_troll_nearest_target():
	var from = Vector2(0, 0)
	var p_far = {"position": Vector2(100, 0), "dead": false, "index": 0}
	var p_near = {"position": Vector2(10, 0), "dead": false, "index": 1}
	var r = TrollLogic.nearest_target(from, [p_far, p_near])
	_check(r["found"] and r["index"] == 1, "troll: cible = joueur le plus proche")
	var p_dead_near = {"position": Vector2(5, 0), "dead": true, "index": 2}
	var r2 = TrollLogic.nearest_target(from, [p_dead_near, p_far])
	_check(r2["found"] and r2["index"] == 0, "troll: ignore le joueur mort")
	var r3 = TrollLogic.nearest_target(from, [])
	_check(not r3["found"], "troll: liste vide => aucune cible")
	var r4 = TrollLogic.nearest_target(from, [p_dead_near])
	_check(not r4["found"], "troll: tous morts => aucune cible")


func _test_troll_step_velocity():
	var v = TrollLogic.step_velocity(Vector2(0, 0), Vector2(10, 0), 100.0)
	_check(_approx(v.x, 100.0) and _approx(v.y, 0.0), "troll: déplacement vers la droite = (100,0)")
	_check(_approx(v.length(), 100.0), "troll: norme du déplacement = vitesse")
	var z = TrollLogic.step_velocity(Vector2(5, 5), Vector2(5, 5), 100.0)
	_check(z == Vector2.ZERO, "troll: positions confondues => zéro")
```

- [ ] **Step 2: Lancer les tests pour vérifier l'échec**

Run : `./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

Expected : ÉCHEC — le runner ne charge pas (erreur de parse « Could not preload resource file … troll_bomb_logic.gd ») car le fichier de logique n'existe pas encore.

- [ ] **Step 3: Écrire la logique pure minimale**

Créer `content/logic/troll_bomb_logic.gd` :

```gdscript
extends Reference
# Logique PURE de la troll bombe (aucune dépendance jeu) — testable headless.
# La bombe posée se "réveille" aléatoirement pendant sa mèche et devient un
# danger mobile qui poursuit le joueur le plus proche. Ici on ne décide QUE :
# le tirage du réveil, l'instant du réveil, la cible la plus proche, et le
# vecteur de déplacement. Tout le reste (scène, hitbox, explosion) est en jeu.

# Vrai si la bombe doit se réveiller. roll attendu dans [0, 1) (ex. randf()).
static func should_wake(roll: float, chance: float) -> bool:
	return roll < chance


# Instant du réveil dans la mèche : fraction (bornée [0,1]) de la durée de mèche.
static func wake_delay(fuse_seconds: float, fraction: float) -> float:
	var f := fraction
	if f < 0.0:
		f = 0.0
	if f > 1.0:
		f = 1.0
	var d := fuse_seconds * f
	if d < 0.0:
		d = 0.0
	return d


# Joueur VIVANT le plus proche.
# targets = Array de Dictionary {position: Vector2, dead: bool, index: int}.
# Retourne {found: bool, index: int, position: Vector2}.
static func nearest_target(from_pos: Vector2, targets: Array) -> Dictionary:
	var best := {"found": false, "index": -1, "position": Vector2.ZERO}
	var best_d := 0.0
	for t in targets:
		if t.get("dead", false):
			continue
		var p: Vector2 = t["position"]
		var d := from_pos.distance_squared_to(p)
		if not best["found"] or d < best_d:
			best = {"found": true, "index": t.get("index", -1), "position": p}
			best_d = d
	return best


# Vecteur de déplacement vers la cible, normé à speed. Zéro si positions confondues.
static func step_velocity(from_pos: Vector2, target_pos: Vector2, speed: float) -> Vector2:
	var delta := target_pos - from_pos
	if delta.length() < 0.0001:
		return Vector2.ZERO
	return delta.normalized() * speed
```

- [ ] **Step 4: Lancer les tests pour vérifier le succès**

Run : `./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

Expected : la ligne `=== N tests, 0 échec(s) ===` avec N = ancien total (25) + 17 nouveaux = **42 tests, 0 échec(s)**, code de sortie 0.

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): logique pure de la troll bombe (dé, réveil, cible, déplacement)"
```

---

## Task 2: Entité `troll_bomb` (scène + script + visage placeholder)

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/skins/troll_bomb_face.png`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.tscn`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.gd`

**Interfaces:**
- Consumes : `TrollBombLogic.nearest_target`, `TrollBombLogic.step_velocity` (Task 1) ; `BombSkin.load_world_texture(tier)`, `BombSkin._load(path)` (existant).
- Produces (utilisé par la Task 3) :
  - Scène `troll_bomb.tscn` avec la méthode :
    `func arm(p_player_index: int, p_stats: WeaponStats, p_tier: int, p_explosion_scale: float = 1.5, p_damage_tracking_key_hash: int = Keys.empty_hash) -> void`

Note : pas de test headless possible (autoloads + physique). Le **garde automatique** est : la suite de tests reste verte (Task 1) et le mod se charge en jeu **sans erreur de parse**. La vérification fonctionnelle est faite **en jeu par l'humain** (cf. Step 6).

- [ ] **Step 1: Créer le visage placeholder**

On réutilise un overlay existant du mod comme placeholder runtime (art final plus tard). Depuis la racine du repo :

```bash
cp Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/bomberman_eyes.png \
   Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/skins/troll_bomb_face.png
```

- [ ] **Step 2: Écrire le script de l'entité**

Créer `content/entities/troll_bomb.gd` :

```gdscript
extends Node2D
# Troll bombe : bombe posée qui s'est "réveillée" et poursuit le joueur VIVANT
# le plus proche pour lui exploser au visage. Inarrêtable par les armes (aucune
# hurtbox -> ne prend pas de dégâts) ; ne disparaît qu'en explosant — au CONTACT
# d'un joueur OU en fin de minuteur de poursuite.
#
# Dégâts : via une Hitbox couche 4 (le chemin de contact des ENNEMIS) -> seules
# les hurtbox de joueurs/alliés réagissent, jamais les ennemis. damage = celui
# de la bombe d'origine. L'explosion finale est purement VISUELLE (damage 0) :
# les vrais dégâts viennent de la Hitbox de contact.
#
# Couleur du corps = tier de la bombe d'origine (sprite en jeu réutilisé) ;
# visage fâché en surcouche. Vitesse FIXE (indépendante de la stat vitesse).

const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")
const TrollBombLogic = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd")

const _FACE_PATH := "res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/skins/troll_bomb_face.png"

# --- Paramètres réglables (calibrage final en jeu) ---
const SPEED := 120.0          # ≈ vitesse de base d'un joueur, CONSTANTE
const PURSUIT_SECONDS := 5.0  # minuteur de poursuite (plage à tester 4-6)

var _player_index: int = -1
var _stats: WeaponStats = null
var _tier: int = 0
var _explosion_scale: float = 1.5
var _damage_tracking_key_hash: int = Keys.empty_hash
var _exploded: bool = false

var _explosion_scene: PackedScene = preload("res://projectiles/explosion.tscn")
var _exploding_effect: ExplodingEffect = null
var _explode_args := WeaponServiceExplodeArgs.new()

onready var _body: Sprite = $Body
onready var _face: Sprite = $Face
onready var _hitbox: Hitbox = $Hitbox
onready var _pursuit_timer: Timer = $PursuitTimer


func _ready() -> void:
	# Effet d'explosion VISUEL (équivaut au .tres landmine ; damage 0 à l'usage).
	_exploding_effect = ExplodingEffect.new()
	_exploding_effect.explosion_scene = _explosion_scene
	_exploding_effect.scale = _explosion_scale
	_exploding_effect.base_smoke_amount = 40
	_exploding_effect.sound_db_mod = -10
	var _e1 = _pursuit_timer.connect("timeout", self, "_on_pursuit_timeout")
	# La hurtbox du joueur appelle hitbox.hit_something() quand elle encaisse :
	# c'est notre signal de "contact joueur" -> on explose.
	var _e2 = _hitbox.connect("hit_something", self, "_on_hit_player")


# Appelée juste après instanciation par bomb_entity (au réveil).
func arm(p_player_index: int, p_stats: WeaponStats, p_tier: int, p_explosion_scale: float = 1.5, p_damage_tracking_key_hash: int = Keys.empty_hash) -> void:
	_player_index = p_player_index
	_stats = p_stats
	_tier = p_tier
	_explosion_scale = p_explosion_scale
	_damage_tracking_key_hash = p_damage_tracking_key_hash
	if _exploding_effect != null:
		_exploding_effect.scale = _explosion_scale

	# Corps coloré par le tier d'origine (sprite en jeu 48 réutilisé).
	var body_tex = BombSkin.load_world_texture(p_tier)
	if body_tex != null and is_instance_valid(_body):
		_body.texture = body_tex
	# Visage fâché en surcouche (placeholder -> art final).
	var face_tex = BombSkin._load(_FACE_PATH)
	if face_tex != null and is_instance_valid(_face):
		_face.texture = face_tex

	# Hitbox de contact : inflige les dégâts de la bombe aux joueurs/alliés (couche 4).
	if is_instance_valid(_hitbox):
		_hitbox.damage = int(_stats.damage) if _stats != null else 1
		_hitbox.from = null
		_hitbox.damage_tracking_key_hash = Keys.empty_hash
		_hitbox.enable()

	_pursuit_timer.wait_time = PURSUIT_SECONDS
	_pursuit_timer.start()


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	var target = _nearest_player()
	if not target["found"]:
		return
	var vel = TrollBombLogic.step_velocity(global_position, target["position"], SPEED)
	global_position += vel * delta


# Construit la liste pure des joueurs et délègue le choix à la logique pure.
func _nearest_player() -> Dictionary:
	var main = Utils.get_scene_node()
	if main == null or not ("_players" in main):
		return {"found": false}
	var targets := []
	var idx := 0
	for p in main._players:
		if is_instance_valid(p):
			targets.append({"position": p.global_position, "dead": p.dead, "index": idx})
		idx += 1
	return TrollBombLogic.nearest_target(global_position, targets)


# Le joueur a encaissé notre Hitbox -> explosion au visage.
func _on_hit_player(_thing_hit, _damage_dealt) -> void:
	_explode()


# Le minuteur de poursuite a expiré sans contact -> explosion sur place.
func _on_pursuit_timeout() -> void:
	_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	set_physics_process(false)
	if is_instance_valid(_hitbox):
		_hitbox.disable()
	# Explosion VISUELLE uniquement (damage 0) : les dégâts joueur viennent de
	# la Hitbox de contact. WeaponService.explode crée le visuel + fumée + son.
	_explode_args.pos = global_position
	_explode_args.damage = 0
	if _stats != null:
		_explode_args.accuracy = _stats.accuracy
		_explode_args.crit_chance = _stats.crit_chance
		_explode_args.crit_damage = _stats.crit_damage
		_explode_args.burning_data = _stats.burning_data
		_explode_args.scaling_stats = _stats.scaling_stats
	_explode_args.from_player_index = _player_index
	_explode_args.from = null
	_explode_args.damage_tracking_key_hash = Keys.empty_hash
	var _inst = WeaponService.explode(_exploding_effect, _explode_args)
	queue_free()
```

- [ ] **Step 3: Écrire la scène**

Créer `content/entities/troll_bomb.tscn` :

```
[gd_scene load_steps=4 format=2]

[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.gd" type="Script" id=1]
[ext_resource path="res://overlap/hitbox.tscn" type="PackedScene" id=2]

[sub_resource type="CircleShape2D" id=1]
radius = 50.0

[node name="TrollBomb" type="Node2D"]
script = ExtResource( 1 )

[node name="Body" type="Sprite" parent="."]

[node name="Face" type="Sprite" parent="."]

[node name="Hitbox" parent="." instance=ExtResource( 2 )]
collision_layer = 4

[node name="Collision" parent="Hitbox" index="0"]
shape = SubResource( 1 )

[node name="PursuitTimer" type="Timer" parent="."]
one_shot = true

[editable path="Hitbox"]
```

- [ ] **Step 4: Vérifier que la suite de tests reste verte (garde de non-régression)**

Run : `./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

Expected : `=== 42 tests, 0 échec(s) ===`, code de sortie 0 (la logique pure n'a pas bougé ; on confirme juste qu'on n'a rien cassé).

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.gd Brotato/mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.tscn Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/skins/troll_bomb_face.png
git commit -m "feat(bomberman): entité troll bombe (poursuite + explosion au contact, dégâts joueurs)"
```

- [ ] **Step 6: Vérification EN JEU (humain) — à faire après la Task 3**

L'entité n'est pas instanciée tant que `bomb_entity` ne la réveille pas (Task 3). Les vérifs en jeu sont donc listées au Step 6 de la Task 3.

---

## Task 3: Réveil dans `bomb_entity` (dé + bascule + son)

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd`

**Interfaces:**
- Consumes : `TrollBombLogic.should_wake`, `TrollBombLogic.wake_delay` (Task 1) ; scène `troll_bomb.tscn` + `arm(...)` (Task 2) ; `BombTiming.fuse_seconds` (existant).

- [ ] **Step 1: Ajouter les preloads et constantes**

Dans `content/entities/bomb_entity.gd`, après la ligne `const BombSkin = preload(...)` (en tête), ajouter :

```gdscript
const TrollBomb = preload("res://mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.tscn")
const TrollBombLogic = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd")

# --- Paramètres réglables de la troll bombe (calibrage final en jeu) ---
const TROLL_WAKE_CHANCE := 0.10   # ~10 % qu'une bombe posée se réveille
const TROLL_WAKE_FRACTION := 0.5  # réveil à ~50 % de la mèche
const TROLL_WAKE_SOUND := "res://entities/units/enemies/pursuer/sci-fi_code_fail_08.wav"
```

- [ ] **Step 2: Ajouter les membres d'état**

Après la ligne `var _damage_tracking_key_hash: int = Keys.empty_hash`, ajouter :

```gdscript
var _tier: int = 0           # tier de la bombe (pour la couleur de la troll bombe)
var _will_wake: bool = false # tirage du réveil, décidé à l'armement
```

- [ ] **Step 3: Tirer le dé à l'armement**

Dans `func arm(...)`, remplacer le bloc final actuel :

```gdscript
	_fuse_timer.wait_time = BombTiming.fuse_seconds(p_tier)
	_fuse_timer.start()
```

par :

```gdscript
	_tier = p_tier
	# Tirage unique du réveil. Si elle se réveille, la "mèche" sert de délai
	# avant la bascule en troll bombe (instant = fraction de la mèche) ; sinon
	# c'est la mèche normale qui mène à l'explosion.
	_will_wake = TrollBombLogic.should_wake(randf(), TROLL_WAKE_CHANCE)
	if _will_wake:
		_fuse_timer.wait_time = TrollBombLogic.wake_delay(BombTiming.fuse_seconds(p_tier), TROLL_WAKE_FRACTION)
	else:
		_fuse_timer.wait_time = BombTiming.fuse_seconds(p_tier)
	_fuse_timer.start()
```

- [ ] **Step 4: Brancher la bascule à l'expiration du timer**

Au tout début de `func _on_fuse_timeout() -> void:`, AVANT la ligne `if _stats == null:`, ajouter :

```gdscript
	if _will_wake:
		_wake_into_troll()
		return
```

Puis ajouter la nouvelle méthode à la fin du fichier :

```gdscript
# Réveil : joue un son, instancie la troll bombe à la place de l'explosion, et
# se libère sans exploser. La troll bombe prend le relais (poursuite + explosion).
func _wake_into_troll() -> void:
	var snd = load(TROLL_WAKE_SOUND)
	if snd != null:
		SoundManager2D.play(snd, global_position, -6.0)
	var troll = TrollBomb.instance()
	Utils.get_scene_node().add_child(troll)
	troll.global_position = global_position
	troll.arm(_player_index, _stats, _tier, _explosion_scale, _damage_tracking_key_hash)
	queue_free()
```

- [ ] **Step 5: Vérifier que la suite de tests reste verte (garde de non-régression)**

Run : `./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

Expected : `=== 42 tests, 0 échec(s) ===`, code de sortie 0.

- [ ] **Step 6: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd
git commit -m "feat(bomberman): réveil aléatoire d'une bombe posée en troll bombe (~10%) + son"
```

- [ ] **Step 7: Vérification EN JEU (humain)**

Copier/symlinker le dossier du mod dans `mods-unpacked/` à côté du `.pck`, lancer Brotato avec Bombertoe, et vérifier :
1. **Chargement** : aucune erreur de parse/console au lancement du mod.
2. **Réveil** : en posant beaucoup de bombes, certaines (~1/10) ne s'explosent pas sur place mais **se relèvent en bombe à visage fâché** vers ~50 % de la mèche, avec un **son** de réveil.
3. **Couleur** : la troll bombe a la **couleur du tier** de la bombe d'origine (gris T1 … rouge T4).
4. **Poursuite** : elle suit le **joueur le plus proche** à vitesse constante ; un joueur avec bonus de vitesse la sème, un joueur ralenti non.
5. **Inarrêtable** : les tirs/armes ne la détruisent pas.
6. **Explosion au contact** : si elle touche un joueur → **dégâts au joueur** (≈ ceux de la bombe) + explosion + disparition.
7. **Minuteur** : si personne n'est touché en ~5 s → elle explose sur place et disparaît.
8. **Cible des dégâts** : l'explosion / le contact **n'abîme pas les ennemis** ; en coop, elle peut toucher les coéquipiers à portée.
9. **Calibrage** : noter si vitesse / durée / % / instant de réveil doivent être ajustés (constantes en tête de `troll_bomb.gd` et `bomb_entity.gd`).

---

## Notes de calibrage (constantes regroupées)

- `bomb_entity.gd` : `TROLL_WAKE_CHANCE` (10 %), `TROLL_WAKE_FRACTION` (0.5), `TROLL_WAKE_SOUND`.
- `troll_bomb.gd` : `SPEED` (120), `PURSUIT_SECONDS` (5.0), rayon de la `Hitbox` (50, dans `troll_bomb.tscn`).

## Points connus à finaliser plus tard (humain)

- Art **final** du visage (`troll_bomb_face.png`, actuellement placeholder = yeux de Bombertoe) ; ajuster sa taille/position dans `troll_bomb.tscn` (`Face`) si besoin.
- Choix du **son** de réveil définitif (placeholder = son « pursuer » vanilla).
- Packaging : `troll_bomb_face.png` doit être embarqué par `tools/build-bomberman.ps1` (chargé au runtime, comme les autres skins) — vérifier qu'il entre bien dans le `.zip` Workshop.
