# Bombe Frag — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter au mod Bomberman une 6ᵉ bombe, la **Bombe Frag** — un cluster dont l'obus éclate sans dégâts et projette 4 à 7 fragments dispersés au hasard, qui explosent chacun pour de bon — débloquée en montant la Bombe sangsue au niveau IV.

**Architecture:** Le fragment est une vraie `BombEntity` d'un élément interne dédié (`FRAG_CHILD`), instanciée par la Frag à sa détonation. On réutilise intégralement le chemin existant : explosion vanilla poolée, suivi des dégâts, skin, cycle de vie. Deux calculs purs seulement (la dispersion), le reste est du branchement. Le prédicat `is_effect()`, qui confond aujourd'hui deux questions, est scindé en trois.

**Tech Stack:** Godot 3.7 / GDScript 3, ModLoader 6.3.0 (script extensions uniquement), runner de tests `SceneTree` autonome (pas de GUT).

**Spec:** `docs/superpowers/specs/2026-07-16-bombe-frag-design.md` — à lire avant de commencer. Les sections « Le piège du carré » et « Sprites » contiennent des pièges non déductibles du code.

**Branche:** `feat/bombe-frag` (déjà créée, branchée sur `feat/defis-bombes`). Le sprite `frag.png` est **déjà en place et commité**.

## Global Constraints

- **Langue** : tout en français — commentaires, docs, libellés de commits. Les libellés UI sont bilingues FR/EN.
- **GDScript 3, pas 4** : pas de `static var`, pas de lambdas, pas de typed arrays, `.methode()` pour appeler le parent (pas `super()`), `connect("sig", obj, "method")`.
- **Logique pure = 100 % statique, hasard/temps INJECTÉS** : jamais de `randf()` ni d'`OS.get_ticks_msec()` dans `content/logic/` — l'appelant tire, le module calcule. C'est ce qui rend les tests déterministes en headless.
- **Pas de classe interne dans un module pur** : elle devrait appeler les statiques de son script hôte → self-preload → **référence cyclique** en Godot 3. Passer des `Array` par référence à la place.
- **Commande de test** (⚠️ celle de Bomberman, PAS `./run-tests.sh` qui est ShopConfig) :
  ```
  "Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
  ```
  Code de sortie = nombre d'échecs. Les erreurs moteur affichées **après** la ligne « N tests, M échec(s) » sont la fermeture des autoloads du jeu : sans effet sur le résultat.
- **⚠️⚠️ CONTRÔLE OBLIGATOIRE après TOUTE modification de `bomb_entity.gd` ou `bomb_weapon.gd`** : la suite de tests ne charge **jamais** ces fichiers (ils dépendent des autoloads du jeu). Une erreur de parse ou de compilation y est **totalement invisible, tests au vert** — c'est déjà arrivé deux fois, et plus aucune bombe n'existait en jeu. Passer la sortie du runner au grep :
  ```
  <commande de test> 2>&1 | grep -iE "parse error|compile error|bomb_entity|bomb_weapon"
  ```
  **Doit être VIDE.**
- **⚠️ Corruption du jeu décompilé** : lancer `Godot --path Brotato` régénère les `.png.import` et peut supprimer des `ext_resource` PNG de certains `.tres`. Vérifier `git status` après chaque passage du runner ; les `.import` sont gitignorés (normal), mais un `.tres` modifié à votre insu est un signal d'alarme.
- **Valeurs figées par la spec, à ne pas « améliorer »** : dégâts par fragment 54/65/78/93, fragments 4/5/6/7, rayon de gerbe 150 px, échelle d'explosion du fragment 0,35, échelle du sprite 0,4, mèche 0,4 s + gigue 0,15 s. ⚠️ **Les dégâts et l'échelle d'explosion sont liés** : `dégâts × rayon²` est la puissance. Changer l'un sans recalculer l'autre par `(221 / nouveau_rayon_px)²` casse l'équilibrage au carré.

---

## File Structure

| Fichier | Responsabilité | Action |
|---|---|---|
| `content/logic/bomb_frag.gd` | Logique **pure** : où tombent les fragments. Une seule fonction. | **Créer** |
| `content/logic/bomb_element.gd` | Élément d'une bombe + les 3 prédicats de comportement. | Modifier |
| `content/logic/bomb_challenges.gd` | Chaîne de défis : le maillon Sangsue IV → Frag. | Modifier |
| `content/logic/bomb_skin.gd` | Chemins des sprites + chargement (⚠️ vanilla ≠ maison). | Modifier |
| `content/entities/bomb_entity.gd` | La détonation en cluster + la mèche du fragment. **Le cœur.** | Modifier |
| `extensions/singletons/challenge_service.gd` | Enregistrement du défi de la Frag. | Modifier |
| `content/i18n/bomberman_translations.gd` | Libellés FR/EN. | Modifier |
| `content/weapons/bomb/bomb_frag_{1..4}_data.tres` | Données d'arme par tier (nom, prix, upgrade). | **Créer** |
| `content/weapons/bomb/bomb_frag_{1..4}_stats.tres` | Stats par tier (dégâts, nb fragments). | **Créer** |
| `content/challenges/chal_bomb_frag_data.tres` | Le défi + sa récompense. | **Créer** |
| `test/run_tests.gd` | Tests purs. | Modifier |
| `content/weapons/bomb/frag.png` | Sprite de la mère. | ✅ **DÉJÀ FAIT** |

---

## Task 1: Logique pure — la dispersion des fragments

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_frag.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Consumes: rien (module autonome).
- Produces:
  - `BombFrag.RANDOMS_PER_FRAGMENT : int` — nombre de tirages consommés par fragment (= 2).
  - `BombFrag.scatter_offsets(n: int, radius: float, randoms: Array) -> Array` — retourne `n` `Vector2` (des décalages depuis le centre), répartis **uniformément** dans le disque de rayon `radius`. `randoms` = tableau de flottants dans `[0,1)` fourni par l'appelant, `RANDOMS_PER_FRAGMENT` par fragment.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter le preload en haut du fichier, juste après la ligne `const BombLeech = ...` :

```gdscript
const BombFrag = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_frag.gd")
```

Ajouter l'appel dans `_init()`, juste après `_test_bomb_leech()` :

```gdscript
	_test_bomb_frag()
```

Ajouter la fonction de test à la fin du fichier, juste avant `func _check(cond, name):` :

