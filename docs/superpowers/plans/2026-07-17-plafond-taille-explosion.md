# Plafond de taille d'explosion des bombes — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Borner le rayon d'explosion des bombes de Bomberto à 512 px (25 % de la map de départ classique 2048), en plafonnant le facteur de grossissement dû à la stat `explosion_size`.

**Architecture:** Un helper PUR (`ExplosionVisual.cap_growth_scale`) calcule l'échelle plafonnée `min(échelle_courante, base × facteur_max)`, testé en headless. `bomb_entity` l'appelle sur l'instance d'explosion juste après `WeaponService.explode`, à côté du plafond d'opacité déjà en place. Le plafond porte sur le FACTEUR (pas la taille absolue), donc il reste proportionnel à la taille de base de chaque bombe (la normale plafonne à 512 px, un fragment à ~119 px).

**Tech Stack:** Godot 3.7 / GDScript 3, ModLoader 6.3.0 (script extensions uniquement), runner de tests `SceneTree` autonome (pas de GUT).

**Spec:** `docs/superpowers/specs/2026-07-17-plafond-taille-explosion-design.md` — à lire avant de commencer.

## Global Constraints

- **Langue** : tout en français — commentaires, docs, libellés de commits.
- **GDScript 3, pas 4** : pas de `static var`, pas de lambdas, pas de typed arrays, `.methode()` pour appeler le parent, `Vector2` natif.
- **Logique pure = 100 % statique, aucune dépendance jeu** : `explosion_visual.gd` reste un module pur (`extends Reference`), testable en headless.
- **Valeurs figées par la spec, à ne pas « améliorer »** : `MAX_EXPLOSION_GROWTH = 2.32` (= 512 px / 221 px). C'est la seule valeur d'équilibrage. Le rayon de la normale non buffée (221 px = échelle 1,5) et la map classique (2048 px de large) sont les données de dérivation.

- **Commande de test** (⚠️ celle de Bomberman, PAS `./run-tests.sh` qui est ShopConfig).

  ⚠️⚠️ **NE PAS utiliser le wrapper `Godot_v3.6.2-stable_win64_console.cmd`** : il se termine par un `pause > nul` qui **bloque indéfiniment** toute capture de sortie synchrone sous Windows natif. **Appeler l'exe directement** :
  ```powershell
  $root = "C:\Users\tanit\claudecode\claude\workspace\brotato-extension"
  $p = Start-Process -FilePath (Join-Path $root "Godot_v3.6.2-stable_win64.exe\Godot_v3.6.2-stable_win64.exe") -WorkingDirectory $root `
    -ArgumentList '--path','Brotato','--no-window','-s','res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd' `
    -RedirectStandardOutput out.txt -RedirectStandardError err.txt -PassThru -NoNewWindow
  $p.WaitForExit(60000); Get-Content out.txt
  ```
  Code de sortie = nombre d'échecs. La ligne qui compte : `=== N tests, M échec(s) ===`. Les `SCRIPT ERROR` affichés APRÈS cette ligne sont la fermeture des autoloads (progress_data/cursor_manager) : sans effet.

- **⚠️⚠️ CONTRÔLE OBLIGATOIRE après TOUTE modification de `bomb_entity.gd`** : la suite de tests ne charge **jamais** ce fichier (il dépend des autoloads). Une erreur de parse/compilation y est **invisible, tests au vert**. Passer la sortie du runner au grep :
  ```
  <commande de test> 2>&1 | grep -iE "parse error|compile error|cyclic|bomb_entity"
  ```
  **Doit être VIDE** (les lignes ModLoader « Installing script extension ... item_service » ne comptent pas — c'est l'inverse : l'extension s'installe, donc elle compile).

- **⚠️ Corruption du jeu décompilé** : lancer le runner régénère les `.png.import` et peut supprimer des `ext_resource` PNG de certains `.tres`. Vérifier `git status` après chaque passage ; un `.tres` étranger modifié = alarme (`git checkout` dessus).

---

## File Structure

