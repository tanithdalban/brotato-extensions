# Bombe Frag — design

**Date** : 2026-07-16
**Mod** : Tanith-Bomberman
**Statut** : validé, prêt pour le plan d'implémentation
**Branche** : `feat/defis-bombes` (à jour de la bombe sangsue)

## Intention

Une **6ᵉ bombe**, la **Bombe Frag** (`weapon_bomb_frag`), débloquée en montant la Bombe
sangsue au **niveau IV**. C'est le sommet de tout l'arbre du mod : pour l'atteindre il
faut d'abord gagner la Sangsue (tenir les 4 bombes en même temps), puis la monter au
tier IV — soit deux runs au minimum.

À la détonation, l'obus **éclate sans faire de dégâts** et projette une gerbe de
**fragments** — de vraies petites bombes à mèche courte, dispersées **au hasard** autour
du point d'impact, qui explosent chacune pour de bon.

C'est une **arme de nuée**, par opposition à la Bombe normale qui reste l'**arme de
précision**. Les deux font des dégâts, mais ne répondent jamais à la même situation :
la normale frappe fort là où on l'a posée, la Frag couvre une surface sans qu'on
choisisse où ça tombe.

## Ce que la Frag rompt, délibérément

⚠️ **C'est une inversion assumée d'une décision de design antérieure.** Jusqu'ici la
règle était : « la normale est la seule bombe de dégâts, les autres sont utilitaires »,
et le bonus « +5 % dégâts d'explosion par point d'ingénierie » lui était réservé — pour
ne pas rendre Bomberto trop facile.

La Frag est la **2ᵉ vraie bombe de dégâts** et **reçoit le bonus d'explosion**. Ce n'est
pas un oubli : c'est une contrainte structurelle. Bomberto a **-75 % de dégâts**, et ce
bonus est la seule chose qui compense ce malus. Une bombe de dégâts qui ne le touche pas
encaisse le -75 % à nu — c'est très exactement la Foudre, qui plafonne à ~800 dégâts sur
une run là où la normale en fait ~20 000. Sans le bonus, la Frag serait morte-née et le
capstone tomberait à plat.

**Ce qui paie cette puissance, c'est la VARIANCE, pas un rabais sur la moyenne.** À
espérance égale avec la normale, la Frag est une **loterie** : un peu plus de la moitié
des ennemis de l'emprise ne prennent **rien du tout**, et ceux qui sont touchés encaissent
~2,6× ce que fait la normale (davantage encore dans un recouvrement). Sur une nuée dense,
la loi des grands nombres joue et la Frag rend son plein potentiel. Sur un boss — cible
unique — c'est un coup de dés, et la normale reste indispensable.

⚠️ **La dispersion ne coûte donc PAS de la puissance moyenne, elle coûte de la
FIABILITÉ.** C'est la formulation exacte, et elle a mis du temps à être trouvée (cf.
« Le piège du carré » ci-dessous).

## Découverte fondatrice : l'armure n'existe pas

⭐ **Aucun ennemi du jeu de base n'a d'armure.** Les **39** `*_stats.tres` de
`entities/units/enemies/` ont tous `armor = 0` **et** `armor_increase_each_wave = 0.0` —
grep exhaustif, zéro exception. La mécanique existe dans le code (`unit.gd:502`,
`max(1, dmg - armor)`) et le codex sait l'afficher (`ItemEnemy.gd:17-18`), mais rien ne
s'en sert.

**C'est ce qui rend la Frag possible.** Puisque l'armure se soustrait **à plat de chaque
coup**, segmenter des dégâts aurait coûté `(N-1) × armure` par ennemi : découper 36 en
7×5 face à une armure de 10 aurait laissé 7 fragments à 1 dégât plancher = 7 au lieu de
36. Avec une armure à zéro, **segmenter ne coûte rien** : 36 en 7 morceaux font 36.