```gdscript
func _test_bomb_frag() -> void:
	# ⚠️ Signature du helper existant : _check(cond, name) — la CONDITION d'abord.

	# --- Le compte : un fragment par demande, ni plus ni moins. ---
	var r7 := []
	for _i in range(7 * BombFrag.RANDOMS_PER_FRAGMENT):
		r7.append(0.5)
	_check(BombFrag.scatter_offsets(7, 150.0, r7).size() == 7, "frag: 7 demandés => 7 offsets")
	_check(BombFrag.scatter_offsets(4, 150.0, r7).size() == 4, "frag: 4 demandés => 4 offsets")

	# --- Tous DANS le disque : aucun fragment ne part hors de la gerbe. ---
	var inside := true
	var many := []
	for i in range(7 * BombFrag.RANDOMS_PER_FRAGMENT):
		many.append(float(i) / float(7 * BombFrag.RANDOMS_PER_FRAGMENT))
	for off in BombFrag.scatter_offsets(7, 150.0, many):
		if off.length() > 150.0 + 0.0001:
			inside = false
	_check(inside, "frag: tous les offsets sont dans le disque de 150")

	# --- ⚠️ LE TEST DISCRIMINANT : la racine carrée. ---
	# Tirer l'angle ET la distance uniformément ENTASSE les fragments au centre (la
	# surface d'une couronne croît avec le rayon). Il faut r = radius * sqrt(u).
	# Avec u = 0.25 : sqrt => 0.5 * 100 = 50. Sans sqrt (linéaire) => 25.
	# CE TEST ÉCHOUE si l'implémentation oublie la racine carrée.
	var quarter = BombFrag.scatter_offsets(1, 100.0, [0.0, 0.25])
	_check(_approx(quarter[0].length(), 50.0), "frag: distance = rayon * sqrt(u) — u=0.25 => 50, PAS 25 (racine carrée obligatoire)")
	var half = BombFrag.scatter_offsets(1, 100.0, [0.0, 0.5])
	_check(_approx(half[0].length(), 100.0 * sqrt(0.5)), "frag: u=0.5 => rayon * sqrt(0.5) ≈ 70.7")

	# --- L'angle : u_angle = 0 => plein est ; u_dist = 1 => bord du disque. ---
	var east = BombFrag.scatter_offsets(1, 100.0, [0.0, 1.0])
	_check(_approx(east[0].x, 100.0) and _approx(east[0].y, 0.0), "frag: angle 0 + distance max => (100, 0)")
	# u_angle = 0.5 => un demi-tour => plein ouest.
	var west = BombFrag.scatter_offsets(1, 100.0, [0.5, 1.0])
	_check(_approx(west[0].x, -100.0), "frag: angle 0.5 (demi-tour) => plein ouest")
	# u_dist = 0 => pile au centre.
	var center = BombFrag.scatter_offsets(1, 100.0, [0.3, 0.0])
	_check(_approx(center[0].length(), 0.0), "frag: distance 0 => au centre")

	# --- Déterminisme : mêmes tirages => mêmes positions (hasard INJECTÉ). ---
	var seed_vals := [0.1, 0.2, 0.3, 0.4]
	var a = BombFrag.scatter_offsets(2, 80.0, seed_vals)
	var b = BombFrag.scatter_offsets(2, 80.0, seed_vals)
	_check(a[0] == b[0] and a[1] == b[1], "frag: déterministe à tirages égaux")

	# --- Chaque fragment consomme SES PROPRES tirages (pas tous au même endroit). ---
	var distinct = BombFrag.scatter_offsets(2, 100.0, [0.0, 1.0, 0.5, 1.0])
	_check(distinct[0] != distinct[1], "frag: deux fragments, tirages différents => positions différentes")

	# --- Garde-fous : jamais de crash, jamais d'index hors bornes. ---
	_check(BombFrag.scatter_offsets(0, 150.0, r7).size() == 0, "frag: 0 demandé => aucun offset")
	_check(BombFrag.scatter_offsets(-3, 150.0, r7).size() == 0, "frag: nombre négatif => aucun offset")
	# Tirages MANQUANTS : on complète par 0.0, on ne plante pas et on ne perd AUCUN
	# fragment (sinon des dégâts disparaîtraient silencieusement).
	_check(BombFrag.scatter_offsets(7, 150.0, []).size() == 7, "frag: aucun tirage fourni => 7 fragments quand même (dégradation propre)")
	_check(BombFrag.scatter_offsets(7, 150.0, [0.5]).size() == 7, "frag: tirages incomplets => 7 fragments quand même")
	# Rayon nul ou négatif : tous au centre, mais TOUS présents (pas de dégât perdu).
	var zero_r = BombFrag.scatter_offsets(3, 0.0, r7)
	_check(zero_r.size() == 3 and zero_r[0] == Vector2.ZERO, "frag: rayon 0 => 3 fragments au centre (aucun perdu)")
	var neg_r = BombFrag.scatter_offsets(3, -50.0, r7)
	_check(neg_r.size() == 3 and neg_r[0] == Vector2.ZERO, "frag: rayon négatif => 3 fragments au centre, pas de crash")
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: échec au chargement — `bomb_frag.gd` n'existe pas encore (erreur de preload / « Parse Error: Can't preload resource »).

- [ ] **Step 3: Écrire le module**

Créer `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_frag.gd` :

```gdscript
extends Reference
# Logique PURE de la Bombe Frag : où tombent les fragments.
# Aucune dépendance aux autoloads du jeu -> testable en headless.
#
# À la détonation, l'obus éclate SANS dégâts (l'explosion mère n'est qu'un vecteur :
# repère visuel + son) et projette N fragments à des positions ALÉATOIRES dans un
# disque. Ce sont eux qui portent TOUS les dégâts. Ce module ne calcule QUE ces
# positions.
#
# ⭐ Il n'y a RIEN à partager entre les fragments : le `damage` du .tres est le dégât
# PAR FRAGMENT, pas un total à répartir. C'est la convention VANILLA des armes
# multi-projectiles (la Foudre porte `damage = 8` avec `nb_projectiles = 6`, et les 8
# sont par éclair). Le dégât d'explosion calculé à la pose est donc passé TEL QUEL à
# chaque fragment — d'où l'absence totale de fonction de partage ici.
#
# Le hasard est INJECTÉ (`randoms`) : jamais de randf() dans ce module, pour rester
# déterministe et testable en headless — même principe que le temps injecté dans
# bomb_leech.gd.

# Tirages consommés par fragment : un pour l'angle, un pour la distance.
const RANDOMS_PER_FRAGMENT := 2


# N décalages (depuis le centre de l'obus) répartis UNIFORMÉMENT dans le disque de
# rayon `radius`.
#
# `randoms` : flottants dans [0,1) fournis par l'appelant, RANDOMS_PER_FRAGMENT par
# fragment. S'il en manque, on complète par 0.0 : dégradation propre, jamais de crash
# ni d'index hors bornes, et surtout AUCUN fragment perdu (un fragment manquant, ce
# sont des dégâts qui disparaissent en silence).
#
# ⚠️ PIÈGE DE MATHS — LA RACINE CARRÉE EST OBLIGATOIRE. Tirer l'angle ET la distance
# uniformément ENTASSE les fragments au centre : la surface d'une couronne croît avec
# son rayon, donc une distance uniforme sur-représente massivement le centre. Pour une
# gerbe HOMOGÈNE il faut `r = radius * sqrt(u)`. Sans ça, la dispersion réelle serait
# bien plus concentrée que les 46 % de couverture calculés dans la spec, et tout
# l'équilibrage (qui repose sur les trous du tapis) tomberait à côté.
static func scatter_offsets(n: int, radius: float, randoms: Array) -> Array:
	var result := []
	if n <= 0:
		return result
	var r := max(0.0, radius)
	for i in range(n):
		var angle_idx := i * RANDOMS_PER_FRAGMENT
		var dist_idx := angle_idx + 1
		var u_angle: float = randoms[angle_idx] if angle_idx < randoms.size() else 0.0
		var u_dist: float = randoms[dist_idx] if dist_idx < randoms.size() else 0.0
		var angle := u_angle * TAU
		var dist := r * sqrt(clamp(u_dist, 0.0, 1.0))
		result.append(Vector2(cos(angle), sin(angle)) * dist)
	return result
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===` — tous les `_test_bomb_frag` en `ok :`.

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_frag.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): logique pure de la dispersion des fragments

Le hasard est injecte, donc le module reste deterministe et testable.
La racine carree sur la distance est obligatoire : sans elle les
fragments s'entassent au centre (la surface d'une couronne croit avec
le rayon) et la couverture trouee dont depend tout l'equilibrage
n'existe pas. Un test discriminant la verrouille.

Aucune fonction de partage des degats : le damage du .tres est le degat
PAR fragment, comme la Foudre (damage 8 + nb_projectiles 6) — convention
vanilla des armes multi-projectiles.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Trois prédicats au lieu d'un

**Contexte :** `BombElement.is_effect()` répond aujourd'hui à **deux questions distinctes** avec un seul classement — *fait-elle 0 dégât ?* (`bomb_entity.gd:107`) et *peut-elle se changer en troll bombe ?* (`bomb_entity.gd:72`). Ça marchait tant que les deux réponses coïncidaient. **La Frag est le premier cas qui les sépare** : elle fait des dégâts **et** ne troll jamais. Sans ce découpage, elle ne peut pas exister. Refactor **sans changement de comportement** pour les 5 bombes existantes.

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd` (fichier entier)
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd:72` et `:107`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd` (fonction `_test_bomb_element`)

**Interfaces:**
- Consumes: rien.
- Produces:
  - `BombElement.FRAG : String` = `"frag"` — l'obus (a un `weapon_id`).
  - `BombElement.FRAG_CHILD : String` = `"frag_child"` — le fragment (élément **interne**, sans `weapon_id`).
  - `BombElement.deals_explosion_damage(element: String) -> bool` — vrai pour `NORMAL` et `FRAG_CHILD`.
  - `BombElement.can_troll(element: String) -> bool` — vrai pour `NORMAL` seul.
  - `BombElement.is_cluster(element: String) -> bool` — vrai pour `FRAG` seul.
  - `is_effect()` est **supprimé** (plus aucun appelant).

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, **remplacer intégralement** la fonction `_test_bomb_element` par :

