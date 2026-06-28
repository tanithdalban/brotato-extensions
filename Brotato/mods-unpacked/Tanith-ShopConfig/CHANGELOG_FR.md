# ShopConfig — Journal des modifications

Un écran de configuration du pool du magasin, par joueur, inséré entre la
sélection du personnage et celle de l'arme. Chaque joueur y exclut des
objets/armes pour qu'ils n'apparaissent jamais dans *sa propre* boutique de la run.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/).

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
