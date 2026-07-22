# Bomberman — Journal des modifications

Un mod de personnage pour Brotato : « Bomberto », un personnage lanceur de bombes
dont la boutique propose aussi des armes explosives et de mêlée à fort knockback,
accompagné d'une arme Bombe qui pose des bombes à intervalle régulier (sans visée)
et mise sur les dégâts d'explosion et le scaling élémentaire/ingénierie.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/).

## [3.0.1] — 2026-07-22

### Corrigé
- **Reprendre une partie après avoir fermé le jeu ne fait plus perdre Bomberto ni ses bombes.** En quittant une run en cours puis en relançant le jeu, la partie reprise rendait un personnage **sans arme en main** — et la sauvegarde était aussitôt réécrite ainsi amputée, rendant la perte définitive. Le contenu du mod est désormais enregistré **avant** que le jeu ne relise la partie en cours. Les objets et armes du mod présents dans la boutique en attente sont eux aussi préservés.

## [3.0.0] — 2026-07-17

Deux nouvelles bombes, une refonte du **déblocage** des bombes élémentaires — qui se
**méritent** désormais — et un **plafond** sur la taille des explosions.

### Ajouté
- **Bombe Sangsue** — une 5ᵉ bombe qui ne fait aucun dégât d'explosion mais **draine les ennemis** de sa zone : elle leur retire des points de vie et vous les rend. Le soin est plafonné et partagé, par seconde, entre toutes vos Bombes Sangsue (les empiler rend le soin régulier, pas plus gros). Elle se débloque en détenant les **quatre bombes d'origine** (Bombe, Glace, Foudre, Poison) en même temps.
- **Bombe Frag** — une 6ᵉ bombe à sous-munitions : l'obus éclate sans dégâts et projette **4 à 7 fragments** dispersés au hasard, qui explosent chacun pour de bon. Redoutable sur une nuée dense, plus hasardeuse sur une cible isolée. Elle se débloque en montant une **Bombe Sangsue au niveau IV**.
- **Chaîne de défis des bombes** — les bombes de Glace, de Foudre et de Poison ne sont plus offertes d'emblée. Montez une bombe au **niveau IV** pour débloquer la suivante : Bombe → Glace → Foudre → Poison, puis Sangsue IV → Frag. Si vous possédiez déjà ces bombes, un **choix** vous est proposé sur l'écran de sélection (en solo) : revivre la progression, ou les conserver.

### Modifié
- **La taille des explosions est désormais plafonnée.** Le scaling élémentaire — et certains objets comme le Pot de miel — pouvait faire grossir les explosions jusqu'à couvrir toute la carte. Elles plafonnent maintenant à environ **un quart de la carte**, quel que soit l'investissement ; les fragments restent proportionnellement petits. Le reste de votre élémentaire continue de renforcer le poison, la foudre, etc.
- **La troll bombe** poursuit désormais **3 secondes** (au lieu de 5) avant d'exploser, et son explosion est plafonnée comme les autres.

## [2.0.0] — 2026-07-11

Refonte complète de **la façon dont les bombes se posent**. Jusqu'ici elles tombaient
toutes sous les pieds du joueur, au même pixel, à une cadence erratique. Elles
dessinent désormais une **traînée lisible** derrière Bomberto.

### Modifié
- **Les bombes ne tombent plus sous vos pieds.** Chaque bombe se pose maintenant sur une **couronne** autour du joueur, à distance fixe. L'ouverture de cette couronne s'adapte toute seule à votre façon de jouer : **en course, elle se referme derrière vous** et les bombes forment une traînée dans l'axe de votre fuite ; **à l'arrêt, elle s'ouvre en cercle complet** et les bombes vous entourent. Entre les deux, la transition est continue — aucun basculement brutal. Le mod tient compte du **déplacement réellement parcouru** entre deux poses : si courir suffit à espacer les bombes, il laisse la course faire le travail ; sinon (joueur lent, ou six bombes qui tombent coup sur coup), il écarte les bombes par l'angle.
- **Cadence de pose régulière et prévisible.** Toutes les armes-bombe partagent désormais la même période, et le mod retire le **bruit aléatoire** que le jeu ajoute normalement à chaque tir (±33 % avec six armes). Avec N bombes équipées, il en tombe une à intervalle constant, indéfiniment.
- ⚠️ **Contrepartie assumée : monter en niveau n'accélère plus la pose.** Le rythme est identique du niveau I au niveau IV. La progression passe désormais entièrement par le reste : dégâts, mèche plus courte, poison plus fort, éclairs plus nombreux, ralentissement plus mordant.

### Corrigé
- **Le décalage entre deux bombes équipées ne fonctionnait pas** — et n'avait en réalité **jamais** fonctionné depuis la création du mod. Deux bombes en main pouvaient donc se poser en même temps, au même endroit. Elles se relaient maintenant proprement.

## [1.9.0] — 2026-07-11

