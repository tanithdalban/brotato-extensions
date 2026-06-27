# Mod Bomberman — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter au jeu un mod `Tanith-Bomberman` : un personnage qui ne peut équiper que des « Bombes » (jusqu'à 6), et une arme « Bombe » qui se pose aux pieds du joueur au rythme de la cadence, attend une mèche dépendante du tier, puis explose via le système d'explosion vanilla.

**Architecture:** Mod ModLoader (Godot 3.6) calqué sur `Tanith-ShopConfig`. Le contenu neuf (perso, arme, set, entité bombe) est défini en `.tres`/`.tscn`/`.gd` propres au mod et **enregistré en ajoutant aux tableaux exportés de l'autoload `ItemService`** (`characters`, `weapons`, `sets`) via une extension de script sur `item_service.gd`. La bombe posée est une `Node2D` autonome avec un `Timer` de mèche qui appelle `WeaponService.explode(...)` — exactement comme `landmine.gd`. L'arme est une scène neuve dont le script surcharge `should_shoot()`/`shoot()` pour poser une bombe sans ciblage.

**Tech Stack:** Godot 3.6.2 (GDScript), ModLoader (`compatible_mod_loader_version` `6.3.0`), runner de tests GDScript headless autonome (pas de GUT).

## Global Constraints

