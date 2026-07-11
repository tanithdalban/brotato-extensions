# Refonte de la pose de bombes — design

**Date** : 2026-07-11
**Mod** : Tanith-Bomberman
**Statut** : design validé, à implémenter

## Le problème

Aujourd'hui, `BombWeapon.shoot()` pose la bombe exactement sous le joueur :

```gdscript
bomb.global_position = _parent.global_position
```

Trois symptômes en découlent :

1. **Empilement.** Joueur immobile = toutes les bombes au même pixel. Leurs zones
   d'effet se confondent : si la bombe normale nettoie la zone, les bombes à effet
   qui suivent explosent dans le vide.
2. **Train chaotique en déplacement.** L'espacement de la traînée est irrégulier.
3. **Le résultat dépend de tout** : vitesse d'attaque, déplacement du joueur, nombre
   d'armes bombe équipées, tiers et types mélangés.

### Cause racine de l'irrégularité (trouvée dans le code vanilla)

Le jeu **bruite volontairement** le cooldown de chaque arme, à chaque tir
(`weapons/weapon.gd:337-354`) :

```gdscript
var max_rand = get_max_rand_cooldown(cooldown_basis)
return rand_range(max(1, cooldown_basis - max_rand), cooldown_basis + max_rand)

func get_max_rand_cooldown(cooldown_basis: int) -> float:
	var weapon_count = min(_parent.get_nb_weapons(), 6)
	return min(weapon_count * cooldown_basis / 5.0, weapon_count * 5.0)
```

Avec 6 bombes et un cooldown de 90 : `rand_range(60, 120)`, soit **±33 % de gigue,
tirée indépendamment par chaque arme, à chaque tir**. Vanilla fait ça pour
désynchroniser six armes identiques.

Notre `BombTiming.slot_phase_offset()` ne s'applique **qu'au début de la vague**
(`init_stats(at_wave_begin)`). La gigue le pulvérise en quelques cycles : le « train »
n'a aucune chance de tenir.

Second facteur : les cooldowns **diffèrent** d'une bombe à l'autre (90/80/70/60 selon
le tier). Deux armes de périodes différentes dérivent l'une par rapport à l'autre,
même sans gigue.

## L'intention

Décision utilisateur : **une traînée lisible derrière soi**. La régularité de la pose
prime ; la couverture du terrain en découle.

Corollaire explicitement écarté : on **n'indexe pas** l'écartement sur le rayon
d'explosion. Bomberto fait grossir ses explosions (+5 % de taille par point
d'élémentaire) ; un écartement proportionnel enverrait les bombes à plusieurs
centaines de pixels en fin de run, éparpillées aux quatre coins — on perdrait la
traînée, qui est justement l'objectif.

**Conséquence assumée** : avec un écartement fixe et des explosions qui grossissent,
les zones d'effet se recouvriront en fin de partie. Le symptôme n°1 (« la normale
nettoie, les autres explosent dans le vide ») n'est donc traité qu'**indirectement** :
les bombes ne s'empilent plus, mais le gâchis ne disparaît pas complètement.

## Le joueur PEUT poser en mouvement (piège de lecture évité)

La règle vanilla (`weapons/weapon.gd:273-283`, reproduite par notre `should_shoot`) se
lit : une arme ne tire que si le joueur est immobile, **sauf** effet
`can_attack_while_moving`.

**Cette exception est en réalité la règle.** `can_attack_while_moving` vaut **1 par
défaut pour tout joueur** (`singletons/player_run_data.gd:498`, la table des effets
initiaux — la même qui contient `can_burn_enemies`). Le joueur n'est **jamais** contraint
de s'arrêter pour poser une bombe.

Conséquence : au moment de la pose, `_parent._current_movement` est **non nul** dans le
cas courant. On peut donc orienter la traînée avec le mouvement réel.

**La mémoire du mouvement reste néanmoins nécessaire, pour deux raisons :**

1. **Lisser.** Le kiting est un va-et-vient permanent (courir, freiner, repartir). Sans
   lissage, l'éventail claquerait du cercle complet à la file stricte à chaque
   micro-arrêt, et la traînée serait hachée.
