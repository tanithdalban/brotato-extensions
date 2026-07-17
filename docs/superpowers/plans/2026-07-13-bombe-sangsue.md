# Bombe sangsue — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter au mod Bomberman une 5ᵉ bombe, la **Bombe sangsue** (`weapon_bomb_leech`), qui n'inflige aucun dégât d'explosion mais **draine** les ennemis touchés : chaque proc de vol de vie retire N PV à l'ennemi et rend les mêmes N PV au joueur, dans la limite d'un plafond par explosion.

**Architecture:** La logique décidable (tirage, montant, plafond) vit dans un nouveau module **pur** `content/logic/bomb_leech.gd`, testable en headless. Le câblage runtime réutilise **à l'identique** le patron déjà validé de la Bombe de Glace : `bomb_entity` connecte le signal `hit_something` de l'explosion vanilla à une méthode de `bomb_weapon` (l'arme persistante), qui applique l'effet par ennemi touché en **duck-typing** — donc **aucune extension de `enemy.gd`, `unit.gd`, `player.gd` ni du vol de vie vanilla**.

**Tech Stack:** GDScript (Godot 3.6/3.7), ModLoader (script extensions), ressources `.tres`, runner de tests GDScript maison.

**Spec de référence :** `docs/superpowers/specs/2026-07-13-bombe-sangsue-design.md`

## Global Constraints

- **Langue** : tout le code, les commentaires, les docs et les libellés de commit sont en **français**. Les libellés UI sont **bilingues FR/EN** (deux `Translation` dans `bomberman_translations.gd`).
- **Runner de tests Bomberman** (⚠️ **PAS** `./run-tests.sh`, qui lance ceux de ShopConfig) — depuis la racine du repo, en Git Bash :
  ```
  "./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
  ```
  Résultat attendu : la ligne `=== N tests, 0 échec(s) ===`. Les erreurs moteur affichées **après** cette ligne sont le teardown des autoloads : sans effet.
- **⚠️ CONTRÔLE OBLIGATOIRE après toute modif de `bomb_weapon.gd`** : le runner ne charge **jamais** ce fichier, donc les tests ne prouvent pas qu'il compile. Après chaque modif, la sortie du runner passée au filtre `grep -iE "parse error|compile error|bomb_weapon"` **doit être vide**.
- **Vol de vie effectif** : ne **jamais** recalculer `base + stat joueur`. `current_stats.lifesteal` de l'arme tenue le porte déjà (`weapon_service.gd:260`, branche `not is_structure`).
- **Invariant du drain** : le nombre de PV **retirés à l'ennemi** est **toujours égal** au nombre de PV **rendus au joueur**.
- **Plafond compté en PV** (pas en procs), et **N est toujours écrêté par le budget restant**.
- Valeurs de la spec, à respecter exactement :

  | Tier (index) | Vol de vie de base | Plafond PV / explosion |
  |---|---|---|
  | I (0) | 0.40 | 3 |
  | II (1) | 0.50 | 4 |
  | III (2) | 0.55 | 5 |
  | IV (3) | 0.65 | 6 |

---

## File Structure

**Créés :**
- `content/logic/bomb_leech.gd` — logique **pure** du drain : tirage, montant par proc, budget d'explosion (avec la classe interne `Budget`). Zéro dépendance jeu.
- `content/weapons/bomb/bomb_leech_{1..4}_stats.tres` — stats des 4 tiers (dont `lifesteal`).
- `content/weapons/bomb/bomb_leech_{1..4}_data.tres` — données d'arme des 4 tiers (nom, tier, valeur, `weapon_id`, chaîne d'upgrades, ligne d'infobulle).
- `content/challenges/chal_bomb_leech_data.tres` — le défi de déblocage, récompense = `bomb_leech_1_data.tres`.
- `content/weapons/bomb/sangsue.png` — sprite de la bombe (**asset humain**, cf. Tâche 6).

**Modifiés :**
- `content/logic/bomb_element.gd` — constante `LEECH` + entrée `_BY_WEAPON_ID`.
- `content/logic/bomb_skin.gd` — entrée `"leech"` dans `_SPRITE_PATHS`.
- `content/logic/bomb_challenges.gd` — `LEECH_REQUIRED`, `unlocks_leech()`, entrée dans `REWARD`.
- `content/entities/bomb_entity.gd` — connexion du drain à l'explosion (budget frais par explosion).
- `content/weapons/bomb/bomb_weapon.gd` — `on_leech_hit()`.
- `extensions/singletons/run_data.gd` — complète `chal_bomb_leech` quand les 4 bombes sont en inventaire.
- `extensions/singletons/item_service.gd` — enregistre les 4 armes.
- `extensions/singletons/challenge_service.gd` — enregistre le défi.
- `content/i18n/bomberman_translations.gd` — clés FR/EN.
- `test/run_tests.gd` — nouveaux tests.

**Non modifiés (et c'est volontaire) :** `content/logic/shop_pool.gd` — `is_allowed()` accepte déjà tout `weapon_id` commençant par `weapon_bomb` (préfixe), donc la sangsue entre au pool de boutique **sans une ligne de code**.

---

### Task 1: Logique pure du drain (`bomb_leech.gd`)

Le cœur décidable, isolé et testable en headless. Aucune autre tâche ne peut être revue sans lui.

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_leech.gd`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Consumes: rien.
- Produces (utilisé par les Tâches 3 et 4) :
  - `const CAP_BY_TIER := [3, 4, 5, 6]`
  - `static func cap_for_tier(tier: int) -> int`
  - `static func procs(roll: float, lifesteal: float) -> bool`
  - `static func proc_amount(has_double_bonus: bool) -> int` → `1` ou `2`
  - `static func granted(amount: int, remaining: int) -> int` → écrêtage
  - `static func new_budget(tier: int) -> Array` → budget d'une explosion
  - `static func remaining(budget: Array) -> int`
  - `static func take(budget: Array, amount: int) -> int` (rend le montant réellement accordé **et** décrémente le budget)

⚠️ **Le budget est un `Array` à un élément**, pas une classe. En GDScript, un `Array` est passé **par référence** : c'est ce qui permet à tous les ennemis d'une même explosion de partager le même compteur, tout en gardant le module **100 % statique** (donc trivialement testable). Une classe interne aurait dû appeler les fonctions statiques de son script hôte, ce qui oblige le script à se `preload` lui-même — un motif qui déclenche des erreurs de **référence cyclique** en Godot 3. On l'évite.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter le `preload` en tête de fichier, à la suite des autres :

```gdscript
const BombLeech = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_leech.gd")
```

Ajouter l'appel dans `_init()`, juste après `_test_bomb_challenges()` :

```gdscript
	_test_bomb_leech()
```

Ajouter la fonction de test en fin de fichier, avant `func _check(cond, name):` :

```gdscript
func _test_bomb_leech() -> void:
	# ⚠️ Signature du helper existant : _check(cond, name) — la CONDITION d'abord.

	# --- cap_for_tier : le plafond de PV par explosion, par tier (spec) ---
	_check(BombLeech.cap_for_tier(0) == 3, "sangsue: plafond T1 = 3 PV")
	_check(BombLeech.cap_for_tier(1) == 4, "sangsue: plafond T2 = 4 PV")
	_check(BombLeech.cap_for_tier(2) == 5, "sangsue: plafond T3 = 5 PV")
	_check(BombLeech.cap_for_tier(3) == 6, "sangsue: plafond T4 = 6 PV")
	# Garde-fous : tier hors bornes => clampé (pas de crash, pas d'index négatif).
	_check(BombLeech.cap_for_tier(-5) == 3, "sangsue: tier négatif => clamp T1")
	_check(BombLeech.cap_for_tier(99) == 6, "sangsue: tier trop grand => clamp T4")

	# --- procs : tirage, dé INJECTÉ (déterminisme, pas de randf() dans le pur) ---
	_check(BombLeech.procs(0.0, 0.4) == true, "sangsue: dé 0.0 < 40% => proc")
	_check(BombLeech.procs(0.39, 0.4) == true, "sangsue: dé 0.39 < 40% => proc")
	_check(BombLeech.procs(0.4, 0.4) == false, "sangsue: dé 0.4 pas < 40% => pas de proc")
	_check(BombLeech.procs(0.9, 0.4) == false, "sangsue: dé 0.9 => pas de proc")
	_check(BombLeech.procs(0.5, 0.0) == false, "sangsue: 0% de vol de vie => jamais")
	_check(BombLeech.procs(0.99, 1.0) == true, "sangsue: 100% de vol de vie => toujours")
	# Au-delà de 100 % (stat joueur très haute) : toujours, jamais d'erreur.
	_check(BombLeech.procs(0.99, 2.5) == true, "sangsue: vol de vie > 100% => toujours")

	# --- proc_amount : 1 PV, 2 avec l'item double vol de vie (aligné vanilla) ---
	_check(BombLeech.proc_amount(false) == 1, "sangsue: proc normal = 1 PV")
	_check(BombLeech.proc_amount(true) == 2, "sangsue: proc avec bonus double = 2 PV")

	# --- granted : écrêtage au budget restant ---
	_check(BombLeech.granted(1, 3) == 1, "sangsue: 1 PV demandé sur 3 restants => 1")
	_check(BombLeech.granted(2, 3) == 2, "sangsue: 2 PV demandés sur 3 restants => 2")
	# LE cas de la spec : un proc « double » ne perce pas le plafond.
	_check(BombLeech.granted(2, 1) == 1, "sangsue: proc double sur 1 PV restant => écrêté à 1")
	_check(BombLeech.granted(2, 0) == 0, "sangsue: budget épuisé => 0")
	_check(BombLeech.granted(1, -1) == 0, "sangsue: restant négatif => 0 (pas de soin fantôme)")
	_check(BombLeech.granted(-3, 5) == 0, "sangsue: montant négatif => 0")

	# --- Budget : l'état mutable partagé par les ennemis d'UNE explosion ---
	# (Array à un élément : passé par référence, donc partagé sans classe.)
	var b = BombLeech.new_budget(0)  # T1 => 3 PV
	_check(BombLeech.remaining(b) == 3, "sangsue: budget T1 démarre à 3")
	_check(BombLeech.take(b, 1) == 1, "sangsue: 1er proc accordé (1 PV)")
	_check(BombLeech.remaining(b) == 2, "sangsue: budget décrémenté à 2")
	_check(BombLeech.take(b, 2) == 2, "sangsue: proc double accordé (2 PV)")
	_check(BombLeech.remaining(b) == 0, "sangsue: budget épuisé")
	# Plafond JAMAIS dépassé : les ennemis suivants du même souffle ne drainent plus.
	_check(BombLeech.take(b, 1) == 0, "sangsue: budget épuisé => plus aucun drain")
	_check(BombLeech.remaining(b) == 0, "sangsue: budget ne devient jamais négatif")

	# Le partage par RÉFÉRENCE est ce qui fait tenir le plafond entre deux ennemis du
	# même souffle : si le budget était copié, chacun aurait le sien et le plafond
	# ne vaudrait plus rien. Test explicite de cette propriété.
	var shared = BombLeech.new_budget(0)  # T1 => 3 PV
	var alias = shared
	var _g = BombLeech.take(alias, 3)
	_check(BombLeech.remaining(shared) == 0, "sangsue: budget partagé par référence (pas copié)")

	# Le plafond tient face à une horde : 20 ennemis, tous procs => jamais plus que le cap.
	var b2 = BombLeech.new_budget(3)  # T4 => 6 PV
	var total := 0
	for _i in range(20):
		total += BombLeech.take(b2, 1)
	_check(total == 6, "sangsue: 20 ennemis, tous procs => exactement le plafond T4 (6 PV)")

	# Le bonus double atteint le plafond avec MOINS d'ennemis, mais ne le perce pas.
	var b3 = BombLeech.new_budget(3)  # T4 => 6 PV
	var total3 := 0
	for _i in range(20):
		total3 += BombLeech.take(b3, 2)
	_check(total3 == 6, "sangsue: bonus double => même plafond (6 PV), atteint plus vite")

	# Garde-fous : un budget malformé ne draine rien et ne plante pas.
	_check(BombLeech.take([], 1) == 0, "sangsue: budget vide => 0 (pas de crash)")
	_check(BombLeech.remaining([]) == 0, "sangsue: remaining d'un budget vide => 0")
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run (depuis la racine du repo, Git Bash) :
```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: ÉCHEC — le runner ne compile pas, erreur de type « Could not resolve... bomb_leech.gd » (le fichier n'existe pas encore).

- [ ] **Step 3: Écrire l'implémentation minimale**

Créer `content/logic/bomb_leech.gd` :

```gdscript
extends Reference
# Logique PURE de la Bombe sangsue (drain).
# Aucune dépendance aux autoloads du jeu -> testable en headless.
#
# Le drain : à l'explosion, chaque ennemi touché tire sur le vol de vie de l'arme.
# En cas de proc, on lui RETIRE N PV et on en REND N au joueur (invariant : les deux
# montants sont toujours égaux). Un budget de PV par explosion borne le total.
#
# POURQUOI un budget : une explosion touche tous ses ennemis dans la MÊME frame.
# Sans plafond, une bombe lâchée dans une horde de fin de vague rendrait la barre
# entière. Le budget est donc la manette d'équilibrage principale de cette arme.
#
# Le budget est compté en PV, pas en procs : l'item « double vol de vie » atteint
# donc le plafond avec moins d'ennemis, mais ne le perce jamais.

# Plafond de PV volés par explosion, indexé par tier (0 = I ... 3 = IV).
const CAP_BY_TIER := [3, 4, 5, 6]


# Plafond du tier, borné (un tier hors bornes ne doit jamais indexer hors tableau).
static func cap_for_tier(tier: int) -> int:
	var i := int(clamp(tier, 0, CAP_BY_TIER.size() - 1))
	return CAP_BY_TIER[i]


# Le tirage. `roll` est INJECTÉ (randf() reste chez l'appelant) : c'est ce qui rend
# cette fonction déterministe, donc testable.
static func procs(roll: float, lifesteal: float) -> bool:
	return roll < lifesteal


# PV volés par proc : 1, ou 2 avec l'effet joueur `double_lifesteal_bonus`.
# Aligné sur le vanilla, où AUCUNE arme ne rend jamais plus d'1 PV par proc.
static func proc_amount(has_double_bonus: bool) -> int:
	return 2 if has_double_bonus else 1


# Écrêtage au budget restant. Un proc « double » sur 1 PV restant ne draine que 1.
static func granted(amount: int, remaining: int) -> int:
	if amount <= 0 or remaining <= 0:
		return 0
	return int(min(amount, remaining))


# --- Budget d'UNE explosion ---
#
# C'est un Array à UN élément : [pv_restants]. En GDScript, un Array est passé par
# RÉFÉRENCE — c'est ce qui permet à tous les ennemis d'un même souffle de partager le
# même compteur. Instancié à l'explosion et passé en bind à la connexion du signal
# `hit_something`, il donne à chaque explosion son propre budget.
#
# POURQUOI pas une classe : une classe interne devrait appeler les fonctions statiques
# de son script hôte, ce qui oblige le script à se preload lui-même -> référence
# cyclique en Godot 3. L'Array garde le module 100 % statique, donc trivialement testable.

static func new_budget(tier: int) -> Array:
	return [cap_for_tier(tier)]


static func remaining(budget: Array) -> int:
	if budget == null or budget.empty():
		return 0
	return int(budget[0])


# Accorde jusqu'à `amount` PV, décrémente le budget, et rend le montant RÉELLEMENT
# accordé (0 si le budget est épuisé ou malformé).
static func take(budget: Array, amount: int) -> int:
	var left := remaining(budget)
	var given := granted(amount, left)
	if given > 0:
		budget[0] = left - given
	return given
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run :
```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: la ligne `=== N tests, 0 échec(s) ===`, avec un total **supérieur** à celui d'avant la tâche (tous les `_check` de `_test_bomb_leech` sont comptés) et **zéro** échec.

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_leech.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): logique pure du drain de la bombe sangsue"
```

---

### Task 2: Déblocage — les 4 bombes en inventaire

Le défi `chal_bomb_leech` se complète quand un joueur détient **simultanément** les 4 bombes, **quel que soit leur tier**. Ce n'est **pas** un maillon de `CHAIN` (qui, lui, est indexé « arme X au tier IV »).

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/run_data.gd`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Consumes: rien (indépendant de la Tâche 1).
- Produces (utilisé par l'extension `run_data`) :
  - `const LEECH_REQUIRED := ["weapon_bomb", "weapon_bomb_ice", "weapon_bomb_poison", "weapon_bomb_storm"]`
  - `const LEECH_CHALLENGE := "chal_bomb_leech"`
  - `static func unlocks_leech(weapon_ids: Array) -> bool`

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, à la **fin** de la fonction `_test_bomb_challenges()` existante, ajouter :

```gdscript
	# --- Bombe sangsue : débloquée par la COLLECTION, pas par un tier IV. ---
	# Le poison reste la fin de CHAIN : sa montée en tier IV ne débloque toujours rien.
	_check(BombChallenges.challenge_for("weapon_bomb_poison", 3) == "",
		"sangsue: Poison IV ne complète toujours rien (la sangsue n'est pas dans CHAIN)")

	# Les 4 bombes en inventaire, tous tiers confondus => défi complété.
	_check(BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb_ice", "weapon_bomb_storm", "weapon_bomb_poison"]),
		"sangsue: les 4 bombes => déblocage")
	# L'ordre ne compte pas.
	_check(BombChallenges.unlocks_leech(
			["weapon_bomb_poison", "weapon_bomb", "weapon_bomb_storm", "weapon_bomb_ice"]),
		"sangsue: ordre indifférent")
	# Une arme étrangère en plus ne gêne pas (inventaire réel : 6 slots).
	_check(BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb_ice", "weapon_bomb_storm", "weapon_bomb_poison", "weapon_pistol"]),
		"sangsue: armes étrangères en plus => déblocage quand même")

	# 3 bombes seulement => pas de déblocage.
	_check(not BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb_ice", "weapon_bomb_storm"]),
		"sangsue: 3 bombes sur 4 => pas de déblocage")
	# ⚠️ Le piège : des DOUBLONS ne remplacent pas une bombe manquante.
	_check(not BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb", "weapon_bomb", "weapon_bomb"]),
		"sangsue: 4x la même bombe => PAS de déblocage")
	_check(not BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb_ice", "weapon_bomb_ice", "weapon_bomb_storm"]),
		"sangsue: doublon de glace au lieu du poison => pas de déblocage")
	_check(not BombChallenges.unlocks_leech([]),
		"sangsue: inventaire vide => pas de déblocage")

	# La sangsue est une récompense connue (le popup de migration itère sur REWARD).
	_check(BombChallenges.REWARD.has("chal_bomb_leech"),
		"sangsue: chal_bomb_leech est dans REWARD (couvert par la migration)")
	_check(BombChallenges.REWARD["chal_bomb_leech"] == "weapon_bomb_leech",
		"sangsue: chal_bomb_leech récompense weapon_bomb_leech")
	_check(BombChallenges.unearned_bombs(["weapon_bomb_leech"], []) == ["weapon_bomb_leech"],
		"migration: sangsue possédée et non gagnée => à proposer")
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run :
```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: ÉCHEC — erreur d'appel « Invalid call ... 'unlocks_leech' » (la fonction n'existe pas).

- [ ] **Step 3: Écrire l'implémentation**

Dans `content/logic/bomb_challenges.gd`, remplacer le bloc de commentaire de tête :

```gdscript
# La chaîne : monter une bombe au niveau IV débloque la bombe suivante.
#   Bombe IV -> Glace, Glace IV -> Foudre, Foudre IV -> Poison.
# Le Poison est la fin de la chaîne : il ne débloque rien.
```

par :

```gdscript
# Deux mécanismes de déblocage, distincts :
#
# 1. La CHAÎNE (CHAIN) : monter une bombe au niveau IV débloque la suivante.
#      Bombe IV -> Glace, Glace IV -> Foudre, Foudre IV -> Poison.
#    Le Poison est la fin de la chaîne : il ne débloque rien.
#
# 2. La COLLECTION (unlocks_leech) : détenir les 4 bombes EN MÊME TEMPS, quels que
#    soient leurs tiers, débloque la Bombe sangsue. Ça immobilise 4 des 6 slots
#    d'arme : c'est un sacrifice de build délibéré, et c'est tout l'intérêt du défi.
#
# ⚠️ La sangsue n'est donc PAS dans CHAIN (qui est indexé « arme X au tier IV »), mais
# elle EST dans REWARD, ce qui suffit à ce que le popup de migration la couvre.
```

Puis ajouter, après la constante `REWARD` :

```gdscript
# --- Bombe sangsue : déblocage par la COLLECTION (pas par un tier IV). ---

# Les 4 bombes à détenir SIMULTANÉMENT (tier indifférent).
const LEECH_REQUIRED := [
	"weapon_bomb",
	"weapon_bomb_ice",
	"weapon_bomb_poison",
	"weapon_bomb_storm",
]

const LEECH_CHALLENGE := "chal_bomb_leech"


# Vrai si l'inventaire (liste de weapon_id, doublons tolérés) contient les 4 bombes.
# ⚠️ Des doublons ne remplacent JAMAIS une bombe manquante : on vérifie la présence
# de CHACUNE des 4, pas un simple compte.
static func unlocks_leech(weapon_ids: Array) -> bool:
	for required in LEECH_REQUIRED:
		if not weapon_ids.has(required):
			return false
	return true
```

Enfin, ajouter l'entrée dans `REWARD` (la sangsue est une récompense, donc couverte par `unearned_bombs`) :

```gdscript
const REWARD := {
	"chal_bomb_ice": "weapon_bomb_ice",
	"chal_bomb_storm": "weapon_bomb_storm",
	"chal_bomb_poison": "weapon_bomb_poison",
	"chal_bomb_leech": "weapon_bomb_leech",
}
```

⚠️ Le test de cohérence existant (« chaque défi de la chaîne a une récompense ») itère `CHAIN` → `REWARD` : ajouter une entrée à `REWARD` sans l'ajouter à `CHAIN` le laisse **vert**. C'est intentionnel.

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run :
```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===`.

- [ ] **Step 5: Brancher le déblocage sur l'acquisition d'arme**

Dans `extensions/singletons/run_data.gd`, remplacer entièrement la fonction `_try_complete_bomb_challenge` et ajouter deux helpers. Le fichier devient :

```gdscript
func add_weapon(weapon: WeaponData, player_index: int, is_selection: bool = false) -> WeaponData:
	var new_weapon = .add_weapon(weapon, player_index, is_selection)
	_try_complete_bomb_challenge(new_weapon)
	_try_complete_leech_challenge(player_index)
	return new_weapon


func _try_complete_bomb_challenge(weapon) -> void:
	if weapon == null:
		return

	var chal_id: String = BombChallenges.challenge_for(weapon.weapon_id, weapon.tier)
	if chal_id == "":
		return

	_complete(chal_id)


# Bombe sangsue : débloquée par la COLLECTION (les 4 bombes en inventaire en même
# temps, tier indifférent), pas par un tier IV. On relit l'inventaire du joueur
# APRÈS l'ajout de l'arme — add_weapon est l'entonnoir unique de toute acquisition.
func _try_complete_leech_challenge(player_index: int) -> void:
	if player_index < 0 or player_index >= players_data.size():
		return

	var weapon_ids := []
	for w in players_data[player_index].weapons:
		if w != null:
			weapon_ids.append(w.weapon_id)

	if not BombChallenges.unlocks_leech(weapon_ids):
		return

	_complete(BombChallenges.LEECH_CHALLENGE)


func _complete(chal_id: String) -> void:
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

Mettre aussi à jour le bloc de commentaire de tête du fichier, qui ne parle que de la chaîne :

```gdscript
extends "res://singletons/run_data.gd"
# Complète les défis des bombes à l'acquisition d'une arme. Deux mécanismes :
#   - la CHAÎNE : une bombe de niveau IV entre dans l'inventaire -> débloque la suivante ;
#   - la COLLECTION : les 4 bombes sont détenues EN MÊME TEMPS -> débloque la sangsue.
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
```

- [ ] **Step 6: Relancer les tests (non-régression)**

Run :
```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===`, et **aucune** « parse error » mentionnant `run_data.gd`.

- [ ] **Step 7: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/run_data.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): débloque la bombe sangsue en détenant les 4 bombes"
```

---

### Task 3: Élément LEECH et skin

Enregistre l'élément dans les deux tables qui pilotent le comportement (`bomb_element`) et le visuel (`bomb_skin`). `is_effect()` en découle automatiquement (« tout ce qui n'est pas normal »), ce qui donne gratuitement **0 dégât d'explosion AoE** et **jamais de troll bombe**.

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Consumes: rien.
- Produces (utilisé par les Tâches 4 et 5) : `BombElement.LEECH == "leech"`, et `BombSkin.element_sprite_path("leech")` → `.../sangsue.png`.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, à la fin de `_test_bomb_element()` :

```gdscript
	_check(BombElement.from_weapon_id("weapon_bomb_leech") == BombElement.LEECH, "element: weapon_bomb_leech => leech")
	_check(BombElement.is_effect(BombElement.LEECH), "element: leech est un effet (0 dégât AoE, pas de troll)")
```

Et à la fin de `_test_bomb_skin_element()` :

```gdscript
	_check(BombSkin.element_sprite_path("leech").ends_with("sangsue.png"), "skin: leech -> sangsue.png")
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run :
```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: ÉCHEC sur `element: weapon_bomb_leech => leech` et `skin: leech -> sangsue.png` (ces deux-là au moins ; `BombElement.LEECH` n'existant pas, le script peut aussi refuser de compiler — c'est un échec valide).

- [ ] **Step 3: Écrire l'implémentation**

Dans `content/logic/bomb_element.gd`, ajouter la constante et l'entrée :

```gdscript
const NORMAL := "normal"
const ICE := "ice"
const POISON := "poison"
const STORM := "storm"
const LEECH := "leech"

const _BY_WEAPON_ID := {
	"weapon_bomb_ice": ICE,
	"weapon_bomb_poison": POISON,
	"weapon_bomb_storm": STORM,
	"weapon_bomb_leech": LEECH,
}
```

Mettre à jour le commentaire de tête du même fichier :

```gdscript
# Élément d'une bombe, déduit du weapon_id partagé par ses 4 tiers.
# Pilote le sous-comportement à l'explosion (normal = dégâts+brûlure+troll ;
# glace/poison/foudre/sangsue = "bombes à effet" : 0 dégât AoE, jamais de trollbombe).
```

Dans `content/logic/bomb_skin.gd`, ajouter l'entrée dans `_SPRITE_PATHS` :

```gdscript
# Clés = valeurs de BombElement (normal/ice/storm/poison/leech).
const _SPRITE_PATHS := {
	"normal": _BOMB_DIR + "/bombe_normale.png",
	"ice": _BOMB_DIR + "/glace.png",
	"storm": _BOMB_DIR + "/storm.png",
	"poison": _BOMB_DIR + "/poison.png",
	"leech": _BOMB_DIR + "/sangsue.png",
}
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run :
```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===`.

Note : le test porte sur le **chemin**, pas sur le chargement du PNG — il passe donc même si `sangsue.png` n'existe pas encore (l'asset arrive en Tâche 6). En jeu, un PNG manquant fait rendre `null` à `build_world_texture`, et la bombe garde le sprite par défaut de sa scène : dégradation propre, pas de crash.

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): déclare l'élément sangsue (comportement + skin)"
```

---

### Task 4: Câblage runtime du drain

Branche la logique pure sur le jeu, en copiant **exactement** le patron de la Bombe de Glace (déjà validé en jeu) : `bomb_entity` connecte `hit_something` de l'explosion vers l'arme persistante, qui applique l'effet par ennemi.

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd`