- **Tout le code, commentaires et libellés de commit en français.** Libellés UI bilingues FR/EN si besoin (helper `_t(en, fr)` comme ShopConfig).
- **Namespace mod : `Tanith`**, nom du mod : `Bomberman` → dossier `Brotato/mods-unpacked/Tanith-Bomberman/`.
- **Godot 3 : pas de `static var`.** Pour un drapeau global, méta sur `Engine` (cf. `mod_log.gd`).
- **Aucun patch destructif du vanilla.** Intégration uniquement par contenu neuf + extensions de script ModLoader (`ModLoaderMod.install_script_extension`).
- **Logique testable = logique 100 % pure uniquement.** Tout ce qui touche aux autoloads (ItemService, WeaponService, RunData, ModLoader) **ne se charge pas en headless** et se vérifie **en jeu** (philosophie héritée de ShopConfig).
- **Identité d'un élément** : `ItemParentData.my_id : String` (+ `my_id_hash`). Armes : `weapon_id : String`, `type` (0 = MELEE, 1 = RANGED), `tier` (enum 0..3 = I..IV).
- **Commande de test** (code de sortie = nb d'échecs) :
  ```
  "Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
  ```
- **Test en jeu** : copier/symlinker `Brotato/mods-unpacked/Tanith-Bomberman/` à côté du `.pck`, lancer Brotato. Le mod `Tanith-DevUnlockAll` déverrouille les persos pour les tests.
- **Spec de référence** : `docs/superpowers/specs/2026-06-23-bomberman-character-design.md`.

## Décisions verrouillées (rappel)

| Sujet | Valeur |
|---|---|
| Pose | Position courante du joueur, sans ciblage. |
| Dégâts | `stats.damage` de l'arme + bonus `explosion_damage`/`explosion_size` (moteur) ⇒ dynamite/pot de miel automatiques. Set « outil/ingé » pour scaling Ingénierie. |
| Auto-dégâts joueur | Aucun. |
| Slots | 6 (défaut Brotato, non modifié) ; toutes armes non-Bombe bannies. |
| Train | Traînée naturelle (chaque arme pose à la position courante) + déphasage de cooldown par slot. |
| Départ | 1 Bombe ; jusqu'à 6 par achats ; 4 tiers. |
| Mèche | Par tier : T1 = 2.0 s → T4 = 1.0 s (interpolé : T2 ≈ 1.67 s, T3 ≈ 1.33 s). |
| `wanted_tags` | `["explosive"]`. |
| Art | Placeholders jouables d'abord, puis brief IA. |

---

## Structure des fichiers

```
Brotato/mods-unpacked/Tanith-Bomberman/
  manifest.json                         # métadonnées mod (T1)
  mod_main.gd                           # init + install des extensions (T1, étendu T6/T8)
  content/
    logic/
      mod_log.gd                        # logger désactivable (T1)
      bomb_timing.gd                    # LOGIQUE PURE : mèche par tier + déphasage slot (T2)
    entities/
      bomb_entity.gd                    # bombe posée : Timer mèche -> WeaponService.explode (T3)
      bomb_entity.tscn                  # scène de la bombe posée (T3)
    weapons/bomb/
      bomb_weapon.gd                    # arme : should_shoot()/shoot() -> pose bombe (T4)
      bomb.tscn                         # scène d'arme (T4)
      bomb_1_data.tres .. bomb_4_data.tres   # WeaponData par tier (T5)
      bomb_1_stats.tres .. bomb_4_stats.tres # RangedWeaponStats par tier (T5)
      bomb_icon.png, bomb.png           # placeholders (T9)
    sets/
      bomb_set_data.tres                # set « outil/ingé » de la Bombe (T5)
    characters/bomberman/
      bomberman_data.tres               # CharacterData (T6)
      bomberman_explosion_effect.tres   # +explosion_damage inné (T6)
      bomberman_eyes.png + _appearance.tres     # overlay (T9)
      bomberman_mouth.png + _appearance.tres    # overlay (T9)
      bomberman_helmet.png + _appearance.tres   # overlay casque (T9)
      bomberman_icon.png                # icône sélection (T9)
  extensions/
    singletons/
      item_service.gd                   # enregistre perso/armes/set dans les pools (T5/T6)
  test/
    run_tests.gd                        # runner headless (T1, étendu T2)
  docs/
    art-brief.md                        # prompts IA + specs px (T8)
```

---

## Task 1 : Scaffold du mod (charge en jeu + runner de tests)

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/manifest.json`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Produces : `ModLog.info(msg)` / `ModLog.error(msg)` / `ModLog.set_enabled(bool)` (statics). Constante `mod_main.LOG_NAME = "Tanith-Bomberman"`.

- [ ] **Step 1 : Écrire `manifest.json`**

```json
{
    "name": "Bomberman",
    "namespace": "Tanith",
    "version_number": "0.1.0",
    "description": "Personnage Bomberman : pose des bombes à mèche (jusqu'à 6), seule arme dispo.",
    "website_url": "",
    "dependencies": [],
    "extra": {
        "godot": {
            "authors": ["Tanith"],
            "tags": ["content", "character", "weapon"],
            "optional_dependencies": [],
            "load_before": [],
            "incompatibilities": [],
            "compatible_mod_loader_version": ["6.3.0"],
            "compatible_game_version": [],
            "config_schema": {
                "type": "object",
                "properties": {
                    "debug_log": { "type": "boolean", "description": "Active les logs détaillés de Bomberman.", "default": false }
                }
            }
        }
    }
}
```

- [ ] **Step 2 : Écrire `content/logic/mod_log.gd`** (copie adaptée de ShopConfig)

```gdscript
extends Reference
# Logger propre au mod, désactivable. Godot 3 n'a pas de static var :
# le drapeau est stocké en méta globale sur Engine.

const LOG_NAME := "Tanith-Bomberman"
const _META := "tanith_bomberman_log_enabled"

static func set_enabled(value: bool) -> void:
	Engine.set_meta(_META, value)

static func is_enabled() -> bool:
	return Engine.has_meta(_META) and Engine.get_meta(_META)

static func info(msg: String) -> void:
	if is_enabled():
		ModLoaderLog.info(msg, LOG_NAME)

static func error(msg: String) -> void:
	ModLoaderLog.error(msg, LOG_NAME)
```

- [ ] **Step 3 : Écrire `mod_main.gd`** (sans extension pour l'instant)

```gdscript
extends Node

const LOG_NAME := "Tanith-Bomberman"
const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")

func _init() -> void:
	_setup_logging()
	ModLog.info("init")
	_install_extensions()

func _setup_logging() -> void:
	var enabled := false
	var conf = null
	if ModLoaderConfig.get_current_config_name(LOG_NAME) != "":
		conf = ModLoaderConfig.get_current_config(LOG_NAME)
	else:
		conf = ModLoaderConfig.get_default_config(LOG_NAME)
	if conf != null and conf.data is Dictionary:
		enabled = bool(conf.data.get("debug_log", false))
	ModLog.set_enabled(enabled)

func _install_extensions() -> void:
	# Les extensions seront ajoutées aux tâches T5/T6.
	pass
```

- [ ] **Step 4 : Écrire le runner `test/run_tests.gd`** (squelette, 0 test pour l'instant)

```gdscript
extends SceneTree
# Runner de tests autonome (pas de GUT dans le build Brotato).
# Lancer : Godot --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
# Code de sortie = nombre d'échecs (0 = tout passe).
# On ne teste QUE la logique 100 % pure (pas d'autoload ModLoader/jeu).

var _failures := 0
var _count := 0

func _init():
	print("=== Bomberman tests ===")
	# Les suites de tests seront ajoutées en T2.
	print("=== %d tests, %d échec(s) ===" % [_count, _failures])
	quit(_failures)

func _check(cond, name):
	_count += 1
	if not cond:
		_failures += 1
		print("FAIL: ", name)
	else:
		print("ok  : ", name)
```

- [ ] **Step 5 : Lancer le runner, vérifier 0 échec**

Run :
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected : sortie `=== 0 tests, 0 échec(s) ===`, code de sortie 0.

- [ ] **Step 6 : Vérification en jeu — le mod charge**

Lancer Brotato avec le mod en place. Expected : la console / `ModLoaderLog` affiche l'`init` du mod `Tanith-Bomberman` sans erreur, et le jeu atteint le menu principal.

- [ ] **Step 7 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/manifest.json \
        Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): scaffold du mod (charge en jeu + runner de tests)"
```

---

## Task 2 : Logique pure `bomb_timing.gd` (mèche par tier + déphasage slot)

Seule unité 100 % testable en headless. TDD strict.

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Produces :
  - `BombTiming.fuse_seconds(tier: int) -> float` — tier 0..3 (= I..IV) ⇒ 2.0, 1.6667, 1.3333, 1.0 ; clampe hors bornes.
  - `BombTiming.slot_phase_offset(slot_index: int, nb_slots: int, cooldown: float) -> float` — décalage initial de cooldown (en mêmes unités que `cooldown`) pour égrener les bombes. `slot 0 -> 0`, répartit les slots régulièrement sur `[0, cooldown)`.

- [ ] **Step 1 : Écrire les tests d'abord** — ajouter dans `run_tests.gd`

Ajouter le preload en haut du fichier (après `extends SceneTree`) :
```gdscript
const BombTiming = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd")
```
Remplacer le corps de `_init()` par :
```gdscript
func _init():
	print("=== Bomberman tests ===")
	_test_fuse_seconds()
	_test_slot_phase_offset()
	print("=== %d tests, %d échec(s) ===" % [_count, _failures])
	quit(_failures)


func _approx(a, b):
	return abs(a - b) < 0.0001


func _test_fuse_seconds():
	_check(_approx(BombTiming.fuse_seconds(0), 2.0), "fuse: T1 = 2.0s")
	_check(_approx(BombTiming.fuse_seconds(3), 1.0), "fuse: T4 = 1.0s")
	_check(_approx(BombTiming.fuse_seconds(1), 2.0 - (1.0 / 3.0)), "fuse: T2 interpolé ≈ 1.667s")
	_check(_approx(BombTiming.fuse_seconds(2), 2.0 - (2.0 / 3.0)), "fuse: T3 interpolé ≈ 1.333s")
	_check(_approx(BombTiming.fuse_seconds(-5), 2.0), "fuse: clamp bas = T1")
	_check(_approx(BombTiming.fuse_seconds(99), 1.0), "fuse: clamp haut = T4")


func _test_slot_phase_offset():
	_check(_approx(BombTiming.slot_phase_offset(0, 4, 60.0), 0.0), "phase: slot 0 = 0")
	_check(_approx(BombTiming.slot_phase_offset(1, 4, 60.0), 15.0), "phase: slot 1/4 sur 60 = 15")
	_check(_approx(BombTiming.slot_phase_offset(2, 4, 60.0), 30.0), "phase: slot 2/4 sur 60 = 30")
	_check(_approx(BombTiming.slot_phase_offset(0, 1, 60.0), 0.0), "phase: slot unique = 0")
	_check(_approx(BombTiming.slot_phase_offset(3, 4, 0.0), 0.0), "phase: cooldown 0 => 0")
```

- [ ] **Step 2 : Lancer les tests, vérifier l'échec**

Run la commande de test. Expected : FAIL (classe `BombTiming` / fichier introuvable, ou méthodes absentes).

- [ ] **Step 3 : Écrire l'implémentation minimale** `content/logic/bomb_timing.gd`

```gdscript
extends Reference
# Logique PURE de la Bombe (aucune dépendance jeu) — testable en headless.
# Tiers : 0..3 correspondent à I..IV.

const _FUSE_T1 := 2.0  # mèche tier I (s)
const _FUSE_T4 := 1.0  # mèche tier IV (s)
const _MAX_TIER := 3

# Durée de mèche par tier, interpolée linéairement de T1 (2.0s) à T4 (1.0s).
static func fuse_seconds(tier: int) -> float:
	var t := tier
	if t < 0:
		t = 0
	if t > _MAX_TIER:
		t = _MAX_TIER
	var ratio := float(t) / float(_MAX_TIER)  # 0.0 en T1, 1.0 en T4
	return _FUSE_T1 + (_FUSE_T4 - _FUSE_T1) * ratio

# Décalage initial de cooldown pour égrener les bombes en file ("train").
# Répartit régulièrement les slots sur [0, cooldown). slot 0 -> 0.
static func slot_phase_offset(slot_index: int, nb_slots: int, cooldown: float) -> float:
	if nb_slots <= 1 or cooldown <= 0.0 or slot_index <= 0:
		return 0.0
	var i := slot_index % nb_slots
	return cooldown * (float(i) / float(nb_slots))
```

- [ ] **Step 4 : Lancer les tests, vérifier le succès**

Run la commande de test. Expected : tous les `ok  :`, `=== 11 tests, 0 échec(s) ===`, code de sortie 0.

- [ ] **Step 5 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): logique pure mèche-par-tier et déphasage de slot (TDD)"
```

---

## Task 3 : Entité « Bombe posée » (mèche → explosion vanilla)

Calquée sur `Brotato/entities/structures/landmine/landmine.gd` : construit des `WeaponServiceExplodeArgs` et appelle `WeaponService.explode(effect, args)`. Vérifiée **en jeu** (touche WeaponService/Main).

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.tscn`

