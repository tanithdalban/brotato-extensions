# Spec — Écran de configuration du magasin (mod Brotato)

- **Date** : 2026-06-19
- **Statut** : Design validé, en attente de revue finale
- **Type** : Mod Brotato (Godot 4 + Brotato ModLoader)
- **Distribution** : Usage personnel d'abord, structure prête pour Steam Workshop plus tard

## 1. Objectif

Ajouter, dans le flux de démarrage d'une partie, un **nouvel écran** situé **entre la sélection du personnage et la sélection de l'arme de départ**. Cet écran permet à chaque joueur de **paramétrer le pool d'objets et d'armes** dans lequel son magasin piochera pendant la partie.

Le but est de permettre des runs personnalisées / défis / builds curés : en retirant du contenu du pool, le joueur rend les éléments restants plus fréquents (sans rien forcer ni casser la probabilité naturelle).

## 2. Modèle conceptuel

L'écran définit, **par joueur**, le **pool de pioche** du magasin.

- On part de **tout le contenu compatible avec le personnage** choisi (tout est dans le pool par défaut).
- Le joueur **retire** ce qu'il ne veut pas voir.
- On ne stocke que **les exclusions** (la liste des IDs retirés). Aucun état « normal » ni « garanti » n'est stocké : le défaut est implicite.
- Le jeu continue de **piocher naturellement** dans le pool restant : les tiers, la chance (luck) et la vague gouvernent l'apparition comme d'habitude.

### Conséquence assumée : pas de garantie absolue

Il n'existe **pas** de mécanisme qui force un objet à apparaître. « Garantir » se traduit par « rester dans le pool ». Un objet de tier élevé n'apparaîtra que **quand son tier est naturellement éligible** (pas dès la vague 1) et seulement si la pioche le sort. Plus le joueur **réduit** son pool, plus ses éléments gardés reviennent souvent — c'est le comportement recherché.

### Trois couches de filtrage combinées

Elles s'appliquent dans cet ordre, **sans interférence mutuelle** :

1. **Compatibilité personnage** — logique native du jeu (objets/armes interdits pour la classe choisie). Déjà appliquée par le jeu.
2. **Exclusion native** — la liste d'exclusion intégrée de Brotato (limite de 8 par défaut). **Jamais** modifiée par le mod.
3. **Exclusions de notre écran** — par joueur. Couche **additive** appliquée au moment de la génération du pool du magasin.

Un élément est écarté s'il est exclu par **n'importe laquelle** de ces couches (union).

## 3. Périmètre

**Dans le périmètre (v1) :**

- Paramétrage des **objets** (items passifs) **et des armes** proposés par le magasin.
- Un pool **par joueur**, jusqu'à **4 joueurs** en coop local.
- Config définie **avant** la partie, **figée** pendant la run, **remise à zéro** à chaque nouvelle partie (aucune persistance, aucun preset).

**Hors périmètre (v1) :**

- La fonction « garantir / forcer » une apparition (remplacée par la curation du pool).
- Toute mécanique d'obtention d'objets **hors magasin** (récompenses spéciales, mods tiers à sources alternatives).
- Persistance / presets nommés / mémorisation de la dernière config.
- Édition de la config **en cours de partie**.
- Packaging et métadonnées Steam Workshop (préparé structurellement, pas réalisé).

## 4. Écran & UI

### 4.1 Position dans le flux

```
Menu → Sélection perso (par joueur) → [NOUVEL ÉCRAN : Config magasin] → Sélection arme de départ → Partie
```

L'écran est placé **après** le choix du personnage : il connaît donc le perso de chaque joueur et peut filtrer le contenu en conséquence.

### 4.2 Disposition responsive (calquée sur les écrans coop natifs)

- **1 joueur** = plein écran.
- **2 joueurs** = deux moitiés.
- **3-4 joueurs** = quarts d'écran.
- Chaque joueur édite **son quadrant** avec **sa propre manette**, **simultanément**.
- Chaque joueur dispose d'un bouton « **Prêt** ». On avance vers la sélection d'arme uniquement quand **tous** sont prêts (même logique que les écrans natifs).

### 4.3 Contenu d'un quadrant

- Deux onglets : **Objets** / **Armes**.
- **Grille d'icônes** scrollable. Chaque case = l'**icône** de l'objet/arme, avec une **case à cocher** (état binaire : dans le pool / exclu). **Tout est coché** (dans le pool) au départ.
- **Infobulle** (nom + description) affichée sur l'élément en **focus** (navigation manette).
- **Filtres de navigation** : par **tier**, par **tag** (ingénierie, structure, etc.), par **type d'arme**. Les filtres aident seulement à parcourir la grille ; ils ne modifient pas la sélection.
- La grille est **pré-filtrée par le personnage** du joueur (couche 1) : les éléments interdits pour sa classe **n'apparaissent pas**.