**Interfaces:**
- Consumes: `BombLeech.new_budget(tier) -> Budget` et `Budget.take(amount) -> int` (Tâche 1) ; `BombElement.LEECH` (Tâche 3).
- Produces: `BombWeapon.on_leech_hit(thing_hit, _damage_dealt, budget) -> void` — la cible du signal `hit_something`.

**⚠️ Rappel de la contrainte globale** : le runner ne charge **jamais** `bomb_weapon.gd`. Les tests ne prouveront **pas** que cette tâche compile — le contrôle `grep` de l'étape 4 est le seul filet.

- [ ] **Step 1: Ajouter `on_leech_hit` à l'arme**

Dans `content/weapons/bomb/bomb_weapon.gd`, ajouter le `preload` en tête, à la suite des autres constantes :

```gdscript
const BombLeech = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_leech.gd")
```

Puis ajouter la méthode **juste après** `on_ice_hit` (dont elle est le jumeau) :

```gdscript
# Cible du signal hit_something de l'explosion d'une bombe SANGSUE (connecté par
# bomb_entity, avec un budget FRAIS par explosion). Draine l'ennemi touché : on lui
# RETIRE N PV et on en REND N au joueur (invariant : les deux montants sont égaux).
# Duck-typé : ne touche que des unités ayant current_stats + take_damage (marche
# vanilla/DLC/autre mod, sans étendre enemy.gd).
#
# POURQUOI notre propre soin, et pas RunData.manage_life_steal : le vol de vie vanilla
# est gardé par le LifestealTimer du joueur (0,1 s, player.gd:734), qui JETTE tout proc
# arrivant pendant qu'il tourne. Or une explosion touche tous ses ennemis dans la MÊME
# frame : passer par le vanilla rendrait 1 PV par explosion, quel que soit le nombre
# d'ennemis. On ne contourne ce timer que sur NOTRE chemin ; il reste intact pour toutes
# les autres armes.
func on_leech_hit(thing_hit, _damage_dealt, budget: Array) -> void:
	if BombLeech.remaining(budget) <= 0:
		return
	if not is_instance_valid(thing_hit):
		return
	if not ("current_stats" in thing_hit) or thing_hit.current_stats == null:
		return
	if not thing_hit.has_method("take_damage"):
		return
	if current_stats == null:
		return

	# current_stats.lifesteal porte DÉJÀ « base de l'arme + stat du joueur / 100 »
	# (weapon_service.gd:260, branche not is_structure). Ne rien recalculer.
	if not BombLeech.procs(randf(), current_stats.lifesteal):
		return

	var amount: int = BombLeech.take(budget, BombLeech.proc_amount(_has_double_lifesteal()))
	if amount <= 0:
		return

	# Le drain, retiré à l'ennemi : armor_applied = false -> l'armure ne le mange pas
	# (unit.gd:502) ; hitbox = null -> ni crit ni recul. Un drain sec.
	var args := TakeDamageArgs.new(player_index, null)
	args.armor_applied = false
	args.dodgeable = false
	var _dmg = thing_hit.take_damage(amount, args)

	# ... et rendu au joueur, à l'identique. on_healing_effect clampe aux PV max.
	if is_instance_valid(_parent) and _parent.has_method("on_healing_effect"):
		var _healed = _parent.on_healing_effect(amount)


# L'item « double vol de vie » fait passer les procs à 2 PV (cf. run_data.gd:1378).
func _has_double_lifesteal() -> bool:
	var effects = RunData.get_player_effects(player_index)
	if not effects.has(Keys.stat_double_lifesteal_bonus_hash):
		return false
	return RunData.get_player_effect_bool(Keys.stat_double_lifesteal_bonus_hash, player_index)
```