⚠️ **Réserve** : seul `Brotato.pck` est décompilé ici, **pas le DLC Abyssal Terrors**.
Ses ennemis n'ont pas été vérifiés. Si le DLC introduit de l'armure, la Frag s'effondre
sur ces ennemis-là (et la Foudre avec elle) — à contrôler si le mod vise le DLC.

⚠️ **Ceci corrige une note antérieure erronée** : « l'armure retranchée de chaque éclair
est probablement la vraie cause des ~800 de la foudre » était une hypothèse **jamais
vérifiée, et fausse**. La vraie cause reste établie : la foudre encaisse le -75 % sans
toucher le bonus d'explosion.

## Le piège du carré (à lire avant de toucher aux chiffres)

⚠️⚠️ **Erreur commise puis rattrapée pendant le design. Ne pas la refaire.**

L'intention de départ était « aussi puissant que la normale, juste segmenté en plusieurs
morceaux », soit des dégâts totaux de 12/18/26/36 (= la normale) répartis entre les
fragments. **C'est faux, et d'un facteur 18.**

Dans un jeu de zones, la puissance d'une bombe n'est pas son chiffre de dégâts, c'est
**dégâts × surface** — et la surface croît avec le **carré du rayon**. Deux pertes se
multiplient donc sans qu'on les voie :

- Normale : `36 × 221² = 1 760 000`
- Frag « segmentée » : `7 × 5,14 × 52² = 100 000` → **18× plus faible que la normale**,
  très loin derrière même la Foudre. Le capstone de tout l'arbre aurait été la pire arme
  du mod.

52 px contre 221, une fois au carré, ce n'est pas 24 % — c'est **5,5 %**. « Segmenter »
en zones plus petites ne conserve pas la puissance : ça la détruit au carré.

⭐ **La formule libératrice** : la puissance ne dépend QUE de
**`dégâts_totaux × rayon_fragment²`**. Ni le nombre de fragments, ni le rayon de la
gerbe n'y changent quoi que ce soit — ils ne font que **redistribuer**. Le recouvrement
ne gaspille rien non plus (un ennemi pris dans trois zones encaisse bien trois
explosions distinctes). **Forme et puissance sont donc deux réglages indépendants** : on
choisit librement la silhouette, puis on règle la puissance avec le seul chiffre de
dégâts.

## Chiffres

### Progression par tier — double

Le tier fait monter **les dégâts ET la couverture**.

Les dégâts par fragment sont calibrés pour que la **puissance moyenne égale celle de la
Bombe normale**, en appliquant le facteur de compensation `(221/52)² ≈ 18` (rayon de la
normale / rayon du fragment, au carré).

⭐ **Le `damage` du `.tres` est le dégât PAR FRAGMENT, pas un total à partager** — c'est
la **convention vanilla** pour toute arme multi-projectiles : la Foudre porte
`damage = 8` avec `nb_projectiles = 6`, et les 8 sont par éclair. On s'aligne dessus
plutôt que d'inventer notre propre sémantique.

**Conséquence majeure : il n'y a RIEN à partager.** Le dégât d'explosion calculé à la
pose est passé **tel quel** à chacun des fragments. Pas de répartition, pas d'arrondi,
pas de plus-fort-reste, pas de cas limite « total < nombre de fragments ». La logique
pure se réduit à la seule dispersion.

| Tier | `damage` du .tres (par fragment) | `nb_projectiles` | vs normale | Vérif : `dég × 52² × N` |
|---|---|---|---|---|
| I | **54** | 4 | ×4,5 | ≈ 12 × 221² ✓ |
| II | **65** | 5 | ×3,6 | ≈ 18 × 221² ✓ |
| III | **78** | 6 | ×3,0 | ≈ 26 × 221² ✓ |
| IV | **93** | 7 | ×2,6 | ≈ 36 × 221² ✓ |