2. **Garder une direction à l'arrêt.** Quand le joueur est réellement immobile,
   `_current_movement` vaut `Vector2.ZERO` : il n'y a plus de direction à lire. On
   conserve la dernière connue. (Sa valeur importe peu : à l'arrêt la mobilité tombe à 0
   et l'éventail devient un cercle complet, donc l'orientation n'a plus d'effet visible.)

Note : `_current_movement` (`entities/units/unit/unit.gd:36`) est le **vecteur
d'entrée**, pas une vitesse — le moteur le normalise puis le multiplie par la vitesse
de déplacement (`unit.gd:219`). Sa magnitude n'est pas exploitable comme vitesse ; la
vitesse réelle se lit avec `_parent.get_move_speed()` (`unit.gd:222`).

## Le design

### 1. Cadence : un rythme prévisible

Trois changements convergents :

- **Cooldown figé à 75** dans les **16** fichiers de stats
  (`bomb_{1..4}`, `bomb_ice_{1..4}`, `bomb_poison_{1..4}`, `bomb_storm_{1..4}`),
  au lieu de 90/80/70/60 par tier. Toutes les armes bombe partagent désormais la même
  période.
- **Suppression de la gigue** : `BombWeapon` surcharge `get_next_cooldown()` pour
  renvoyer le cooldown déterministe, sans le `rand_range` de vanilla.
- **Le déphasage par slot** (`BombTiming.slot_phase_offset`, déjà écrit et testé)
  devient enfin fiable : toutes les périodes étant égales, les phases restent
  verrouillées toute la vague.

**Pourquoi ça suffit, et pourquoi aucun « chef d'orchestre » n'est nécessaire :** la
seule chose qui module encore le cooldown est la **vitesse d'attaque**, qui est une
stat **du joueur** — elle s'applique donc à l'identique à toutes ses armes bombe (nos
`.tres` gardent `attack_speed_mod = 0`). Les armes restent en phase par construction.

Résultat : avec N bombes équipées, il en tombe une **toutes les `75 / N` frames**,
indéfiniment.

**Contrepartie assumée** : le cooldown était la progression de tier (90 → 60 = +50 %
de cadence au tier IV). Monter en tier n'accélère plus la pose. La progression
subsiste ailleurs : dégâts, mèche raccourcie (2 s → 1 s), DOT du poison, nombre
d'éclairs de la foudre, % de ralentissement de la glace.

Valeur 75 = moyenne de la fourchette actuelle → équilibre global quasi neutre (tier I
plus rapide, tier IV plus lent).

### 2. Position : la couronne à éventail

Nouveau module de **logique pure** `content/logic/bomb_placement.gd` (aucune dépendance
jeu, testable en headless, comme `bomb_timing.gd`). Il répond à une seule question :
*étant donné un numéro de pose, un slot d'arme, une direction et une mobilité récentes,
quel décalage applique-t-on à la position du joueur ?*

**L'angle brut** combine deux termes :

- le **slot de l'arme** (`weapon_pos / nb_slots × TAU`) : deux armes différentes ne
  visent pas le même azimut ;
- un **angle d'or** (`≈ 2.39996 rad`, soit 137,5°) multiplié par le compteur de tirs de
  l'arme (`_nb_shots_taken`, déjà maintenu par `Weapon`). L'angle d'or ne reboucle
  jamais : les poses successives d'une **même** arme se répartissent d'elles-mêmes
  autour du cercle sans retomber au même endroit.

Ce second terme est ce qui règle le **cas critique** : le joueur n'a qu'**une seule**
bombe en main (cas le plus fréquent en début de run), où le terme de slot ne
différencie rien.

**Le repliement vers l'arrière.** L'angle brut n'est pas utilisé tel quel : il est
**projeté** sur un éventail centré derrière le joueur, dont la demi-ouverture rétrécit
quand la mobilité augmente.