```gdscript
func _test_bomb_element():
	_check(BombElement.from_weapon_id("weapon_bomb") == BombElement.NORMAL, "element: weapon_bomb => normal")
	_check(BombElement.from_weapon_id("weapon_bomb_ice") == BombElement.ICE, "element: weapon_bomb_ice => ice")
	_check(BombElement.from_weapon_id("weapon_bomb_poison") == BombElement.POISON, "element: poison")
	_check(BombElement.from_weapon_id("weapon_bomb_storm") == BombElement.STORM, "element: storm")
	_check(BombElement.from_weapon_id("weapon_smg") == BombElement.NORMAL, "element: inconnu => normal (repli)")
	_check(BombElement.from_weapon_id("") == BombElement.NORMAL, "element: vide => normal")
	_check(BombElement.from_weapon_id("weapon_bomb_leech") == BombElement.LEECH, "element: weapon_bomb_leech => leech")
	_check(BombElement.from_weapon_id("weapon_bomb_frag") == BombElement.FRAG, "element: weapon_bomb_frag => frag")

	# ⚠️ FRAG_CHILD est un élément INTERNE : aucun weapon_id ne doit le produire.
	# C'est ce qui garde la garde anti-récursion STRUCTURELLE.
	_check(BombElement.from_weapon_id("weapon_bomb_frag_child") == BombElement.NORMAL,
		"element: frag_child n'a PAS de weapon_id (élément interne)")

	# --- deals_explosion_damage : qui inflige des dégâts d'explosion ? ---
	_check(BombElement.deals_explosion_damage(BombElement.NORMAL), "dégâts: la normale en fait")
	_check(BombElement.deals_explosion_damage(BombElement.FRAG_CHILD), "dégâts: le FRAGMENT en fait (il porte tout le dégât de la Frag)")
	_check(not BombElement.deals_explosion_damage(BombElement.FRAG), "dégâts: l'OBUS Frag n'en fait PAS (simple vecteur)")
	_check(not BombElement.deals_explosion_damage(BombElement.ICE), "dégâts: la glace n'en fait pas")
	_check(not BombElement.deals_explosion_damage(BombElement.POISON), "dégâts: le poison n'en fait pas")
	_check(not BombElement.deals_explosion_damage(BombElement.STORM), "dégâts: la foudre n'en fait pas (ses éclairs les portent)")
	_check(not BombElement.deals_explosion_damage(BombElement.LEECH), "dégâts: la sangsue n'en fait pas")

	# --- can_troll : la troll bombe reste la signature EXCLUSIVE de la normale. ---
	_check(BombElement.can_troll(BombElement.NORMAL), "troll: la normale peut troller")
	_check(not BombElement.can_troll(BombElement.FRAG), "troll: la Frag ne troll jamais")
	_check(not BombElement.can_troll(BombElement.FRAG_CHILD), "troll: un fragment ne troll jamais")
	_check(not BombElement.can_troll(BombElement.ICE), "troll: la glace ne troll pas")
	_check(not BombElement.can_troll(BombElement.POISON), "troll: le poison ne troll pas")
	_check(not BombElement.can_troll(BombElement.STORM), "troll: la foudre ne troll pas")
	_check(not BombElement.can_troll(BombElement.LEECH), "troll: la sangsue ne troll pas")

	# --- is_cluster : qui se scinde ? ---
	_check(BombElement.is_cluster(BombElement.FRAG), "cluster: la Frag se scinde")
	# ⚠️ LE test de la garde anti-récursion : un fragment n'est PAS un cluster, donc il
	# ne peut pas se scinder à son tour. La garde est structurelle, pas conditionnelle.
	_check(not BombElement.is_cluster(BombElement.FRAG_CHILD), "cluster: un FRAGMENT ne se scinde PAS (garde anti-récursion structurelle)")
	_check(not BombElement.is_cluster(BombElement.NORMAL), "cluster: la normale ne se scinde pas")
	_check(not BombElement.is_cluster(BombElement.ICE), "cluster: la glace ne se scinde pas")
	_check(not BombElement.is_cluster(BombElement.POISON), "cluster: le poison ne se scinde pas")
	_check(not BombElement.is_cluster(BombElement.STORM), "cluster: la foudre ne se scinde pas")
	_check(not BombElement.is_cluster(BombElement.LEECH), "cluster: la sangsue ne se scinde pas")

	# --- Les 3 prédicats sont FAUX pour un élément inconnu : jamais de crash. ---
	_check(not BombElement.is_cluster("inconnu"), "prédicats: élément inconnu => pas un cluster")
	_check(not BombElement.can_troll("inconnu"), "prédicats: élément inconnu => ne troll pas")
	_check(not BombElement.deals_explosion_damage("inconnu"), "prédicats: élément inconnu => pas de dégâts")
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: erreur de parse — `FRAG`, `FRAG_CHILD`, `deals_explosion_damage`, `can_troll`, `is_cluster` n'existent pas.

- [ ] **Step 3: Réécrire `bomb_element.gd`**

Remplacer **tout** le contenu de `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd` par :

```gdscript
extends Reference
# Élément d'une bombe, déduit du weapon_id partagé par ses 4 tiers.
# Pilote le sous-comportement à l'explosion.
#
# ⚠️ TROIS QUESTIONS DISTINCTES, TROIS PRÉDICATS — ne pas les refondre en un seul.
# Un unique `is_effect()` a longtemps suffi parce que les réponses coïncidaient :
# la normale faisait des dégâts ET pouvait troller, les bombes à effet ni l'un ni
# l'autre. La Frag est le premier cas qui les SÉPARE : elle fait des dégâts (via ses
# fragments) et ne troll JAMAIS. Les reconfondre rendrait la Frag impossible.

const NORMAL := "normal"
const ICE := "ice"
const POISON := "poison"
const STORM := "storm"
const LEECH := "leech"
# L'obus Frag : explose SANS dégâts (simple vecteur) et se scinde en fragments.
const FRAG := "frag"
# Le fragment projeté par la Frag. Élément INTERNE : aucun weapon_id ne le produit
# (il est absent de _BY_WEAPON_ID). C'est ce qui rend la garde anti-récursion
# STRUCTURELLE plutôt que conditionnelle : un FRAG_CHILD n'est pas un FRAG, donc
# is_cluster() est faux et la branche de dispersion ne peut pas le reprendre.
# Rien à tester côté récursion : elle est impossible par construction.
const FRAG_CHILD := "frag_child"

const _BY_WEAPON_ID := {
	"weapon_bomb_ice": ICE,
	"weapon_bomb_poison": POISON,
	"weapon_bomb_storm": STORM,
	"weapon_bomb_leech": LEECH,
	"weapon_bomb_frag": FRAG,
}

# Élément d'une arme d'après son weapon_id. Repli NORMAL (dont "weapon_bomb").
static func from_weapon_id(weapon_id: String) -> String:
	return _BY_WEAPON_ID.get(weapon_id, NORMAL)


# Qui inflige des DÉGÂTS d'explosion ?
# - la Bombe normale ;
# - le FRAGMENT de la Frag, qui porte TOUT le dégât de celle-ci.
# Les bombes à effet (glace/poison/sangsue) sont à 0 par design ; la foudre porte ses
# dégâts dans ses éclairs, pas dans une zone ; et l'OBUS Frag lui-même est à 0 (il
# n'est qu'un vecteur de dispersion).
static func deals_explosion_damage(element: String) -> bool:
	return element == NORMAL or element == FRAG_CHILD


# Qui peut se réveiller en troll bombe ? La Bombe normale SEULE — c'est sa signature
# exclusive, et la Frag ne doit pas la lui voler.
static func can_troll(element: String) -> bool:
	return element == NORMAL


# Qui se scinde en fragments à la détonation ? La Frag SEULE.
static func is_cluster(element: String) -> bool:
	return element == FRAG
```

- [ ] **Step 4: Migrer les deux appelants dans `bomb_entity.gd`**

Dans `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd`, remplacer ce bloc (autour de la ligne 71) :

```gdscript
	# Seule la Bombe normale peut se transformer en trollbombe ; les bombes à
	# effet (glace/poison/foudre) ne se réveillent jamais.
	if BombElement.is_effect(_element):
		_will_wake = false
	else:
		_will_wake = TrollBombLogic.should_wake(randf(), TROLL_WAKE_CHANCE)
```

par :

```gdscript
	# Seule la Bombe normale peut se transformer en trollbombe : c'est sa signature
	# exclusive. Ni les bombes à effet, ni la Frag, ni ses fragments ne se réveillent.
	if BombElement.can_troll(_element):
		_will_wake = TrollBombLogic.should_wake(randf(), TROLL_WAKE_CHANCE)
	else:
		_will_wake = false
