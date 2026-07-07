# Bomberman — Journal des modifications

Un mod de personnage pour Brotato : « Bomberto », un personnage lanceur de bombes
dont la boutique propose aussi des armes explosives et de mêlée à fort knockback,
accompagné d'une arme Bombe qui pose des bombes à intervalle régulier (sans visée)
et mise sur les dégâts d'explosion et le scaling élémentaire/ingénierie.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/).

## 1.6.0
- Nouveau skin de la Bombe : bombe noire classique partout (icône, arme tenue, bombe posée). Le niveau (tier) se lit via le contour coloré en jeu et un fond coloré sur l'icône de boutique.

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