```
demi_ouverture = PI * (1 - mobilite)        # mobilite ∈ [0, 1]
t              = wrapf(angle_brut, -PI, PI) / PI    # t ∈ [-1, 1]
angle_final    = arriere.angle() + t * demi_ouverture
decalage       = Vector2(cos(angle_final), sin(angle_final)) * RAYON
```

- **mobilité = 0** → demi-ouverture = `PI` → l'éventail est le **cercle entier** : les
  bombes entourent le joueur.
- **mobilité = 1** → demi-ouverture = `0` → toutes les bombes partent **strictement
  derrière** : c'est une file, et l'espacement est produit par le **déplacement réel**
  du joueur entre deux poses.

Une seule formule continue, aucune bascule entre deux modes.

**Le rayon est une constante fixe** (`RAYON ≈ 64 px`, à régler en jeu). Pas d'indexation
sur le rayon d'explosion (cf. « L'intention »).

#### La mobilité n'est PAS « le joueur bouge-t-il ? »

C'est le point délicat du design, et le piéger serait de le rater.

La vitesse de déplacement du joueur est **variable en jeu** (objets, bonus). Si
l'éventail se refermait dès que le joueur bouge — sans regarder **à quelle vitesse** —
on réintroduirait l'empilement qu'on cherche à tuer : un joueur **lent** (ou qui a
**beaucoup de bombes**, donc un intervalle de pose très court) verrait l'éventail se
fermer alors qu'il n'a parcouru que quelques pixels entre deux poses. Les bombes
viseraient toutes le même point derrière lui.

La mobilité mesure donc **« le déplacement suffit-il, à lui seul, à espacer les
bombes ? »** :

```
intervalle       = (cooldown_courant / nb_bombes) / 60.0     # secondes entre deux poses
deplacement      = vitesse_reelle * intervalle               # pixels parcourus entre deux poses
mobilite_cible   = clamp(deplacement / (2.0 * RAYON), 0, 1)
```

Le seuil `2 × RAYON` est le **diamètre de la couronne** : c'est l'espacement que la
couronne fournirait à elle seule. La règle devient auto-régulante :

- **le déplacement fait le travail** (joueur rapide, peu de bombes) → mobilité → 1 →
  l'éventail se ferme → file nette derrière ;
- **le déplacement ne suffit pas** (joueur lent, ou six bombes qui tombent coup sur
  coup) → mobilité basse → l'éventail **reste ouvert** → c'est l'**angle** qui fournit
  l'espacement, en éparpillant les bombes autour du joueur.

Les deux sources d'espacement — la **distance parcourue** et l'**angle** — se relaient
automatiquement. Ce seul mécanisme absorbe la vitesse variable du joueur, le nombre de
bombes équipées **et** la vitesse d'attaque (qui raccourcissent l'intervalle).

La vitesse réelle se lit sur le joueur : `_parent.get_move_speed()`
(`entities/units/unit/unit.gd:222` — inclut `current_stats.speed`, `bonus_speed` et
`decaying_bonus_speed`).

### 3. Le mouvement mémorisé

`BombWeapon` observe le joueur **à chaque frame** (`_process`), pas seulement au moment
du tir, et entretient deux valeurs :

- **`_last_dir`** : la dernière direction de déplacement **non nulle**
  (`_parent._current_movement.normalized()`). Elle définit « l'arrière »
  (`arriere = -_last_dir`).
- **`_mobility`** : le facteur `[0, 1]` défini plus haut, **lissé dans le temps**. À
  chaque frame on calcule la `mobilite_cible` (0 si le joueur est immobile, sinon la
  formule `deplacement / (2 × RAYON)`), et `_mobility` glisse vers elle avec des
  constantes de temps distinctes : **montée rapide, descente plus lente** (de l'ordre de
  0,2 s et 0,5 s, à régler).

Le lissage absorbe le va-et-vient permanent du kiting. Sans lui, l'éventail claquerait du
cercle complet à la file stricte à chaque freinage, et la traînée serait hachée.

