# Chaîne de défis des bombes — plan d'implémentation

> **Pour les agents :** SOUS-SKILL REQUIS — utiliser `superpowers:subagent-driven-development` (recommandé) ou `superpowers:executing-plans` pour exécuter ce plan tâche par tâche. Les étapes sont des cases à cocher (`- [ ]`).

**But :** verrouiller les trois bombes élémentaires (Glace, Foudre, Poison) derrière une chaîne de défis in-game : Bombe IV → Glace, Glace IV → Foudre, Foudre IV → Poison.

**Architecture :** aucune arme nouvelle. On pose `unlocked_by_default = false` sur les bombes (le magasin et l'écran d'arme de départ les ignorent alors nativement), on enregistre trois `ChallengeData` dans le `ChallengeService` du jeu, et on complète le défi voulu depuis une extension de `RunData.add_weapon()` — l'entonnoir unique par lequel passe toute acquisition d'arme. Le déblocage prend effet à la run suivante, comme tous ceux du jeu.

**Stack :** GDScript (Godot 3.6), ModLoader script extensions, `.tres` de ressources.

**Spec :** `docs/superpowers/specs/2026-07-11-defis-chaine-bombes-design.md`
**Branche :** `feat/defis-bombes` (déjà créée, spec commitée en `0cad5f6`)

## Contraintes globales

