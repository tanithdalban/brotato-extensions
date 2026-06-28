# Bomberto rework v1.3.0 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire évoluer le personnage à bombes (renommage Bomberto, boutique élargie aux armes explosives/knockback, départ bombe forcée + 1 arme choisie, buffs scaling élémentaire/ingénierie façon Artificier avec -75 % dégâts, scaling arme, entité bombe agrandie) et corriger un bug coop de la troll bombe.

**Architecture:** Mod Brotato (Godot 3.7) intégré par **script extensions** ModLoader + ressources `.tres` ajoutées au pool du jeu. La logique pure (filtre de pool, plafond non-létal) vit dans `content/logic/*.gd` et se teste **headless** ; le reste (effets `.tres`, scènes, code d'entité) se vérifie **en jeu**.

**Tech Stack:** GDScript (Godot 3.6.2 runtime), ModLoader 6.x, ressources `.tres` format 2.

## Global Constraints

- **Langue** : tout en **français** (commentaires, docs, libellés de commits). Libellés UI bilingues via le helper i18n existant.
- **Aucune dépendance autoload dans la logique pure** (`content/logic/*.gd`) — sinon les tests headless ne chargent pas.
- **Tests purs** — runner **Bomberman** (⚠️ PAS le script `run-tests.sh`, qui teste ShopConfig). Commande exacte, lancée depuis la racine du repo :
  ```
  "./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
  ```
  Le résultat est la ligne `=== N tests, M échec(s) ===` (chercher `0 échec(s)`). Les erreurs moteur **après** cette ligne sont la fermeture des autoloads et n'affectent pas le résultat. Baseline avant ce plan : **51 tests, 0 échec**.
- **Identité d'un élément** : `my_id : String` / `weapon_id : String`. `WeaponData.Type { MELEE = 0, RANGED = 1 }`.
- **Intégration** : ne jamais toucher au ban natif, aux item boxes, ni au pool d'**items** ; seulement le pool d'**armes** de la boutique et la sélection de départ.
- **Commits fréquents**, un par tâche minimum. Branche de travail : `feat/troll-bombe`.
- **Version cible** : `1.3.0` (`manifest.json` + `CHANGELOG.md`).

---

## File Structure

**Logique pure (testable headless) :**
- `content/logic/shop_pool.gd` — MODIFIER : remplacer `keep_only_bombs` par `keep_allowed_weapons` + helpers (bombe / set explosive / knockback≥20 mêlée).
- `content/logic/troll_bomb_logic.gd` — MODIFIER : ajouter `min_living_hp(hps)`.
- `test/run_tests.gd` — MODIFIER : remplacer le test du filtre, ajouter le test `min_living_hp`.

**Extensions / entités (code, vérif en jeu) :**
- `extensions/singletons/item_service.gd` — MODIFIER : `get_pool` appelle `keep_allowed_weapons`.
- `content/entities/bomb_entity.gd` — MODIFIER : sprite ×1.25 ; dégât via `get_explosion_damage`.
- `content/weapons/bomb/bomb_weapon.gd` — MODIFIER : calcule la dégât d'explosion et le passe à la bombe.
- `content/entities/troll_bomb.gd` — MODIFIER : plafond contact au PV min global.

**Données (`.tres`, vérif en jeu) :**
- `content/i18n/bomberman_translations.gd` — MODIFIER : `Bombertoe` → `Bomberto`.
- `content/characters/bomberman/bomberman_data.tres` — MODIFIER : `effects`, `starting_weapons`.
- `content/characters/bomberman/effect_damage_malus.tres` — CRÉER : `stat_percent_damage -75`.
- `content/characters/bomberman/effect_explosion_size_per_elemental.tres` — CRÉER.
- `content/characters/bomberman/effect_explosion_damage_per_engineering.tres` — CRÉER.
- `content/characters/bomberman/effect_starting_bomb.tres` — CRÉER : `starting_weapon: weapon_bomb_1`.
- `content/weapons/bomb/bomb_{1..4}_stats.tres` — MODIFIER : `scaling_stats`.

**Méta :**
- `manifest.json`, `CHANGELOG.md` — MODIFIER : bump 1.3.0.

Tous les chemins ci-dessus sont relatifs à `Brotato/mods-unpacked/Tanith-Bomberman/`.

---

## Task 1: Pool boutique élargi (logique pure + branchement)

**Files:**
- Modify: `content/logic/shop_pool.gd`
- Modify: `test/run_tests.gd`
- Modify: `extensions/singletons/item_service.gd`

**Interfaces:**
- Produces: `ShopPool.keep_allowed_weapons(pool: Array) -> Array` et `ShopPool.is_allowed(weapon) -> bool`.
- Consumes (en jeu) : `WeaponData` réel expose `weapon_id: String`, `sets: Array` (chaque `SetData` a `my_id`), `stats` (a `knockback`), `type: int`.

- [ ] **Step 1: Écrire le test qui échoue**

Dans `test/run_tests.gd`, **remplacer** la classe stub et le test `_test_keep_only_bombs` par les stubs et le test suivants. D'abord, remplacer la classe `_StubWeapon` (lignes 16-19) par :

```gdscript
# Faux objets minimaux pour les tests purs du filtre de pool.
class _StubSet:
	var my_id
	func _init(id):
		my_id = id

class _StubStats:
	var knockback
	func _init(kb):
		knockback = kb

class _StubWeapon:
	var weapon_id
	var sets
	var stats
	var type
	func _init(p_weapon_id = "", p_sets = [], p_knockback = 0, p_type = 1):
		weapon_id = p_weapon_id
		sets = p_sets
		stats = _StubStats.new(p_knockback)
		type = p_type
```

Puis **remplacer** l'appel `_test_keep_only_bombs()` (ligne 25) par `_test_keep_allowed_weapons()`, et **remplacer** la fonction `_test_keep_only_bombs` (lignes 58-70) par :

```gdscript
func _test_keep_allowed_weapons():
	var SET_EXPLOSIVE = [_StubSet.new("set_explosive")]
	var SET_HEAVY = [_StubSet.new("set_heavy")]
	# weapon_id, sets, knockback, type (0=MELEE, 1=RANGED)
	var bomb = _StubWeapon.new("weapon_bomb", [], 0, 1)
	var rocket = _StubWeapon.new("weapon_rocket_launcher", SET_EXPLOSIVE, 0, 1)
	var hammer = _StubWeapon.new("weapon_hammer", SET_HEAVY, 30, 0)
	var hand = _StubWeapon.new("weapon_hand", [], 30, 0)
	var pistol = _StubWeapon.new("weapon_pistol", [], 15, 1)
	var sword = _StubWeapon.new("weapon_sword", [], 2, 0)
	var sniper = _StubWeapon.new("weapon_sniper", [], 20, 1)

	_check(ShopPool.is_allowed(bomb), "pool: bombe autorisée")
	_check(ShopPool.is_allowed(rocket), "pool: set explosive autorisé")
	_check(ShopPool.is_allowed(hammer), "pool: knockback 30 mêlée autorisé")
	_check(ShopPool.is_allowed(hand), "pool: hand (kb 30 mêlée) autorisé")
	_check(not ShopPool.is_allowed(pistol), "pool: pistolet (kb 15 distance) refusé")
	_check(not ShopPool.is_allowed(sword), "pool: épée (kb 2) refusée")
	_check(not ShopPool.is_allowed(sniper), "pool: sniper (kb 20 mais distance) refusé")
	_check(not ShopPool.is_allowed(null), "pool: null refusé")

	var pool = [sword, bomb, pistol, rocket, hand]
	var kept = ShopPool.keep_allowed_weapons(pool)
	_check(kept.size() == 3, "pool: garde 3 sur 5 (bombe, rocket, hand)")
	_check(kept[0] == bomb and kept[1] == rocket and kept[2] == hand, "pool: conserve l'ordre")
	_check(pool.size() == 5, "pool: n'altère pas la liste d'entrée")
	_check(ShopPool.keep_allowed_weapons([]).size() == 0, "pool: vide => vide")
```

- [ ] **Step 2: Lancer les tests pour vérifier l'échec**

Run: `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected: ÉCHEC — `keep_allowed_weapons`/`is_allowed` n'existent pas encore (erreur de méthode invalide ou `FAIL`).

- [ ] **Step 3: Implémenter le filtre pur**

**Remplacer intégralement** le contenu de `content/logic/shop_pool.gd` par :

```gdscript
extends Reference
# Logique PURE du filtrage du pool d'ARMES du magasin pour le Bomberto.
# Le jeu vanilla ne sait pas bannir une arme du magasin par ID (character.banned_items
# n'est consulté QUE pour les items, jamais les armes) : on filtre nous-mêmes le pool
# d'armes pour ne garder que le roster du Bomberto.
#
# Une arme est conservée si : c'est une Bombe, OU elle appartient au set explosive,
# OU elle a un knockback >= 20 ET est une arme de mêlée (les armes à distance qui
# atteignent 20 au tier 4 — sniper, potato thrower — sont exclues, hors thème).

const BOMB_WEAPON_ID := "weapon_bomb"
const EXPLOSIVE_SET_ID := "set_explosive"
const KNOCKBACK_THRESHOLD := 20
const TYPE_MELEE := 0  # WeaponData.Type.MELEE


# Vrai si l'arme appartient au roster accessible du Bomberto.
static func is_allowed(weapon) -> bool:
	if weapon == null:
		return false
	if ("weapon_id" in weapon) and weapon.weapon_id == BOMB_WEAPON_ID:
		return true
	if _in_explosive_set(weapon):
		return true
	if _has_strong_knockback_melee(weapon):
		return true
	return false


static func _in_explosive_set(weapon) -> bool:
	if not ("sets" in weapon) or weapon.sets == null:
		return false
	for s in weapon.sets:
		if s != null and ("my_id" in s) and s.my_id == EXPLOSIVE_SET_ID:
			return true
	return false


static func _has_strong_knockback_melee(weapon) -> bool:
	if not ("type" in weapon) or weapon.type != TYPE_MELEE:
		return false
	if not ("stats" in weapon) or weapon.stats == null:
		return false
	if not ("knockback" in weapon.stats):
		return false
	return weapon.stats.knockback >= KNOCKBACK_THRESHOLD


# Retourne une NOUVELLE liste filtrée. N'altère pas `pool` ; conserve l'ordre.
static func keep_allowed_weapons(pool: Array) -> Array:
	var result := []
	for item in pool:
		if is_allowed(item):
			result.push_back(item)
	return result
```

- [ ] **Step 4: Lancer les tests pour vérifier le succès**

Run: `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected: SUCCÈS — la ligne `=== N tests, 0 échec(s) ===` (N augmente vs avant).

- [ ] **Step 5: Brancher l'extension sur le nouveau filtre**

Dans `extensions/singletons/item_service.gd`, fonction `get_pool` (ligne ~82-86), **remplacer** :

```gdscript
		pool = ShopPool.keep_only_bombs(pool)
```

par :

```gdscript
		pool = ShopPool.keep_allowed_weapons(pool)
```

(Le commentaire d'en-tête de la fonction `get_pool`/`_BOMBERMAN` parle de « magasin Bombe uniquement » : mettre à jour ce commentaire pour dire « roster Bomberto : bombe + explosive + knockback mêlée ».)

- [ ] **Step 6: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/shop_pool.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd
git commit -m "feat(bomberman): boutique élargie (bombe + explosive + knockback mêlée)"
```

---

## Task 2: Fix coop — troll bombe non-létale pour tous

**Files:**
- Modify: `content/logic/troll_bomb_logic.gd`
- Modify: `test/run_tests.gd`
- Modify: `content/entities/troll_bomb.gd`

**Interfaces:**
- Produces: `TrollBombLogic.min_living_hp(hps: Array) -> int` (min des PV fournis ; `0x7FFFFFFF` si liste vide).
- Consumes: `troll_bomb.gd` collecte les PV courants des joueurs vivants (`p.current_stats.health`) et passe la liste à `min_living_hp`.

- [ ] **Step 1: Écrire le test qui échoue**

Dans `test/run_tests.gd`, ajouter l'appel `_test_troll_min_living_hp()` dans `_init()` (juste après `_test_troll_nonlethal_damage()`), puis ajouter la fonction :

```gdscript
func _test_troll_min_living_hp():
	_check(TrollLogic.min_living_hp([30, 10, 50]) == 10, "troll: min PV = 10")
	_check(TrollLogic.min_living_hp([5]) == 5, "troll: un seul joueur => son PV")
	_check(TrollLogic.min_living_hp([]) == 0x7FFFFFFF, "troll: aucun joueur => très grand (pas de plafond)")
	_check(TrollLogic.min_living_hp([1, 100]) == 1, "troll: prend le plus bas (1)")
```

- [ ] **Step 2: Lancer les tests pour vérifier l'échec**

Run: `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected: ÉCHEC — `min_living_hp` n'existe pas encore.

- [ ] **Step 3: Implémenter `min_living_hp`**

Dans `content/logic/troll_bomb_logic.gd`, ajouter en fin de fichier (après `keep_distance`) :

```gdscript

# Plus petit PV parmi ceux fournis (PV courants des joueurs VIVANTS, déjà filtrés
# par l'appelant). Retourne un très grand nombre si la liste est vide (=> aucun
# plafond, mais sans cible le dégât n'a de toute façon pas d'effet).
static func min_living_hp(hps: Array) -> int:
	var m := 0x7FFFFFFF
	for hp in hps:
		if hp < m:
			m = hp
	return m
```

- [ ] **Step 4: Lancer les tests pour vérifier le succès**

Run: `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected: SUCCÈS — `=== N tests, 0 échec(s) ===`.

- [ ] **Step 5: Brancher la troll bombe sur le PV min global**

Dans `content/entities/troll_bomb.gd` :

(a) Ajouter une méthode qui collecte le PV min de **tous** les joueurs vivants (sans rayon), juste après `_min_hp_in_blast()` :

```gdscript

# Plus petit PV courant parmi TOUS les joueurs vivants (sans notion de rayon).
# Sert à plafonner le dégât de CONTACT pour qu'aucun joueur — pas seulement le
# poursuivi — ne puisse mourir en coop (la Hitbox couche 4 touche n'importe quel
# joueur qui la chevauche).
func _min_hp_all_living() -> int:
	var main = Utils.get_scene_node()
	if main == null or not ("_players" in main):
		return 0x7FFFFFFF
	var hps := []
	for p in main._players:
		if is_instance_valid(p) and not p.dead:
			hps.append(int(p.current_stats.health))
	return TrollBombLogic.min_living_hp(hps)
```

(b) Dans `_physics_process`, **remplacer** la ligne du plafond de contact :

```gdscript
		_hitbox.damage = TrollBombLogic.nonlethal_damage(_base_damage, int(node.current_stats.health))
```

par :

```gdscript
		_hitbox.damage = TrollBombLogic.nonlethal_damage(_base_damage, _min_hp_all_living())
```

(c) Mettre à jour le commentaire de la ligne (au-dessus) pour refléter « PV min de tous les joueurs vivants (coop-safe) » au lieu de « joueur poursuivi ».

- [ ] **Step 6: Lancer les tests (non-régression)**

Run: `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected: SUCCÈS — toujours `0 échec(s)`.

- [ ] **Step 7: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/troll_bomb_logic.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.gd
git commit -m "fix(bomberman): troll bombe non-létale pour TOUS les joueurs (coop)"
```

> **Vérif en jeu (à faire à la passe finale)** : en coop, avec un allié à bas PV, déclencher une troll bombe (~10 % à la pose) et la laisser toucher l'allié → il survit (jamais 0 PV).

---

## Task 3: Renommage Bombertoe → Bomberto

**Files:**
- Modify: `content/i18n/bomberman_translations.gd`

Pas de test pur (i18n) → vérification en jeu.

- [ ] **Step 1: Modifier les deux locales**

Dans `content/i18n/bomberman_translations.gd`, remplacer les **deux** lignes `add_message("CHARACTER_BOMBERMAN", "Bombertoe")` (locale `en` puis `fr`) par :

```gdscript
	tr_en.add_message("CHARACTER_BOMBERMAN", "Bomberto")
```

et

```gdscript
	tr_fr.add_message("CHARACTER_BOMBERMAN", "Bomberto")
```

(Les clés `WEAPON_BOMB` restent inchangées : `"Bomb"` / `"Bombe"`.)

- [ ] **Step 2: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd
git commit -m "feat(bomberman): renomme le perso Bombertoe -> Bomberto"
```

> **Vérif en jeu** : l'écran de sélection affiche « Bomberto ».

---

## Task 4: Buffs du personnage (effets natifs façon Artificier)

**Files:**
- Create: `content/characters/bomberman/effect_damage_malus.tres`
- Create: `content/characters/bomberman/effect_explosion_size_per_elemental.tres`
- Create: `content/characters/bomberman/effect_explosion_damage_per_engineering.tres`
- Modify: `content/characters/bomberman/bomberman_data.tres`

Pas de test pur (données `.tres`) → vérification en jeu.

- [ ] **Step 1: Créer l'effet -75 % dégâts**

Créer `content/characters/bomberman/effect_damage_malus.tres` :

```
[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "stat_percent_damage"
text_key = ""
value = -75
custom_key = ""
storage_method = 0
effect_sign = 3
custom_args = [  ]
```

- [ ] **Step 2: Créer l'effet +5 % taille d'explosion / point d'élémentaire**

Créer `content/characters/bomberman/effect_explosion_size_per_elemental.tres` (calqué sur `res://items/characters/artificer/artificer_effect_1b.tres`) :

```
[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://effects/items/gain_stat_for_every_stat_effect.gd" type="Script" id=1]
[ext_resource path="res://items/global/custom_arg.gd" type="Script" id=2]

[sub_resource type="Resource" id=1]
script = ExtResource( 2 )
arg_index = 4
arg_sign = 4
arg_value = 0
arg_format = 0
arg_key = ""

[resource]
script = ExtResource( 1 )
key = "explosion_size"
text_key = "EFFECT_GAIN_STAT_FOR_EVERY_STAT"
value = 5
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [ SubResource( 1 ) ]
nb_stat_scaled = 1
stat_scaled = "stat_elemental_damage"
perm_stats_only = false
```

- [ ] **Step 3: Créer l'effet +5 % dégâts d'explosion / point d'ingénierie**

Créer `content/characters/bomberman/effect_explosion_damage_per_engineering.tres` :

```
[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://effects/items/gain_stat_for_every_stat_effect.gd" type="Script" id=1]
[ext_resource path="res://items/global/custom_arg.gd" type="Script" id=2]

[sub_resource type="Resource" id=1]
script = ExtResource( 2 )
arg_index = 4
arg_sign = 4
arg_value = 0
arg_format = 0
arg_key = ""

[resource]
script = ExtResource( 1 )
key = "explosion_damage"
text_key = "EFFECT_GAIN_STAT_FOR_EVERY_STAT"
value = 5
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [ SubResource( 1 ) ]
nb_stat_scaled = 1
stat_scaled = "stat_engineering"
perm_stats_only = false
```

- [ ] **Step 4: Référencer les 3 effets dans le perso (et retirer l'ancien)**

Dans `content/characters/bomberman/bomberman_data.tres` :

(a) Dans l'en-tête `[ext_resource ...]`, **remplacer** la ligne de l'ancien effet d'explosion (`bomberman_explosion_effect.tres`, `id=3`) par les trois nouveaux. C.-à-d. retirer :

```
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/characters/bomberman/bomberman_explosion_effect.tres" type="Resource" id=3]
```

et ajouter (réutiliser `id=3`, ajouter `id=8`, `id=9` — vérifier que ces ids ne sont pas déjà pris dans le fichier ; sinon prendre les prochains libres) :

```
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/characters/bomberman/effect_damage_malus.tres" type="Resource" id=3]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/characters/bomberman/effect_explosion_size_per_elemental.tres" type="Resource" id=8]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/characters/bomberman/effect_explosion_damage_per_engineering.tres" type="Resource" id=9]
```

(b) Mettre à jour `load_steps` en haut du fichier (`[gd_resource type="Resource" load_steps=N format=2]`) : +2 ressources nettes (3 retirée, 3+8+9 ajoutées = +2). Incrémenter `load_steps` de 2.

(c) **Remplacer** la ligne `effects = [ ExtResource( 3 ) ]` par :

```
effects = [ ExtResource( 3 ), ExtResource( 8 ), ExtResource( 9 ) ]
```

> Note : l'ancien fichier `bomberman_explosion_effect.tres` peut rester sur disque (plus référencé) ; le supprimer est optionnel et traité en fin de plan si souhaité.

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/
git commit -m "feat(bomberman): buffs -75% dégâts + scaling explosion élémentaire/ingé"
```

> **Vérif en jeu** : fiche perso affiche -75 % dégâts ; en montant l'élémentaire les explosions grossissent ; en montant l'ingé les explosions tapent plus fort.

---

## Task 5: Armes de départ — bombe forcée + 1 arme choisie

**Files:**
- Create: `content/characters/bomberman/effect_starting_bomb.tres`
- Modify: `content/characters/bomberman/bomberman_data.tres`

Pas de test pur → vérification en jeu.

- [ ] **Step 1: Créer l'effet « arme de départ forcée : Bombe »**

Créer `content/characters/bomberman/effect_starting_bomb.tres` (calqué sur `res://items/characters/crazy/crazy_effect_3.tres`) :

```
[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "weapon_bomb_1"
text_key = "effect_starting_item"
value = 1
custom_key = "starting_weapon"
storage_method = 1
effect_sign = 3
custom_args = [  ]
```

- [ ] **Step 2: Référencer l'effet de départ + étendre la liste de choix**

Dans `content/characters/bomberman/bomberman_data.tres` :

(a) Ajouter dans l'en-tête les `ext_resource` pour l'effet de départ **et** les 6 armes de choix vanilla (la Bombe `id=4` est déjà référencée). Utiliser des ids libres (adapter si déjà pris) :

```
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/characters/bomberman/effect_starting_bomb.tres" type="Resource" id=10]
[ext_resource path="res://weapons/ranged/shredder/1/shredder_data.tres" type="Resource" id=11]
[ext_resource path="res://weapons/melee/plank/1/plank_data.tres" type="Resource" id=12]
[ext_resource path="res://weapons/melee/hand/1/hand_data.tres" type="Resource" id=13]
[ext_resource path="res://weapons/melee/spiky_shield/1/spiky_shield_data.tres" type="Resource" id=14]
[ext_resource path="res://weapons/melee/torch/1/torch_data.tres" type="Resource" id=15]
[ext_resource path="res://weapons/melee/wrench/1/wrench_data.tres" type="Resource" id=16]
```

(b) Incrémenter `load_steps` de **7** (1 effet + 6 armes).

(c) Ajouter l'effet de départ à la liste `effects` (qui contient déjà 3, 8, 9 depuis Task 4) :

```
effects = [ ExtResource( 3 ), ExtResource( 8 ), ExtResource( 9 ), ExtResource( 10 ) ]
```

(d) **Remplacer** `starting_weapons = [ ExtResource( 4 ) ]` (la Bombe seule) par la liste de choix complète (Bombe conservée → 2 bombes possibles) :

```
starting_weapons = [ ExtResource( 4 ), ExtResource( 11 ), ExtResource( 12 ), ExtResource( 13 ), ExtResource( 14 ), ExtResource( 15 ), ExtResource( 16 ) ]
```

- [ ] **Step 3: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/
git commit -m "feat(bomberman): départ = bombe forcée + 1 arme choisie (roster tier-0)"
```

> **Vérif en jeu** : l'écran de sélection d'arme propose Bombe + Shredder, Plank, Hand, Spiky Shield, Torch, Wrench (les déverrouillées) ; quel que soit le choix, on démarre **avec une Bombe** en plus ; choisir la Bombe → départ avec 2 bombes.

---

## Task 6: Scaling de l'arme Bombe (100 % ingé + 150 % élémentaire)

**Files:**
- Modify: `content/weapons/bomb/bomb_1_stats.tres`
- Modify: `content/weapons/bomb/bomb_2_stats.tres`
- Modify: `content/weapons/bomb/bomb_3_stats.tres`
- Modify: `content/weapons/bomb/bomb_4_stats.tres`

Pas de test pur → vérification en jeu.

- [ ] **Step 1: Modifier les 4 fichiers de stats**

Dans **chacun** des 4 fichiers `bomb_{1..4}_stats.tres`, **remplacer** la ligne :

```
scaling_stats = [ [ "stat_elemental_damage", 0.5 ], [ "stat_engineering", 0.5 ] ]
```

par :

```
scaling_stats = [ [ "stat_engineering", 1.0 ], [ "stat_elemental_damage", 1.5 ] ]
```

(Vérifier la valeur exacte présente avant remplacement : les 4 tiers partagent la même ligne `scaling_stats` `0.5/0.5`.)

- [ ] **Step 2: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_1_stats.tres \
        Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_2_stats.tres \
        Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_3_stats.tres \
        Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_4_stats.tres
git commit -m "feat(bomberman): arme Bombe scaling 100% ingé + 150% élémentaire"
```

> **Vérif en jeu** : la fiche de la Bombe montre le scaling ingé/élémentaire ; le dégât augmente avec ces deux stats.

---

## Task 7: Entité bombe — sprite ×1.25 (visuel)

**Files:**
- Modify: `content/entities/bomb_entity.gd`

Pas de test pur → vérification en jeu.

- [ ] **Step 1: Agrandir le sprite à l'armement**

Dans `content/entities/bomb_entity.gd`, fonction `arm(...)`, juste **après** le bloc qui assigne le skin au sprite (après `_sprite.texture = skin`), ajouter l'agrandissement visuel :

```gdscript
	# Grossissement purement VISUEL de la bombe posée (n'affecte pas le rayon
	# d'explosion, géré par _explosion_scale / explosion_size).
	if is_instance_valid(_sprite):
		_sprite.scale = Vector2(1.25, 1.25)
```

- [ ] **Step 2: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd
git commit -m "feat(bomberman): bombe posée 1.25x plus grosse (visuel)"
```

> **Vérif en jeu** : la bombe au sol est visiblement plus grosse ; le rayon d'explosion est inchangé.

---

## Task 8: Faire bénéficier la Bombe du bonus `explosion_damage` (ingé)

**Files:**
- Modify: `content/weapons/bomb/bomb_weapon.gd`
- Modify: `content/entities/bomb_entity.gd`

**Interfaces:**
- Modifie la signature : `bomb_entity.arm(p_player_index, p_stats, p_tier, p_explosion_scale, p_damage_tracking_key_hash, p_explosion_damage)` — nouveau dernier paramètre `p_explosion_damage: int` (dégât d'explosion pré-calculé, incluant `%Damage` + `explosion_damage`).

Pas de test pur (dépend de `WeaponService`/autoloads) → vérification en jeu + raisonnement.

**Contexte :** la Bombe a `effects = []`, donc le jeu ne la recalcule pas comme « exploding » → `current_stats.damage` n'inclut **pas** le bonus `explosion_damage`. On calcule le dégât correct via `WeaponService.get_explosion_damage(base_stats, player_index)` (`weapon_service.gd:281` : applique `scaling_stats` + `%Damage` + `explosion_damage`, min 1) à partir des **stats de base** de l'arme (`weapon.stats`, pas `current_stats`, pour ne pas double-compter le `%Damage`).

- [ ] **Step 1: Calculer le dégât d'explosion dans l'arme et le passer à la bombe**

Dans `content/weapons/bomb/bomb_weapon.gd`, fonction `shoot()`, **remplacer** la ligne :

```gdscript
	bomb.arm(player_index, current_stats, tier, EXPLOSION_SCALE)
```

par :

```gdscript
	# Dégât d'explosion calculé depuis les stats de BASE (pas current_stats) pour
	# inclure le bonus explosion_damage (buff ingé) sans double-compter le %Damage.
	# La Bombe n'a pas d'ExplodingEffect dans ses `effects`, donc current_stats
	# ne porte pas ce bonus.
	var explosion_damage = WeaponService.get_explosion_damage(stats, player_index)
	bomb.arm(player_index, current_stats, tier, EXPLOSION_SCALE, Keys.empty_hash, explosion_damage)
```

- [ ] **Step 2: Accepter et utiliser le dégât pré-calculé dans l'entité**

Dans `content/entities/bomb_entity.gd` :

(a) Ajouter un champ près des autres variables d'état (vers ligne 26) :

```gdscript
var _explosion_damage_override: int = -1  # dégât d'explosion pré-calculé (-1 = non fourni)
```

(b) **Remplacer** la signature et le corps de `arm(...)` pour accepter le nouveau paramètre. Modifier la ligne `func arm(...)` :

```gdscript
func arm(p_player_index: int, p_stats: WeaponStats, p_tier: int, p_explosion_scale: float = 1.75, p_damage_tracking_key_hash: int = Keys.empty_hash, p_explosion_damage: int = -1) -> void:
```

puis, dans le corps de `arm`, juste après `_damage_tracking_key_hash = p_damage_tracking_key_hash`, ajouter :

```gdscript
	_explosion_damage_override = p_explosion_damage
```

(c) Dans `_on_fuse_timeout()`, **remplacer** :

```gdscript
	_explode_args.damage = _stats.damage
```

par :

```gdscript
	_explode_args.damage = _explosion_damage_override if _explosion_damage_override >= 0 else _stats.damage
```

> Note : la troll bombe (`_wake_into_troll`) continue de recevoir `_stats` et plafonne son dégât en non-létal (Task 2) — elle n'est volontairement pas concernée par ce calcul.

- [ ] **Step 3: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd
git commit -m "fix(bomberman): la Bombe bénéficie du bonus explosion_damage (buff ingé)"
```

> **Vérif en jeu** : à ingé élevé, le dégât réel de l'explosion de la Bombe augmente nettement (le buff +5 %/ingé l'atteint), et à -75 % dégâts sans ingé/élémentaire la Bombe tape très faiblement (min 1).

---

## Task 9: Bump version 1.3.0 + CHANGELOG

**Files:**
- Modify: `manifest.json`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Bump manifest**

Dans `manifest.json`, remplacer `"version_number": "1.2.0",` par `"version_number": "1.3.0",`.

- [ ] **Step 2: Entrée CHANGELOG**

En tête de `CHANGELOG.md`, juste avant `## [1.2.0] — 2026-06-27`, insérer :

```markdown
## [1.3.0] — 2026-06-27

### Changed
- Personnage renommé **Bombertoe → Bomberto**.
- Boutique élargie : en plus des Bombes, propose désormais les armes du set
  **explosive** et les armes de mêlée à **fort knockback (≥ 20)** (Hammer, Hand,
  Spiky Shield, Torch, Wrench…).
- Armes de départ : on commence **toujours avec une Bombe** (forcée), **plus** une
  arme choisie parmi le roster accessible disposant d'un tier-0 (Bombe, Shredder,
  Plank, Hand, Spiky Shield, Torch, Wrench). Choisir la Bombe = démarrer avec 2 bombes.
- Refonte des buffs : **-75 % dégâts**, **+5 % taille d'explosion par point
  d'élémentaire**, **+5 % dégâts d'explosion par point d'ingénierie** (effets globaux,
  s'appliquent aussi aux armes explosives achetées).
- Arme Bombe : scaling **100 % ingénierie + 150 % élémentaire** (au lieu de 50/50).
- Bombe posée **1.25× plus grosse** (visuel uniquement).

### Fixed
- La Bombe bénéficie désormais réellement du bonus de **dégâts d'explosion**
  (le buff ingénierie l'atteint).
- **Coop** : une troll bombe ne peut plus **tuer un coéquipier** — le dégât de
  contact est plafonné au PV minimum de **tous** les joueurs vivants.
```

- [ ] **Step 3: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/manifest.json \
        Brotato/mods-unpacked/Tanith-Bomberman/CHANGELOG.md
git commit -m "chore(bomberman): bump 1.3.0 + changelog (rework Bomberto)"
```

---

## Passe de vérification finale (en jeu)

Après la Task 9, lancer Brotato avec le mod (copier/symlinker le dossier dans `mods-unpacked/` à côté du `.pck`) et dérouler la checklist **« Vérif en jeu »** de chaque tâche :

1. Nom « Bomberto » affiché.
2. Sélection de départ = roster tier-0 ; départ = Bombe forcée + choix.
3. Boutique propose bombe + explosive + knockback mêlée (tous tiers).
4. Buffs : -75 % dégâts ; explosions plus grosses (élémentaire) ; plus fortes (ingé) ; la Bombe en bénéficie.
5. Bombe posée plus grosse (×1.25), rayon inchangé.
6. Coop : troll bombe ne tue jamais un allié.

Lancer une dernière fois `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd` → `0 échec(s)`.

> Déploiement Steam Workshop (item `3748276960`) hors périmètre de ce plan.