La descente plus lente que la montée est délibérée : elle laisse le joueur freiner,
tourner et repartir sans que la traînée se transforme en couronne au moindre à-coup.

La fonction d'intégration est **pure** et vit dans `bomb_placement.gd` :

```gdscript
static func mobility_target(move_speed: float, interval_seconds: float,
                            radius: float) -> float

static func mobility_step(current: float, target: float, delta: float,
                          rise_seconds: float, fall_seconds: float) -> float
```

**Effet concret.** Le joueur court vite : la mobilité est haute → les bombes tombent
**derrière lui**, dans l'axe de sa course. Il campe sur place : la mobilité retombe → la
couronne se rouvre et les bombes l'entourent. Il se traîne à faible vitesse avec six
bombes en main : la mobilité reste **basse malgré le mouvement**, l'éventail reste
ouvert, et les bombes s'éparpillent autour de lui au lieu de se tasser derrière. La
transition entre ces trois régimes se fait toute seule, sans bascule.

## Portée des changements

| Fichier | Nature |
|---|---|
| `content/logic/bomb_placement.gd` | **Nouveau**, pur, testé en headless |
| `content/weapons/bomb/bomb_weapon.gd` | Mémoire du mouvement (`_process`), surcharge `get_next_cooldown()`, calcul de la position dans `shoot()` |
| 16 × `bomb_*_stats.tres` | `cooldown = 75` |

`bomb_entity.gd` n'est **pas** touché : il reçoit déjà sa position de l'arme.
`bomb_timing.gd` n'est **pas** touché : `slot_phase_offset` est déjà correct — il
devient simplement fiable.

## Tests

**Headless (logique pure, `bomb_placement.gd`)** :

- `mobility_target` : vaut 1 quand le déplacement entre deux poses atteint `2 × RAYON` ;
  **décroît quand la vitesse du joueur baisse** ; **décroît aussi quand le nombre de
  bombes augmente** (l'intervalle raccourcit, donc le déplacement par pose aussi) ;
  borné dans `[0, 1]` ; ne divise pas par zéro si `radius` ou `interval` valent 0.
- `mobility_step` : glisse vers la cible, monte plus vite qu'il ne descend, reste borné
  dans `[0, 1]`, idempotent à `delta = 0`.
- Angle brut : deux slots différents donnent des azimuts différents ; deux poses
  successives d'un **même** slot donnent des azimuts différents (propriété de l'angle
  d'or) ; le cas `nb_slots <= 1` ne divise pas par zéro.
- Repliement : à mobilité 0, les décalages couvrent tout le cercle ; à mobilité 1, tous
  les décalages sont colinéaires à l'arrière ; le décalage a toujours pour norme
  `RAYON`.
- Direction nulle (`_last_dir == Vector2.ZERO`, au tout début d'une vague) : aucune
  division par zéro, repli sur un axe arbitraire — sans conséquence puisque la mobilité
  vaut alors 0 et que l'éventail est un cercle complet.

**En jeu (humain)** : régularité de la traînée en kiting ; couronne à l'arrêt ; absence
d'empilement avec 1 seule bombe en main (cas critique de l'angle d'or) ; absence
d'empilement avec 6 bombes de tiers et types mélangés ; réglage du rayon (64 px) et des
constantes de mobilité ; cadence ressentie au cooldown figé à 75 ; coop (deux joueurs,
chacun sa mémoire de mouvement — la mémoire vit sur l'arme, donc par joueur par
construction).

## Risques

- **Le cooldown figé est un changement d'équilibrage**, pas seulement un changement de
  confort : le tier IV perd sa cadence. À juger en jeu.
- **La surcharge de `get_next_cooldown()`** retire aussi le `is_big_reload_active`
  (rechargement long). Nos bombes ont `additional_cooldown_every_x_shots = -1`, donc ce
  mécanisme est déjà inactif : la surcharge ne perd rien. À ne pas oublier si on active
  un jour ce champ.
- **`_process` sur l'arme** : coût négligeable (deux valeurs mises à jour), mais c'est
  du travail à chaque frame pour chaque arme bombe équipée.