**Interfaces:**
- Consumes : `BombTiming.fuse_seconds(tier)` (T2) ; `WeaponService.explode(ExplodingEffect, WeaponServiceExplodeArgs)` (vanilla) ; `WeaponServiceExplodeArgs` (vanilla, champs : `pos`, `damage`, `accuracy`, `crit_chance`, `crit_damage`, `burning_data`, `scaling_stats`, `from_player_index`, `damage_tracking_key_hash`, `from`) ; `ExplodingEffect` (vanilla, champs : `explosion_scene`, `scale`, `base_smoke_amount`, `sound_db_mod`).
- Produces : `bomb_entity.tscn` instanciable ; méthode `arm(p_player_index: int, p_stats: WeaponStats, p_tier: int, p_explosion_scale: float) -> void` qui démarre la mèche puis explose.

- [ ] **Step 1 : Écrire `content/entities/bomb_entity.gd`**

```gdscript
extends Node2D
# Bombe posée au sol. Modèle : landmine.gd (placée puis WeaponService.explode).
# Aucun auto-dégât joueur : l'explosion vanilla n'affecte pas le joueur.

const BombTiming = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_timing.gd")
const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")

# Scène d'explosion vanilla réutilisée (dégâts de zone + lecture explosion_damage/size).
var _explosion_scene: PackedScene = preload("res://projectiles/explosion.tscn")

var _player_index: int = -1
var _stats: WeaponStats = null
var _explosion_scale: float = 1.75  # cf. landmine (scale par défaut)
var _explode_args := WeaponServiceExplodeArgs.new()
var _exploding_effect: ExplodingEffect = null

onready var _fuse_timer: Timer = $FuseTimer

func _ready() -> void:
	# Construit l'effet d'explosion (équivaut au .tres d'effet du landmine).
	_exploding_effect = ExplodingEffect.new()
	_exploding_effect.explosion_scene = _explosion_scene
	_exploding_effect.scale = _explosion_scale
	_exploding_effect.base_smoke_amount = 40
	_exploding_effect.sound_db_mod = -10
	var _e = _fuse_timer.connect("timeout", self, "_on_fuse_timeout")

# Appelée juste après instanciation par l'arme.
func arm(p_player_index: int, p_stats: WeaponStats, p_tier: int, p_explosion_scale: float = 1.75) -> void:
	_player_index = p_player_index
	_stats = p_stats
	_explosion_scale = p_explosion_scale
	if _exploding_effect != null:
		_exploding_effect.scale = _explosion_scale
	_fuse_timer.wait_time = BombTiming.fuse_seconds(p_tier)
	_fuse_timer.start()

func _on_fuse_timeout() -> void:
	if _stats == null:
		queue_free()
		return
	_explode_args.pos = global_position
	_explode_args.damage = _stats.damage
	_explode_args.accuracy = _stats.accuracy
	_explode_args.crit_chance = _stats.crit_chance
	_explode_args.crit_damage = _stats.crit_damage
	_explode_args.burning_data = _stats.burning_data
	_explode_args.scaling_stats = _stats.scaling_stats
	_explode_args.from_player_index = _player_index
	_explode_args.from = null  # pas d'auto-attribution à un noeud qui va disparaître
	var _inst = WeaponService.explode(_exploding_effect, _explode_args)
	queue_free()
```

