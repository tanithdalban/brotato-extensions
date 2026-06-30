# Icône animée de Bomberto (écran de sélection de perso) — design

**Date :** 2026-06-30
**Mod :** `Tanith-Bomberman`
**Statut :** spec validé (brainstorming). Implémentation NON faite (reportée).

## Objectif

Animer l'icône du personnage **Bomberto** dans l'écran de sélection de perso :
la mèche de sa bombe se consume jusqu'à l'explosion, puis l'icône revient à
l'image de départ, **en boucle**. But : donner de la vie et de l'identité au
perso dès l'écran de choix.

## Décisions (issues du brainstorming)

| Question | Choix retenu |
|---|---|
| Cadrage | **Hybride** : Bomberto visible en fond + sa bombe agrandie au premier plan (bas-centre), mèche lisible. |
| Réaction de Bomberto | **Réagit à l'explosion** : sursaut (squash-and-stretch) au boom, puis retour au calme. |
| Portée | **Écran de sélection de perso uniquement** (pas le corps en jeu, pas le HUD). |
| Intensité explosion | **Punchy & juicy** : flash franc + éclosion orange/jaune + petit screen-pop. |

## Pourquoi c'est faisable proprement

Dans `ui/menus/shop/item_description.gd`, l'icône est un simple
`TextureRect` : `_icon.texture = item_data.get_icon()`. Or en Godot 3.x
**`AnimatedTexture` hérite de `Texture`** → une `AnimatedTexture` posée sur
`character.icon` s'anime toute seule, sans modifier le rendu vanilla. L'écran
anime déjà une icône (le `random_icon` via `AnimationPlayer`), preuve que
l'animation d'icône fonctionne ici.

On réutilise deux patterns **déjà éprouvés** dans le mod :
- `content/logic/bomb_skin.gd` : `Image.load` au runtime (hors cache d'import).
- `extensions/singletons/item_service.gd._ready()` : mutation d'icône au runtime
  (`w.icon = skin`).

## Approche retenue : frames PNG + `AnimatedTexture` au runtime

Alternatives écartées :
- **Sprite-sheet + `AtlasTexture`** : 1 fichier au lieu de N, mais logique de
  découpe en plus pour un gain marginal.
- **100 % procédural en GDScript** : compositer l'explosion en GDScript est
  pénible ; repo propre mais douloureux à itérer.

Retenu : on génère ~18 frames PNG hors-ligne (PIL), on les charge via
`Image.load` et on les empile dans une `AnimatedTexture` posée sur
`character.icon`. Zéro hack nouveau, art facile à itérer (1 frame = 1 fichier).

## Rendu

- **Canvas** : 96×96 (taille native de l'icône — à confirmer sur
  `bomberman_icon.png`).
- **Composition hybride** : Bomberto en fond (`bomberman_icon.png`), bombe
  agrandie au premier plan bas-centre (`bomb_*_48.png` / `bomb_*.png`) avec sa
  mèche bien lisible.
- **Boucle (~18 frames @ 12 fps ≈ 1,5 s)** :
  1. **Idle** (~2 frames) : image de départ, mèche pleine.
  2. **Mèche** (~10 frames) : étincelle lumineuse qui descend la mèche, mèche
     qui raccourcit progressivement.
  3. **Explosion punchy** (~4 frames) : flash blanc + éclosion orange/jaune
     (halo `projectiles/rocket/explosion.png` du jeu agrandi + burst procédural).
  4. **Réaction + settle** (~2 frames) : Bomberto sursaute (squash-and-stretch :
     translaté de quelques px + écrasé) au boom, puis retour à l'image 1 → boucle.

## Honnêteté sur la « réaction »

La réaction = **squash-jump procédural** (déplacement + déformation), **pas**
des yeux/une bouche redessinés à la main : l'icône est une image *plate* (les
couches `eyes`/`mouth` du perso ne servent qu'au corps en jeu, pas à l'icône).
Un petit overlay « choc » procédural (goutte de sueur / éclat) est possible,
mais aucune expression faciale peinte. Le rendu est de l'animation **composée
par code** : net et « juicy », pas du pixel-art bespoke peint frame par frame.

## Architecture / composants

- **`content/logic/animated_icon.gd`** (NOUVEAU, logique pure, testable) :
  assemble une `AnimatedTexture` à partir d'une liste de chemins de frames + un
  fps. Responsabilité unique : construire/configurer la texture (nb de frames,
  fps, `oneshot = false` pour boucler). Dépendances : `bomb_skin._load` pour le
  chargement runtime des PNG.
  - Interface : `build(frame_paths: Array, fps: float) -> AnimatedTexture`.
  - Testable headless : nb de frames posées, fps, drapeau de bouclage. (Le
    chargement réel des PNG se vérifie en jeu, comme pour `bomb_skin`.)
- **`extensions/singletons/item_service.gd`** (point d'accroche) : dans
  `_ready()`, après le chargement du perso Bomberman, `character.icon =
  AnimatedIcon.build(<frames>, 12.0)` — à côté du `w.icon = skin` existant.
- **`tools/` (NON embarqué dans le mod)** : script PIL qui génère les ~18 PNG
  dans `content/characters/bomberman/icon_anim/`. Reproductible et versionné,
  comme la preview Workshop.

## Flux

`ItemService._ready()` (extension Bomberman) → construit l'`AnimatedTexture` →
l'assigne à `character.icon` → l'écran de sélection lit `get_icon()` → la pose
sur son `TextureRect` → animation automatique en boucle.

## Tests

- **Pur (headless, runner Bomberman)** : `animated_icon.build()` produit une
  `AnimatedTexture` avec le bon nb de frames, le bon fps, et le bouclage activé ;
  cas limites (liste vide → null ou texture vide ; fps ≤ 0 borné).
- **En jeu (manuel)** : l'icône s'anime bien dans la sélection et boucle ;
  pas de figement sur la 1ʳᵉ frame ; pas de régression sur les autres persos.

## Risques à vérifier EN JEU

- La sélection lit bien `character.get_icon()` / `.icon` et **aucun cache** ne
  fige la 1ʳᵉ frame.
- Une `AnimatedTexture` dans le `TextureRect` de la sélection s'anime
  effectivement (devrait, par temps moteur).
- ⚠️ **Corruption du jeu décompilé** : lancer Godot sur `Brotato/` peut
  supprimer des `ext_resource` PNG de certains `.tres` (cf. note mémoire). Toute
  vérif en jeu se fait avec ce risque en tête / sauvegarde préalable.

## Hors périmètre (YAGNI)

- Pas d'animation du corps du perso en jeu, ni du HUD.
- Pas d'expression faciale peinte (réaction = mouvement procédural seulement).
- Pas de généralisation à d'autres persos.

## Reste à faire (prochaine session)

1. Générer les frames (script PIL).
2. Implémenter `animated_icon.gd` + ses tests purs.
3. Brancher dans `item_service.gd._ready()`.
4. Vérifier en jeu (avec garde anti-corruption).