### 4.4 Actions rapides

- « **Tout réinitialiser** » : remet tout le contenu de l'onglet courant dans le pool.
- « **Tout désélectionner** » : retire tout le contenu de l'onglet courant du pool. Utile pour les **builds précis** (tout exclure puis re-cocher les quelques éléments voulus, plus rapide que décocher un par un). Le risque de magasin vide est couvert par le garde-fou (§4.5) : impossible de valider tant qu'il ne reste rien à acheter.
- « **Exclure tout l'affiché** » : exclut uniquement le sous-ensemble **actuellement filtré** (ex. filtrer les armes à distance, ou un tier, puis tout exclure d'un coup). **Désactivé s'il n'y a aucun filtre actif**.

### 4.5 Garde-fou « pas de magasin vide »

- **Blocage dur** : un joueur ne peut pas passer « Prêt » si son pool est **entièrement vide**. Le bouton reste désactivé avec un message clair (« Garde au moins quelques objets/armes »).
- Le minimum est vérifié **globalement** : il doit rester **au moins un élément achetable** (objet **ou** arme), peu importe lequel. Cela autorise les builds « tout objets, zéro arme » (ou l'inverse).
- **Avertissement souple** : si le pool restant est non vide mais **plus petit que la taille d'un magasin**, on affiche un avertissement discret (le magasin proposera moins d'éléments) sans bloquer — c'est un choix de jeu valable.

## 5. Architecture technique

### 5.1 Approche retenue (Approche A — filtrage à la génération du pool)

Un **autoload de mod** conserve, pour la partie en cours, les exclusions de chaque joueur. À la validation de l'écran, ces exclusions y sont écrites. On **étend la fonction native de génération du pool du magasin** : avant la pioche pondérée du jeu, on **retire les IDs exclus** du joueur de la liste des candidats. Aucune injection, aucune manipulation de tier → la probabilité naturelle est préservée et les couches « compatibilité perso » et « exclusion native » restent appliquées par le jeu lui-même.

### 5.2 Structure des fichiers (ModLoader)

```
Auteur-ConfigMagasin/
├── manifest.json              # métadonnées, version, compatibilité Brotato
├── mod_main.gd                # installe les extensions, enregistre l'autoload + la scène
├── extensions/
│   ├── <navigation menu>      # insère notre écran entre perso et arme
│   └── <génération pool shop> # retire les exclusions avant la pioche native
├── scenes/
│   ├── shop_config_screen.tscn / .gd        # conteneur responsive multi-joueurs
│   └── player_shop_config_panel.tscn / .gd  # un quadrant : grille, filtres, infobulle, Prêt
├── singletons/
│   └── shop_config_store.gd   # autoload : exclusions par joueur, reset par partie
└── content/logic/
    └── pool_filter.gd         # fonction PURE : (candidats, exclus) → candidats filtrés
```

### 5.3 Composants

| Composant | Responsabilité | Dépend de |
|---|---|---|
| `mod_main.gd` | Point d'entrée ModLoader : installe les script extensions, enregistre l'autoload et la scène. | API ModLoader |
| `shop_config_store.gd` (autoload) | Stocke `joueur → ensemble d'IDs exclus` pour la run. Reset au démarrage d'une partie. | — |
| `shop_config_screen` | Conteneur responsive : instancie un panneau par joueur, gère le layout 1/2/4 et la condition « tous prêts ». | données joueurs/persos |
| `player_shop_config_panel` | Un quadrant : grille d'icônes, onglets, filtres, infobulle, actions rapides, garde-fou, bouton Prêt. | liste vivante objets/armes, compat perso |
| `pool_filter.gd` | Fonction **pure** retirant un ensemble d'exclusions d'une liste de candidats. | — |
| Extension navigation | Insère l'écran entre sélection perso et sélection arme ; écrit les exclusions dans l'autoload à la validation. | scripts de navigation natifs |
| Extension génération pool | Lit l'autoload pour le joueur concerné et applique `pool_filter` avant la pioche native. | scripts de magasin natifs |

### 5.4 Sources de données