⚠️ **Ces chiffres paraissent énormes à côté des 36 de la normale : c'est normal et
voulu.** Un fragment frappe 2,6× plus fort qu'elle, mais dans une zone 4,25× plus petite
en rayon. C'est le prix de la granularité, pas un cadeau.

⚠️ **Ces valeurs sont liées au rayon du fragment (0,35).** Toute modification du rayon
impose de **recalculer les dégâts** par `(221 / nouveau_rayon_px)²`, sinon l'équilibrage
part au carré dans un sens ou dans l'autre.

Du tier I au IV : puissance ×3 (comme la normale), fragment individuel +72 %, couverture
+75 %. La montée est donc **plus raide que celle de la normale** (qui ne gagne que les
dégâts). Assumé : la Frag I est chétive, la Frag IV écrase — c'est un capstone qui se
mérite.

Le nombre de fragments est porté par le champ **`nb_projectiles`** des stats, qui existe
déjà dans le schéma vanilla (c'est lui qui porte les 6→10 éclairs de la Foudre). Rien à
inventer.

### Géométrie

Base de référence : le hitbox de `projectiles/explosion.tscn` est un `CircleShape2D` de
**147,34 px** de rayon à l'échelle 1, et `set_area()` met à l'échelle la **racine** de
la scène — donc le hitbox avec. Le rayon réel vaut `147,34 × échelle`.

| | Échelle | Rayon réel |
|---|---|---|
| Bombe normale | 1,5 | **221 px** (un disque plein) |
| **Fragment** | **0,35** | **52 px** |
| Foudre (référence) | — | **500 px** (`max_range` des éclairs) |

- **Rayon de gerbe : 150 px**, fixe.
- **Emprise totale de la Frag** : ~200 px (150 de gerbe + 52 de portée du fragment) —
  soit *moins* que la normale (221) et **moitié moins que la Foudre** (500). La Frag est
  délibérément l'arme la plus **serrée** du lot ; c'est sa granularité qui la distingue,
  pas son étendue.
- **Couverture** : 7 fragments de 52 px dans une emprise de ~200 px ≈ **46 %**. Un vrai
  patchwork troué. C'est ce chiffre qui fait vivre la contrepartie.

⚠️ **Le rayon du fragment est le paramètre le plus sensible du design.** À l'échelle 0,7
(103 px) la couverture monte à **116 %** : le tapis sature, il n'y a plus un seul trou,
la dispersion cesse d'être une contrepartie et la Frag redevient « la normale en mieux ».
Ne pas remonter cette valeur sans refaire le calcul de couverture.

### Gerbe fixe, indépendante de la portée

Le rayon de gerbe est une **constante**. Rien ne le couple à une stat du joueur :
`stat_range` pilote la portée des armes à distance et n'a aucun lien avec les explosions.

⭐ **Conséquence émergente, gratuite, et voulue** : `player_explosion.gd:72` gonfle le
rayon d'explosion par la stat **`explosion_size`** du joueur —
`max(0.1, p_area + p_area × explosion_size/100)`. Donc **le rayon des fragments grandit
avec cette stat, mais pas la gerbe.** Un joueur qui monte `explosion_size` voit son tapis
**se refermer** : les trous disparaissent, les zones se recouvrent, et la Frag se
transforme sous ses yeux d'arme de nuée en **frappe concentrée** — enfin viable sur un
boss. La stat devient le curseur de build qui redéfinit l'arme.

**C'est un argument de plus pour des fragments petits** : à 52 px de base, la stat a de
la place pour refermer le tapis. À 103 px, le tapis est déjà saturé au départ et la stat
ne fait plus que du gaspillage.

### Timing

- **Mèche de la Frag** : la mèche normale, pilotée par le tier et la vitesse d'attaque
  (`BombTiming.fuse_seconds_scaled`) — comme toutes les bombes.
- **Mèche du fragment** : **~0,4 s, fixe**, indépendante du tier **et** de la vitesse
  d'attaque, **plus une gigue** étalant les détonations sur ~0,15 s.

⭐ **La gigue n'est pas cosmétique, elle règle trois problèmes d'un coup** :
1. **Anti-scintillement** — sans elle, les 7 fragments détonent dans la **même frame**.
   Le plafond d'opacité ne protège pas d'une **synchronisation** : 7 sprites à 20 % qui
   se superposent se composent (`1-0.8ⁿ`) et remontent à ~50 % d'opacité instantanée.
   C'est le **nombre simultané** qui fait le stroboscope, pas la brillance de chacun.
2. **Performance** — étale la quarantaine de spawns d'explosion sur plusieurs frames au
   lieu d'un pic sur une seule.
3. **Sensation** — une munition à fragmentation crépite (pop-pop-pop), elle ne fait pas
   « boum ». C'est le son signature du cluster.

⚠️⚠️ **LA GIGUE EST STRICTEMENT CONFINÉE AUX MÈCHES DES FRAGMENTS.** La mèche **et** le
cooldown de la **bombe mère** restent rigoureusement **déterministes** — on n'y touche
pas, sous aucun prétexte.

Ne pas confondre avec la gigue qu'on a **retirée** du vanilla lors de la refonte de la
pose (`get_next_cooldown()` surcharge `weapon.gd:337-354` pour supprimer le `rand_range`
±33 %) : celle-là portait sur le **cooldown de l'arme**, et c'est ce qui permet aux
armes bombe de partager la même période, donc au **déphasage par slot** de tenir et à la
**traînée de rester propre et régulière**. Ça a été arraché de haute lutte (le déphasage
n'avait jamais fonctionné depuis l'origine du mod) — **le réintroduire, même
indirectement, annulerait toute la refonte de la pose**.

La mèche d'un fragment, elle, n'est liée à **aucun** déphasage : elle démarre à la
détonation de sa mère et meurt 0,4 s plus tard. La gigue y est donc sans conséquence sur
la cadence, et le train de bombes reste propre.

## Ce que la Frag n'a PAS

- **Pas de brûlure.** La normale en a une ; c'est sa signature (elle *marque* sa cible
  dans la durée). La Frag *couvre* une surface à l'impact. Si elle brûlait aussi, elle
  deviendrait « la normale en mieux » et les deux bombes de dégâts fusionneraient.
  (À noter : la brûlure n'étant pas cumulative — le jeu garde la plus forte — 7 fragments
  n'auraient pas brûlé 7 fois ; mais la couverture aurait rendu la brûlure quasi
  certaine, ce qui aurait suffi à écraser la normale.)
