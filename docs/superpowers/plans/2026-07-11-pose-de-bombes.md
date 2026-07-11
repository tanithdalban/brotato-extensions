# Refonte de la pose de bombes — plan d'implémentation

> **Pour les agents :** SOUS-SKILL REQUIS — utiliser `superpowers:subagent-driven-development` (recommandé) ou `superpowers:executing-plans` pour exécuter ce plan tâche par tâche. Les étapes utilisent des cases à cocher (`- [ ]`).

**Objectif :** remplacer la pose de bombes « sous les pieds du joueur » par une **couronne à éventail** posée à cadence **déterministe**, pour obtenir une traînée régulière derrière le joueur et supprimer l'empilement.

**Architecture :** trois volets. (1) La **cadence** devient prévisible : cooldown figé à 75 dans les 16 `.tres` de stats + suppression de la gigue aléatoire de vanilla, ce qui rend fiable le déphasage par slot qui existe déjà. (2) La **position** est calculée par un nouveau module de **logique pure** (`bomb_placement.gd`) : angle = slot + angle d'or (précession), projeté sur un éventail centré derrière le joueur. (3) L'éventail est piloté par une **mobilité auto-régulante** qui mesure si le déplacement suffit, à lui seul, à espacer les bombes.

**Stack :** GDScript (Godot 3.6), mod ModLoader. Tests = runner maison headless.

**Spec :** `docs/superpowers/specs/2026-07-11-pose-de-bombes-design.md`

## Contraintes globales