### Ajouté
- **Nouvelle arme : la Bombe de Poison** (4 niveaux), proposée dans la boutique de Bomberto et sélectionnable comme arme de départ. Elle n'inflige **aucun dégât d'explosion** mais **empoisonne les ennemis touchés** : des dégâts sur la durée qui **ignorent l'armure** et qui scalent sur l'**ingénierie**, à la manière d'une tourelle enflammée. Ses flammes sont **vertes**, et son infobulle annonce des « dégâts de poison » plutôt qu'une brûlure générique.

### Corrigé
- **Les dégâts de poison ne sont plus amputés des trois quarts.** Le malus de dégâts de Bomberto (-75 %) s'appliquait au poison alors qu'il ne devait pas : l'infobulle affichait la bonne valeur (par exemple 17 par tic) mais les ennemis n'en prenaient que le quart (4). Le poison inflige désormais réellement ce qui est annoncé.

### Modifié
- **Les éclairs de la Bombe de Foudre repoussent désormais les ennemis.** Comme ils partent en étoile depuis la bombe, les ennemis pris dans la salve sont soufflés vers l'extérieur : la Bombe de Foudre devient une vraie arme de **contrôle**, là où la Glace ralentit. La dispersion s'intensifie avec le niveau, puisque le nombre d'éclairs augmente (6 à 10).
- **Ralentissement de la Bombe de Glace revu à la hausse** : 30 / 45 / 60 / **75 %** selon le niveau (au lieu de 30 / 40 / 50 / 60 %).
- **Rééquilibrage des bombes.** La Bombe normale reste la principale source de dégâts de Bomberto, mais son scaling est ramené à 90 % (ingénierie et élémentaire) ; la Bombe de Foudre passe à 100 % ; la Bombe de Poison voit son poison renforcé. Les quatre bombes gardent des rôles distincts : la normale frappe fort, la glace ralentit, la foudre disperse, le poison ronge les blindés.

## [1.8.0] — 2026-07-09

### Ajouté
- **Nouvelle arme : la Bombe de Foudre** (4 niveaux), proposée dans la boutique de Bomberto et sélectionnable comme arme de départ. À la détonation, elle libère une **salve d'éclairs en cercle** (à la manière de l'objet Tyler) qui portent les dégâts — **sans explosion de zone**. Le nombre d'éclairs et les dégâts croissent selon le niveau, avec du scaling ingénierie et élémentaire.

### Corrigé
- **Les dégâts des bombes sont désormais comptabilisés** dans l'infobulle de l'arme (« dégâts infligés » de la dernière vague), comme pour les autres armes. Auparavant, les bombes frappant à distance de l'arme (explosion / éclairs), leurs dégâts n'étaient pas attribués et le compteur restait à 0.

## [1.7.0] — 2026-07-09

### Ajouté
- **Nouvelle arme : la Bombe de Glace** (4 niveaux), proposée dans la boutique de Bomberto et sélectionnable comme arme de départ. Elle n'inflige **aucun dégât d'explosion** mais **ralentit durablement les ennemis touchés** — le ralentissement ne se cumule pas (on garde le plus fort) — et les marque d'un **contour bleu givré**. Son infobulle indique le pourcentage de ralentissement, croissant selon le niveau (30 / 40 / 50 / 60 %).

## [1.6.0] — 2026-07-07

### Modifié
- Nouveau skin de la Bombe : bombe noire classique partout (icône, arme tenue, bombe posée). Le niveau (tier) se lit via le contour coloré en jeu et un fond coloré sur l'icône de boutique.
- Troll bombe agrandie (≈ la taille d'un ennemi de base) pour mieux se voir comme un danger.
- Explosions de bombes plus discrètes : l'opacité de la zone d'effet est réduite (~20 %) pour limiter les flashs répétés (confort visuel / épilepsie). N'affecte ni la zone touchée ni les dégâts.

## [1.5.1] — 2026-07-02

### Corrigé
- **Prix de l'arme Bombe recalé** (erreur de conception). Sa `value` de base était
  bien trop élevée : 40 au tier I, soit le double de l'arme de départ vanilla la
  plus chère (20) et un prix déjà dans la fourchette du tier II. Les 4 tiers sont
  remis sur la courbe canonique d'une arme de base « haut de gamme » (spear, SMG,
  wrench) : **20 / 39 / 74 / 149** (au lieu de 40 / 56 / 78 / 106). En boutique, la
  Bombe tier I coûte désormais ~23 or (comme le SMG) au lieu de ~45. La revente
  s'aligne d'autant.
- **Vignette de Bomberto en sélection de personnage** : son fond se colore
  désormais selon le **danger max battu** (et reçoit un cadre au danger 6), comme
  les persos vanilla. Le perso n'avait aucune entrée de suivi de difficulté
  (`difficulties_unlocked`), à cause de l'ordre de chargement des singletons : le
  danger battu n'était jamais enregistré, la vignette gardait donc le fond par
  défaut. Corrigé en rejouant le déblocage natif du jeu après l'injection du perso.