- **Pas de troll bombe.** Elle reste la signature exclusive de la Bombe normale.
- **Pas de récursion.** Un fragment ne se scinde jamais.

## Architecture

### Le nettoyage préalable (prérequis, pas confort)

`BombElement.is_effect()` répond aujourd'hui à **deux questions distinctes** avec un seul
classement :
- *fait-elle 0 dégât d'explosion ?* (`bomb_entity.gd:107`)
- *peut-elle se changer en troll bombe ?* (`bomb_entity.gd:72`)

Ça marchait tant que les deux réponses coïncidaient pour les 4 bombes à effet. **La Frag
est le premier cas qui les sépare** : elle fait des dégâts **et** ne troll jamais. Sans
ce découpage, elle ne peut pas exister.

On remplace donc le prédicat unique par **trois questions** :

| Prédicat | Vrai pour |
|---|---|
| `deals_explosion_damage(element)` | `NORMAL`, `FRAG_CHILD` |
| `can_troll(element)` | `NORMAL` |
| `is_cluster(element)` | `FRAG` |

Deux nouveaux éléments :
- **`FRAG`** — l'élément de l'arme, issu de `weapon_bomb_frag`. Explosion mère à 0 dégât,
  se scinde.
- **`FRAG_CHILD`** — élément **interne**, sans `weapon_id` (jamais produit par
  `from_weapon_id`). Fait des dégâts, ne troll pas, ne se scinde pas.