| Fichier | Responsabilité | Action |
|---|---|---|
| `content/logic/explosion_visual.gd` | Ajoute la constante `MAX_EXPLOSION_GROWTH` et le helper PUR `cap_growth_scale`. | Modifier |
| `test/run_tests.gd` | Preload `ExplosionVisual` + tests purs du helper. | Modifier |
| `content/entities/bomb_entity.gd` | Applique le plafond sur l'instance d'explosion après `explode`. | Modifier |

---

## Task 1: Logique pure — l'échelle d'explosion plafonnée

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/explosion_visual.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Consumes: rien (module autonome).
- Produces:
  - `ExplosionVisual.MAX_EXPLOSION_GROWTH : float` = `2.32` — facteur de grossissement maximal.
  - `ExplosionVisual.cap_growth_scale(current_scale: Vector2, base_scale: float) -> Vector2` — retourne `current_scale` avec chaque composante clampée à `base_scale × MAX_EXPLOSION_GROWTH`.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter le preload en haut du fichier, juste après la ligne `const BombFrag = ...` (ligne 18) :

```gdscript
const ExplosionVisual = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/explosion_visual.gd")
```

Ajouter l'appel dans `_init()`, juste après `_test_bomb_frag()` (ligne 66) :

```gdscript
	_test_explosion_visual()
```

Ajouter la fonction de test à la fin du fichier, juste avant `func _check(cond, name):` :

```gdscript
func _test_explosion_visual() -> void:
	# ⚠️ Signature du helper existant : _check(cond, name) — la CONDITION d'abord.

	# base 1.5 (bombe normale), facteur 2.32 => échelle plafond = 3.48.
	var cap_normal = 1.5 * ExplosionVisual.MAX_EXPLOSION_GROWTH

	# --- Sous le plafond : inchangé. ---
	var below = ExplosionVisual.cap_growth_scale(Vector2(2.0, 2.0), 1.5)
	_check(_approx(below.x, 2.0) and _approx(below.y, 2.0), "explosion: sous le plafond => échelle inchangée")

	# --- Au-dessus : clampé à base * MAX (les DEUX composantes). ---
	var above = ExplosionVisual.cap_growth_scale(Vector2(10.0, 10.0), 1.5)
	_check(_approx(above.x, cap_normal) and _approx(above.y, cap_normal), "explosion: au-dessus => clampé à base*2.32")

	# --- Pile au plafond : inchangé (c'est un min). ---
	var at = ExplosionVisual.cap_growth_scale(Vector2(cap_normal, cap_normal), 1.5)
	_check(_approx(at.x, cap_normal) and _approx(at.y, cap_normal), "explosion: pile au plafond => inchangé")

	# --- Fragment (base 0.35) : plafond PROPORTIONNELLEMENT plus petit. ---
	# C'est tout l'intérêt de plafonner le FACTEUR et pas la taille absolue :
	# le fragment reste petit (~119 px), jamais un tapis de gros cercles.
	var cap_frag = 0.35 * ExplosionVisual.MAX_EXPLOSION_GROWTH
	var frag = ExplosionVisual.cap_growth_scale(Vector2(5.0, 5.0), 0.35)
	_check(_approx(frag.x, cap_frag) and _approx(frag.y, cap_frag), "explosion: fragment clampé à 0.35*2.32 (reste petit)")
	_check(cap_frag < cap_normal, "explosion: plafond fragment < plafond normale (proportionnel)")

	# --- Clamp INDÉPENDANT par composante. ---
	var mixed = ExplosionVisual.cap_growth_scale(Vector2(2.0, 10.0), 1.5)
	_check(_approx(mixed.x, 2.0) and _approx(mixed.y, cap_normal), "explosion: clamp par composante")

	# --- Garde-fou : base 0 => plafond 0, pas de crash (dégénéré mais sûr). ---
	var zero = ExplosionVisual.cap_growth_scale(Vector2(3.0, 3.0), 0.0)
	_check(_approx(zero.x, 0.0) and _approx(zero.y, 0.0), "explosion: base 0 => échelle 0, pas de crash")

	# --- Verrou de la valeur d'équilibrage : 2.32 cale la normale à ~512 px. ---
	# Rayon normale non buffée = 221 px (échelle 1.5) ; au plafond 221*2.32 ≈ 513
	# = 25 % de la map classique (2048). Ce test échoue si quelqu'un change 2.32.
	_check(_approx(ExplosionVisual.MAX_EXPLOSION_GROWTH, 2.32), "explosion: facteur = 2.32 (normale ~512 px = 25% map)")
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run la commande de test (cf. Global Constraints).
Expected: FAIL sur les `explosion:` — `cap_growth_scale` et `MAX_EXPLOSION_GROWTH` n'existent pas encore (erreur « Invalid call » / « Invalid get index MAX_EXPLOSION_GROWTH »).

- [ ] **Step 3: Écrire le module**

Dans `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/explosion_visual.gd`, ajouter à la FIN du fichier (après `cap_aoe_opacity`) :

```gdscript


