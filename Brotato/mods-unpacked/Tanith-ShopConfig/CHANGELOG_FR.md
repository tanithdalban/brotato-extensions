# ShopConfig — Journal des modifications

Un écran de configuration du pool du magasin, par joueur, inséré entre la
sélection du personnage et celle de l'arme. Chaque joueur y exclut des
objets/armes pour qu'ils n'apparaissent jamais dans *sa propre* boutique de la run.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] — 2026-07-19

### Modifié
- **L'écran adopte le style visuel du jeu de base** : thème vanilla (panneaux
  arrondis, polices Brotato, boutons stylés) au lieu du skin gris par défaut, et
  fond texturé du magasin à la place de l'aplat noir — les panneaux et boutons se
  détachent enfin. Les filtres tier/classe passent aussi au skin natif.
- **Grille d'objets/armes responsive** : le nombre de colonnes s'ajuste à la
  largeur disponible et remplit le panneau au lieu de laisser un vide à droite.
- Barre de filtres et actions plus lisibles et compactes : libellés complets
  quand il y a la place, resserrés dans les configurations à 3-4 joueurs sans
  déborder de l'écran.

### Corrigé
- La navigation clavier dans la grille **fait désormais défiler** pour suivre le
  focus (cas solo sans manette).

## [1.0.1] — 2026-07-15

### Corrigé
- L'option **« Config du magasin »** n'apparaît plus **en double** dans le
  panneau d'options quand un autre mod étend le même écran de sélection de
  personnage (constaté avec le mod Bomberman, qui rejoue le `_ready()` vanilla).
  L'ajout de la case est désormais idempotent.

## [1.0.0] — 2026-06-29

Première version stable : toutes les anomalies connues sont corrigées.

### Corrigé
- **Coop** : la navigation manette/clavier ne « bave » plus quand on ouvre un
  filtre (tier ou classe). Les filtres étaient des listes déroulantes natives
  dont le menu surgissant était *globalement modal* — il figeait/parasitait
  l'autre joueur. Ils sont désormais des listes déroulantes « maison »
  affichées dans le panneau (de vrais boutons navigables au focus de chaque
  joueur, sans menu surgissant natif) : on revoit toutes les valeurs et la
  navigation reste bornée à chaque joueur.

## [0.4.3] — 2026-06-27

### Modifié
- L'option « Config du magasin » est désormais **activée par défaut** (auparavant
  désactivée). L'écran est actif sauf si le joueur décoche explicitement la case —
  un filet de sécurité au cas où la case n'apparaîtrait pas dans le panneau d'options
  de la run.

## [0.4.2] — 2026-06-27

### Corrigé
- Un objet exclu pouvait encore se glisser dans la boutique via le repli de pioche
  vanilla. Quand la boutique est restreinte à un seul objet (p. ex. un build
  Bombe-uniquement), le second slot vidait le pool anti-doublon et le jeu retombait
  sur un accès direct, non filtré, au tier que `get_pool` ne peut pas intercepter. La
  pioche aléatoire est désormais encapsulée : si l'objet tiré est exclu, il est
  remplacé par un objet autorisé (du même type d'abord, sinon de l'autre type), en
  tolérant un doublon dans le cas de la boutique à objet unique.

## [0.4.1] — 2026-06-26

### Ajouté
- Option facultative pour activer/désactiver l'écran de config du magasin
  (désactivée par défaut).

### Modifié
- Déplacement de l'option « Config du magasin » en bas du panneau d'options.

## [0.4.0] — 2026-06-20

### Ajouté
- Persistance des exclusions en mémoire de session (conservées d'une run à l'autre,
  sans fichier disque ; effacées automatiquement à la fermeture du jeu).

### Modifié
- Bouton Prêt plus grand et coche de validation verte (pratique en coop).
- Ajustement de la taille des icônes d'aide aux touches.

## [0.3.0] — 2026-06-20

### Ajouté
- Retour beta #2 : actions rapides, aides touches/boutons, onglets clavier/manette.
- Mise en avant des actions rapides, popup `ui_info`, dédoublonnage des armes, et un
  garde-fou « garder au moins quelques objets ».

## [0.2.0] — 2026-06-20

### Modifié
- Refonte de l'écran en une scène autonome plein écran (split horizontal, sortie via
  `change_scene`) ; suppression des anciens bricolages d'overlay.
- L'entrée se fait désormais par un swap manuel de scène.

### Ajouté
- Navigation coop par joueur via un `FocusEmulator` dédié par panneau.
- Onglets Objets/Armes en boutons focusables, navigables à la manette.

## [0.1.0] — 2026-06-19

### Ajouté
- Version initiale : unités de logique pure (`pool_filter`, store), logger activable.
- Extension `ItemService` filtrant le pool de pioche, strictement bornée à la boutique.
- UI complète (infobulle, filtres tier/classe, retour) et insertion dans le flux de run.