⭐ **La garde anti-récursion est structurelle, pas conditionnelle** : un `FRAG_CHILD`
n'est pas un `FRAG`, donc `is_cluster` est faux et la branche de dispersion ne peut pas
le reprendre. Rien à tester : c'est impossible par construction.

### Le chemin des dégâts est déjà en place

⭐ **C'est ce qui rend le chantier petit.** `bomb_weapon.gd:120` calcule **déjà**
`WeaponService.get_explosion_damage(stats, player_index)` — qui porte le bonus
d'ingénierie — et le passe à `arm()` pour **toutes** les bombes, y compris celles qui
le jettent ensuite. Les bombes à effet ne le perdent qu'au dernier moment, à la
détonation.

**La Frag se contente de ne pas le jeter, et de le passer tel quel à chaque fragment**
(le `damage` du `.tres` étant déjà le dégât *par fragment*, cf. « Chiffres »). Aucun
calcul de dégâts n'est inventé, aucune répartition n'est faite : on réutilise celui de
la normale, à l'identique.

⚠️ La valeur transmise est le dégât **déjà mis à l'échelle** (avec le -75 % de Bomberto,
le bonus d'explosion, les scalings) — **pas** le 54/65/78/93 brut du `.tres`.

### Flux de la détonation

1. La Frag arrive au terme de sa mèche.
2. **Explosion mère à 0 dégât** — visuel et son uniquement, plafond d'opacité appliqué.
3. `N = nb_projectiles` (4/5/6/7 selon le tier).
4. **Dispersion** : N positions tirées au hasard dans le disque de 150 px.
5. Spawn de N bombes `FRAG_CHILD`, chacune armée du **dégât mis à l'échelle tel quel**
   (aucun partage), de l'échelle d'explosion 0,35, d'une mèche de ~0,4 s + gigue, et de
   la **référence à l'arme** (voir ci-dessous).
6. La Frag se libère.
7. Chaque fragment explose ensuite par le **chemin vanilla existant**.

### Attribution des dégâts

Le fragment doit recevoir la référence à la `BombWeapon` **persistante** pour que le
signal `hit_something` de son explosion remonte à `on_weapon_hit_something` →
`RunData.add_weapon_dmg_dealt(weapon_pos)`. C'est ce qui fait que l'infobulle « dégâts
infligés (dernière vague) » comptera juste — **gratuitement**, sans une ligne de plus.
La référence est déjà un paramètre d'`arm()` : il suffit de la transmettre.

### Logique pure (testable en headless)

Nouveau module `content/logic/bomb_frag.gd`, **100 % statique, hasard INJECTÉ**, sur le
modèle de `bomb_leech.gd` et `bomb_placement.gd`.

Il ne contient **qu'une seule fonction** — le partage des dégâts n'existe pas (cf.
« Chiffres ») :

- **`scatter_offsets(n: int, radius: float, randoms: Array) -> Array`** — N positions
  dans le disque. ⚠️ **Piège de maths** : tirer un angle et une distance uniformes
  **entasse les fragments au centre**. Pour une gerbe homogène il faut
  `r = radius × sqrt(u)`. Sans ça, la dispersion réelle serait bien plus concentrée que
  les 46 % calculés et tout l'équilibrage tomberait à côté.

### Sprites

**Deux sprites, dont un seul à produire.**

