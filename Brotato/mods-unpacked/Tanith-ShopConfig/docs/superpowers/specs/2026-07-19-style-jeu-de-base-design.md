# Design — Aligner le style du ShopConfig sur le jeu de base

**Date** : 2026-07-19
**Mod** : Tanith-ShopConfig
**Périmètre choisi** : thème global (le plus léger, le moins risqué)

## Objectif

L'écran de configuration du magasin (`shop_config_screen.gd` + `player_shop_config_panel.gd`)
est construit intégralement en code et rendu avec le **skin Godot par défaut** (boutons gris
plats, polices système). On veut lui donner le **look du jeu de base** : panneaux arrondis
semi-transparents, polices Brotato, styleboxes de boutons hover/normal — pour un rendu cohérent
avec le reste des menus.

## Contexte : une décision jadis figée, rouverte proprement

Une décision figée du mod disait de garder le skin par défaut : le « fix DA/thème » avait été
**abandonné** par peur de la **corruption du jeu décompilé** (lancer l'éditeur Godot sur
`Brotato/` supprime des `ext_resource` PNG de certains `.tres`).

Cette peur visait l'**éditeur Godot** et l'édition de fichiers `.tres`. **Aucun des deux n'est
nécessaire ici.** Le jeu applique son style en posant une seule ressource de thème sur le Control
racine d'une scène ; Godot 3 la **propage** à toute la descendance. On fait pareil **100 % par
code au runtime** — aucun éditeur ouvert, aucun `.tres` modifié. Donc **aucun risque de
corruption**. Ce qui avait été abandonné, c'était la méthode risquée, pas l'objectif.

## Approche

Le jeu de base applique `res://resources/themes/base_theme.tres` sur le Control racine de ses
scènes de menu (ex. `weapon_selection.tscn`). Ce thème définit fonts, styleboxes de boutons
(`button_normal`/`button_hover`), panneaux arrondis semi-transparents, barres de défilement, etc.

En Godot 3, un `Control.theme` **se propage à toute la descendance dans le SceneTree**, quel que
soit le nœud qui a créé ces enfants. L'écran, ses panneaux joueurs, et l'overlay des dropdowns
sont tous descendants d'un même Control racine → **une seule pose de thème suffit** pour tout
habiller.

### Changements (tout par code)

1. **Pose du thème** — dans `shop_config_screen.gd` :
   `const BaseTheme := preload("res://resources/themes/base_theme.tres")`, puis affecter
   `theme = BaseTheme` sur le Control racine de l'écran (le nœud sur lequel toute l'UI est
   ajoutée). Effet en cascade sur :
   - le bouton **Retour** ;
   - dans chaque panneau : header joueur, barre de filtres, **les dropdowns maison** (leur
     `PanelContainer` + `Button` deviennent natifs — précisément l'objectif abandonné à l'époque),
     boutons d'action (Réinitialiser / Exclure-Inclure), onglets Objets/Armes, label
     d'avertissement, bouton **Prêt**.

2. **Ce qui reste intact** — les overrides explicites l'emportent sur le thème, donc rien à
   défaire :
   - police `font_35_outline` du bouton Prêt (`add_font_override`) ;
   - atténuation `modulate = 0.5` des onglets inactifs ;
   - coche verte « prêt » (`big_checkmark.png`) ;
   - voile d'exclusion (`ColorRect` sombre) + croix « X » sur les cases ;
   - infobulle riche = déjà le vrai `item_popup.tscn` du magasin.

3. **Fond** — **conservé tel quel** : le `ColorRect` sombre actuel
   (`Color(0.06, 0.06, 0.08, 1.0)`) de `shop_config_screen._build_ui`. Les panneaux du thème
   sont semi-transparents (alpha ≈ 0.78) ; un fond sombre uni les met en valeur. Pas de fond
   « façon magasin » (hors périmètre choisi).

### Point de vigilance : densité (passe de réglage prévue)

Le thème apporte des **polices plus grandes** et des **marges de bouton généreuses** (~15 px).
Dans un split **2 à 4 joueurs**, l'écran peut se retrouver serré ou déborder. Le plan inclut donc
une **passe de réglage en jeu** :
- observer le rendu en solo **et** en coop 4 joueurs ;
- si nécessaire, réduire la police sur les éléments denses (champs de filtres, hints de touches)
  et/ou ajuster les espacements/`rect_min_size` — **sans jamais modifier le thème lui-même** ;
- `CELL_SIZE` et `GRID_COLUMNS` restent inchangés.

Ces ajustements ne sont appliqués **que si** le rendu l'exige : on ne réduit rien à l'aveugle.

## Portée et non-portée

- **Dans le périmètre** : pose du thème global + éventuels réglages de densité par code.
- **Hors périmètre** (non retenu par l'utilisateur) : remplacer les `Button` plats par les
  boutons de menu animés du jeu (`my_menu_button.gd`), thèmes spécifiques par élément, fond de
  type magasin, refonte de disposition.

## Risque

Nul côté fichiers : aucun éditeur Godot ouvert, aucun `.tres` modifié, aucune régénération de
ressource. Le changement est du **code de jeu exécuté au runtime**. La seule inconnue est
esthétique (densité du split), traitée par la passe de réglage.

## Tests / vérification

- La **logique pure** (`content/logic/pool_filter.gd`, `singletons/shop_config_store.gd`) n'est
  pas touchée → les tests unitaires restent verts (aucune régression attendue).
- Le **rendu** se vérifie **en jeu** (comme toute l'UI du mod, non chargeable en headless) :
  - solo : écran affiché entre perso et arme, panneau habillé au thème, dropdowns natifs,
    grille/onglets/filtres lisibles, bouton Prêt et coche OK ;
  - coop 4 joueurs : les 4 panneaux tiennent à l'écran, navigation manette inchangée, pas de
    débordement ; sinon appliquer la passe de réglage.