```

Puis remplacer ce bloc (autour de la ligne 105) :

```gdscript
	# Bombes à effet : AUCUN dégât d'explosion AoE (les effets — slow, givre —
	# s'appliquent indépendamment ; deals_damage reste true donc les hits sont émis).
	if BombElement.is_effect(_element):
		_explode_args.damage = 0
	else:
		_explode_args.damage = _explosion_damage_override if _explosion_damage_override >= 0 else _stats.damage
```

par :

```gdscript
	# Qui blesse, qui ne blesse pas. Les bombes à effet sont à 0 par design (leurs
	# effets — slow, givre, drain — s'appliquent indépendamment ; deals_damage reste
	# true, donc les hits sont émis quand même). L'OBUS Frag est à 0 lui aussi : il
	# n'est qu'un vecteur, ce sont ses fragments qui portent tout le dégât.
	if BombElement.deals_explosion_damage(_element):
		_explode_args.damage = _explosion_damage_override if _explosion_damage_override >= 0 else _stats.damage
	else:
		_explode_args.damage = 0
```

- [ ] **Step 5: Lancer les tests pour vérifier qu'ils passent**

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===`

- [ ] **Step 6: ⚠️ Contrôle obligatoire — aucune erreur de compilation dans `bomb_entity.gd`**

Les tests ne chargent JAMAIS `bomb_entity.gd`. Ce grep est le SEUL filet.

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd 2>&1 | grep -iE "parse error|compile error|bomb_entity"
```
Expected: **sortie VIDE**. Toute ligne ici = `bomb_entity.gd` est cassé et plus aucune bombe n'existe en jeu, quels que soient les tests au vert.

- [ ] **Step 7: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_element.gd Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "refactor(bomberman): scinde is_effect en trois predicats

is_effect repondait a DEUX questions distinctes avec un seul classement :
qui fait des degats, et qui peut troller. Ca tenait tant que les reponses
coincidaient. La Frag est le premier cas qui les separe — elle fait des
degats via ses fragments et ne troll jamais — donc le prédicat unique la
rendait litteralement impossible.

deals_explosion_damage / can_troll / is_cluster. Aucun changement de
comportement pour les 5 bombes existantes.

FRAG_CHILD est un element interne, absent de _BY_WEAPON_ID : c'est ce qui
rend la garde anti-recursion structurelle plutot que conditionnelle.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Le maillon Sangsue IV → Frag

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd` (fonction `_test_bomb_challenges`)

**Interfaces:**
- Consumes: rien.
- Produces: `BombChallenges.CHAIN` gagne `"weapon_bomb_leech": "chal_bomb_frag"` ; `BombChallenges.REWARD` gagne `"chal_bomb_frag": "weapon_bomb_frag"`. `LEECH_REQUIRED` est **inchangé** (la Frag n'entre pas dans le défi de la sangsue).

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter à la **fin** de la fonction `_test_bomb_challenges` :

```gdscript
	# --- Bombe Frag : le maillon terminal, débloqué par la Sangsue IV. ---
	_check(BombChallenges.challenge_for("weapon_bomb_leech", 3) == "chal_bomb_frag",
		"frag: Sangsue IV -> défi frag")
	# Seul le tier IV compte, ici comme partout.
	_check(BombChallenges.challenge_for("weapon_bomb_leech", 2) == "",
		"frag: Sangsue III ne complète rien")
	_check(BombChallenges.challenge_for("weapon_bomb_leech", 0) == "",
		"frag: Sangsue I ne complète rien")
	# La Frag est la FIN de la chaîne : elle ne débloque rien à son tour.
	_check(BombChallenges.challenge_for("weapon_bomb_frag", 3) == "",
		"frag: Frag IV ne complète rien (fin de chaîne)")

	# La Frag est une récompense connue (le popup de migration itère sur REWARD, donc
	# il la couvre gratuitement).
	_check(BombChallenges.REWARD.has("chal_bomb_frag"),
		"frag: chal_bomb_frag est dans REWARD (couvert par la migration)")
	_check(BombChallenges.REWARD["chal_bomb_frag"] == "weapon_bomb_frag",
		"frag: chal_bomb_frag récompense weapon_bomb_frag")
	_check(BombChallenges.unearned_bombs(["weapon_bomb_frag"], []) == ["weapon_bomb_frag"],
		"migration: frag possédée et non gagnée => à proposer")
	_check(BombChallenges.unearned_bombs(["weapon_bomb_frag"], ["chal_bomb_frag"]).empty(),
		"migration: frag possédée ET gagnée => rien à proposer")

	# ⚠️ La Frag n'entre PAS dans le défi de la sangsue : celui-ci exige les 4 bombes
	# d'ORIGINE. Sinon l'avertissement du carnet (« chaque bombe ajoutée mange un slot
	# pendant la tentative ») s'appliquerait et le défi deviendrait ingérable.
	_check(not BombChallenges.LEECH_REQUIRED.has("weapon_bomb_frag"),
		"frag: la Frag n'est PAS requise pour débloquer la sangsue")
	_check(BombChallenges.unlocks_leech(
			["weapon_bomb", "weapon_bomb_ice", "weapon_bomb_storm", "weapon_bomb_poison"]),
		"frag: les 4 bombes d'origine suffisent toujours pour la sangsue")
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: FAIL sur « frag: Sangsue IV -> défi frag » et « frag: chal_bomb_frag est dans REWARD ».

- [ ] **Step 3: Ajouter le maillon**

Dans `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd`, remplacer l'en-tête et les deux dictionnaires (lignes 1 à 37) par :

```gdscript
extends Reference
# Logique PURE de la chaîne de défis des bombes.
# Aucune dépendance aux autoloads du jeu -> testable en headless.
#
# Deux mécanismes de déblocage, distincts :
#
# 1. La CHAÎNE (CHAIN) : monter une bombe au niveau IV débloque la suivante.
#      Bombe IV -> Glace, Glace IV -> Foudre, Foudre IV -> Poison.
#      Puis, en bout de parcours : Sangsue IV -> Frag.
#    Le Poison est la fin de la BRANCHE ÉLÉMENTAIRE : il ne débloque rien.
#    La Frag est la fin de TOUT l'arbre : elle ne débloque rien non plus.
#
# 2. La COLLECTION (unlocks_leech) : détenir les 4 bombes EN MÊME TEMPS, quels que
#    soient leurs tiers, débloque la Bombe sangsue. Ça immobilise 4 des 6 slots
#    d'arme : c'est un sacrifice de build délibéré, et c'est tout l'intérêt du défi.
#
# ⚠️ La sangsue n'est donc PAS dans CHAIN en tant que RÉCOMPENSE (qui est indexé
# « arme X au tier IV »), mais elle y est comme SOURCE (Sangsue IV -> Frag) — et elle
# EST dans REWARD, ce qui suffit à ce que le popup de migration la couvre.
#
# ⚠️ La Frag n'entre PAS dans LEECH_REQUIRED : le défi de la sangsue exige les 4 bombes
# d'ORIGINE. L'ajouter rendrait le défi ingérable (5 slots sur 6 immobilisés) et la
# boutique élargie de Bomberto inutilisable pendant la tentative.

# ItemParentData.Tier : COMMON=0, UNCOMMON=1, RARE=2, LEGENDARY=3.
# Le niveau IV affiché en jeu est donc le tier 3.
const TIER_IV := 3

# weapon_id -> my_id du défi que « posséder cette arme au tier IV » complète.
# ⚠️ La correspondance est EXACTE, jamais un begins_with() : "weapon_bomb" est un
# préfixe de "weapon_bomb_ice", "weapon_bomb_storm", "weapon_bomb_poison",
# "weapon_bomb_leech" et "weapon_bomb_frag".
const CHAIN := {
	"weapon_bomb": "chal_bomb_ice",
	"weapon_bomb_ice": "chal_bomb_storm",
	"weapon_bomb_storm": "chal_bomb_poison",
	"weapon_bomb_leech": "chal_bomb_frag",
}

# my_id du défi -> weapon_id de la bombe qu'il débloque.
const REWARD := {
	"chal_bomb_ice": "weapon_bomb_ice",
	"chal_bomb_storm": "weapon_bomb_storm",
	"chal_bomb_poison": "weapon_bomb_poison",
	"chal_bomb_leech": "weapon_bomb_leech",
	"chal_bomb_frag": "weapon_bomb_frag",
}
```

Le reste du fichier (à partir de `# --- Bombe sangsue : déblocage par la COLLECTION...`) est **inchangé**.

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===`. Le test de cohérence existant (« chaque défi de la chaîne a une récompense ») doit rester vert : il vérifie automatiquement le nouveau maillon.

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): la Sangsue IV debloque la bombe frag

Un maillon de plus dans CHAIN, aucun mecanisme nouveau. L'entree dans
REWARD suffit a ce que le popup de migration couvre la Frag gratuitement.

LEECH_REQUIRED reste inchange : le defi de la sangsue exige les 4 bombes
d'origine, pas la 5e. Ajouter la Frag immobiliserait 5 slots sur 6 et
rendrait la boutique elargie de Bomberto inutilisable pendant l'essai.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Les sprites

**Contexte :** la mère a son dessin (`frag.png`, déjà commité). Le fragment réutilise un **asset vanilla** — la boule de feu — donc aucun art à produire et zéro octet ajouté au zip. Mais un asset vanilla **ne se charge pas comme les nôtres**.

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd` (fonction `_test_bomb_skin_element`)

**Interfaces:**
- Consumes: rien.
- Produces:
  - `BombSkin.element_sprite_path("frag")` → chemin de `frag.png`.
  - `BombSkin.FRAG_CHILD_SPRITE : String` — chemin **vanilla** de la boule de feu.
  - `BombSkin.build_world_texture("frag_child")` → la texture vanilla, chargée par `load()`.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter à la **fin** de la fonction `_test_bomb_skin_element` :

```gdscript
	# La mère a son propre dessin, comme les 5 autres bombes.
	_check(BombSkin.element_sprite_path("frag").ends_with("frag.png"), "skin: frag -> frag.png")

	# --- Le FRAGMENT réutilise un asset VANILLA (aucun art, zéro octet dans le zip). ---
	_check(BombSkin.FRAG_CHILD_SPRITE.ends_with("fireball_projectile.png"),
		"skin: le fragment pointe la boule de feu vanilla")
	# ⚠️ C'est un chemin du JEU, pas du mod : c'est précisément ce qui impose le
	# chargeur de ressources standard plutôt que le chargeur maison.
	_check(not BombSkin.FRAG_CHILD_SPRITE.begins_with("res://mods-unpacked"),
		"skin: le sprite du fragment est un asset du JEU, pas du mod")
	_check(BombSkin.FRAG_CHILD_SPRITE.begins_with("res://projectiles/"),
		"skin: chemin vanilla des projectiles")
	# On prend le PNG, JAMAIS la .tscn : la scène embarque des particules de flammes
	# (torch_burning_particles) et nos fragments cracheraient du feu alors que la Frag
	# ne brûle pas.
	_check(not BombSkin.FRAG_CHILD_SPRITE.ends_with(".tscn"),
		"skin: le PNG, jamais la scène (qui embarque des particules de feu)")
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: erreur de parse — `FRAG_CHILD_SPRITE` n'existe pas.

- [ ] **Step 3: Ajouter le chemin de la mère**

Dans `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd`, remplacer le bloc `_SPRITE_PATHS` (lignes 19-26) par :

```gdscript
# Clés = valeurs de BombElement (normal/ice/storm/poison/leech/frag).
const _SPRITE_PATHS := {
	"normal": _BOMB_DIR + "/bombe_normale.png",
	"ice": _BOMB_DIR + "/glace.png",
	"storm": _BOMB_DIR + "/storm.png",
	"poison": _BOMB_DIR + "/poison.png",
	"leech": _BOMB_DIR + "/sangsue.png",
	"frag": _BOMB_DIR + "/frag.png",
}

# Sprite du FRAGMENT de la Frag : un asset VANILLA réutilisé — aucun art à produire,
# ZÉRO octet ajouté au zip. La boule de feu fait 49×49 (donc déjà à la taille cible de
# 48 : le piège de padding qui nous a coûté un aller-retour sur la sangsue n'existe
# pas ici), elle est RONDE (nos fragments n'ont pas d'orientation) et son gros contour
# noir la rend lisible en tout petit. Réutiliser un asset du jeu est déjà le motif du
# mod : on réutilise explosion.tscn, le popup d'objet de la boutique, et le projectile
# d'éclair vanilla pour la Bombe de Foudre.
#
# ⚠️ Le PNG, JAMAIS fireball_projectile.tscn : la scène embarque un système de
# particules de flammes (torch_burning_particles) et nos fragments cracheraient du feu
# alors que la Frag ne brûle pas.
#
# ⭐ REPLI si ça ne tient pas en jeu (lisibilité à 20 px, ou elle lit « feu ») :
# basculer sur la mère en réduit, c'est-à-dire supprimer la branche frag_child de
# build_world_texture et ajouter "frag_child": _BOMB_DIR + "/frag.png" ci-dessus.
const FRAG_CHILD_SPRITE := "res://projectiles/fireball_projectile/fireball_projectile.png"
```

- [ ] **Step 4: Router le fragment vers le chargeur de ressources standard**

Dans le même fichier, remplacer la fonction `build_world_texture` par :

```gdscript
# Sprite EN JEU : sprite de l'élément, 48×48, SANS fond.
#
# ⚠️⚠️ PIÈGE — UN ASSET VANILLA NE SE CHARGE PAS COMME LES NÔTRES.
# Le chargeur maison (_compose_world -> _load_image -> Image.load) lit un PNG BRUT sur
# le disque : parfait pour nos images, qui voyagent en clair dans le zip du mod. Mais
# un jeu Godot EXPORTÉ n'embarque PAS les PNG sources, seulement leur version compilée
# (.stex) — le PNG de la boule de feu n'existe dans notre projet décompilé que parce
# que GDRE l'a reconstruit. Il faut donc le chargeur de ressources STANDARD (load()),
# qui résout via le .import.
# Avec le chargeur maison, le fragment s'afficherait dans le projet décompilé et
# serait INVISIBLE sur le vrai jeu — et aucun test ne le verrait.
static func build_world_texture(element: String) -> Texture:
	if element == "frag_child":
		return load(FRAG_CHILD_SPRITE) as Texture
	return _compose_world(element_sprite_path(element))
```

- [ ] **Step 5: Lancer les tests pour vérifier qu'ils passent**

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===`

- [ ] **Step 6: Vérifier qu'aucun `.tres` n'a été corrompu par le passage du runner**

Run: `git status --short`
Expected: seuls les fichiers que vous avez édités apparaissent. **Aucun `.tres` que vous n'avez pas touché.** Si un `.tres` apparaît, le runner a corrompu le jeu décompilé (`git checkout` dessus).

- [ ] **Step 7: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): sprites de la frag et de ses fragments