- [ ] **Step 2 : Créer `content/entities/bomb_entity.tscn`**

Scène minimale (peut être créée à la main en `.tscn` texte). Racine `Node2D` (script `bomb_entity.gd`), un enfant `Sprite` nommé `Sprite` (texture placeholder branchée en T9), et un `Timer` nommé `FuseTimer` (`one_shot = true`). Contenu :

```
[gd_scene load_steps=2 format=2]

[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd" type="Script" id=1]

[node name="BombEntity" type="Node2D"]
script = ExtResource( 1 )

[node name="Sprite" type="Sprite" parent="."]

[node name="FuseTimer" type="Timer" parent="."]
one_shot = true
```

- [ ] **Step 3 : Harnais de test temporaire en jeu**

Comme `WeaponService`/`Main` ne se chargent pas en headless, valider via un appel temporaire : dans `mod_main._init()`, après init, **NE PAS** instancier (Main absent au boot). À la place, prévoir le test réel en T4 quand l'arme posera la bombe. Marquer cette étape comme "vérif différée à T4" et passer.

- [ ] **Step 4 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.tscn
git commit -m "feat(bomberman): entité bombe posée (mèche puis explosion vanilla)"
```

---

## Task 4 : Arme « Bombe » (pose sans ciblage au rythme du cooldown)

Scène d'arme neuve dont le script étend `Weapon` et surcharge `should_shoot()` (tirer dès cooldown prêt, sans cible) et `shoot()` (instancier la bombe à la position du joueur). Vérifiée **en jeu**.

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn`