# --- Plafond de TAILLE de nos explosions (borne l'inflation par explosion_size) ---
#
# La stat joueur `explosion_size` gonfle le rayon dans player_explosion.set_area :
#   scale = base * (1 + explosion_size/100).
# Chez Bomberto elle monte SANS borne (+5 par point d'élémentaire, + le Pot de miel,
# + tout objet à explosion_size) et l'explosion finit par couvrir toute la map. On
# plafonne le FACTEUR de grossissement, PAS la taille absolue : la borne s'exprime
# `base * MAX_EXPLOSION_GROWTH`, donc elle reste PROPORTIONNELLE à la taille de base de
# chaque bombe. La normale (base 1.5) plafonne à 512 px ; un fragment (base 0.35) à
# ~119 px — les fragments ne deviennent jamais un tapis de gros cercles couvrant la map.
#
# 2.32 = 512 px (25 % de la map de départ classique, 2048 de large) / 221 px (rayon de
# la bombe normale NON buffée, échelle 1.5). Seule valeur d'équilibrage : la monter
# agrandit le plafond, la descendre le resserre.
const MAX_EXPLOSION_GROWTH := 2.32


# Échelle d'explosion plafonnée : chaque composante clampée à base_scale * MAX_EXPLOSION_GROWTH.
# `base_scale` = l'échelle de BASE de la bombe (avant l'inflation par explosion_size),
# soit le _explosion_scale que bomb_entity a passé à l'effet. Pur, testable en headless.
static func cap_growth_scale(current_scale: Vector2, base_scale: float) -> Vector2:
	var cap := base_scale * MAX_EXPLOSION_GROWTH
	return Vector2(min(current_scale.x, cap), min(current_scale.y, cap))
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run la commande de test.
Expected: `=== N tests, 0 échec(s) ===` — tous les `_test_explosion_visual` en `ok :`.

- [ ] **Step 5: Vérifier qu'aucun `.tres` n'a été corrompu**

Run: `git status --short`
Expected: seuls `explosion_visual.gd` et `run_tests.gd` apparaissent. **Aucun `.tres` étranger.**

- [ ] **Step 6: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/explosion_visual.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): logique pure du plafond de taille d'explosion

Plafonne le FACTEUR de grossissement (1 + explosion_size/100), pas la
taille absolue : la borne s'exprime base * MAX_EXPLOSION_GROWTH, donc elle
reste proportionnelle a la taille de base de chaque bombe. La normale
plafonne a 512 px (25% de la map classique), un fragment a ~119 px.

2.32 = 512 / 221 (rayon de la normale non buffee). Un test verrouille la
valeur. Hasard/temps non concernes : pur clamp Vector2, testable headless.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Appliquer le plafond à la détonation

**Contexte :** `bomb_entity.gd` crée l'instance d'explosion via `WeaponService.explode`, qui appelle `player_explosion.set_area` → pose `_inst.scale = _explosion_scale × (1 + explosion_size/100)`. On reclampe cette échelle juste après, au même endroit que le plafond d'opacité. ⚠️ **Les tests ne chargent JAMAIS `bomb_entity.gd`** — le grep de l'étape finale est le seul filet.

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd:186`

**Interfaces:**
- Consumes: `ExplosionVisual.cap_growth_scale(current_scale, base_scale)` (Task 1). `ExplosionVisual` est **déjà preloadé** dans `bomb_entity.gd` (ligne 7). `_explosion_scale` est un membre existant (l'échelle de base de la bombe, réglée dans `arm()`).
- Produces: rien (point d'aboutissement).

- [ ] **Step 1: Insérer le clamp après le plafond d'opacité**

Dans `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd`, remplacer :

```gdscript
	# Anti-épilepsie : plafonne l'opacité du sprite d'AOE (ne touche pas les dégâts).
	ExplosionVisual.cap_aoe_opacity(_inst)