- **La Frag mère** : `frag.png` — ✅ **FAIT et en place**
  (`content/weapons/bomb/frag.png`). Une grenade à fragmentation **segmentée** : les
  segments disent visuellement « je vais me scinder en morceaux », donc le sprite raconte
  la mécanique sans infobulle. C'est lui qui sert aussi d'**icône de boutique** (composée
  sur le disque coloré à la rareté par `BombSkin.build_icon`).

  ⭐ **Canevas 128×128** (et non 150 comme les autres) — c'est délibéré. Ce qui compte
  n'est pas la taille du fichier mais le **taux de remplissage**, puisque
  `_compose_world` écrase tout le canevas à 48 px **uniformément** : à fichier égal, un
  dessin qui touche les bords paraît plus gros en jeu. Le dessin livré faisait 107×125
  dans un canevas de 150 → remplissage 0,833 → **40 px**, soit la plus petite bombe de la
  série (12 % sous la glace et le poison) — un comble pour le capstone de l'arbre. Le
  canevas a donc été **rogné à 128×128** par recadrage pur (dessin recentré sur sa bbox,
  **aucun pixel touché, aucun rééchantillonnage** — vérifié pixel à pixel) →
  remplissage **0,977** → **46,9 px**, ce qui en fait le 2ᵉ obus le plus imposant, juste
  sous la foudre.

  ⚠️ **Le canevas doit rester CARRÉ** : `_compose_world` force le sprite en 48×48 sans
  se soucier du rapport — un canevas non carré déformerait le dessin.

  Remplissages de la série, pour référence (le trio glace/poison/sangsue ≈ 0,92 est la
  référence de fait) : normale 0,867 (41,6 px) · sangsue 0,919 (44,1) · glace 0,933
  (44,8) · poison 0,940 (45,1) · **frag 0,977 (46,9)** · foudre 1,000 (48,0).
- **Le fragment** : la **boule de feu vanilla**,
  `res://projectiles/fireball_projectile/fireball_projectile.png` — **aucun art à
  produire, zéro octet ajouté au zip**. Elle fait **49×49** (donc déjà à la taille cible
  de 48 : redimensionnement d'un pixel, aucune perte, et **le piège de padding de la
  sangsue n'existe pas**), elle est **ronde** (nos fragments n'ont pas d'orientation), et
  son gros contour noir la rend lisible en tout petit. Réutiliser un asset du jeu est
  déjà le motif du mod : on réutilise `explosion.tscn`, le popup d'objet de la boutique,
  et le projectile d'éclair vanilla pour la Bombe de Foudre.

⚠️⚠️ **PIÈGE DE CHARGEMENT — un asset vanilla ne se charge PAS comme les nôtres.** Le
chargeur maison (`BombSkin._load_image` → `Image.load`) lit un **PNG brut sur le
disque** : ça marche pour nos images, qui voyagent en clair dans le zip du mod. Mais **un
jeu Godot exporté n'embarque pas les PNG sources**, seulement leur version compilée
(`.stex`) — le PNG de la boule de feu n'existe ici que parce que GDRE l'a reconstruit.
Il faut donc passer par le **chargeur de ressources standard** (`load()`), qui résout via
le `.import`. Avec le chargeur maison, ça **marcherait dans le projet décompilé et
échouerait sur le vrai jeu** : exactement le genre de bug qu'aucun test ne verrait.

⚠️ Ne prendre que le **PNG**, jamais `fireball_projectile.tscn` : la scène embarque un
système de **particules de flammes** (`torch_burning_particles`) — nos fragments
cracheraient du feu alors que la Frag ne brûle pas.

⭐ **REPLI officiel (décision utilisateur)** : si la boule de feu pose problème —
chargement, lisibilité à 20 px, ou le fait qu'elle lise « feu » alors que la Frag ne
brûle pas — on bascule le fragment sur **la mère en réduit** (`frag.png`, déjà en
place). C'est **une ligne** dans le dictionnaire des chemins de `bomb_skin.gd`. La
décision est donc réversible pour presque rien : on part sur la boule de feu, on
constate en jeu, on bascule si besoin — plutôt que de produire un 2ᵉ dessin en
spéculant.

⭐ **Taille du fragment à l'écran : échelle 0,4 → ~20 px** (constante nommée, à affiner
en test). C'est un arbitrage entre cohérence et lisibilité :