## [1.5.0] — 2026-07-01

### Ajouté
- **Icône animée de Bomberto** dans la sélection de personnage : la mèche de sa
  bombe se consume jusqu'à l'explosion (flash + éclosion orange/jaune, petit
  sursaut du perso), puis l'icône revient à l'image de départ, en boucle.

## [1.4.1] — 2026-06-30

### Corrigé
- Arme Bombe : suppression du spam de log « Signal already connected » (sur
  `killed_something`, `added_gold_on_crit`, `critically_hit_something`). Le
  `_ready()` vanilla de l'arme rebranche les signaux de la hitbox sans garde
  `is_connected` ; quand il repasse sur la même bombe, Godot refusait (sans effet)
  les connexions en double mais polluait le log. La Bombe nettoie désormais ces
  connexions avant le rebranchement. Purement cosmétique : aucun impact de jeu.

## [1.4.0] — 2026-06-28

### Ajouté
- Arme Bombe : la **vitesse d'attaque raccourcit la mèche** (même formule que le
  cooldown vanilla, plancher 0.5 s). Plus on attaque vite, plus les bombes
  explosent tôt ; une vitesse d'attaque négative rallonge au contraire la mèche.
  S'applique à la bombe normale comme à la troll bombe.

### Corrigé
- Arme Bombe : la **brûlure** fonctionne désormais réellement en jeu. Elle était
  posée sur `stats.burning_data`, un champ que la sérialisation de run ne conserve
  pas (la brûlure retombait à 0 dès le premier passage boutique/vague). Elle passe
  maintenant par un `BurningEffect` dans `WeaponData.effects` (schéma vanilla de la
  Torch), ré-appliqué à chaque calcul de stats et persistant. Brûlure progressive
  par tier inchangée (3 dmg/3 s → 12 dmg/9 s, scaling élémentaire).

## [1.3.0] — 2026-06-27

### Modifié
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
- Arme Bombe : l'explosion **enflamme** désormais les ennemis (même brûlure que la
  **Torch**, progressive par tier : 3 dmg/3 s → 12 dmg/9 s, scaling élémentaire).
- Bombe posée **1.25× plus grosse** (visuel uniquement) ; la troll bombe aussi.

### Corrigé
- La Bombe bénéficie désormais réellement du bonus de **dégâts d'explosion**
  (le buff ingénierie l'atteint).
- **Coop** : une troll bombe ne peut plus **tuer un coéquipier** — le dégât de
  contact est plafonné au PV minimum de **tous** les joueurs vivants.

## [1.2.0] — 2026-06-27

### Ajouté
- « Troll bombe » : une bombe posée peut aléatoirement (~10 %) se réveiller en
  cours de mèche, se transformer en danger mobile inarrêtable et poursuivre le
  joueur vivant le plus proche pour lui exploser au visage (touche joueurs/alliés,
  jamais les ennemis).
  - Télégraphe de réveil : un son d'alerte retentit et la troll bombe reste
    immobile un court instant avant le début de la poursuite, et elle n'apparaît
    jamais juste sur un joueur.
  - La couleur du corps correspond au tier de la bombe d'origine, avec un visage
    en colère en surimpression.
  - Non-létale : les dégâts de contact et l'AoE de fin de minuteur sont plafonnés
    pour toujours laisser le joueur à au moins 1 PV.

## [1.1.0] — 2026-06-26

### Ajouté
- « Bombertoe » v1.1.0 : apparence de personnage façon patate, icône en jeu, et
  outils de packaging.
- Classes Élémentaire + Ingénierie sur la Bombe, avec le scaling correspondant.
- Bombes colorées par tier.

### Modifié
- La boutique ne propose plus que la Bombe (le pool d'armes est filtré).
- Fusion des trois apparences séparées en un seul `bomberman_appearance.tres` ;
  mise à jour de l'icône et des sprites de bombe.
- La bombe posée utilise désormais le sprite de dynamite vanilla au lieu d'une mine.

### Corrigé
- Les bombes peuvent à nouveau être relancées (réinitialise `_is_shooting` après
  en avoir posé une).
- Les bombes n'apparaissent plus en dehors des vagues (phase d'amélioration).

## [1.0.0] — 2026-06-24

### Ajouté
- Première version jouable (art provisoire) : personnage bombes-uniquement avec
  bonus d'explosion et bans d'armes, arme Bombe sur 4 tiers, entité bombe posée
  (mèche puis explosion vanilla), déphasage du cooldown par slot pour un « train »
  de bombes échelonné.
- Traductions FR/EN (dans le code).

### Corrigé
- Déverrouille explicitement l'arme + le personnage (ordre des autoloads).
- `projectile_speed` non nul sur les stats de la Bombe (évite une division par zéro).

## [0.1.0] — 2026-06-23

### Ajouté
- Squelette du mod : se charge en jeu, runner de tests, logique pure de mèche par
  tier et de déphasage par slot (TDD).