La mere a son dessin (frag.png, deja commite). Le fragment reutilise la
boule de feu VANILLA : aucun art a produire, zero octet dans le zip, et
elle fait 49x49 donc deja a la taille cible de 48 — le piege de padding
de la sangsue n'existe pas.

Elle passe par load() et NON par le chargeur maison : un export Godot
n'embarque pas les PNG sources, seulement les .stex. Avec Image.load le
fragment marcherait dans le projet decompile et serait invisible sur le
vrai jeu, sans qu'aucun test le voie.

Le PNG seul, jamais la .tscn : elle embarque des particules de flammes.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Le contenu — 4 tiers, le défi, les traductions

**Contexte :** que du `.tres` et des libellés. ⚠️ Le `damage` est le dégât **PAR FRAGMENT** (convention vanilla), et `nb_projectiles` porte le nombre de fragments.

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_frag_{1,2,3,4}_stats.tres`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_frag_{1,2,3,4}_data.tres`
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_frag_data.tres`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/challenge_service.gd`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd`

**Interfaces:**
- Consumes: `BombChallenges.REWARD["chal_bomb_frag"] == "weapon_bomb_frag"` (Task 3) — le `weapon_id` des `.tres` **doit** valoir exactement `weapon_bomb_frag`, et le `my_id` du défi exactement `chal_bomb_frag`.
- Produces: les 4 tiers de `weapon_bomb_frag`, le défi `chal_bomb_frag`, les clés `WEAPON_BOMB_FRAG`, `WEAPON_BOMB_FRAG_COUNT`, `CHAL_BOMB_FRAG`, `CHAL_BOMB_FRAG_DESC`.

- [ ] **Step 1: Créer les 4 fichiers de stats**

`content/weapons/bomb/bomb_frag_1_stats.tres` :

```
[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://weapons/weapon_stats/ranged_weapon_stats.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
cooldown = 75
damage = 54
accuracy = 1.0
crit_chance = 0.03
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
nb_projectiles = 4
projectile_spread = 0.0
piercing = 0
piercing_dmg_reduction = 0.5
bounce = 0
bounce_dmg_reduction = 0.5
can_bounce = false
projectile_speed = 3000
increase_projectile_speed_with_range = false
```

`bomb_frag_2_stats.tres` : **identique**, sauf `damage = 65` et `nb_projectiles = 5`.

`bomb_frag_3_stats.tres` : **identique**, sauf `damage = 78` et `nb_projectiles = 6`.

`bomb_frag_4_stats.tres` : **identique**, sauf `damage = 93` et `nb_projectiles = 7`.

⚠️ `cooldown = 75` sur les 4 tiers : c'est la refonte de la pose — toutes les armes bombe partagent la même période pour que le déphasage par slot tienne. **Ne pas graduer le cooldown.**
⚠️ `damage` = dégât **par fragment**. Ces valeurs paraissent énormes à côté des 12/18/26/36 de la normale : c'est voulu, elles compensent le rayon 4,25× plus petit (cf. « Le piège du carré » dans la spec).

- [ ] **Step 2: Créer les 4 fichiers de données**

`content/weapons/bomb/bomb_frag_1_data.tres` :

```
[gd_resource type="Resource" load_steps=8 format=2]

[ext_resource path="res://items/global/weapon_data.gd" type="Script" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=2]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn" type="PackedScene" id=3]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_frag_1_stats.tres" type="Resource" id=4]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_frag_2_data.tres" type="Resource" id=5]
[ext_resource path="res://items/sets/explosive/explosive_set_data.tres" type="Resource" id=6]
[ext_resource path="res://effects/weapons/null_effect.gd" type="Script" id=7]