**Interfaces:**
- Consumes : classe vanilla `Weapon` (`weapon.gd`) — propriétés/méthodes : `_current_cooldown`, `_parent` (l'unité porteuse, a `global_position` et `_current_movement`), `player_index`, `current_stats` (`WeaponStats` avec `.damage` etc.), `get_next_cooldown()`, `data` (`WeaponData`, a `.tier`). `RunData.get_player_effect(Keys.can_attack_while_moving_hash, player_index)`. Entité `bomb_entity.tscn` + méthode `arm(...)` (T3).
- Produces : scène `bomb.tscn` référencée par les `WeaponData` en T5 ; classe `BombWeapon`.

- [ ] **Step 1 : Écrire `content/weapons/bomb/bomb_weapon.gd`**

```gdscript
extends Weapon
class_name BombWeapon
# Arme "Bombe" : ne vise pas. Pose une bombe à la position du joueur dès que
# le cooldown est prêt. La bombe (entité) gère sa mèche puis explose.

const BombEntity = preload("res://mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.tscn")
const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")

# Échelle d'explosion de base (équiv. landmine). Ajustable au réglage.
const EXPLOSION_SCALE := 1.5

# Surcharge : tirer dès que le cooldown est prêt, SANS exiger de cible/portée.
# Respecte la règle de mouvement vanilla (immobile, sauf effet "attaque en bougeant").
func should_shoot() -> bool:
	if _is_shooting:
		return false
	if _current_cooldown > 0:
		return false
	var can_move_attack = RunData.get_player_effect(Keys.can_attack_while_moving_hash, player_index)
	if _parent._current_movement != Vector2.ZERO and not can_move_attack:
		return false
	return true

# Surcharge : poser une bombe à la position du joueur (pas de projectile dirigé).
func shoot() -> void:
	_nb_shots_taken += 1
	var bomb = BombEntity.instance()
	Utils.get_scene_node().add_child(bomb)
	bomb.global_position = _parent.global_position
	var tier = data.tier if data != null else 0
	bomb.arm(player_index, current_stats, tier, EXPLOSION_SCALE)
	_current_cooldown = get_next_cooldown()
```

- [ ] **Step 2 : Créer `content/weapons/bomb/bomb.tscn`**

Cloner la structure d'une scène d'arme vanilla simple. **Procédure** : ouvrir `res://weapons/ranged/pistol/pistol.tscn` comme référence de structure (noeuds attendus par `Weapon`/`RangedWeapon` : `Sprite`, points d'ancrage). Créer `bomb.tscn` avec la racine portant le script `bomb_weapon.gd`, un `Sprite` nommé `Sprite` (texture placeholder branchée en T9). Le script étant `extends Weapon`, fournir au minimum les noeuds que `weapon.gd` attend en `onready` (vérifier les `onready var` de `Brotato/weapons/weapon.gd` et reproduire les noeuds nommés correspondants ; au minimum `Sprite`). En-tête :

```
[gd_scene load_steps=2 format=2]

[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd" type="Script" id=1]

[node name="Bomb" type="Position2D"]
script = ExtResource( 1 )

[node name="Sprite" type="Sprite" parent="."]
```

> NB : la racine d'arme vanilla est un `Position2D`/`Sprite` selon le type ; reproduire le type de noeud racine de `pistol.tscn` pour garder la compat avec `Weapon`. Ajuster d'après la lecture de `pistol.tscn`.

- [ ] **Step 3 : Vérification différée**

La scène d'arme n'est utile qu'une fois référencée par un `WeaponData` (T5) et équipée. Marquer "vérif en T5/T6" et passer.

- [ ] **Step 4 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn
git commit -m "feat(bomberman): arme Bombe (pose sans ciblage au rythme du cooldown)"
```

---

## Task 5 : Données d'arme + set + enregistrement dans les pools

Crée les 4 tiers de `WeaponData`/`WeaponStats`, le set, et **enregistre** armes + set dans `ItemService` via une extension de script. À l'issue : la Bombe est une arme réelle du jeu, achetable/équipable (testée en jeu avec un perso vanilla).

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/sets/bomb_set_data.tres`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_1_stats.tres` .. `bomb_4_stats.tres`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_1_data.tres` .. `bomb_4_data.tres`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd` (installer l'extension)

**Interfaces:**
- Consumes : `ItemService` (autoload) exporte `weapons: Array`, `sets: Array` ; méthode vanilla `ItemService._ready()` (à appeler après ajout pour recâbler `upgrades_into.previous_upgrade`). `bomb.tscn` (T4).
- Produces : armes `weapon_bomb_1..4` (`weapon_id = "weapon_bomb"`), set `set_bomb`.

- [ ] **Step 1 : Créer le set `content/sets/bomb_set_data.tres`**

Copier `res://items/sets/tool/tool_set_data.tres` comme modèle (set « outil/ingé »), OU créer un set propre. Procédure : lire `Brotato/items/sets/` pour le schéma exact d'un `*_set_data.tres` (script `set_data.gd`, champs `my_id`, `name`, bonus par paliers). Créer `bomb_set_data.tres` avec `my_id = "set_bomb"`. Si on réutilise le scaling Ingénierie sans set custom complexe, on peut référencer le set `tool` vanilla dans les `WeaponData` (Step 3) au lieu d'un set neuf — **décision d'implémentation** : commencer en réutilisant le set `tool` vanilla (moins de surface), ne créer `bomb_set_data.tres` que si un bonus de set dédié est voulu. Vérifier le chemin réel du set outil via `grep -rl "set_tool" Brotato/items/sets`.

- [ ] **Step 2 : Créer les 4 `*_stats.tres`**

Copier `res://weapons/ranged/rocket_launcher/2/rocket_launcher_2_stats.tres` (arme à explosion) vers `bomb_1_stats.tres`..`bomb_4_stats.tres`. Pour chaque tier, ajuster (lire le fichier source pour les noms de champs exacts du script `ranged_weapon_stats.gd`) :
- `cooldown` : intervalle de pose (frames). Valeurs de départ : T1 ≈ 90, T2 ≈ 80, T3 ≈ 70, T4 ≈ 60 (≈ 1.5s→1.0s à 60 fps). **À régler en jeu.**
- `damage` : dégâts d'explosion de base. Départ : T1 ≈ 12, T2 ≈ 18, T3 ≈ 26, T4 ≈ 36. **À régler.**
- `scaling_stats` : inclure l'Ingénierie (cf. comment l'Artificer/tourelles scalent — reproduire le `scaling_stats` d'une arme « tool »).
- `min_range`/`max_range`/`accuracy` : valeurs neutres (la pose ignore la portée), copier celles de la source.

- [ ] **Step 3 : Créer les 4 `*_data.tres`**

Copier `res://weapons/ranged/pistol/1/pistol_data.tres` vers `bomb_1_data.tres`..`bomb_4_data.tres` et ajuster chaque tier :
- `my_id` : `"weapon_bomb_1"`..`"weapon_bomb_4"`.
- `weapon_id` : `"weapon_bomb"` (identique aux 4 tiers).
- `name` : `"WEAPON_BOMB"` (clé de traduction ; texte ajouté en T8 ou via `add_translation`, sinon affiche la clé — acceptable en placeholder).
- `tier` : 0, 1, 2, 3.
- `type` : 1 (RANGED).
- `scene` : `ExtResource` pointant `res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn`.
- `stats` : le `*_stats.tres` du tier correspondant.
- `sets` : `[ tool_set vanilla ]` (ou `bomb_set_data.tres` si créé en Step 1).
- `upgrades_into` : T1→T2→T3→T4 (chaîne) ; T4 = `null`.
- `icon` : placeholder (branché en T9 ; pointer un icône existant temporairement, p.ex. celui du rocket_launcher, pour ne pas casser le chargement).
- `can_be_looted = true`, `unlocked_by_default = true`.
- `tags` : `["explosive"]` si le schéma le permet (cohérent `wanted_tags` du perso).

- [ ] **Step 4 : Écrire l'extension `extensions/singletons/item_service.gd`**

```gdscript
extends "res://singletons/item_service.gd"
# Enregistre le contenu du mod Bomberman dans les pools du jeu :
# on ajoute nos armes (et set) aux tableaux exportés AVANT de recâbler les
# upgrades, en appelant le _ready() parent après injection.

const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")

const _BOMB_WEAPONS := [
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_1_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_2_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_3_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_4_data.tres",
]

func _ready() -> void:
	# Injecter nos armes dans le pool vanilla avant le recâblage des upgrades.
	for path in _BOMB_WEAPONS:
		var w = load(path)
		if w != null and not weapons.has(w):
			weapons.append(w)
			ModLog.info("arme enregistrée: " + str(w.my_id))
	# Le _ready() parent fixe upgrades_into.previous_upgrade pour toutes les armes.
	._ready()
```

- [ ] **Step 5 : Installer l'extension dans `mod_main.gd`**

Remplacer le corps de `_install_extensions()` :
```gdscript
func _install_extensions() -> void:
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd")
```

- [ ] **Step 6 : Vérification en jeu — la Bombe existe comme arme**

Lancer Brotato avec un perso vanilla (ex. Well-Rounded). Utiliser la console de debug / le mod DevUnlockAll si besoin. Expected, **vérifié en jeu** :
1. Aucune erreur de chargement de l'ItemService étendu (logs `arme enregistrée: weapon_bomb_1..4`).
2. La Bombe peut apparaître en boutique (ou être donnée) et s'équipe sans crash.
3. Une fois équipée : à intervalle régulier (sans cible), une bombe apparaît aux pieds du joueur, attend la mèche, explose et **endommage les ennemis** ; le joueur n'est **pas** blessé.
4. Avec une **dynamite** et un **pot de miel** : l'explosion fait visiblement plus de dégâts / est plus grande.

Si un point échoue, déboguer (skill systematic-debugging) avant de continuer.

- [ ] **Step 7 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/sets/ \
        Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/*.tres \
        Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd
git commit -m "feat(bomberman): données d'arme Bombe (4 tiers) + set + enregistrement dans les pools"
```

---

## Task 6 : Personnage « Bomberman » (bombe seule, bonus explosion, bans)

Crée `CharacterData` + effets, l'enregistre dans `ItemService.characters`, le déverrouille, et bannit toutes les armes non-Bombe. Vérifié **en jeu**.

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/bomberman_data.tres`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/bomberman_explosion_effect.tres`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd`

**Interfaces:**
- Consumes : `ItemService.characters: Array` ; `ItemService.item_groups` (pour recenser les sets/groupes d'armes à bannir) ; `ProgressData` (déverrouillage). `CharacterData` (script `character_data.gd`) champs vus sur `artificer_data.tres` : `my_id`, `name`, `tier`, `effects`, `starting_weapons`, `banned_item_groups`, `banned_items`, `wanted_tags`, `item_appearances`, `icon`, `unlocked_by_default`, `can_be_looted`.
- Produces : perso `character_bomberman` sélectionnable.

- [ ] **Step 1 : Créer l'effet bonus explosion `bomberman_explosion_effect.tres`**

Copier `res://items/characters/artificer/artificer_effect_1.tres` (effet `key = "explosion_damage"`). Mettre une valeur de départ modérée (le perso n'a QUE des bombes, donc pas besoin du +175 d'Artificer) : `value = 30`. **À régler en jeu.**

- [ ] **Step 2 : Recenser les armes/sets à bannir**

Objectif : seule la Bombe doit pouvoir apparaître. Inspecter les `sets`/groupes d'armes vanilla :
```
grep -rl "type=\"Resource\"" Brotato/items/sets | head
```
et lister les `weapon_id`/sets. Stratégie retenue : bannir **toutes les autres armes** via `banned_items` (liste des `weapon_id` vanilla) **et/ou** via `banned_item_groups` si des groupes d'armes existent. Comme la liste d'armes vanilla est figée et connue (cf. `ls Brotato/weapons/melee` + `ls Brotato/weapons/ranged`), construire la liste exhaustive des `weapon_id` à bannir (tous sauf `weapon_bomb`). Documenter cette liste dans un commentaire du `.tres` ou dans `bomberman_data.tres`.

> Décision : privilégier `banned_items` avec la liste explicite des `weapon_id` vanilla. Vérifier en jeu (Step 6) que la boutique ne propose QUE des Bombes.

- [ ] **Step 3 : Créer `bomberman_data.tres`**

Copier `res://items/characters/artificer/artificer_data.tres` comme base et ajuster :
- `my_id` : `"character_bomberman"`.
- `name` : `"CHARACTER_BOMBERMAN"` (clé i18n ; texte en T8 sinon affiche la clé).
- `tier` : 0.
- `effects` : `[ bomberman_explosion_effect.tres ]` (+ ajouter ultérieurement un éventuel profil de stats au réglage).
- `wanted_tags` : `[ "explosive" ]`.
- `starting_weapons` : `[ bomb_1_data.tres ]` (1 Bombe tier I).
- `banned_items` : liste des `weapon_id` vanilla à exclure (Step 2).
- `banned_item_groups` : `[]` (ou groupes d'armes si pertinents).
- `item_appearances` : `[ eyes_appearance, mouth_appearance, helmet_appearance ]` (les `.tres` d'apparence sont créés en T9 ; en attendant, réutiliser des apparences vanilla pour ne pas casser le chargement, p.ex. celles de well_rounded).
- `icon` : placeholder (branché en T9 ; pointer un icône vanilla temporaire).
- `unlocked_by_default` : `true`.
- `can_be_looted` : `true`.

- [ ] **Step 4 : Enregistrer + déverrouiller le perso dans l'extension ItemService**

Modifier `extensions/singletons/item_service.gd` — ajouter la constante et l'enregistrement dans `_ready()` (avant `._ready()`):
```gdscript
const _BOMBERMAN_CHAR := "res://mods-unpacked/Tanith-Bomberman/content/characters/bomberman/bomberman_data.tres"
```
Dans `_ready()`, après la boucle des armes et **avant** `._ready()` :
```gdscript
	var character = load(_BOMBERMAN_CHAR)
	if character != null and not characters.has(character):
		characters.append(character)
		ModLog.info("perso enregistré: " + str(character.my_id))
		# Déverrouillage : s'assurer que le perso est jouable d'emblée.
		if ProgressData.has_method("add_character_unlocked"):
			ProgressData.add_character_unlocked(character.my_id_hash)
```

> NB déverrouillage : le nom exact de l'API ProgressData est à confirmer en jeu (`grep -n "unlock" Brotato/singletons/progress_data.gd`). Si `unlocked_by_default = true` suffit à le rendre sélectionnable, retirer le bloc `ProgressData`. Vérifier en jeu (Step 6).

- [ ] **Step 5 : Lancer le runner de tests (non-régression)**

Run la commande de test. Expected : `=== 11 tests, 0 échec(s) ===` (la logique pure n'a pas changé).

- [ ] **Step 6 : Vérification en jeu — le perso joue**

Lancer Brotato. Expected, **vérifié en jeu** :
1. « Bomberman » apparaît et est sélectionnable dans l'écran de sélection de personnage.
2. La run démarre avec **1 Bombe** équipée ; le joueur pose des bombes automatiquement.
3. En **boutique**, seules des **Bombes** apparaissent dans les emplacements d'armes (aucune autre arme).
4. On peut acheter jusqu'à **6 Bombes** (slots pleins) et monter les **tiers** (II, III, IV) ; la mèche raccourcit visiblement avec le tier.
5. Avec plusieurs bombes, en se déplaçant, elles forment une **traînée** derrière le joueur.
6. La compat avec ShopConfig (si actif) reste cohérente : la Bombe peut figurer dans l'écran de config du pool ; les bans perso priment.

- [ ] **Step 7 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/characters/ \
        Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd
git commit -m "feat(bomberman): personnage Bomberman (bombe seule, bonus explosion, bans d'armes)"
```

---

## Task 7 : Déphasage de cooldown par slot (« train » net)

Câble `BombTiming.slot_phase_offset(...)` dans l'arme pour égrener les bombes au lieu de les empiler. Vérifié **en jeu**.

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd`

**Interfaces:**
- Consumes : `BombTiming.slot_phase_offset(slot_index, nb_slots, cooldown)` (T2) ; index de slot de l'arme et nombre d'armes du joueur (via `_parent`/`RunData` — confirmer l'accès en lisant `weapon.gd` pour `weapon_index`/position, et `RunData.get_player_weapons(player_index)` pour le compte).

- [ ] **Step 1 : Lire l'API d'index de slot**

Inspecter `Brotato/weapons/weapon.gd` et `RunData` pour trouver : (a) l'index de cette arme parmi celles du joueur, (b) le nombre d'armes équipées. Run :
```
grep -n "weapon_index\|set_weapon\|func get_player_weapons\|weapons\[" Brotato/weapons/weapon.gd Brotato/singletons/run_data.gd
```

- [ ] **Step 2 : Appliquer le déphasage au début de vague**

Dans `bomb_weapon.gd`, surcharger le point d'initialisation de cooldown de début de vague (lire `weapon.gd` : la fonction qui pose `_current_cooldown = get_next_cooldown(at_wave_begin)` — autour de `weapon.gd:162`). Ajouter, après l'init vanilla, un décalage par slot :

```gdscript
# Égrener les bombes des différents slots ("train") : décaler le 1er cooldown.
func _apply_slot_phase() -> void:
	var slot_index = _bomb_slot_index()      # défini en Step 1 selon l'API trouvée
	var nb_slots = _bomb_slot_count()         # défini en Step 1
	var phase = BombTiming.slot_phase_offset(slot_index, nb_slots, get_next_cooldown(true))
	_current_cooldown += phase
```

Appeler `_apply_slot_phase()` au bon hook de début de vague (surcharge de la méthode vanilla identifiée en Step 1, en appelant `.methode()` d'abord). Implémenter `_bomb_slot_index()` / `_bomb_slot_count()` avec l'API trouvée en Step 1.

- [ ] **Step 3 : Vérification en jeu — train lisible**

Lancer Brotato avec Bomberman, acheter 3–6 Bombes (même cooldown). Expected, **vérifié en jeu** : en se déplaçant en ligne droite, les bombes se posent **espacées** (égrenées) plutôt que toutes au même endroit en même temps ⇒ effet « train » net.

- [ ] **Step 4 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd
git commit -m "feat(bomberman): déphasage de cooldown par slot (train de bombes égrené)"
```

---

## Task 8 : Traductions + brief de génération d'art IA

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/translations/bomberman_en.translation` ou `.csv` (selon ce qu'accepte `ModLoaderMod.add_translation`)
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/docs/art-brief.md`

**Interfaces:**
- Consumes : `ModLoaderMod.add_translation(resource_path)` (vanilla API, vu dans `addons/mod_loader/api/mod.gd`).
- Produces : libellés `CHARACTER_BOMBERMAN`, `WEAPON_BOMB` (+ descriptions) en FR/EN ; `docs/art-brief.md`.

- [ ] **Step 1 : Créer les traductions FR/EN**

Lire un exemple de traduction mod ou la doc `add_translation` pour le format attendu (CSV → `.translation`). Fournir au minimum :
- `CHARACTER_BOMBERMAN` = "Bomberman" (EN) / "Bomberman" (FR)
- `CHARACTER_BOMBERMAN_DESC` = description (EN/FR)
- `WEAPON_BOMB` = "Bomb" / "Bombe"
- `WEAPON_BOMB_DESC` = description (EN/FR)

- [ ] **Step 2 : Charger les traductions dans `mod_main.gd`**

Dans `_init()`, après `_install_extensions()` :
```gdscript
	ModLoaderMod.add_translation("res://mods-unpacked/Tanith-Bomberman/content/translations/bomberman_en.translation")
	# + une ligne par langue fournie (au moins en + fr)
```

- [ ] **Step 3 : Écrire `docs/art-brief.md`**

Inclure, **pour chaque asset**, un prompt IA prêt à l'emploi + contraintes techniques. Tableau des assets (dimensions exactes, fond transparent PNG, palette/style pixel-art Brotato) :

| Asset | Fichier cible | Dimensions | Prompt (résumé) |
|---|---|---|---|
| Yeux | `bomberman_eyes.png` | 150×150 | yeux de Bomberman, style overlay patate Brotato, fond transparent |
| Bouche | `bomberman_mouth.png` | 150×150 | bouche, idem |
| Casque | `bomberman_helmet.png` | 150×150 | casque blanc/rose Bomberman, posé sur le haut de la patate |
| Icône perso | `bomberman_icon.png` | 96×96 | portrait Bomberman cartoon pixel-art |
| Sprite arme | `bomb.png` | 80×80 | petite bombe noire tenue, mèche |
| Icône arme | `bomb_icon.png` | 96×96 | icône bombe |
| Bombe posée | `bomb_entity_sprite.png` | ~48×48 | bombe ronde noire à mèche, vue de dessus/3-4 |

Rédiger les prompts complets (style, palette, cadrage, transparence) dans le corps du doc. Préciser la procédure de dépôt (où ranger les PNG, régénérer les `.import` en relançant l'éditeur Godot).

- [ ] **Step 4 : Vérification en jeu — libellés FR/EN**

Lancer Brotato (FR puis EN). Expected : « Bomberman » et « Bombe »/« Bomb » s'affichent correctement (plus de clés brutes `CHARACTER_BOMBERMAN`).

- [ ] **Step 5 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/translations/ \
        Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/docs/art-brief.md
git commit -m "feat(bomberman): traductions FR/EN + brief de génération d'art IA"
```

---

## Task 9 : Sprites placeholders + branchement

Fabrique des PNG provisoires (recolor/copie d'assets existants) et crée les `.tres` d'apparence, puis branche tout pour un rendu propre. Vérifié **en jeu**.

**Files:**
- Create: PNG placeholders (perso : eyes/mouth/helmet/icon ; arme : `bomb.png`, `bomb_icon.png` ; bombe : sprite)
- Create: `bomberman_eyes_appearance.tres`, `bomberman_mouth_appearance.tres`, `bomberman_helmet_appearance.tres`
- Modify: `bomberman_data.tres` (icon + item_appearances), `bomb_*_data.tres` (icons), `bomb.tscn`, `bomb_entity.tscn` (textures)

**Interfaces:**
- Consumes : schéma `item_appearance_data.gd` (vu sur `well_rounded_eyes_appearance.tres` : `sprite`, `position`, `display_priority`, `depth`, `is_character_appearance = true`).

- [ ] **Step 1 : Générer les placeholders**

Procédure (pas d'outil d'image requis) : copier des PNG vanilla proches comme placeholders, en les renommant.
- Perso : copier `well_rounded_eyes.png` / `well_rounded_mouth.png` ; pour le casque, copier `apprentice_robe.png` (overlay) comme placeholder ; icône : copier `well_rounded_icon.png`.
- Arme : copier `rocket_launcher.png` → `bomb.png` ; `rocket_launcher` icon → `bomb_icon.png`.
- Bombe posée : copier une petite texture ronde existante (p.ex. un sprite de landmine `Brotato/entities/structures/landmine/`).

Les `.png.import` se régénèrent au prochain lancement de l'éditeur Godot ; sinon copier aussi le `.png.import` voisin et corriger le chemin de ressource.

- [ ] **Step 2 : Créer les `.tres` d'apparence**

Pour chaque overlay, copier `res://items/characters/well_rounded/well_rounded_eyes_appearance.tres` et pointer le `sprite` vers notre PNG. Pour le casque, s'inspirer de `apprentice_robe_appearance.tres` (`position = 11`, `display_priority = 1`, `depth = 320.0`) pour le placer au-dessus de la tête.

- [ ] **Step 3 : Brancher icônes et apparences**

- `bomberman_data.tres` : `icon` → `bomberman_icon.png` ; `item_appearances` → `[ eyes, mouth, helmet ]` (remplacer les apparences vanilla temporaires de T6).
- `bomb_1..4_data.tres` : `icon` → `bomb_icon.png` (remplacer l'icône vanilla temporaire de T5).
- `bomb.tscn` : `Sprite.texture` → `bomb.png`.
- `bomb_entity.tscn` : `Sprite.texture` → sprite de bombe posée.

- [ ] **Step 4 : Vérification en jeu — rendu**

Lancer Brotato. Expected : l'icône Bomberman s'affiche en sélection ; le perso a son overlay casque sur la patate ; l'arme Bombe a son icône ; la bombe posée a un sprite visible au sol. Aucun carré rose « texture manquante ».

- [ ] **Step 5 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/
git commit -m "feat(bomberman): sprites placeholders + apparences branchées (en attente art IA)"
```

---

## Task 10 : Passe de vérification complète (solo + coop) + statut mémoire

**Files:** aucun code ; mise à jour de la mémoire de session si pertinent.

- [ ] **Step 1 : Vérification en jeu solo**

Run de bout en bout en solo : sélection Bomberman → run → pose de bombes → boutique (uniquement Bombes) → achat jusqu'à 6 → montée en tiers (mèche plus courte) → dynamite/pot de miel augmentent l'explosion → aucun auto-dégât → fin de vague/run sans crash.

- [ ] **Step 2 : Vérification en jeu coop**

Lancer en coop (2 joueurs), au moins un joueur en Bomberman. Expected : chaque joueur pose ses bombes indépendamment, pas de crash, pools/boutiques par joueur cohérents.

- [ ] **Step 3 : Non-régression tests purs**

Run la commande de test. Expected : `=== 11 tests, 0 échec(s) ===`.

- [ ] **Step 4 : Bump version + commit**

Passer `manifest.json` `version_number` à `1.0.0` (premier jet jouable complet, art placeholder). Mettre à jour la mémoire (`MEMORY.md`) avec un pointeur vers le mod Bomberman si utile.

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/manifest.json
git commit -m "chore(bomberman): bump 0.1.0 -> 1.0.0 (mod jouable, art placeholder)"
```

---

## Self-review (couverture du spec)

- **§2 pose aux pieds** → T4 `shoot()`. ✅
- **§2 scaling explosion + Ingénierie** → T5 stats `scaling_stats` + set tool. ✅
- **§2 dynamite/pot de miel automatiques** → T3 (explosion vanilla) + vérif T5 Step 6.4. ✅
- **§2 aucun auto-dégât** → T3 (`from = null`, explosion vanilla) + vérif T5 Step 6.3. ✅
- **§2 6 slots, bombes seules** → T6 bans + slots défaut, vérif T6 Step 6.3-6.4. ✅
- **§2 train serpent + déphasage slot** → T2 (logique) + T7 (câblage), vérif T7 Step 3. ✅
- **§2 départ 1 bombe, 4 tiers** → T5 (tiers) + T6 (`starting_weapons`). ✅
- **§2 mèche par tier 2→1s** → T2 (logique, testée) + T3 (consommation) + T5 (cooldown/tier). ✅
- **§2 wanted_tags explosive** → T6 `wanted_tags`. ✅
- **§5 art placeholders + brief IA** → T8 (brief) + T9 (placeholders). ✅
- **§6 enregistrement ModLoader** → T5/T6 extension ItemService. ✅
- **§6 tests purs headless + vérif en jeu** → T2 (purs) ; T3-T9 vérif en jeu. ✅
- **Contraintes : FR, namespace Tanith, pas de static var, no patch destructif** → respectées (T1 scaffold, extensions only). ✅

**Points nécessitant une confirmation en jeu** (signalés dans les tâches, non bloquants pour le plan) : API exacte de déverrouillage `ProgressData` (T6 Step 4), type de noeud racine de scène d'arme (T4 Step 2), API d'index/compte de slots d'arme (T7 Step 1), format de traduction accepté (T8 Step 1). Chacun a une procédure d'inspection (`grep`/lecture de fichier vanilla) intégrée à sa tâche.