```

par :

```gdscript
	# Anti-épilepsie : plafonne l'opacité du sprite d'AOE (ne touche pas les dégâts).
	ExplosionVisual.cap_aoe_opacity(_inst)
	# Plafond de TAILLE : borne l'inflation de l'explosion par la stat explosion_size
	# (élémentaire de Bomberto, Pot de miel…), qui autrement fait couvrir toute la map.
	# player_explosion.set_area a posé _inst.scale = _explosion_scale * (1 + explosion_size/100) ;
	# on reclampe au facteur max. Contrairement au plafond d'opacité, ce clamp réduit
	# AUSSI la zone de dégâts (la hitbox suit l'échelle de la racine) — c'est voulu, c'est
	# bien la TAILLE de l'explosion qu'on borne. _explosion_scale porte la base de CETTE
	# bombe (1.5 normale, 0.5 obus Frag, 0.35 fragment), donc le plafond reste proportionnel.
	if _inst != null:
		_inst.scale = ExplosionVisual.cap_growth_scale(_inst.scale, _explosion_scale)
```

- [ ] **Step 2: ⚠️ LE contrôle — aucune erreur de parse ni de compilation**

C'est l'étape la plus importante : les tests ne chargent jamais ce fichier.

Run: `<commande de test> 2>&1 | grep -iE "parse error|compile error|cyclic|bomb_entity"`
Expected: **sortie VIDE** (hors la ligne ModLoader « Installing script extension … bomb… » s'il y en a — mais `bomb_entity` n'y figure pas ; toute vraie erreur de parse/compile y apparaîtrait).

- [ ] **Step 3: Lancer les tests pour vérifier qu'ils passent toujours**

Run la commande de test.
Expected: `=== N tests, 0 échec(s) ===` (inchangé par rapport à la Task 1 : `bomb_entity` n'est pas testé, mais un plantage de parse ferait chuter le chargement du mod — le grep ci-dessus est le vrai filet).

Run: `git status --short`
Expected: seul `bomb_entity.gd` apparaît. **Aucun `.tres` étranger.**

- [ ] **Step 4: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd
git commit -m "feat(bomberman): plafonne la taille d'explosion des bombes en jeu

Reclampe _inst.scale a _explosion_scale * MAX_EXPLOSION_GROWTH juste apres
explode, au meme endroit que le plafond d'opacite. La stat explosion_size
(elementaire de Bomberto, Pot de miel) gonflait le rayon sans borne
jusqu'a couvrir toute la map ; il plafonne desormais a 512 px (25% de la
map classique). Le clamp reduit aussi la zone de degats (la hitbox suit
l'echelle), ce qui est voulu.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Vérifications EN JEU (après le plan)

Non couvertes par les tests (touchent les autoloads du jeu) :

- [ ] **Le plafond.** Monter l'élémentaire très haut (ou empiler les Pots de miel) : l'explosion de la bombe normale **cesse de grandir** une fois ~27 élém atteints et ne dépasse jamais ~1/4 de la map.
- [ ] **La zone de dégâts suit.** Vérifier que la borne réduit bien la portée réelle (les ennemis hors du cercle plafonné ne sont plus touchés), pas seulement le visuel.
- [ ] **Les fragments restent petits.** Même à fort élémentaire, les explosions de fragments restent modestes (~119 px), pas un tapis de gros cercles.
- [ ] **Les bombes à effet.** Glace/poison/sangsue : leur zone d'effet (slow/DOT/drain) est bornée pareil (pas un champ grand comme la map).
- [ ] **Non-régression.** Sans investissement élémentaire, les explosions gardent leur taille habituelle (le plafond ne mord pas en dessous de ~27 élém).

## Hors périmètre

- Modifier l'effet `explosion_size`-par-élémentaire de Bomberto (on le garde, il sert au ressenti jusqu'au plafond).
- Recalculer le plafond selon la zone/map courante (figé sur la map classique, choix utilisateur).
- Toucher à l'étalement des fragments (150 px, constant).