| | Sprite (diamètre) | Explosion (diamètre) | Sprite / explosion |
|---|---|---|---|
| Bombe normale (référence) | 60 px (48 × 1,25) | 442 px | **13,6 %** |
| Fragment, boule de feu **native** | 49 px | 104 px | 47 % ✗ |
| Fragment, proportion **stricte** | 14 px | 104 px | 13,6 % |
| **Fragment retenu (0,4)** | **~20 px** | 104 px | **19 %** |

À sa taille native la boule remplirait **la moitié du souffle de son propre fragment** :
ça lit « la bombe fait pschitt », pas « la bombe explose » — c'est le rapport de 1 à 7 de
la normale qui donne l'impression de puissance. À l'inverse, la proportion stricte donne
un grain de poussière de 14 px, invisible dans la mêlée, et on perdrait le télégraphe qui
justifiait de faire de vraies petites bombes plutôt que des explosions surgies de nulle
part. 0,4 est le compromis.

### Garde-fous visuels et perf

- **Plafond d'opacité** : le même que les autres (`ExplosionVisual.AOE_OPACITY_CAP`,
  20 %), appliqué à l'explosion mère **et** à chaque fragment. Quitte à le baisser au
  test en jeu.
- **Fumée coupée sur les fragments** : `base_smoke_amount` est à 40 pour la bombe mère —
  absurde et coûteux sur un fragment de 52 px.

## Déblocage

Ajout d'un maillon à la chaîne existante — **aucun mécanisme nouveau** :

```
CHAIN  : "weapon_bomb_leech" -> "chal_bomb_frag"
REWARD : "chal_bomb_frag"    -> "weapon_bomb_frag"
```

- L'entrée dans `REWARD` suffit à ce que le **popup de migration** couvre la Frag
  gratuitement.
- Le déblocage porte sur le `weapon_id`, **commun aux 4 tiers**.
- Effectif **à la run suivante** (comportement vanilla ; on ne rappelle pas
  `init_unlocked_pool()` à chaud).
- Le défi de la **Sangsue** exige les **4 bombes d'origine**, pas la 5ᵉ : ajouter la Frag
  ne touche pas à `LEECH_REQUIRED`. L'avertissement du carnet (« chaque bombe ajoutée
  mange un slot pendant la tentative ») **ne s'applique donc pas ici**.
- Verrouillage 100 % natif : `unlocked_by_default = false` sur les 4 `.tres`.

## Fichiers

Coût d'une bombe standard, **moins cher que la sangsue** (un seul sprite à produire, et
pas de module de partage) :

- **9 `.tres`** : `bomb_frag_{1..4}_data.tres` + `bomb_frag_{1..4}_stats.tres` +
  `chal_bomb_frag_data.tres`
- **1 sprite à produire** : `frag.png` (la mère). Le fragment réutilise la boule de feu
  vanilla — **rien à dessiner, rien à empaqueter** (cf. « Sprites »).
- **1 module pur** `content/logic/bomb_frag.gd` (une seule fonction : la dispersion)
- **Branchements** : `bomb_element.gd` (2 éléments + 3 prédicats), `bomb_entity.gd`
  (branche cluster + mèche du fragment), `bomb_challenges.gd` (CHAIN + REWARD),
  `challenge_service.gd` (+1 chemin), `bomberman_translations.gd` (FR/EN),
  `bomb_skin.gd` (skin de la Frag ; ⚠️ le fragment passe par le **chargeur de ressources
  standard**, pas par le chargeur maison — cf. « Sprites »)

## Tests