- [ ] **Step 2: Connecter le drain à l'explosion**

Dans `content/entities/bomb_entity.gd`, ajouter le `preload` en tête, à la suite des autres :

```gdscript
const BombLeech = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_leech.gd")
```

Puis, dans `_on_fuse_timeout()`, **juste après** le bloc `if _element == BombElement.ICE and ...` (et avant le `queue_free()` final), ajouter :

```gdscript
	# Sangsue : draine les ennemis touchés, via le même signal public hit_something de
	# l'explosion que la glace (émis même à 0 dégât, unit.gd:608) -> notre BombWeapon
	# (persistant). Le budget est instancié ICI : chaque explosion a donc le sien, et le
	# plafond de PV vaut par explosion. La connexion est nettoyée par
	# PlayerExplosion.end_explosion (disconnect_all hit_something).
	if _element == BombElement.LEECH and _inst != null and is_instance_valid(_weapon):
		var budget := BombLeech.new_budget(_tier)
		if not _inst.is_connected("hit_something", _weapon, "on_leech_hit"):
			_inst.connect("hit_something", _weapon, "on_leech_hit", [budget])
```

⚠️ Le budget est **lui-même un `Array`**, et le 3ᵉ argument de `connect()` est la **liste des binds**. Il faut donc bien `[budget]` (une liste contenant le budget), et **surtout pas** `budget` : passer le budget nu ferait de son unique élément — l'entier des PV restants — le bind, et `on_leech_hit` recevrait un `int` au lieu du compteur partagé.