- **Tout est en français** : commentaires, docs, libellés de commits. Les libellés UI sont **bilingues FR/EN**.
- **Aucun succès Steam.** Tout appel à `ChallengeService.complete_challenge()` doit passer `also_complete_platform_challenge = false`.
- **Le mod n'a pas de `.csv`** : ModLoader exige un `.translation` compilé, donc **tout** libellé passe par `content/i18n/bomberman_translations.gd`, codé en dur.
- **Runner de tests** (⚠️ ce n'est PAS `./run-tests.sh`, qui lance ShopConfig) :
  ```
  "./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
  ```
  Résultat = ligne `=== N tests, M échec(s) ===`. Les erreurs moteur **après** cette ligne sont la fermeture des autoloads : sans effet.
- **⚠️ CONTRÔLE OBLIGATOIRE après toute modif d'un `.gd` chargé en jeu** (la suite de tests ne charge QUE la logique pure — elle ne peut pas prouver que les extensions compilent) : la sortie du runner ne doit contenir **ni `parse error` ni `compile error`**.
- **Le niveau IV est le `tier = 3`** (`ItemParentData.Tier` : COMMON=0, UNCOMMON=1, RARE=2, LEGENDARY=3).
- **⚠️ `"weapon_bomb"` est un PRÉFIXE de `"weapon_bomb_ice"`** : toute correspondance de `weapon_id` doit être **exacte**, jamais un `begins_with()`.

---

### Task 1 : la logique pure de la chaîne

**Fichiers :**
- Créer : `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd`
- Modifier : `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces :**
- Consomme : rien.
- Produit :
  - `const TIER_IV := 3`
  - `const CHAIN := Dictionary` — `weapon_id` → `my_id` du défi que « posséder cette arme au tier IV » complète.
  - `const REWARD := Dictionary` — `my_id` du défi → `weapon_id` de la bombe qu'il débloque.
  - `const MIGRATION_ASKED_ID := "chal_bomb_migration_asked"`
  - `static func challenge_for(weapon_id: String, tier: int) -> String` — `""` si aucun défi.
  - `static func unearned_bombs(unlocked_weapon_ids: Array, completed_challenge_ids: Array) -> Array` — les `weapon_id` possédés mais non gagnés, triés.

- [ ] **Étape 1 : écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter le `preload` en tête, à la suite des autres :

```gdscript
const BombChallenges = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd")
```

Ajouter l'appel dans `_init()`, après `_test_bomb_placement()` :

```gdscript
	_test_bomb_challenges()
```

Puis ajouter la fonction de test en fin de fichier :

```gdscript
func _test_bomb_challenges() -> void:
	# ⚠️ Signature du helper existant : _check(cond, name) — la CONDITION d'abord.

	# La chaîne : chaque bombe au tier IV débloque la suivante.
	_check(BombChallenges.challenge_for("weapon_bomb", 3) == "chal_bomb_ice",
		"défis: Bombe IV -> défi glace")
	_check(BombChallenges.challenge_for("weapon_bomb_ice", 3) == "chal_bomb_storm",
		"défis: Glace IV -> défi foudre")
	_check(BombChallenges.challenge_for("weapon_bomb_storm", 3) == "chal_bomb_poison",
		"défis: Foudre IV -> défi poison")

	# Fin de chaîne : le poison ne débloque rien.
	_check(BombChallenges.challenge_for("weapon_bomb_poison", 3) == "",
		"défis: Poison IV ne complète rien (fin de chaîne)")

	# Seul le tier IV compte.
	_check(BombChallenges.challenge_for("weapon_bomb", 2) == "",
		"défis: Bombe III ne complète rien")
	_check(BombChallenges.challenge_for("weapon_bomb", 0) == "",
		"défis: Bombe I ne complète rien")

	# Une arme étrangère ne complète rien.
	_check(BombChallenges.challenge_for("weapon_pistol", 3) == "",
		"défis: arme non-bombe ne complète rien")

	# ⚠️ "weapon_bomb" est un préfixe des autres : la correspondance doit être EXACTE.
	# Ce test échoue si l'implémentation utilise begins_with().
	_check(BombChallenges.challenge_for("weapon_bomb_ice", 3) != "chal_bomb_ice",
		"défis: correspondance exacte, pas par préfixe")

	# Cohérence interne : toute récompense de la chaîne est une bombe connue.
	var coherent := true
	for weapon_id in BombChallenges.CHAIN:
		var chal_id = BombChallenges.CHAIN[weapon_id]
		if not BombChallenges.REWARD.has(chal_id):
			coherent = false
	_check(coherent, "défis: chaque défi de la chaîne a une récompense")

	# Migration : bombes possédées mais non gagnées.
	_check(BombChallenges.unearned_bombs([], []).empty(),
		"migration: rien de possédé => rien à proposer")
	_check(BombChallenges.unearned_bombs(["weapon_bomb_ice"], []) == ["weapon_bomb_ice"],
		"migration: glace possédée et non gagnée => à proposer")
	_check(BombChallenges.unearned_bombs(["weapon_bomb_ice"], ["chal_bomb_ice"]).empty(),
		"migration: glace possédée ET gagnée => rien à proposer")
	_check(BombChallenges.unearned_bombs(
			["weapon_bomb_ice", "weapon_bomb_storm", "weapon_bomb_poison"], []).size() == 3,
		"migration: les trois possédées => les trois à proposer")
	_check(BombChallenges.unearned_bombs(["weapon_bomb"], []).empty(),
		"migration: la bombe normale n'est jamais concernée")
```

> Note : `_check(nom, condition)` est le helper d'assertion déjà présent dans `run_tests.gd`. S'il porte un autre nom dans le fichier, utiliser celui-là — ne pas en créer un second.

- [ ] **Étape 2 : lancer les tests pour vérifier qu'ils échouent**

```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```

Attendu : échec au chargement (`bomb_challenges.gd` n'existe pas) — le runner ne démarre pas.

- [ ] **Étape 3 : écrire l'implémentation minimale**

Créer `content/logic/bomb_challenges.gd` :

```gdscript
extends Reference
# Logique PURE de la chaîne de défis des bombes.
# Aucune dépendance aux autoloads du jeu -> testable en headless.
#
# La chaîne : monter une bombe au niveau IV débloque la bombe suivante.
#   Bombe IV -> Glace, Glace IV -> Foudre, Foudre IV -> Poison.
# Le Poison est la fin de la chaîne : il ne débloque rien.

# ItemParentData.Tier : COMMON=0, UNCOMMON=1, RARE=2, LEGENDARY=3.
# Le niveau IV affiché en jeu est donc le tier 3.
const TIER_IV := 3

# weapon_id -> my_id du défi que « posséder cette arme au tier IV » complète.
# ⚠️ La correspondance est EXACTE, jamais un begins_with() : "weapon_bomb" est un
# préfixe de "weapon_bomb_ice", "weapon_bomb_storm" et "weapon_bomb_poison".
const CHAIN := {
	"weapon_bomb": "chal_bomb_ice",
	"weapon_bomb_ice": "chal_bomb_storm",
	"weapon_bomb_storm": "chal_bomb_poison",
}

# my_id du défi -> weapon_id de la bombe qu'il débloque.
const REWARD := {
	"chal_bomb_ice": "weapon_bomb_ice",
	"chal_bomb_storm": "weapon_bomb_storm",
	"chal_bomb_poison": "weapon_bomb_poison",
}

# Défi CACHÉ, sans ChallengeData ni récompense : sa seule fonction est de mémoriser
# qu'on a déjà posé la question de migration au joueur. Poussé tel quel dans
# ProgressData.challenges_completed (que le jeu sauvegarde), il reste invisible :
# l'écran Progression itère le tableau ChallengeService.challenges, pas les hash
# complétés. Aucun fichier maison, aucune persistance à écrire.
const MIGRATION_ASKED_ID := "chal_bomb_migration_asked"


# Le défi complété par l'obtention de cette arme, ou "" si aucun.
static func challenge_for(weapon_id: String, tier: int) -> String:
	if tier != TIER_IV:
		return ""
	return CHAIN.get(weapon_id, "")


# Les bombes que le joueur POSSÈDE sans les avoir GAGNÉES (défi non complété).
# C'est ce qui déclenche la proposition de migration, et exactement ce qu'on
# reverrouille s'il l'accepte. Trié pour être déterministe.
static func unearned_bombs(unlocked_weapon_ids: Array, completed_challenge_ids: Array) -> Array:
	var result := []
	for chal_id in REWARD:
		var weapon_id: String = REWARD[chal_id]
		if unlocked_weapon_ids.has(weapon_id) and not completed_challenge_ids.has(chal_id):
			result.append(weapon_id)
	result.sort()
	return result
```

- [ ] **Étape 4 : lancer les tests pour vérifier qu'ils passent**

```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```

Attendu : `=== 138 tests, 0 échec(s) ===` (125 existants + 13 nouveaux).

- [ ] **Étape 5 : commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): logique pure de la chaîne de défis des bombes"
```

---

### Task 2 : les trois défis et leur enregistrement

**Fichiers :**
- Créer : `content/challenges/chal_bomb_ice_data.tres`
- Créer : `content/challenges/chal_bomb_storm_data.tres`
- Créer : `content/challenges/chal_bomb_poison_data.tres`
- Créer : `extensions/singletons/challenge_service.gd`
- Modifier : `content/i18n/bomberman_translations.gd`
- Modifier : `mod_main.gd`

**Interfaces :**
- Consomme : `BombChallenges.REWARD` (Task 1) pour les `my_id` (`chal_bomb_ice`, `chal_bomb_storm`, `chal_bomb_poison`).
- Produit : trois `ChallengeData` présents dans `ChallengeService.challenges`, hashés, avec récompense = la bombe de tier I correspondante.

**Contexte indispensable :**

`ChallengeService` est un autoload chargé **APRÈS** `ItemService` (`project.godot:2466` puis `:2474`). On ne peut donc PAS enregistrer les défis depuis l'extension `item_service.gd` : le singleton n'existe pas encore à ce moment. On étend `challenge_service.gd` et on injecte **avant** l'appel au parent — c'est le patron déjà employé pour les armes.

⚠️ `ChallengeService._generate_hashes()` est gardé par un drapeau `_hashes_generated` et **ne repassera jamais** après son `_ready()`. En injectant avant `._ready()`, nos défis sont hashés par le passage natif.

⚠️ La `description` ne doit **surtout pas** valoir `"CHAL_CHARACTER_DESC"` : `_sync_platform_challenges()` (`challenge_service.gd:171`) route cette valeur vers `_sync_character_challenge()`, qui va chercher un personnage inexistant.

- [ ] **Étape 1 : créer les trois ChallengeData**

`content/challenges/chal_bomb_ice_data.tres` :

```
[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_ice_1_data.tres" type="Resource" id=2]
[ext_resource path="res://challenges/global/challenge_data.gd" type="Script" id=3]

[resource]
script = ExtResource( 3 )
my_id = "chal_bomb_ice"
unlocked_by_default = false
can_be_looted = true
icon = ExtResource( 1 )
name = "CHAL_BOMB_ICE"
tier = 0
value = 1
effects = [  ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
description = "CHAL_BOMB_ICE_DESC"
reward_type = 1
reward = ExtResource( 2 )
number = 0
stat = ""
additional_args = [  ]
```

`content/challenges/chal_bomb_storm_data.tres` : identique, sauf

```
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_storm_1_data.tres" type="Resource" id=2]
```
```
my_id = "chal_bomb_storm"
name = "CHAL_BOMB_STORM"
description = "CHAL_BOMB_STORM_DESC"
```

`content/challenges/chal_bomb_poison_data.tres` : identique, sauf

```
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_poison_1_data.tres" type="Resource" id=2]
```
```
my_id = "chal_bomb_poison"
name = "CHAL_BOMB_POISON"
description = "CHAL_BOMB_POISON_DESC"
```

> `reward_type = 1` = `RewardType.WEAPON`. La récompense pointe la bombe de **tier I** : `unlock_reward()` déverrouille par `weapon_id`, qui est **commun aux 4 tiers** — toute la famille est débloquée d'un coup.

- [ ] **Étape 2 : ajouter les libellés bilingues**

Dans `content/i18n/bomberman_translations.gd`, ajouter aux blocs `tr_en` **et** `tr_fr` (à la suite des messages existants) :

```gdscript
	tr_en.add_message("CHAL_BOMB_ICE", "Ice Handler")
	tr_en.add_message("CHAL_BOMB_ICE_DESC", "Get a tier IV Bomb.")
	tr_en.add_message("CHAL_BOMB_STORM", "Storm Handler")
	tr_en.add_message("CHAL_BOMB_STORM_DESC", "Get a tier IV Ice Bomb.")
	tr_en.add_message("CHAL_BOMB_POISON", "Poison Handler")
	tr_en.add_message("CHAL_BOMB_POISON_DESC", "Get a tier IV Storm Bomb.")
```

```gdscript
	tr_fr.add_message("CHAL_BOMB_ICE", "Artificier de glace")
	tr_fr.add_message("CHAL_BOMB_ICE_DESC", "Obtenez une Bombe de niveau IV.")
	tr_fr.add_message("CHAL_BOMB_STORM", "Artificier de foudre")
	tr_fr.add_message("CHAL_BOMB_STORM_DESC", "Obtenez une Bombe de Glace de niveau IV.")
	tr_fr.add_message("CHAL_BOMB_POISON", "Artificier de poison")
	tr_fr.add_message("CHAL_BOMB_POISON_DESC", "Obtenez une Bombe de Foudre de niveau IV.")
```

> ⚠️ Les descriptions ne doivent contenir **aucun** `{0}`/`{1}` : `ChallengeData.get_description_text()` les formate avec `[str(value), tr(stat.to_upper())]`, et notre `stat` est vide.

- [ ] **Étape 3 : créer l'extension du ChallengeService**

`extensions/singletons/challenge_service.gd` :

```gdscript
extends "res://singletons/challenge_service.gd"
# Enregistre les défis du mod dans le service de défis du jeu.
#
# POURQUOI ICI, et pas dans l'extension item_service : ChallengeService est un autoload
# chargé APRÈS ItemService (project.godot:2466 puis :2474). Depuis item_service._ready(),
# le singleton ChallengeService n'existe pas encore.
#
# ⚠️ L'injection DOIT précéder l'appel au parent : _generate_hashes() est gardé par le
# drapeau _hashes_generated et ne repassera jamais. En injectant avant ._ready(), nos
# défis sont hashés par le passage natif (qui remplit aussi hash_to_id).

const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")

const _CHALLENGES := [
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_ice_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_storm_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_poison_data.tres",
]


func _ready() -> void:
	for path in _CHALLENGES:
		var chal = load(path)
		if chal != null and not challenges.has(chal):
			challenges.append(chal)
			ModLog.info("défi enregistré: " + str(chal.my_id))

	._ready()
```

- [ ] **Étape 4 : déclarer l'extension**

Dans `mod_main.gd`, fonction `_install_extensions()`, ajouter :

```gdscript
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-Bomberman/extensions/singletons/challenge_service.gd")
```

- [ ] **Étape 5 : lancer les tests et le contrôle de compilation**

```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd 2>&1 | grep -aiE "parse error|compile error|=== [0-9]+ tests"
```

Attendu : la ligne `=== 138 tests, 0 échec(s) ===` et **aucune** ligne `parse error` / `compile error`.

- [ ] **Étape 6 : commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/challenges Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/challenge_service.gd Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd
git commit -m "feat(bomberman): enregistre les trois défis de la chaîne des bombes"
```

---

### Task 3 : verrouiller les trois bombes

**Fichiers :**
- Modifier : `content/weapons/bomb/bomb_ice_{1,2,3,4}_data.tres` (ligne `unlocked_by_default`)
- Modifier : `content/weapons/bomb/bomb_storm_{1,2,3,4}_data.tres`
- Modifier : `content/weapons/bomb/bomb_poison_{1,2,3,4}_data.tres`

**Interfaces :**
- Consomme : rien.
- Produit : les 12 `.tres` portent `unlocked_by_default = false`.

**Contexte indispensable :**

Le verrouillage est **entièrement natif**, il n'y a rien à coder. `ItemService.init_unlocked_pool()` (`singletons/item_service.gd:119-127`) ne verse une arme dans les pools du magasin que si son `weapon_id_hash` figure dans `ProgressData.weapons_unlocked` ; l'écran de choix d'arme de départ filtre sur la même liste.

⚠️ **Le point le plus fragile de toute la fonctionnalité :** l'extension `item_service.gd` du mod rejoue `ProgressData.add_unlocked_by_default()` (ligne 102) pour réparer le déblocage des armes injectées après le passage natif. Ce replay **doit respecter** le drapeau `unlocked_by_default` de chaque arme. S'il déverrouillait tout inconditionnellement, les bombes resteraient débloquées et la fonctionnalité entière serait sans effet. **C'est la première chose à vérifier en jeu (Task 6).** Ne PAS modifier ce replay : la bombe normale, le personnage et les difficultés en dépendent.

- [ ] **Étape 1 : basculer le drapeau sur les 12 fichiers**

Dans chacun des 12 fichiers, remplacer la ligne :

```
unlocked_by_default = true
```

par :

```
unlocked_by_default = false
```

⚠️ Ne toucher **ni** aux 4 `bomb_{1..4}_data.tres` (la Bombe normale reste débloquée : c'est l'arme de départ forcée de Bomberto, et le premier maillon de la chaîne), **ni** au personnage.

- [ ] **Étape 2 : vérifier qu'aucun fichier n'a été oublié**

```bash
grep -l "unlocked_by_default = true" Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_{ice,storm,poison}_*_data.tres
```

Attendu : **aucune sortie** (les 12 sont à `false`).

```bash
grep -c "unlocked_by_default = true" Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_1_data.tres
```

Attendu : `1` (la Bombe normale reste débloquée).

- [ ] **Étape 3 : lancer les tests**

```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```

Attendu : `=== 138 tests, 0 échec(s) ===` (les tests purs ne lisent pas les `.tres` — c'est une non-régression).

- [ ] **Étape 4 : commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/
git commit -m "feat(bomberman): verrouille les bombes glace, foudre et poison"
```

---

### Task 4 : détecter l'obtention d'une bombe IV

**Fichiers :**
- Créer : `extensions/singletons/run_data.gd`
- Modifier : `mod_main.gd`

**Interfaces :**
- Consomme : `BombChallenges.challenge_for(weapon_id, tier)` (Task 1) ; les `ChallengeData` enregistrés (Task 2).
- Produit : le défi correspondant est complété dès qu'une bombe de tier IV entre dans l'inventaire.

**Contexte indispensable :**

`RunData.add_weapon()` (`singletons/run_data.gd:982`) est l'**entonnoir unique** de toute acquisition d'arme : fusion en boutique (`base_shop.gd:693`), achat direct d'une arme de tier IV (`base_shop.gd:615/620`), arme de départ. Accrocher là ne laisse aucun angle mort — contrairement à un accrochage sur la seule fusion, qui oublierait le joueur qui **achète** sa bombe IV en fin de run.

Précédent vanilla : `run_data.gd:979` appelle déjà `ChallengeService.complete_challenge()` depuis ce même fichier. On ne fait rien d'exotique.

`RunData` est un autoload `.tscn` (`run_data.tscn`) : l'extension porte sur le `.gd`, comme d'habitude.

- [ ] **Étape 1 : créer l'extension**

`extensions/singletons/run_data.gd` :

```gdscript
extends "res://singletons/run_data.gd"
# Complète les défis de la chaîne des bombes quand une bombe de niveau IV entre
# dans l'inventaire du joueur.
#
# POURQUOI add_weapon : c'est l'entonnoir UNIQUE de toute acquisition d'arme —
# fusion en boutique (base_shop.gd:693), achat direct d'une arme de tier IV
# (base_shop.gd:615/620) ET arme de départ. La fusion est le chemin normal, mais le
# magasin propose aussi des armes de tier IV à l'acheter en fin de run : un défi
# accroché à la seule fusion laisserait ce joueur bloqué sans comprendre pourquoi.
#
# Le déblocage prend effet à la RUN SUIVANTE : on ne rappelle PAS init_unlocked_pool()
# à chaud. C'est le comportement de tous les déblocages du jeu (les pools sont
# reconstruits au démarrage de chaque run, run_data.gd:574).

const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")
const BombChallenges = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd")


func add_weapon(weapon: WeaponData, player_index: int, is_selection: bool = false) -> WeaponData:
	var new_weapon = .add_weapon(weapon, player_index, is_selection)
	_try_complete_bomb_challenge(new_weapon)
	return new_weapon


func _try_complete_bomb_challenge(weapon) -> void:
	if weapon == null:
		return

	var chal_id: String = BombChallenges.challenge_for(weapon.weapon_id, weapon.tier)
	if chal_id == "":
		return

	# Keys.generate_hash alimente aussi hash_to_string (keys.gd:450), dont dépend
	# SteamPlatform.complete_challenge : sans ça, un hash inconnu y planterait.
	var chal_hash: int = Keys.generate_hash(chal_id)
	if ChallengeService.is_challenge_completed(chal_hash):
		return

	# false = ne JAMAIS toucher aux succès de la plateforme. Un mod ne peut pas créer
	# de succès Steam (ils sont déclarés par l'éditeur) ; nos défis restent 100 % locaux.
	ChallengeService.complete_challenge(chal_hash, false)
	ModLog.info("défi complété: " + chal_id)
```

- [ ] **Étape 2 : déclarer l'extension**

Dans `mod_main.gd`, fonction `_install_extensions()`, ajouter :

```gdscript
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-Bomberman/extensions/singletons/run_data.gd")
```

- [ ] **Étape 3 : lancer les tests et le contrôle de compilation**

```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd 2>&1 | grep -aiE "parse error|compile error|run_data|=== [0-9]+ tests"
```

Attendu : `=== 138 tests, 0 échec(s) ===`, et **aucune** ligne `parse error` / `compile error`.

- [ ] **Étape 4 : commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/run_data.gd Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd
git commit -m "feat(bomberman): complète le défi à l'obtention d'une bombe de niveau IV"
```

---

### Task 5 : la migration des joueurs existants

**Fichiers :**
- Créer : `extensions/ui/menus/run/character_selection.gd`
- Modifier : `content/i18n/bomberman_translations.gd`
- Modifier : `mod_main.gd`

**Interfaces :**
- Consomme : `BombChallenges.unearned_bombs(...)`, `BombChallenges.REWARD`, `BombChallenges.MIGRATION_ASKED_ID` (Task 1).
- Produit : rien pour les tâches suivantes.

**Contexte indispensable :**

Les bombes étant `unlocked_by_default` jusqu'ici, elles sont **déjà inscrites dans la sauvegarde** de tous ceux qui ont lancé le mod. Passer le drapeau à `false` (Task 3) ne les leur retire pas : sans cette tâche, la chaîne ne se déclencherait jamais pour eux.

⚠️ **SOLO UNIQUEMENT.** En couch coop, un popup natif capte **n'importe quel device** : la manette d'un invité pourrait reverrouiller la progression de l'hôte. On ne pose donc jamais la question en coop.

⚠️ **On n'appelle PAS `ChallengeService.complete_challenge()`** pour la migration : il émet le signal `challenge_completed`, ce qui déclencherait le pop-up de fanfare « Défi accompli » (trois fois) sur l'écran de sélection. On écrit directement dans `ProgressData.challenges_completed`.

⚠️ ShopConfig étend **déjà** `character_selection.gd`. ModLoader empile les extensions d'un même script vanilla : appeler le parent avec `._ready()` préserve la chaîne.

Le composant `ConfirmationDialog` de Godot fournit nativement les deux boutons. Échapper (`ui_cancel`) ferme sans choisir : on ne marque alors PAS la question comme posée, et elle sera reposée au prochain lancement. C'est volontairement indulgent.

- [ ] **Étape 1 : ajouter les libellés bilingues**

Dans `content/i18n/bomberman_translations.gd` :

```gdscript
	tr_en.add_message("BOMB_MIGRATION_TITLE", "New — bombs must be earned")
	tr_en.add_message("BOMB_MIGRATION_TEXT", "The Ice, Storm and Poison Bombs are now unlocked by completing challenges: take a bomb to tier IV to earn the next one.\n\nYou already own them. Lock them again to play through the progression, or keep them?")
	tr_en.add_message("BOMB_MIGRATION_PROGRESS", "Play the progression")
	tr_en.add_message("BOMB_MIGRATION_KEEP", "Keep my bombs")
```

```gdscript
	tr_fr.add_message("BOMB_MIGRATION_TITLE", "Nouveauté — les bombes se méritent")
	tr_fr.add_message("BOMB_MIGRATION_TEXT", "Les bombes de Glace, de Foudre et de Poison se débloquent désormais en relevant des défis : montez une bombe au niveau IV pour gagner la suivante.\n\nVous les possédez déjà. Voulez-vous les reverrouiller pour vivre la progression, ou les conserver ?")
	tr_fr.add_message("BOMB_MIGRATION_PROGRESS", "Vivre la progression")
	tr_fr.add_message("BOMB_MIGRATION_KEEP", "Garder mes bombes")
```

- [ ] **Étape 2 : créer l'extension de l'écran de sélection**

`extensions/ui/menus/run/character_selection.gd` :

```gdscript
extends "res://ui/menus/run/character_selection.gd"
# Propose UNE FOIS aux joueurs qui possèdent déjà les bombes élémentaires de les
# reverrouiller pour vivre la chaîne de défis.
#
# ⚠️ SOLO UNIQUEMENT : le choix engage la sauvegarde du PROPRIÉTAIRE du jeu. En couch
# coop, un popup natif capte n'importe quel device (la leçon qui a fait retirer les
# OptionButton de ShopConfig) : la manette d'un invité pourrait reverrouiller la
# progression de l'hôte. On règle le problème par la géométrie, pas par la technique.
#
# ⚠️ ShopConfig étend DÉJÀ ce script. ModLoader empile les extensions : l'appel au
# parent (._ready()) préserve la chaîne.

const ModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")
const BombChallenges = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd")


func _ready() -> void:
	._ready()

	if RunData.is_coop_run:
		return
	if _migration_asked():
		return

	var pending: Array = _unearned_bombs()
	if pending.empty():
		return

	call_deferred("_show_migration_popup", pending)


# Les bombes possédées mais non gagnées (calcul pur dans BombChallenges).
func _unearned_bombs() -> Array:
	var unlocked := []
	var completed := []

	for chal_id in BombChallenges.REWARD:
		var weapon_id: String = BombChallenges.REWARD[chal_id]
		if ProgressData.weapons_unlocked.has(Keys.generate_hash(weapon_id)):
			unlocked.append(weapon_id)
		if ChallengeService.is_challenge_completed(Keys.generate_hash(chal_id)):
			completed.append(chal_id)

	return BombChallenges.unearned_bombs(unlocked, completed)


func _migration_asked() -> bool:
	return ProgressData.challenges_completed.has(
		Keys.generate_hash(BombChallenges.MIGRATION_ASKED_ID))


func _show_migration_popup(pending: Array) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.window_title = tr("BOMB_MIGRATION_TITLE")
	dialog.dialog_text = tr("BOMB_MIGRATION_TEXT")
	dialog.get_ok().text = tr("BOMB_MIGRATION_PROGRESS")
	dialog.get_cancel().text = tr("BOMB_MIGRATION_KEEP")

	# Échapper ferme sans choisir : la question sera reposée au prochain lancement.
	dialog.connect("confirmed", self, "_on_migration_relock", [pending])
	dialog.get_cancel().connect("pressed", self, "_on_migration_keep", [pending])

	add_child(dialog)
	dialog.popup_centered()


# « Vivre la progression » : on retire les bombes non gagnées de la sauvegarde.
func _on_migration_relock(pending: Array) -> void:
	for weapon_id in pending:
		ProgressData.weapons_unlocked.erase(Keys.generate_hash(weapon_id))
		ModLog.info("bombe reverrouillée: " + str(weapon_id))

	_mark_migration_asked()
	ProgressData.save()

	# Les pools sont reconstruits au démarrage de la run, mais on les rafraîchit tout
	# de suite : c'est ce que fait le jeu lui-même quand il active/désactive un DLC
	# (global/dlc_data.gd:102).
	ItemService.init_unlocked_pool()


# « Garder mes bombes » : on marque leurs défis comme complétés, pour que la
# progression reste cohérente (l'écran Progression les montre comme gagnés) et que
# la chaîne ne se redéclenche jamais pour ce joueur.
#
# ⚠️ On écrit DIRECTEMENT dans ProgressData plutôt que d'appeler
# ChallengeService.complete_challenge() : celui-ci émet le signal challenge_completed,
# qui déclencherait trois pop-ups « Défi accompli » sur l'écran de sélection.
func _on_migration_keep(pending: Array) -> void:
	for weapon_id in pending:
		for chal_id in BombChallenges.REWARD:
			if BombChallenges.REWARD[chal_id] != weapon_id:
				continue
			var chal_hash: int = Keys.generate_hash(chal_id)
			if not ProgressData.challenges_completed.has(chal_hash):
				ProgressData.challenges_completed.append(chal_hash)

	_mark_migration_asked()
	ProgressData.save()
	ModLog.info("migration: le joueur garde ses bombes")


func _mark_migration_asked() -> void:
	var asked_hash: int = Keys.generate_hash(BombChallenges.MIGRATION_ASKED_ID)
	if not ProgressData.challenges_completed.has(asked_hash):
		ProgressData.challenges_completed.append(asked_hash)
```

- [ ] **Étape 3 : déclarer l'extension**

Dans `mod_main.gd`, fonction `_install_extensions()`, ajouter :

```gdscript
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-Bomberman/extensions/ui/menus/run/character_selection.gd")
```

- [ ] **Étape 4 : lancer les tests et le contrôle de compilation**

```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd 2>&1 | grep -aiE "parse error|compile error|character_selection|=== [0-9]+ tests"
```

Attendu : `=== 138 tests, 0 échec(s) ===`, et **aucune** ligne `parse error` / `compile error`.

- [ ] **Étape 5 : commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/extensions/ui Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd Brotato/mods-unpacked/Tanith-Bomberman/mod_main.gd
git commit -m "feat(bomberman): propose la migration aux joueurs qui ont déjà les bombes"
```

---

### Task 6 : vérifications EN JEU (humain)

**Fichiers :** aucun.

**Interfaces :**
- Consomme : tout ce qui précède.
- Produit : le feu vert pour la release.

Rien de ce qui suit n'est vérifiable en headless : la suite de tests ne charge que la logique pure. **C'est ici que se joue la fonctionnalité.**

- [ ] **Étape 1 : le verrouillage tient (LE point fragile)**

Sur une sauvegarde **neuve** (ou après « Vivre la progression »), lancer une run avec Bomberto :

- l'écran de **choix d'arme de départ** ne propose **ni** Glace, **ni** Foudre, **ni** Poison — seulement la Bombe normale (forcée) et les armes de tier 0 du roster ;
- aucune de ces trois bombes n'apparaît **en boutique**, sur toute une run.

⚠️ Si elles apparaissent, c'est que le replay de `ProgressData.add_unlocked_by_default()` (extension `item_service.gd:102`) ne respecte pas le drapeau `unlocked_by_default`. Toute la fonctionnalité est alors sans effet : il faudra filtrer nos trois bombes avant le replay.

- [ ] **Étape 2 : la chaîne se déclenche**

- Monter une Bombe normale au **niveau IV** (fusionner deux III) → le pop-up « Défi accompli » s'affiche, et l'écran de fin de run montre la récompense.
- Lancer une **nouvelle run** → la Bombe de Glace est proposée au choix d'arme de départ et apparaît en boutique.
- Répéter avec la Glace IV → Foudre, puis la Foudre IV → Poison.
- L'écran **Progression** liste les trois défis, avec leur nom et leur description dans la bonne langue.

- [ ] **Étape 3 : le chemin sans fusion**

Acheter directement une **bombe de tier IV** en boutique de fin de run (sans jamais fusionner) → le défi se complète aussi.

- [ ] **Étape 4 : la migration**

Sur une sauvegarde qui possède **déjà** les trois bombes (ta sauvegarde actuelle) :

- le popup s'affiche à la sélection de personnage, **en solo** ;
- il ne s'affiche **jamais** en coop ;
- « Garder mes bombes » → les trois bombes restent disponibles, les trois défis apparaissent comme complétés dans l'écran Progression, et le popup **ne revient plus** ;
- « Vivre la progression » → les trois bombes disparaissent de la boutique et du choix d'arme de départ dès la run suivante, et le popup **ne revient plus** ;
- Échapper sans choisir → le popup **revient** au prochain lancement ;
- sur une sauvegarde neuve, le popup **ne s'affiche jamais**.

- [ ] **Étape 5 : non-régression**

- Aucune erreur `setAchievement` ni plantage au démarrage (`_sync_platform_challenges` boucle sur nos défis).
- Les succès Steam de Brotato continuent de se débloquer normalement.
- L'écran de sélection de personnage fonctionne toujours avec **ShopConfig actif** (les deux mods étendent `character_selection.gd`).
- La coop fonctionne toujours (aucun popup, chaîne opérante).

---

## Après le plan

Une fois la Task 6 validée : release (bump du manifeste, changelog FR/EN, `tools/build-bomberman.ps1`, upload Workshop **manuel** sur l'item `3752197886`).

⚠️ **Avant le build** : retirer les `.png.import` régénérés par le test-runner (`bombe_normale`, `glace`, `poison`, `storm`), sans quoi `build-bomberman.ps1` réclame des `.stex` d'éditeur et échoue.

⚠️ Mentionner dans la description Workshop que le mod **écrit dans la sauvegarde permanente** (les défis complétés). C'est le premier mod du dépôt à le faire.