**Logique pure (headless)** :
- `scatter_offsets` : bon nombre ; tous dans le disque ; **répartition homogène** (pas
  d'entassement central) ; déterminisme à hasard injecté.
- `bomb_challenges` : `CHAIN` contient le maillon sangsue→frag ; `REWARD` contient la
  frag ; `unearned_bombs` la couvre.
- Les 3 prédicats, pour chacun des 7 éléments.

**⚠️ Le piège connu de ce mod** : la suite de tests ne charge **jamais** `bomb_weapon.gd`
ni `bomb_entity.gd` (ils dépendent des autoloads du jeu). Une **erreur de parse ou de
compilation y serait totalement invisible, tests au vert** — c'est déjà arrivé deux fois,
et plus aucune bombe n'existait en jeu. **Contrôle obligatoire après chaque
modification** : passer la sortie du runner au grep sur `parse error|compile error` et
exiger que ce soit **vide**.

## Risques

1. **Performance (risque n°1, nouveau).** 6 Frags IV équipées = **42 fragments par
   cycle**, soit ~40 explosions toutes les ~1,25 s — **7× ce que produit la normale**.
   Les explosions sont **poolées** (`weapon_service.gd:513`), ce qui absorbe l'essentiel,
   et la Foudre lance déjà 60 projectiles par cycle sans broncher — mais une explosion
   coûte plus qu'un projectile (hitbox + particules). Atténué dès l'écriture par la
   **gigue** (étale les spawns) et la **fumée coupée**. **À surveiller en jeu.**
2. **Scintillement.** Traité par la gigue + le plafond d'opacité. À revérifier en jeu
   avec 6 Frags équipées — c'est le pire cas.
3. **Chargement du sprite du fragment.** ⚠️ Le piège le plus sournois de cette spec :
   avec le chargeur maison, le fragment **s'afficherait dans le projet décompilé et
   serait invisible sur le vrai jeu** (les PNG sources ne sont pas embarqués dans un
   export Godot). Aucun test ne le verrait. Cf. « Sprites ».
4. **DLC Abyssal Terrors non vérifié** (armure). Cf. plus haut. Si le DLC introduit de
   l'armure, la segmentation redevient taxée `(N-1) × armure` et la Frag s'effondre sur
   ces ennemis-là.
5. **Corruption du jeu décompilé** : lancer `Godot --path Brotato` (jeu ou test-runner)
   régénère les `.png.import` et supprime des `ext_resource` PNG de certains `.tres`.
   Nettoyer avant le build final.

## Constantes à régler en jeu

Convention du mod (comme `RADIUS = 64` et `cooldown = 75` de la pose) : constantes bien
nommées, calibrage au test.

| Constante | Départ | Effet |
|---|---|---|
| Rayon de gerbe | **150 px** | serré = concentré et fiable ; large = étalé et dilué. N'affecte **pas** la puissance, seulement la forme |
| Échelle d'explosion du fragment | **0,35** (52 px) | ⚠️⚠️ **le plus sensible du design** — au-delà de ~0,5 le tapis sature et la contrepartie disparaît. Et **tout changement impose de recalculer les dégâts** par `(221 / nouveau_rayon)²` (cf. « Le piège du carré ») |
| Dégâts par fragment | **54/65/78/93** | lié au rayon ci-dessus — les deux se règlent **ensemble**, jamais séparément |
| Échelle du **sprite** du fragment | **0,4** (~20 px) | purement visuel, aucun effet sur les dégâts ni la zone. À ne pas confondre avec l'échelle d'**explosion** |
| Mèche du fragment | **0,4 s** | |
| Gigue de la mèche | **~0,15 s** | anti-scintillement + étalement des spawns |
| Échelle de l'explosion mère | **à choisir** | purement visuel (0 dégât) — l'obus qui éclate |

## Hors périmètre

- **Rendre le plafond d'opacité configurable** (l'option de mod `explosion_opacity` est
  prévue en commentaire depuis le début et n'a jamais été faite) — élargirait le chantier
  au-delà de la Frag.
- **Une 7ᵉ bombe.** `CHAIN` accueillerait un maillon de plus, mais la Frag est la fin de
  l'arbre pour l'instant.
- **Corriger le bug coop de la troll bombe** (spawn écarté du seul joueur le plus proche)
  — connu, indépendant, tracké ailleurs.