Aucune autre modification n'est nécessaire dans ce fichier : `BombElement.is_effect(LEECH)` est déjà vrai (Tâche 3), donc les deux gardes existantes s'appliquent **automatiquement** — `_explode_args.damage = 0` (aucun dégât AoE) et `_will_wake = false` (jamais de troll bombe).

- [ ] **Step 3: Lancer les tests (non-régression)**

Run :
```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===` (inchangé — cette tâche n'ajoute aucun test : elle est 100 % runtime).

- [ ] **Step 4: ⚠️ CONTRÔLE OBLIGATOIRE de compilation**

Le runner ne charge pas `bomb_weapon.gd` : ce filtre est le **seul** garde-fou contre une faute de frappe qui casserait l'arme en jeu.

Run :
```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd 2>&1 | grep -iE "parse error|compile error|bomb_weapon|bomb_entity|bomb_leech"
```
Expected: **sortie VIDE**. La moindre ligne ici est un échec : corriger avant de commiter.

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd
git commit -m "feat(bomberman): draine les ennemis touchés par la bombe sangsue"
```

---

### Task 5: Contenu — les 4 armes, le défi, les traductions

Crée les ressources et les enregistre. C'est la tâche qui rend l'arme **atteignable** en jeu.

**Files:**
- Create: `content/weapons/bomb/bomb_leech_{1,2,3,4}_stats.tres`
- Create: `content/weapons/bomb/bomb_leech_{1,2,3,4}_data.tres`
- Create: `content/challenges/chal_bomb_leech_data.tres`
- Modify: `extensions/singletons/item_service.gd`
- Modify: `extensions/singletons/challenge_service.gd`
- Modify: `content/i18n/bomberman_translations.gd`

(Tous les chemins sont relatifs à `Brotato/mods-unpacked/Tanith-Bomberman/`.)

**Interfaces:**
- Consumes: `BombElement.LEECH` (Tâche 3) — c'est `weapon_id = "weapon_bomb_leech"` dans les `.tres` qui déclenche tout le comportement.
- Produces: l'arme `weapon_bomb_leech` (4 tiers) et le défi `chal_bomb_leech`, enregistrés dans les pools du jeu.

- [ ] **Step 1: Créer les 4 fichiers de stats**

Modèle : `bomb_ice_1_stats.tres`. Les seuls champs qui varient d'un tier à l'autre sont `cooldown` et `lifesteal`. `damage = 0` (bombe à effet : aucun dégât d'explosion).

`content/weapons/bomb/bomb_leech_1_stats.tres` :

```
[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://weapons/weapon_stats/ranged_weapon_stats.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
cooldown = 75
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
lifesteal = 0.4
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

Créer `bomb_leech_2_stats.tres`, `bomb_leech_3_stats.tres` et `bomb_leech_4_stats.tres` à l'identique, en changeant **uniquement** ces deux lignes :

| Fichier | `cooldown` | `lifesteal` |
|---|---|---|
| `bomb_leech_1_stats.tres` | `75` | `0.4` |
| `bomb_leech_2_stats.tres` | `70` | `0.5` |
| `bomb_leech_3_stats.tres` | `65` | `0.55` |
| `bomb_leech_4_stats.tres` | `60` | `0.65` |

Note : `lifesteal > 0` fait apparaître **gratuitement** la ligne « Vol de vie X % » dans l'infobulle (`weapon_stats.gd:167-170`). Rien à coder pour ça.

- [ ] **Step 2: Créer les 4 fichiers de données d'arme**

Modèle : `bomb_ice_1_data.tres`. La `SubResource( 1 )` est un `NullEffect` : il **n'a aucun effet mécanique**, il sert uniquement à afficher une ligne d'infobulle (patron déjà utilisé par la glace et la foudre). `value` y porte le **plafond de PV par explosion** du tier, qui doit rester **cohérent avec `BombLeech.CAP_BY_TIER`** (3/4/5/6).

`content/weapons/bomb/bomb_leech_1_data.tres` :

```
[gd_resource type="Resource" load_steps=9 format=2]

[ext_resource path="res://items/global/weapon_data.gd" type="Script" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=2]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn" type="PackedScene" id=3]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_leech_1_stats.tres" type="Resource" id=4]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_leech_2_data.tres" type="Resource" id=5]
[ext_resource path="res://items/sets/explosive/explosive_set_data.tres" type="Resource" id=6]
[ext_resource path="res://effects/weapons/null_effect.gd" type="Script" id=7]

[sub_resource type="Resource" id=1]
script = ExtResource( 7 )
key = "stat_lifesteal"
text_key = "WEAPON_BOMB_LEECH_DRAIN"
value = 3
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [  ]

[resource]
script = ExtResource( 1 )
my_id = "weapon_bomb_leech_1"
unlocked_by_default = false
can_be_looted = true
icon = ExtResource( 2 )
name = "WEAPON_BOMB_LEECH"
tier = 0
value = 20
effects = [ SubResource( 1 ) ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
weapon_id = "weapon_bomb_leech"
type = 1
sets = [ ExtResource( 6 ) ]
scene = ExtResource( 3 )
stats = ExtResource( 4 )
upgrades_into = ExtResource( 5 )
add_to_chars_as_starting = [  ]
```

Créer les tiers 2, 3 et 4 sur ce modèle, avec ces différences :

| Fichier | `my_id` | `tier` | `value` | `SubResource.value` (plafond) | `stats` (id=4) | `upgrades_into` (id=5) |
|---|---|---|---|---|---|---|
| `bomb_leech_1_data.tres` | `weapon_bomb_leech_1` | `0` | `20` | `3` | `bomb_leech_1_stats.tres` | `bomb_leech_2_data.tres` |
| `bomb_leech_2_data.tres` | `weapon_bomb_leech_2` | `1` | `45` | `4` | `bomb_leech_2_stats.tres` | `bomb_leech_3_data.tres` |
| `bomb_leech_3_data.tres` | `weapon_bomb_leech_3` | `2` | `85` | `5` | `bomb_leech_3_stats.tres` | `bomb_leech_4_data.tres` |
| `bomb_leech_4_data.tres` | `weapon_bomb_leech_4` | `3` | `149` | `6` | `bomb_leech_4_stats.tres` | *(aucun)* |

⚠️ Pour le **tier 4** (fin de chaîne d'upgrades), il n'y a **pas** de `upgrades_into` : supprimer la ligne `upgrades_into = ExtResource( 5 )` **et** la ligne `[ext_resource ...bomb_leech_5_data...]` correspondante, puis passer l'en-tête à `load_steps=8` et renuméroter l'`ext_resource` du set explosive de `id=6` à `id=5` (c'est exactement la structure de `bomb_ice_4_data.tres` — s'y référer en cas de doute).

- [ ] **Step 3: Créer le défi**

`content/challenges/chal_bomb_leech_data.tres`, modèle `chal_bomb_ice_data.tres` :

```
[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_leech_1_data.tres" type="Resource" id=2]
[ext_resource path="res://challenges/global/challenge_data.gd" type="Script" id=3]

[resource]
script = ExtResource( 3 )
my_id = "chal_bomb_leech"
unlocked_by_default = false
can_be_looted = true
icon = ExtResource( 1 )
name = "CHAL_BOMB_LEECH"
tier = 0
value = 1
effects = [  ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
description = "CHAL_BOMB_LEECH_DESC"
reward_type = 1
reward = ExtResource( 2 )
number = 0
stat = ""
additional_args = [  ]
```

- [ ] **Step 4: Enregistrer les armes et le défi**

Dans `extensions/singletons/item_service.gd`, ajouter la liste après `_BOMB_POISON_WEAPONS` :

```gdscript
const _BOMB_LEECH_WEAPONS := [
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_leech_1_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_leech_2_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_leech_3_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_leech_4_data.tres",
]
```

…et la boucle dans `_ready()`, à la suite des quatre existantes (⚠️ **avant** l'appel `._ready()` parent) :

```gdscript
	for path in _BOMB_LEECH_WEAPONS:
		_register_bomb_weapon(path)
```

Dans `extensions/singletons/challenge_service.gd`, ajouter la ligne dans `_CHALLENGES` :

```gdscript
const _CHALLENGES := [
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_ice_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_storm_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_poison_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_leech_data.tres",
]
```

- [ ] **Step 5: Ajouter les traductions FR/EN**

Dans `content/i18n/bomberman_translations.gd`, ajouter dans le bloc `tr_en`, après les lignes du poison :

```gdscript
	tr_en.add_message("WEAPON_BOMB_LEECH", "Leech Bomb")
	tr_en.add_message("WEAPON_BOMB_LEECH_DRAIN", "Drains up to {0} HP per explosion")
	tr_en.add_message("CHAL_BOMB_LEECH", "Bomb Collector")
	tr_en.add_message("CHAL_BOMB_LEECH_DESC", "Hold the Bomb, Ice, Storm and Poison Bombs at the same time.")
```

…et dans le bloc `tr_fr` :

```gdscript
	tr_fr.add_message("WEAPON_BOMB_LEECH", "Bombe Sangsue")
	tr_fr.add_message("WEAPON_BOMB_LEECH_DRAIN", "Draine jusqu'à {0} PV par explosion")
	tr_fr.add_message("CHAL_BOMB_LEECH", "Collectionneur de bombes")
	tr_fr.add_message("CHAL_BOMB_LEECH_DESC", "Détenez en même temps la Bombe, la Bombe de Glace, la Bombe de Foudre et la Bombe de Poison.")
```

Compléter aussi le bloc de commentaire de tête du fichier, qui documente les clés fournies :

```gdscript
#   WEAPON_BOMB_LEECH       — nom de la Bombe Sangsue
#   WEAPON_BOMB_LEECH_DRAIN — ligne d'infobulle « PV drainés par explosion » (via NullEffect,
#                             {0} = plafond du tier). ⚠️ Doit rester cohérent avec
#                             BombLeech.CAP_BY_TIER (3/4/5/6).
#                             La ligne « Vol de vie X % » est, elle, affichée gratuitement
#                             par le vanilla (weapon_stats.gd:get_lifesteal_text).
```

- [ ] **Step 6: Lancer les tests (non-régression)**

Run :
```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===`, et aucune erreur de chargement de ressource mentionnant `bomb_leech` ou `chal_bomb_leech`.

- [ ] **Step 7: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/ Brotato/mods-unpacked/Tanith-Bomberman/content/challenges/ Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/challenge_service.gd Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd
git commit -m "feat(bomberman): contenu de la bombe sangsue (4 tiers, défi, traductions)"
```

---

### Task 6: Asset — le sprite de la bombe

**Cette tâche est humaine** (les visuels du mod sont générés par IA par l'utilisateur, comme les autres skins de bombes).

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/sangsue.png`

- [ ] **Step 1: Fournir le PNG**

Contraintes, calquées sur les skins existants (`glace.png`, `poison.png`, `storm.png`) :
- **48 × 48 px**, PNG **RGBA** (fond transparent — `bomb_skin` compose lui-même le disque de rareté sur l'icône de boutique).
- Un autre format passe quand même : `_compose_world` redimensionne en Lanczos vers 48 × 48. Fournir directement du 48 × 48 évite la perte.
- Thème : bombe **rouge sang / vampirique**, lisible à petite taille.

Sans ce fichier, rien ne casse : `build_world_texture` rend `null` et la bombe garde le sprite par défaut de sa scène. L'arme est jouable, juste pas encore habillée.

- [ ] **Step 2: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/sangsue.png
git commit -m "feat(bomberman): sprite de la bombe sangsue"
```

---

### Task 7: Vérification en jeu

Rien de tout ce qui touche aux autoloads n'est prouvable en headless : le drain, le soin, le déblocage et l'infobulle **doivent** être vus en jeu.

- [ ] **Step 1: Déployer et lancer**

Copier/symlinker `Tanith-Bomberman/` dans le `mods-unpacked/` du jeu installé, lancer Brotato avec Bomberto.

- [ ] **Step 2: Vérifier le déblocage**

Sur une run : réunir les 4 bombes (normale, glace, foudre, poison) **en même temps** dans l'inventaire, tiers quelconques. Attendu : le défi « Collectionneur de bombes » se complète à l'instant où la 4ᵉ entre en inventaire. La Bombe Sangsue est disponible **à la run suivante** (les pools sont reconstruits au démarrage de run — c'est le comportement de tous les déblocages du jeu, pas un bug).

- [ ] **Step 3: Vérifier le drain et le soin**

Avec la Bombe Sangsue, se blesser volontairement, puis exploser une bombe au milieu d'un groupe d'ennemis. Attendu :
- la barre de vie **remonte** (au plus le plafond du tier : 3/4/5/6 PV) ;
- les ennemis touchés perdent **exactement autant** de PV au total ;
- **aucun dégât d'explosion** au-delà de ça (l'AoE est à 0) ;
- la bombe ne se transforme **jamais** en troll bombe.

- [ ] **Step 4: Vérifier l'infobulle**

Dans la boutique, survoler la Bombe Sangsue. Attendu : la ligne **« Vol de vie X % »** (fournie par le vanilla, et qui **monte** avec les items de vol de vie du joueur) **et** la ligne **« Draine jusqu'à N PV par explosion »** (N = 3/4/5/6 selon le tier).

- [ ] **Step 5: Vérifier la synergie**

Acheter des items de vol de vie (papillon, chauve-souris, sangsue…). Attendu : les procs deviennent visiblement plus fréquents, et le plafond par explosion est atteint avec **moins** d'ennemis.

- [ ] **Step 6: Vérifier en coop**

Deux joueurs, dont un Bomberto. Attendu : le drain soigne **le porteur de la bombe**, jamais son coéquipier ; les budgets des deux joueurs ne se mélangent pas.

---

## Notes de revue

**Couverture de la spec.** Chaque section de la spec est portée par une tâche : le vol de vie vanilla (contrainte, pas de code) → Tâches 1 et 4 ; la mécanique → 1 (pur) + 4 (câblage) ; les chiffres → 1 (`CAP_BY_TIER`) + 5 (`lifesteal` des `.tres`) ; le déblocage → 2 ; le découpage → toutes ; « ce qu'on ne touche pas » → respecté (aucune extension de `enemy.gd`/`unit.gd`/`player.gd`) ; les tests → 1, 2, 3 (pur) et 7 (en jeu).

**Duplication assumée du plafond.** Le plafond vit à **deux endroits** : `BombLeech.CAP_BY_TIER` (le comportement) et le `NullEffect.value` de chaque `.tres` (l'affichage). Le jeu ne permet pas de calculer une valeur d'infobulle depuis du code sans effet natif dédié, et c'est exactement le patron déjà employé pour le slow de la glace (`value = 30` dans le `.tres`, magnitude relue par `BombIceSlow`). Le commentaire de la Tâche 5 signale la contrainte de cohérence à qui touchera aux chiffres.

**Extension prévue (hors périmètre).** Une 6ᵉ bombe, débloquée par **Sangsue IV**, viendra plus tard. Elle se branchera sur `CHAIN` (`"weapon_bomb_leech": "chal_bomb_<X>"`), le mécanisme est déjà là. Rien à faire dans ce plan.