[sub_resource type="Resource" id=1]
script = ExtResource( 7 )
key = "nb_projectiles"
text_key = "WEAPON_BOMB_FRAG_COUNT"
value = 4
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [  ]

[resource]
script = ExtResource( 1 )
my_id = "weapon_bomb_frag_1"
unlocked_by_default = false
can_be_looted = true
icon = ExtResource( 2 )
name = "WEAPON_BOMB_FRAG"
tier = 0
value = 25
effects = [ SubResource( 1 ) ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
weapon_id = "weapon_bomb_frag"
type = 1
sets = [ ExtResource( 6 ) ]
scene = ExtResource( 3 )
stats = ExtResource( 4 )
upgrades_into = ExtResource( 5 )
add_to_chars_as_starting = [  ]
```

`bomb_frag_2_data.tres` : identique, sauf — `bomb_frag_2_stats.tres` en id 4, `bomb_frag_3_data.tres` en id 5, `value = 4` du sub_resource → `5`, `my_id = "weapon_bomb_frag_2"`, `tier = 1`, `value = 45`.

`bomb_frag_3_data.tres` : identique, sauf — `bomb_frag_3_stats.tres` en id 4, `bomb_frag_4_data.tres` en id 5, sub_resource `value = 6`, `my_id = "weapon_bomb_frag_3"`, `tier = 2`, `value = 85`.

`bomb_frag_4_data.tres` : **structure différente** — pas d'`upgrades_into` (c'est le dernier tier), donc `load_steps=7` et les ids décalés :

```
[gd_resource type="Resource" load_steps=7 format=2]

[ext_resource path="res://items/global/weapon_data.gd" type="Script" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=2]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb.tscn" type="PackedScene" id=3]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_frag_4_stats.tres" type="Resource" id=4]
[ext_resource path="res://items/sets/explosive/explosive_set_data.tres" type="Resource" id=5]
[ext_resource path="res://effects/weapons/null_effect.gd" type="Script" id=6]

[sub_resource type="Resource" id=1]
script = ExtResource( 6 )
key = "nb_projectiles"
text_key = "WEAPON_BOMB_FRAG_COUNT"
value = 7
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [  ]