- **Liste des objets/armes** : on lit la **liste vivante** du jeu (incluant les ajouts d'autres mods), avec pour chaque élément : ID, icône, nom, description, tier, tags, type d'arme.
- **Compatibilité personnage** : on **réutilise la logique native** du jeu déterminant ce qui est disponible pour un perso, plutôt que de maintenir notre propre liste d'interdictions (robuste face aux mises à jour du jeu et aux mods ajoutant des persos).

### 5.5 Points à localiser pendant l'implémentation

Les noms exacts des scripts/fonctions natifs sont à confirmer par exploration du code décompilé / des sources du jeu :

- La fonction de **transition** entre l'écran de sélection de perso et celui de sélection d'arme (point d'insertion de notre écran).
- La fonction de **génération du pool du magasin** par joueur (point d'application du filtre).
- La fonction/structure native de **compatibilité objet/arme ↔ personnage** (réutilisée pour pré-filtrer la grille).
- L'accès à la **liste vivante** des objets/armes et à leurs métadonnées (tier, tags, icône, description).

### 5.6 Principes transverses

- **Non destructif** : le mod n'écrit jamais dans les données natives (exclusion native incluse). Tout passe par des script extensions et un autoload propre au mod.
- **Modulaire** : la logique de filtrage est isolée dans une fonction pure, l'UI est séparée du stockage, le stockage est séparé de l'intégration magasin. Chaque unité est compréhensible et testable indépendamment.
- **Prêt pour le Workshop** : structure et manifeste compatibles avec une future publication sans refonte.

## 6. Cas limites

- **Pool entièrement vide** : interdit par le garde-fou (bouton Prêt désactivé, vérif globale objet-ou-arme).
- **Pool très réduit** (non vide mais < taille d'un magasin) : autorisé, avertissement discret, le magasin propose moins d'éléments.
- **Exclusion native (8 slots)** : s'additionne à la nôtre, jamais modifiée.
- **Reroll / lock natifs** : continuent de fonctionner normalement sur le pool curé.
- **Hors magasin** : seul le pool du **magasin** est affecté ; les obtentions par d'autres mécanismes sont hors scope v1.
- **En cours de partie** : config figée ; remise à zéro à la partie suivante.
- **Mods tiers ajoutant objets/persos** : pris en charge automatiquement via la liste vivante + la compat native.
- **Nombre de joueurs** : supposé fixé avant notre écran (pas de join/leave pendant la config).

## 7. Stratégie de tests

- **Logique pure** (`pool_filter.gd`) testée en isolation (GUT si disponible) :
  - les IDs exclus sont retirés des candidats ;
  - un ID exclu inconnu est ignoré sans erreur ;
  - exclusion de la totalité → liste vide (le garde-fou UI empêche ce cas en amont, mais la fonction reste correcte).
- **Checklist QA manuelle** :
  - les éléments exclus n'apparaissent **jamais** dans le magasin sur plusieurs vagues ;
  - l'exclusion native (8 slots) reste pleinement fonctionnelle et indépendante ;
  - les interdits de classe sont **absents de la grille** ;
  - layouts corrects en 1 / 2 / 3 / 4 joueurs, chacun pilotable à la manette ;
  - garde-fou « pas de magasin vide » : bouton Prêt désactivé quand pool vide ;
  - avertissement affiché quand pool réduit mais non vide ;
  - actions rapides « Tout réinitialiser », « Tout désélectionner », et « Exclure tout l'affiché » (désactivée sans filtre) ;
  - après « Tout désélectionner », le bouton Prêt reste désactivé jusqu'à re-cocher au moins un élément (garde-fou) ;
  - config bien remise à zéro à la partie suivante.

## 8. Décisions clés (récapitulatif)

| # | Décision |
|---|---|
| 1 | Écran inséré entre sélection perso et sélection arme. |
| 2 | Paramétrage **objets + armes**. |
| 3 | Modèle = curation du **pool de pioche** ; on ne stocke que les **exclusions**. |
| 4 | Pas de garantie absolue : « garder dans le pool » = apparition **naturelle**. |
| 5 | Sélection **objet par objet** via grille d'icônes ; tier/tag/type = **filtres de navigation**. |
| 6 | **Un pool par joueur**, jusqu'à 4, écran **responsive** (1/2/4), navigation **manette**. |
| 7 | Filtrage en **3 couches** (compat perso → exclusion native → notre écran), additif, non destructif. |
| 8 | **Aucune persistance** : reset à chaque partie. |
| 9 | Trois actions rapides : Tout réinitialiser / Tout désélectionner / Exclure tout l'affiché. Garde-fou **global** contre le magasin vide (impossible de valider un pool vide). |
| 10 | Approche technique **A** (filtrage à la génération du pool via script extension ModLoader). |
| 11 | Usage **personnel** d'abord, structure **prête pour le Workshop**. |