- Tout le code, les commentaires et les libellés de commit sont en **français** (convention du dépôt).
- La **logique pure** vit dans `content/logic/`, n'importe **aucune** dépendance jeu (pas d'autoload, pas de `RunData`/`Utils`), et est testée en headless.
- Les tests se lancent **exclusivement** avec :
  ```
  "./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
  ```
  ⚠️ **PAS** `./run-tests.sh` (celui-ci lance les tests de l'autre mod, ShopConfig).
  Succès = la ligne `=== N tests, 0 échec(s) ===`. Les erreurs moteur affichées **après** cette ligne sont la fermeture des autoloads : sans effet.
- Les tests headless ne couvrent **que** la logique pure. Tout ce qui touche `BombWeapon` (autoloads) se vérifie **en jeu**, par l'humain.
- Point de départ des constantes, à **régler en jeu** ensuite : `RADIUS = 64.0`, `MOBILITY_RISE_SECONDS = 0.2`, `MOBILITY_FALL_SECONDS = 0.5`, cooldown `75`.

---

### Task 1 : module de placement (logique pure)

**Fichiers :**
- Créer : `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_placement.gd`
- Modifier : `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces :**
- Consomme : rien (module autonome).
- Produit (utilisé par la Task 3) :
  - `const RADIUS: float`
  - `const MOBILITY_RISE_SECONDS: float`
  - `const MOBILITY_FALL_SECONDS: float`
  - `static func raw_angle(slot_index: int, nb_slots: int, shot_index: int) -> float`
  - `static func mobility_target(move_speed: float, interval_seconds: float, radius: float) -> float`
  - `static func mobility_step(current: float, target: float, delta: float, rise_seconds: float, fall_seconds: float) -> float`
  - `static func fan_half_width(mobility: float) -> float`
  - `static func offset(slot_index: int, nb_slots: int, shot_index: int, last_dir: Vector2, mobility: float, radius: float) -> Vector2`

- [ ] **Étape 1 : écrire les tests qui échouent**

Dans `test/run_tests.gd`, ajouter le `preload` en tête de fichier, à la suite des autres :

```gdscript
const BombPlacement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_placement.gd")
```

Ajouter l'appel dans `_init()`, juste avant la ligne `print("=== %d tests...` :

```gdscript
	_test_bomb_placement()
```

Ajouter la fonction de test en fin de fichier, **avant** `func _check(cond, name):` :

```gdscript
func _test_bomb_placement():
	# --- raw_angle : deux sources d'unicité ---
	# Deux SLOTS différents visent des azimuts différents.
	_check(not _approx(BombPlacement.raw_angle(0, 4, 0), BombPlacement.raw_angle(1, 4, 0)), "placement: slots différents => angles différents")
	# Deux POSES successives d'un MÊME slot visent des azimuts différents.
	# C'est le cas critique : une seule bombe en main (le slot ne différencie rien).
	_check(not _approx(BombPlacement.raw_angle(0, 1, 0), BombPlacement.raw_angle(0, 1, 1)), "placement: poses successives (1 seule bombe) => angles différents")
	_check(not _approx(BombPlacement.raw_angle(0, 1, 1), BombPlacement.raw_angle(0, 1, 2)), "placement: angle d'or ne reboucle pas")
	# Garde-fous : pas de division par zéro.
	_check(BombPlacement.raw_angle(0, 0, 0) == 0.0 or true, "placement: nb_slots 0 => pas de crash")
	_check(BombPlacement.raw_angle(-3, 4, 0) == BombPlacement.raw_angle(0, 4, 0), "placement: slot négatif => traité comme 0")

	# --- mobility_target : « le déplacement suffit-il à espacer les bombes ? » ---
	# Déplacement entre deux poses == 2 x RAYON => mobilité pleine.
	_check(_approx(BombPlacement.mobility_target(128.0, 1.0, 64.0), 1.0), "mobilité: déplacement = 2xRAYON => 1.0")
	# Moitié du seuil => moitié de la mobilité.
	_check(_approx(BombPlacement.mobility_target(64.0, 1.0, 64.0), 0.5), "mobilité: déplacement = RAYON => 0.5")
	# Joueur LENT : l'éventail doit RESTER ouvert (c'est le bug qu'on évite).
	_check(BombPlacement.mobility_target(20.0, 0.1, 64.0) < 0.1, "mobilité: joueur lent => reste basse")
	# BEAUCOUP de bombes : l'intervalle raccourcit => la mobilité baisse aussi.
	var m_1_bombe = BombPlacement.mobility_target(300.0, 1.25, 64.0)
	var m_6_bombes = BombPlacement.mobility_target(300.0, 1.25 / 6.0, 64.0)
	_check(m_6_bombes < m_1_bombe, "mobilité: plus de bombes => intervalle court => mobilité plus basse")
	# Bornes et garde-fous.
	_check(_approx(BombPlacement.mobility_target(9999.0, 1.0, 64.0), 1.0), "mobilité: bornée à 1.0")
	_check(_approx(BombPlacement.mobility_target(0.0, 1.0, 64.0), 0.0), "mobilité: vitesse 0 => 0.0")
	_check(_approx(BombPlacement.mobility_target(100.0, 1.0, 0.0), 0.0), "mobilité: rayon 0 => 0.0 (pas de division par zéro)")
	_check(_approx(BombPlacement.mobility_target(100.0, 0.0, 64.0), 0.0), "mobilité: intervalle 0 => 0.0")

	# --- mobility_step : lissage, montée rapide / descente lente ---
	_check(BombPlacement.mobility_step(0.0, 1.0, 0.1, 0.2, 0.5) > 0.0, "mobilité: monte vers la cible")
	_check(BombPlacement.mobility_step(1.0, 0.0, 0.1, 0.2, 0.5) < 1.0, "mobilité: descend vers la cible")
	# La montée est plus rapide que la descente (constantes 0.2s vs 0.5s).
	var monte = BombPlacement.mobility_step(0.5, 1.0, 0.1, 0.2, 0.5) - 0.5
	var descend = 0.5 - BombPlacement.mobility_step(0.5, 0.0, 0.1, 0.2, 0.5)
	_check(monte > descend, "mobilité: montée plus rapide que descente")
	_check(_approx(BombPlacement.mobility_step(0.5, 1.0, 0.0, 0.2, 0.5), 0.5), "mobilité: delta 0 => inchangé")
	_check(BombPlacement.mobility_step(0.9, 1.0, 10.0, 0.2, 0.5) <= 1.0, "mobilité: bornée haut à 1.0")
	_check(BombPlacement.mobility_step(0.1, 0.0, 10.0, 0.2, 0.5) >= 0.0, "mobilité: bornée bas à 0.0")

	# --- fan_half_width : l'éventail se referme quand la mobilité monte ---
	_check(_approx(BombPlacement.fan_half_width(0.0), PI), "éventail: mobilité 0 => cercle entier (PI)")
	_check(_approx(BombPlacement.fan_half_width(1.0), 0.0), "éventail: mobilité 1 => file stricte (0)")
	_check(BombPlacement.fan_half_width(0.5) < PI and BombPlacement.fan_half_width(0.5) > 0.0, "éventail: mobilité 0.5 => intermédiaire")

	# --- offset : le décalage final ---
	var rayon := 64.0
	var dir := Vector2(1, 0)  # le joueur va vers la DROITE => l'arrière est à GAUCHE
	# La norme du décalage vaut toujours le rayon.
	var o = BombPlacement.offset(0, 1, 0, dir, 0.0, rayon)
	_check(_approx(o.length(), rayon), "placement: norme du décalage = rayon")
	# Mobilité 1 (pleine course) => la bombe part STRICTEMENT derrière (à gauche).
	var arriere = BombPlacement.offset(0, 1, 7, dir, 1.0, rayon)
	_check(_approx(arriere.x, -rayon) and _approx(arriere.y, 0.0), "placement: mobilité 1 => strictement derrière")
	# ... et ce, quel que soit le numéro de pose (l'éventail est fermé).
	var arriere2 = BombPlacement.offset(2, 4, 13, dir, 1.0, rayon)
	_check(_approx(arriere2.x, -rayon) and _approx(arriere2.y, 0.0), "placement: mobilité 1 => derrière, quels que soient slot et pose")
	# Mobilité 0 (à l'arrêt) => les poses successives balaient le cercle : deux poses
	# successives donnent des décalages nettement différents.
	var c0 = BombPlacement.offset(0, 1, 0, dir, 0.0, rayon)
	var c1 = BombPlacement.offset(0, 1, 1, dir, 0.0, rayon)
	_check((c0 - c1).length() > rayon * 0.5, "placement: mobilité 0 => poses successives bien écartées")
	# Direction nulle (début de vague, aucun mouvement mémorisé) : pas de crash.
	var od = BombPlacement.offset(0, 1, 0, Vector2.ZERO, 0.0, rayon)
	_check(_approx(od.length(), rayon), "placement: direction nulle => pas de crash, norme conservée")
```

- [ ] **Étape 2 : lancer les tests pour vérifier qu'ils échouent**

Depuis la racine du dépôt :

```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```

Attendu : **erreur de parsing / de chargement** — le fichier `bomb_placement.gd` n'existe pas encore, donc le `preload` échoue. C'est le comportement attendu à cette étape.

- [ ] **Étape 3 : écrire le module**

Créer `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_placement.gd` :

```gdscript
extends Reference
# Placement des bombes — logique PURE (aucune dépendance jeu, testable en headless).
#
# Deux sources d'espacement, qui se RELAIENT automatiquement :
#   - la DISTANCE parcourue par le joueur entre deux poses ;
#   - l'ANGLE (la couronne autour de lui).
# Quand le déplacement suffit à espacer les bombes, l'éventail se referme derrière le
# joueur (belle file). Quand il ne suffit pas (joueur lent, ou beaucoup de bombes donc
# un intervalle de pose très court), l'éventail reste ouvert et c'est l'angle qui
# fournit l'espacement. Cf. docs/superpowers/specs/2026-07-11-pose-de-bombes-design.md

# Rayon de la couronne, en pixels. Constante FIXE : on ne l'indexe pas sur le rayon
# d'explosion (qui grossit avec l'élémentaire) — sinon les bombes partiraient à des
# centaines de pixels en fin de run et on perdrait la traînée.
const RADIUS := 64.0

# Constantes de temps du lissage de la mobilité. La descente est plus lente que la
# montée : c'est ce qui garde la mémoire de la course pendant le micro-arrêt où la
# bombe est effectivement posée (vanilla interdit de tirer en mouvement).
const MOBILITY_RISE_SECONDS := 0.2
const MOBILITY_FALL_SECONDS := 0.5

# Angle d'or (137,5°) : PI * (3 - sqrt(5)). Il ne reboucle jamais, donc les poses
# successives d'une MÊME arme se répartissent d'elles-mêmes autour du cercle sans
# retomber au même endroit. C'est ce qui règle le cas critique d'UNE SEULE bombe en
# main, où l'index de slot ne différencie rien.
const GOLDEN_ANGLE := 2.399963229728653


# Azimut brut d'une pose, AVANT repliement vers l'arrière.
# Combine le slot de l'arme (deux armes ne visent pas le même azimut) et une
# précession par angle d'or à chaque pose.
static func raw_angle(slot_index: int, nb_slots: int, shot_index: int) -> float:
	var slots := int(max(1, nb_slots))
	var i := slot_index
	if i < 0:
		i = 0
	var slot_term := TAU * (float(i % slots) / float(slots))
	return slot_term + GOLDEN_ANGLE * float(shot_index)


# « Le déplacement suffit-il, à lui seul, à espacer les bombes ? » -> [0, 1].
# Seuil = 2 x rayon (le DIAMÈTRE de la couronne, soit l'espacement qu'elle fournirait
# à elle seule). Retourne 0 si un paramètre est nul (pas de division par zéro).
static func mobility_target(move_speed: float, interval_seconds: float, radius: float) -> float:
	if move_speed <= 0.0 or interval_seconds <= 0.0 or radius <= 0.0:
		return 0.0
	var travelled := move_speed * interval_seconds
	return clamp(travelled / (2.0 * radius), 0.0, 1.0)


# Lissage temporel de la mobilité vers sa cible. Montée et descente ont des constantes
# de temps distinctes. Borné dans [0, 1]. delta = 0 -> inchangé.
static func mobility_step(current: float, target: float, delta: float, rise_seconds: float, fall_seconds: float) -> float:
	if delta <= 0.0:
		return clamp(current, 0.0, 1.0)
	var seconds := rise_seconds if target > current else fall_seconds
	if seconds <= 0.0:
		return clamp(target, 0.0, 1.0)
	var t := clamp(delta / seconds, 0.0, 1.0)
	return clamp(current + (target - current) * t, 0.0, 1.0)


# Demi-ouverture de l'éventail, centré derrière le joueur.
# Mobilité 0 -> PI (cercle entier : la couronne). Mobilité 1 -> 0 (file stricte).
static func fan_half_width(mobility: float) -> float:
	return PI * (1.0 - clamp(mobility, 0.0, 1.0))


# Décalage à appliquer à la position du joueur pour poser la bombe.
# `last_dir` = dernière direction de déplacement connue (non normalisée acceptée).
static func offset(slot_index: int, nb_slots: int, shot_index: int, last_dir: Vector2, mobility: float, radius: float) -> Vector2:
	# L'arrière du joueur. Direction nulle (début de vague) -> axe arbitraire : sans
	# conséquence, car la mobilité vaut alors 0 et l'éventail est un cercle complet.
	var rear := Vector2.RIGHT
	if last_dir.length() > 0.0001:
		rear = -last_dir.normalized()

	# On projette l'azimut brut sur l'éventail : t ∈ [-1, 1] -> +/- la demi-ouverture.
	var t := wrapf(raw_angle(slot_index, nb_slots, shot_index), -PI, PI) / PI
	var angle := rear.angle() + t * fan_half_width(mobility)
	return Vector2(cos(angle), sin(angle)) * radius
```

- [ ] **Étape 4 : relancer les tests pour vérifier qu'ils passent**

```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```

Attendu : la ligne `=== N tests, 0 échec(s) ===` (N passe de 104 à environ 128).

- [ ] **Étape 5 : commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_placement.gd Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): logique pure de placement des bombes (couronne à éventail)

Angle = slot + angle d'or (précession à chaque pose : règle le cas critique
d'une seule bombe en main), projeté sur un éventail centré derrière le joueur.

La mobilité mesure « le déplacement suffit-il à espacer les bombes ? »
(seuil = 2 x rayon = le diamètre de la couronne) : les deux sources d'espacement,
la distance parcourue et l'angle, se relaient automatiquement.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2 : cadence déterministe

**Fichiers :**
- Modifier (16) : `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_{1,2,3,4}_stats.tres`, `bomb_ice_{1,2,3,4}_stats.tres`, `bomb_poison_{1,2,3,4}_stats.tres`, `bomb_storm_{1,2,3,4}_stats.tres`
- Modifier : `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd`

**Interfaces :**
- Consomme : rien.
- Produit : `BombWeapon.get_next_cooldown(at_wave_begin: bool = false) -> float` — cooldown **déterministe**, égal à `current_stats.cooldown`. La Task 3 s'appuie sur le fait que **toutes** les armes bombe partagent désormais la même période.

**Contexte (à ne pas re-dériver) :** vanilla bruite chaque cooldown à chaque tir
(`weapons/weapon.gd:337-354`, `rand_range` de ±33 % avec 6 armes) afin de désynchroniser
des armes identiques. Cette gigue pulvérise notre déphasage par slot. On la retire pour
nos bombes uniquement.

- [ ] **Étape 1 : figer le cooldown à 75 dans les 16 fichiers de stats**

Chaque fichier contient une ligne `cooldown = <valeur>` (aujourd'hui 90, 80, 70 ou 60
selon le tier). La remplacer par `cooldown = 75`.

```bash
cd Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb
for f in bomb_1_stats.tres bomb_2_stats.tres bomb_3_stats.tres bomb_4_stats.tres \
         bomb_ice_1_stats.tres bomb_ice_2_stats.tres bomb_ice_3_stats.tres bomb_ice_4_stats.tres \
         bomb_poison_1_stats.tres bomb_poison_2_stats.tres bomb_poison_3_stats.tres bomb_poison_4_stats.tres \
         bomb_storm_1_stats.tres bomb_storm_2_stats.tres bomb_storm_3_stats.tres bomb_storm_4_stats.tres; do
  sed -i 's/^cooldown = .*$/cooldown = 75/' "$f"
done
grep -h "^cooldown = " *_stats.tres | sort | uniq -c
```

Attendu : `16 cooldown = 75` (une seule valeur distincte).

- [ ] **Étape 2 : supprimer la gigue dans `bomb_weapon.gd`**

Ajouter cette méthode dans `bomb_weapon.gd`, **juste avant** la section
`# --- Déphasage par slot ("train de bombes") ---` :

```gdscript
# Surcharge : cooldown DÉTERMINISTE (pas de rand_range).
#
# Vanilla (weapon.gd:337-354) bruite le cooldown à CHAQUE tir — jusqu'à ±33 % avec 6
# armes — pour désynchroniser des armes identiques. Chez nous, cette gigue pulvérise le
# déphasage par slot (slot_phase_offset) en quelques cycles : le « train de bombes »
# ne tient jamais. On la retire : toutes les armes bombe partagent le même cooldown
# (75) et restent donc en phase toute la vague.
#
# La seule chose qui module encore ce cooldown est la vitesse d'attaque, qui est une
# stat du JOUEUR : elle s'applique à l'identique à toutes ses armes bombe (nos .tres
# gardent attack_speed_mod = 0), donc elle ne les désynchronise pas.
#
# On ne perd rien de la logique vanilla : `is_big_reload_active` dépend de
# `additional_cooldown_every_x_shots`, qui vaut -1 (désactivé) dans tous nos .tres ; et
# le plafond `at_wave_begin` ne s'applique qu'au-delà de 180, très loin de nos 75.
func get_next_cooldown(_at_wave_begin: bool = false) -> float:
	return current_stats.cooldown
```

- [ ] **Étape 3 : lancer les tests (non-régression)**

```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```

Attendu : `=== N tests, 0 échec(s) ===`, avec le même N que la Task 1 (ces changements
ne sont pas couverts en headless — ils touchent des `.tres` et une méthode qui a besoin
des autoloads ; le test sert ici de garde-fou contre une erreur de syntaxe).

- [ ] **Étape 4 : commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/
git commit -m "feat(bomberman): cadence de pose déterministe (cooldown figé à 75)

Cooldown 90/80/70/60 par tier -> 75 pour les 16 armes bombe, et surcharge de
get_next_cooldown() pour retirer la gigue aléatoire de vanilla (weapon.gd:337-354,
rand_range jusqu'à ±33 %, destinée à désynchroniser des armes identiques).

Toutes les armes bombe partagent désormais la même période, donc le déphasage par
slot tient toute la vague. La vitesse d'attaque est une stat du JOUEUR : elle
s'applique identiquement à toutes ses bombes et ne les désynchronise pas.

Contrepartie assumée : monter en tier n'accélère plus la pose. La progression
subsiste ailleurs (dégâts, mèche, DOT, nombre d'éclairs, % de ralentissement).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3 : câblage dans l'arme

**Fichiers :**
- Modifier : `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd`

**Interfaces :**
- Consomme : `BombPlacement.RADIUS`, `.MOBILITY_RISE_SECONDS`, `.MOBILITY_FALL_SECONDS`, `.mobility_target()`, `.mobility_step()`, `.offset()` (Task 1) ; le cooldown déterministe (Task 2).
- Produit : rien (feuille de l'arbre).

**Contexte (à ne pas re-dériver) :**
- ⚠️ **Le joueur PEUT poser en mouvement.** `weapon.gd:273-283` se lit « ne tire que si
  immobile, **sauf** effet `can_attack_while_moving` » — mais cet effet vaut **1 par
  défaut pour tout joueur** (`singletons/player_run_data.gd:498`). L'exception est la
  règle. `_parent._current_movement` est donc **non nul** au moment de la pose, dans le
  cas courant.
- La mémoire du mouvement sert donc à **lisser** (le kiting est un va-et-vient
  permanent : sans lissage, l'éventail claquerait du cercle à la file à chaque freinage)
  et à **conserver une direction** quand le joueur est réellement à l'arrêt (où
  `_current_movement` vaut `Vector2.ZERO`).
- `_parent._current_movement` (`entities/units/unit/unit.gd:36`) est le **vecteur
  d'entrée**, pas une vitesse. La vitesse réelle se lit avec `_parent.get_move_speed()`
  (`unit.gd:222`).
- `_parent.current_weapons` (`entities/units/player/player.gd:22`) est la liste des
  armes du joueur — **toutes** armes confondues. Le déphasage et l'intervalle doivent
  raisonner sur les **bombes uniquement** : Bomberto peut acheter des lance-roquettes.
- `Weapon._physics_process(delta)` (`weapon.gd:179`) est la frame où le cooldown se
  décrémente : c'est le bon endroit pour entretenir la mémoire du mouvement.
- `_nb_shots_taken` est incrémenté en **première ligne** de notre `shoot()` : au moment
  du calcul de position, il vaut donc déjà le numéro de la pose courante.

- [ ] **Étape 1 : ajouter le preload et l'état**

En tête de `bomb_weapon.gd`, à la suite des autres `const` de preload :

```gdscript
const BombPlacement = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_placement.gd")
```

Puis, juste après la constante `FROST_OUTLINE_COLOR`, ajouter l'état de la mémoire de
mouvement :

```gdscript
# --- Mémoire du mouvement (pour orienter la traînée) ---
# Le joueur PEUT poser en mouvement : weapon.gd:273-283 se lit « ne tire que si immobile,
# SAUF can_attack_while_moving », mais cet effet vaut 1 PAR DÉFAUT pour tout joueur
# (player_run_data.gd:498). _current_movement est donc non nul au moment de la pose.
# On entretient quand même une mémoire, à chaque frame, pour deux raisons :
#   - LISSER : le kiting est un va-et-vient permanent ; sans lissage, l'éventail
#     claquerait du cercle complet à la file stricte à chaque freinage ;
#   - GARDER UNE DIRECTION quand le joueur est réellement à l'arrêt (_current_movement
#     vaut alors Vector2.ZERO et il n'y a plus rien à lire).
var _last_dir := Vector2.ZERO
var _mobility := 0.0
```

- [ ] **Étape 2 : entretenir la mémoire à chaque frame**

Ajouter cette méthode dans `bomb_weapon.gd`, juste après `_clear_hitbox_signal_dupes()` :

```gdscript
# Surcharge : on laisse vanilla faire son travail (décrément du cooldown, visée), puis
# on met à jour la mémoire du mouvement du joueur.
func _physics_process(delta: float) -> void:
	._physics_process(delta)
	_update_movement_memory(delta)


# Mémoire du mouvement, mise à jour CHAQUE frame (et pas seulement au moment du tir) :
# c'est ce qui lisse le va-et-vient du kiting et conserve une direction à l'arrêt.
func _update_movement_memory(delta: float) -> void:
	if not is_instance_valid(_parent):
		return

	var movement = _parent._current_movement
	var is_moving: bool = movement != Vector2.ZERO
	if is_moving:
		_last_dir = movement.normalized()

	# Cible de mobilité : « le déplacement suffit-il, à lui seul, à espacer les
	# bombes ? ». Nulle si le joueur est à l'arrêt.
	var target := 0.0
	if is_moving:
		target = BombPlacement.mobility_target(
			_parent.get_move_speed(),
			_placement_interval_seconds(),
			BombPlacement.RADIUS
		)

	_mobility = BombPlacement.mobility_step(
		_mobility,
		target,
		delta,
		BombPlacement.MOBILITY_RISE_SECONDS,
		BombPlacement.MOBILITY_FALL_SECONDS
	)


# Intervalle réel entre deux poses de bombe, TOUTES bombes confondues, en secondes.
# Les armes bombe étant entrelacées et de même période, il tombe une bombe tous les
# `cooldown / nb_bombes` frames. Le cooldown est en FRAMES (weapon.gd:193 le décrémente
# de 60 x delta), d'où la division par 60.
func _placement_interval_seconds() -> float:
	var nb := _bomb_slot_count()
	if nb <= 0:
		nb = 1
	return (current_stats.cooldown / float(nb)) / 60.0
```

- [ ] **Étape 3 : compter et indexer les BOMBES, pas toutes les armes**

Remplacer intégralement les deux méthodes existantes `_bomb_slot_index()` et
`_bomb_slot_count()` par les versions ci-dessous. L'ancienne version utilisait
`weapon_pos` et `_parent.get_nb_weapons()`, qui comptent **toutes** les armes : un
Bomberto portant 3 bombes et 3 lance-roquettes se déphasait sur 6 slots au lieu de 3, et
l'intervalle de pose était faux.

```gdscript
# Liste des armes BOMBE actuellement équipées par le joueur, dans l'ordre des slots.
# `current_weapons` (player.gd:22) contient TOUTES les armes : Bomberto peut acheter des
# lance-roquettes ou des armes de mêlée à knockback. Seules les bombes s'entrelacent.
func _bomb_weapons() -> Array:
	var out := []
	if not is_instance_valid(_parent):
		return out
	for w in _parent.current_weapons:
		if w is BombWeapon:
			out.push_back(w)
	return out


# Index de CETTE arme parmi les seules armes bombe du joueur.
# Retourne -1 si introuvable (garde-fou : slot_phase_offset renverra alors 0).
func _bomb_slot_index() -> int:
	var bombs := _bomb_weapons()
	for i in bombs.size():
		if bombs[i] == self:
			return i
	return -1


# Nombre d'armes BOMBE équipées.
func _bomb_slot_count() -> int:
	return _bomb_weapons().size()
```

- [ ] **Étape 4 : poser la bombe sur la couronne**

Dans `shoot()`, remplacer la ligne :

```gdscript
	bomb.global_position = _parent.global_position
```

par :

```gdscript
	# Position sur la couronne à éventail, plutôt que sous les pieds du joueur.
	# `_nb_shots_taken` vient d'être incrémenté ci-dessus : c'est le numéro de la pose.
	bomb.global_position = _parent.global_position + BombPlacement.offset(
		_bomb_slot_index(),
		_bomb_slot_count(),
		_nb_shots_taken,
		_last_dir,
		_mobility,
		BombPlacement.RADIUS
	)
```

- [ ] **Étape 5 : lancer les tests (non-régression)**

```
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```

Attendu : `=== N tests, 0 échec(s) ===`. Ce câblage n'est **pas** couvert en headless (il
a besoin des autoloads) : le test sert de garde-fou contre une erreur de syntaxe.

- [ ] **Étape 6 : commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd
git commit -m "feat(bomberman): pose des bombes sur la couronne à éventail

BombWeapon entretient à chaque frame (_physics_process) la dernière direction de
déplacement et une mobilité lissée, puis pose la bombe avec BombPlacement.offset()
au lieu de la lâcher sous les pieds du joueur.

La mémoire est indispensable : vanilla interdit de tirer en mouvement
(weapon.gd:273-283), donc _current_movement est NUL au moment exact de la pose.
La descente plus lente que la montée garde le souvenir de la course pendant le
micro-arrêt où la bombe tombe réellement.

Corrige au passage le déphasage : il comptait TOUTES les armes (get_nb_weapons)
alors que seules les BOMBES s'entrelacent — un Bomberto avec 3 bombes et 3
lance-roquettes se déphasait sur 6 slots au lieu de 3.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4 : build local pour le réglage en jeu

**Fichiers :** aucun (livraison).

- [ ] **Étape 1 : retirer les `.png.import` régénérés**

⚠️ Chaque lancement du runner (`Godot --path Brotato`) **réimporte les assets** et
régénère les `.png.import` des sprites chargés au runtime. Le script de build embarque
alors un `.stex` inutile pour chacun (~83 KB de poids mort).

```bash
cd Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb
rm -f bombe_normale.png.import glace.png.import poison.png.import storm.png.import
```

- [ ] **Étape 2 : construire et déposer le mod**

```
tools/build-bomberman.ps1
```

Attendu : `OK -> dist\Tanith-Bomberman.zip` puis `Depose -> D:\SteamLibrary\...\mods-unpacked\Tanith-Bomberman`.

- [ ] **Étape 3 : vérifications EN JEU (humain)**

Ces points ne sont **pas** testables en headless :

- **Cas critique — une seule bombe en main** : les bombes ne doivent **jamais** se
  superposer, même joueur immobile (c'est la précession par angle d'or qui l'assure).
- **Couronne à l'arrêt** : campé sur place, les bombes entourent le joueur.
- **Traînée en course** : en kiting rapide, un chapelet régulier se forme derrière.
- **Joueur lent / six bombes** : l'éventail doit **rester ouvert** et les bombes
  s'éparpiller autour — surtout **pas** se tasser derrière (c'est le piège que la
  mobilité auto-régulante est censée éviter).
- **Cadence** : ressenti du cooldown figé à 75 (le tier IV ne mitraille plus).
- **Réglage** : ajuster `RADIUS` (64 px), `MOBILITY_RISE_SECONDS` (0,2 s) et
  `MOBILITY_FALL_SECONDS` (0,5 s) dans `bomb_placement.gd` selon le ressenti.
- **Coop** : chaque joueur a sa propre mémoire de mouvement (elle vit sur l'arme, donc
  par joueur par construction) — vérifier qu'un joueur n'oriente pas la traînée de
  l'autre.