[resource]
script = ExtResource( 1 )
my_id = "weapon_bomb_frag_4"
unlocked_by_default = false
can_be_looted = true
icon = ExtResource( 2 )
name = "WEAPON_BOMB_FRAG"
tier = 3
value = 165
effects = [ SubResource( 1 ) ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
weapon_id = "weapon_bomb_frag"
type = 1
sets = [ ExtResource( 5 ) ]
scene = ExtResource( 3 )
stats = ExtResource( 4 )
add_to_chars_as_starting = [  ]
```

⚠️ `unlocked_by_default = false` sur les 4 : c'est le verrouillage 100 % natif. `init_unlocked_pool()` ne verse une arme au magasin que si son `weapon_id_hash` est dans `ProgressData.weapons_unlocked`.
⚠️ `add_to_chars_as_starting = [ ]` : contrairement à la sangsue, la Frag **n'est pas** une arme de départ de Bomberman.

⭐ **Pas de brûlure : rien à désactiver, c'est acquis par construction.** La brûlure de la Bombe normale vient d'un `BurningEffect` + une `BurningData` déclarés dans son `bomb_1_data.tres` (pas dans ses stats). Nos `bomb_frag_*_data.tres` ne portent qu'un `NullEffect` d'infobulle : la Frag est donc sans brûlure sans qu'on écrive quoi que ce soit. **Ne pas ajouter de `BurningEffect`** — c'est ce qui garde les deux bombes de dégâts distinctes (la normale *marque* dans la durée, la Frag *couvre* à l'impact).

- [ ] **Step 3: Créer le défi**

`content/challenges/chal_bomb_frag_data.tres` :

```
[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_icon.png" type="Texture" id=1]
[ext_resource path="res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_frag_1_data.tres" type="Resource" id=2]
[ext_resource path="res://challenges/global/challenge_data.gd" type="Script" id=3]

[resource]
script = ExtResource( 3 )
my_id = "chal_bomb_frag"
unlocked_by_default = false
can_be_looted = true
icon = ExtResource( 1 )
name = "CHAL_BOMB_FRAG"
tier = 0
value = 1
effects = [  ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
description = "CHAL_BOMB_FRAG_DESC"
reward_type = 1
reward = ExtResource( 2 )
number = 0
stat = ""
additional_args = [  ]
```

- [ ] **Step 4: Enregistrer le défi**

Dans `Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/challenge_service.gd`, ajouter une entrée à `_CHALLENGES` :

```gdscript
const _CHALLENGES := [
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_ice_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_storm_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_poison_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_leech_data.tres",
	"res://mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_frag_data.tres",
]
```

- [ ] **Step 5: Ajouter les traductions**

Dans `content/i18n/bomberman_translations.gd`, ajouter au bloc de commentaire d'en-tête, après la description de `WEAPON_BOMB_LEECH_DRAIN` :

```gdscript
#   WEAPON_BOMB_FRAG        — nom de la Bombe Frag
#   WEAPON_BOMB_FRAG_COUNT  — ligne d'infobulle « nb de fragments » (via NullEffect,
#                             {0} = nb_projectiles du tier). Calquée sur
#                             WEAPON_BOMB_STORM_BOLTS.
```

Puis, juste après la ligne `tr_en.add_message("CHAL_BOMB_LEECH_DESC", ...)` :

```gdscript
	tr_en.add_message("WEAPON_BOMB_FRAG", "Frag Bomb")
	tr_en.add_message("WEAPON_BOMB_FRAG_COUNT", "Bursts into {0} fragments")
	tr_en.add_message("CHAL_BOMB_FRAG", "Shrapnel Storm")
	tr_en.add_message("CHAL_BOMB_FRAG_DESC", "Own a Leech Bomb of tier IV.")
```

Et juste après la ligne `tr_fr.add_message("CHAL_BOMB_LEECH_DESC", ...)` :

```gdscript
	tr_fr.add_message("WEAPON_BOMB_FRAG", "Bombe Frag")
	tr_fr.add_message("WEAPON_BOMB_FRAG_COUNT", "Éclate en {0} fragments")
	tr_fr.add_message("CHAL_BOMB_FRAG", "Tempête de Shrapnel")
	tr_fr.add_message("CHAL_BOMB_FRAG_DESC", "Détenez une Bombe Sangsue de niveau IV.")
```

- [ ] **Step 6: Vérifier qu'aucun `.tres` ne casse le chargement**

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd 2>&1 | grep -iE "parse error|compile error|failed|frag"
```
Expected: **aucune ligne d'erreur**. Les `.tres` ne sont pas chargés par les tests, mais une faute de syntaxe dans `challenge_service.gd` ou les traductions ressortirait ici.

Run: `git status --short`
Expected: vos nouveaux fichiers + ceux édités. **Aucun `.tres` étranger modifié.**

- [ ] **Step 7: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_frag_*.tres Brotato/mods-unpacked/Tanith-Bomberman/content/challenges/chal_bomb_frag_data.tres Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/challenge_service.gd Brotato/mods-unpacked/Tanith-Bomberman/content/i18n/bomberman_translations.gd
git commit -m "feat(bomberman): contenu de la bombe frag (4 tiers, defi, traductions)

damage = degat PAR FRAGMENT (54/65/78/93), nb_projectiles = nombre de
fragments (4/5/6/7) — convention vanilla des armes multi-projectiles.
Ces chiffres paraissent enormes a cote des 36 de la normale : ils
compensent un rayon 4,25x plus petit, la puissance valant degats x rayon^2.

cooldown fige a 75 sur les 4 tiers (refonte de la pose : meme periode
pour toutes les armes bombe, sinon le dephasage par slot ne tient pas).

unlocked_by_default = false : verrouillage 100 % natif.
Pas d'arme de depart, contrairement a la sangsue.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: La détonation en cluster

**Contexte :** le cœur de la fonctionnalité, et le fichier le plus dangereux du mod. ⚠️ **Les tests ne chargent JAMAIS `bomb_entity.gd`** — une erreur y est invisible, tests au vert, et plus aucune bombe n'existe en jeu. Le grep de l'étape finale est le seul filet.

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd`

**Interfaces:**
- Consumes:
  - `BombFrag.scatter_offsets(n, radius, randoms)` et `BombFrag.RANDOMS_PER_FRAGMENT` (Task 1)
  - `BombElement.FRAG`, `BombElement.FRAG_CHILD`, `BombElement.is_cluster(e)`, `BombElement.can_troll(e)`, `BombElement.deals_explosion_damage(e)` (Task 2)
  - `BombSkin.build_world_texture("frag_child")` (Task 4)
  - `bomb_entity.arm(p_player_index, p_stats, p_tier, p_explosion_scale, p_damage_tracking_key_hash, p_explosion_damage, p_element, p_weapon)` — signature existante, inchangée.
- Produces: rien pour les autres tâches (c'est le point d'aboutissement).

- [ ] **Step 1: Ajouter le preload et les constantes**

Dans `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd`, ajouter après la ligne `const BombLeech = preload(...)` :

```gdscript
const BombFrag = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_frag.gd")
```

Puis ajouter après le bloc de constantes de la troll bombe (après `const TROLL_WAKE_FRACTION := 0.5`) :

```gdscript
# --- Paramètres réglables de la Bombe Frag (calibrage final en jeu) ---
#
# ⚠️⚠️ FRAG_SCATTER_RADIUS et FRAG_CHILD_EXPLOSION_SCALE sont LIÉS AUX DÉGÂTS des
# bomb_frag_*_stats.tres. La puissance d'une bombe vaut `dégâts × rayon²` : changer
# l'échelle d'explosion sans recalculer les dégâts par (221 / nouveau_rayon_px)² casse
# l'équilibrage AU CARRÉ. Lire « Le piège du carré » dans la spec avant d'y toucher.
const FRAG_SCATTER_RADIUS := 150.0        # rayon de la gerbe (px). Ne change PAS la puissance, seulement la forme.
const FRAG_CHILD_EXPLOSION_SCALE := 0.35  # 147,34 × 0,35 ≈ 52 px de rayon. Au-delà de ~0,5 le tapis sature et la contrepartie disparaît.
const FRAG_CHILD_SPRITE_SCALE := 0.4      # ~20 px à l'écran. PUREMENT visuel — à ne pas confondre avec l'échelle d'EXPLOSION ci-dessus.
const FRAG_CHILD_FUSE := 0.4              # mèche du fragment (s), FIXE : ni le tier ni la vitesse d'attaque ne la touchent.
const FRAG_CHILD_FUSE_JITTER := 0.15      # gigue ajoutée à la mèche du fragment (s). Voir _burst_fragments.
const FRAG_CHILD_SMOKE := 4               # fumée du fragment (la mère est à 40 : absurde et coûteux sur 52 px, × 42 fragments).
const FRAG_MOTHER_EXPLOSION_SCALE := 0.5  # l'obus qui éclate : PUREMENT visuel (0 dégât). Un souffle à 1,5 laisserait croire à une grosse explosion inoffensive.

# ⚠️ load() À L'EXÉCUTION, PAS preload() : un fragment EST une BombEntity, donc ce
# script devrait précharger la scène qui porte CE script — c'est une RÉFÉRENCE
# CYCLIQUE, et en Godot 3 elle produit une Compile Error qui invalide TOUT le fichier
# (plus aucune bombe en jeu). Le mod s'est déjà fait avoir deux fois par des cycles de
# ce genre, et les tests ne les voient PAS. load() résout à l'exécution : pas de cycle
# au parse. ResourceLoader met en cache, donc le coût est nul après le premier appel.
const _FRAG_SCENE_PATH := "res://mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.tscn"
```

- [ ] **Step 2: Adapter `arm()` — l'échelle, le skin, la mèche, la fumée**

Dans `arm()`, remplacer :

```gdscript
	_element = p_element
	_weapon = p_weapon
	if _exploding_effect != null:
		_exploding_effect.scale = _explosion_scale
```

par :

```gdscript
	_element = p_element
	_weapon = p_weapon
	# L'obus Frag n'explose que pour la forme (0 dégât) : un souffle à 1,5 laisserait
	# croire à une énorme explosion inoffensive. On le réduit à un éclatement d'obus.
	if BombElement.is_cluster(_element):
		_explosion_scale = FRAG_MOTHER_EXPLOSION_SCALE
	if _exploding_effect != null:
		_exploding_effect.scale = _explosion_scale
		# Fumée coupée sur les fragments : 40 est le réglage d'une bombe pleine taille,
		# absurde et coûteux sur un fragment de 52 px — et il peut y en avoir 42 à
		# l'écran en même temps.
		if _element == BombElement.FRAG_CHILD:
			_exploding_effect.base_smoke_amount = FRAG_CHILD_SMOKE
```

⭐ **Le plafond d'opacité anti-épilepsie : rien à faire, c'est déjà acquis.** `ExplosionVisual.cap_aoe_opacity(_inst)` est appelé **inconditionnellement** dans `_on_fuse_timeout` (ligne 121), et les fragments empruntent exactement ce chemin — ils en héritent donc gratuitement, l'obus mère aussi. **Ne pas dupliquer l'appel.** (Ce qui ne suffit pas, en revanche, c'est le plafond SEUL : voir la gigue à l'étape suivante — il ne protège pas d'une synchronisation.)

Puis remplacer :

```gdscript
	if is_instance_valid(_sprite):
		_sprite.scale = Vector2(1.25, 1.25)
```

par :

```gdscript
	if is_instance_valid(_sprite):
		if _element == BombElement.FRAG_CHILD:
			# ~20 px : compromis entre la grammaire visuelle du mod (la normale est une
			# bille de 60 px pour un souffle de 442 — un rapport de 1 à 7, c'est lui qui
			# donne l'impression de puissance) et la lisibilité (la proportion stricte
			# donnerait 14 px, un grain de poussière invisible dans la mêlée, et on
			# perdrait le télégraphe qui justifie de vraies petites bombes).
			_sprite.scale = Vector2(FRAG_CHILD_SPRITE_SCALE, FRAG_CHILD_SPRITE_SCALE)
		else:
			_sprite.scale = Vector2(1.25, 1.25)
```

Enfin, remplacer le calcul de la mèche :

```gdscript
	var fuse := BombTiming.fuse_seconds_scaled(p_tier, atk_speed_mod)
```

par :

```gdscript
	var fuse: float
	if _element == BombElement.FRAG_CHILD:
		# Mèche COURTE et FIXE : ni le tier ni la vitesse d'attaque ne la touchent. Elle
		# démarre à la détonation de la mère et meurt 0,4 s plus tard.
		#
		# ⭐ La GIGUE règle trois problèmes d'un coup, et n'est PAS cosmétique :
		# 1. ANTI-SCINTILLEMENT — sans elle les 7 fragments détonent dans la MÊME frame.
		#    Le plafond d'opacité ne protège pas d'une SYNCHRONISATION : 7 sprites à
		#    20 % qui se superposent se composent (1-0.8^n) et remontent à ~50 %
		#    d'opacité instantanée. C'est le NOMBRE SIMULTANÉ qui fait le stroboscope,
		#    pas la brillance de chacun.
		# 2. PERFORMANCE — étale la quarantaine de spawns d'explosion sur plusieurs
		#    frames au lieu d'un pic sur une seule.
		# 3. SENSATION — une munition à fragmentation crépite (pop-pop-pop), elle ne
		#    fait pas « boum ». C'est le son signature du cluster.
		#
		# ⚠️⚠️ LA GIGUE EST STRICTEMENT CONFINÉE ICI. Ne JAMAIS en remettre sur le
		# cooldown ni sur la mèche de la bombe MÈRE : on a retiré celle du vanilla lors
		# de la refonte de la pose précisément pour que toutes les armes bombe partagent
		# la même période, donc pour que le déphasage par slot tienne et que la traînée
		# reste propre. La réintroduire annulerait toute cette refonte.
		fuse = FRAG_CHILD_FUSE + rand_range(0.0, FRAG_CHILD_FUSE_JITTER)
	else:
		fuse = BombTiming.fuse_seconds_scaled(p_tier, atk_speed_mod)
```

- [ ] **Step 3: Brancher la dispersion à la détonation**

Dans `_on_fuse_timeout()`, remplacer la ligne finale `queue_free()` (celle qui suit le bloc de la sangsue, tout à la fin de la fonction) par :

```gdscript
	# Frag : l'obus vient d'éclater à 0 dégât (deals_explosion_damage(FRAG) est faux :
	# l'explosion mère n'est qu'un vecteur — repère visuel et son). On projette
	# maintenant les fragments, qui portent TOUT le dégât.
	if BombElement.is_cluster(_element):
		_burst_fragments()
	queue_free()
```

Puis ajouter la fonction à la fin du fichier :

```gdscript
# Frag : projette _stats.nb_projectiles fragments à des positions ALÉATOIRES dans le
# disque de FRAG_SCATTER_RADIUS autour de l'obus.
#
# Chaque fragment est une vraie petite BombEntity d'élément FRAG_CHILD, ce qui lui donne
# gratuitement tout le cycle de vie existant : sprite, mèche, explosion vanilla POOLÉE,
# et surtout l'ATTRIBUTION DES DÉGÂTS à l'arme (on transmet `_weapon`, donc le signal
# hit_something de son explosion remonte à on_weapon_hit_something ->
# RunData.add_weapon_dmg_dealt(weapon_pos), et l'infobulle « dégâts infligés » compte
# juste sans une ligne de plus).
#
# ⭐ Le dégât est passé TEL QUEL, sans rien partager : le `damage` du .tres est déjà le
# dégât PAR FRAGMENT (convention vanilla des armes multi-projectiles — la Foudre porte
# damage 8 + nb_projectiles 6). _explosion_damage_override porte la valeur déjà mise à
# l'échelle par la pose (avec le -75 % de Bomberto ET le bonus d'ingénierie).
#
# ⭐ La garde anti-récursion est STRUCTURELLE : les fragments sont armés en FRAG_CHILD,
# or is_cluster(FRAG_CHILD) est faux — ils ne peuvent donc pas se scinder à leur tour.
# Aucune condition à écrire, aucun compteur de profondeur : c'est impossible par
# construction.
func _burst_fragments() -> void:
	if _stats == null:
		return
	var n := int(_stats.nb_projectiles)
	if n <= 0:
		return
	# Le hasard est tiré ICI et INJECTÉ dans le module pur, qui reste déterministe et
	# testable en headless (même principe que le temps injecté dans BombLeech).
	var randoms := []
	for _i in range(n * BombFrag.RANDOMS_PER_FRAGMENT):
		randoms.append(randf())
	var offsets := BombFrag.scatter_offsets(n, FRAG_SCATTER_RADIUS, randoms)
	var scene = load(_FRAG_SCENE_PATH)
	if scene == null:
		return
	for off in offsets:
		var frag = scene.instance()
		Utils.get_scene_node().add_child(frag)
		frag.global_position = global_position + off
		frag.arm(
			_player_index,
			_stats,
			_tier,
			FRAG_CHILD_EXPLOSION_SCALE,
			_damage_tracking_key_hash,
			_explosion_damage_override,
			BombElement.FRAG_CHILD,
			_weapon
		)
```

- [ ] **Step 4: ⚠️ LE contrôle — aucune erreur de parse ni de compilation**

C'est l'étape la plus importante du plan. Les tests ne chargent jamais ce fichier.

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd 2>&1 | grep -iE "parse error|compile error|bomb_entity|bomb_frag|cyclic"
```
Expected: **sortie VIDE**.

Si une ligne « cyclic reference » ou « Compile Error » apparaît, la cause la plus probable est un `preload` de `bomb_entity.tscn` au lieu du `load()` de l'étape 1 : le script se préchargerait lui-même. Vérifier `_FRAG_SCENE_PATH` et son usage.

- [ ] **Step 5: Lancer les tests pour vérifier qu'ils passent toujours**

Run:
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===`

Run: `git status --short`
Expected: aucun `.tres` étranger modifié.

- [ ] **Step 6: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd
git commit -m "feat(bomberman): detonation en cluster de la bombe frag

L'obus eclate a 0 degat (simple vecteur, repere visuel et son) et projette
nb_projectiles fragments disperses au hasard dans un disque de 150 px.
Chaque fragment est une vraie BombEntity en FRAG_CHILD : il herite ainsi
de tout l'existant, dont l'attribution des degats a l'arme.

Le degat est passe TEL QUEL, sans partage : le damage du .tres est deja
le degat par fragment (convention vanilla).

La garde anti-recursion est structurelle : is_cluster(FRAG_CHILD) est
faux, donc un fragment ne peut pas se scinder. Aucune condition, aucun
compteur de profondeur.

load() et non preload() pour la scene du fragment : un fragment EST une
BombEntity, donc preload serait une reference cyclique — Compile Error
qui invaliderait tout le fichier, et les tests ne le verraient pas.

La gigue sur la meche des fragments n'est pas cosmetique : sans elle les
7 fragments detonent dans la meme frame et le plafond d'opacite ne
protege pas d'une synchronisation (les alphas se composent). Elle etale
aussi le pic de spawns et donne le crepitement du cluster. Elle reste
STRICTEMENT confinee aux fragments : la mere garde sa cadence
deterministe, sinon la refonte de la pose serait annulee.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Vérifications EN JEU (après le plan)

Rien de ce qui suit n'est couvert par les tests — c'est tout ce qui touche aux autoloads du jeu.

- [ ] **Le verrouillage.** Sur une sauvegarde neuve, la Frag n'apparaît **ni en boutique ni au choix d'arme de départ**. C'est le contrôle prioritaire : le même que celui exigé pour la chaîne de défis.
- [ ] **Le déblocage.** Monter une Sangsue au tier IV → le popup de défi se déclenche → la Frag est achetable **à la run suivante** (pas à chaud : comportement vanilla).
- [ ] **La dispersion.** Les fragments tombent bien dans une gerbe autour de l'obus, **pas tous au même endroit** et **pas entassés au centre** (si c'est le cas, la racine carrée a sauté).
- [ ] **Le crépitement.** Les fragments ne détonent pas tous dans la même frame — ça doit faire pop-pop-pop.
- [ ] **⚠️ Le scintillement, pire cas : 6 Frags IV équipées.** ~42 fragments par cycle. Si ça stroboscope, baisser `ExplosionVisual.AOE_OPACITY_CAP` (20 %) ou monter `FRAG_CHILD_FUSE_JITTER`.
- [ ] **⚠️ La performance, même pire cas.** ~40 explosions toutes les ~1,25 s, soit 7× la normale. Les explosions sont poolées et la Foudre lance déjà 60 projectiles par cycle, mais une explosion coûte plus cher (hitbox + particules).
- [ ] **Le sprite du fragment.** La boule de feu vanilla s'affiche bien. ⚠️ **À vérifier sur le VRAI jeu (Steam), pas seulement dans le projet décompilé** — c'est exactement là que le piège du chargeur se révélerait. Si elle est illisible ou lit trop « feu », appliquer le repli : la mère en réduit (une ligne dans `bomb_skin.gd`).
- [ ] **L'infobulle.** « Éclate en N fragments » s'affiche, et « dégâts infligés (dernière vague) » compte bien les fragments.
- [ ] **L'équilibrage.** La Frag doit être forte sur une nuée dense et hasardeuse sur un boss. Si elle domine la normale partout, c'est que le tapis sature : baisser `FRAG_CHILD_EXPLOSION_SCALE` **et recalculer les dégâts** par `(221 / nouveau_rayon_px)²`.
- [ ] **Coop.** Jamais testé sur ce mod depuis le début.

## Hors périmètre

- Rendre le plafond d'opacité configurable (option `explosion_opacity`, prévue en commentaire depuis toujours).
- Une 7ᵉ bombe.
- Le bug coop de la troll bombe (spawn écarté du seul joueur le plus proche).
- Le nettoyage du zip / la release Workshop.
