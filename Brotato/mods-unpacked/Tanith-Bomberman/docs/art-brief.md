# Brief de génération d'art IA — Mod Bomberman

Ce document décrit les assets graphiques à produire pour le mod Bomberman.
Tous les sprites sont en **pixel-art** style Brotato (cartoon coloré, palette limitée, fond transparent PNG).

---

## Tableau récapitulatif des assets

| Asset | Fichier cible | Dimensions | Description courte |
|---|---|---|---|
| Yeux | `bomberman_eyes.png` | 150×150 px | Yeux grands et ronds, style overlay patate Brotato |
| Bouche | `bomberman_mouth.png` | 150×150 px | Sourire malicieux, style overlay patate Brotato |
| Casque | `bomberman_helmet.png` | 150×150 px | Casque blanc/bleu Bomberman sur le haut de la patate |
| Icône personnage | `bomberman_icon.png` | 96×96 px | Portrait Bomberman cartoon pixel-art |
| Sprite arme (tenu) | `bomb.png` | 80×80 px | Petite bombe noire tenue à la main, mèche allumée |
| Icône arme | `bomb_icon.png` | 96×96 px | Icône bombe pour l'interface (codex, boutique) |
| Bombe posée | `bomb_entity_sprite.png` | 48×48 px | Bombe ronde à mèche, vue 3/4 légèrement dessus |
| Preview Workshop | `bomberto_preview.png` | 640×640 px | Vignette de la page Steam Workshop (titre **BOMBERTO**) |

---

## Prompts complets par asset

### 1. Yeux — `bomberman_eyes.png` (150×150)

```
Pixel art sprite, Brotato game style, transparent background PNG.
Facial overlay layer for a potato character.
Two large round eyes, white sclera, dark pupils, slight shine reflection dot.
Slightly determined or mischievous expression.
Centered on a 150x150 canvas with generous transparent padding on all sides.
Clean black outlines, 2-3 pixel border, flat cartoon shading.
Palette: white (#FFFFFF), light grey (#CCCCCC), dark grey (#333333), black (#111111).
No extra elements, no background fill.
```

### 2. Bouche — `bomberman_mouth.png` (150×150)

```
Pixel art sprite, Brotato game style, transparent background PNG.
Facial overlay layer for a potato character.
Mischievous grin or confident smile, showing small square teeth.
Centered on a 150x150 canvas, generous transparent padding.
Clean black outlines, 2-3 pixel border, flat cartoon shading.
Palette: white teeth (#FFFFFF), pink mouth interior (#E87070), dark outline (#111111).
No background, no fill outside the mouth shape.
```

### 3. Casque — `bomberman_helmet.png` (150×150)

```
Pixel art sprite, Brotato game style, transparent background PNG.
Bomberman-style round helmet, white or light blue top, sits on top of the potato.
Rounded dome shape, small visor line or subtle rim detail.
Centered on a 150x150 canvas, helmet occupies upper ~70% of canvas.
Clean black outlines, 2-3 pixel border, flat cartoon shading with a highlight spot.
Palette: white (#F0F0F0), sky blue (#88BBDD), dark outline (#111111), highlight (#FFFFFF).
No background fill, rest of canvas fully transparent.
```

### 4. Icône personnage — `bomberman_icon.png` (96×96)

```
Pixel art icon, Brotato game style, transparent background PNG, 96x96 pixels.
Portrait of Bomberman potato character: round potato body wearing a white Bomberman helmet,
large cartoon eyes visible on the face, holding a small black bomb with a lit fuse.
Vibrant cartoon style matching Brotato character icons (e.g., Well-Rounded, Engineer).
Strong black outlines (2 pixels), limited palette, flat shading with minimal highlights.
Palette: potato yellow/cream (#D4B86A), white helmet (#F0F0F0), black bomb (#222222),
red fuse spark (#FF4444), dark outline (#111111).
Fully transparent background, character centered and occupying ~80% of canvas.
```

### 5. Sprite arme (tenu) — `bomb.png` (80×80)

```
Pixel art weapon sprite, Brotato game style, transparent background PNG, 80x80 pixels.
A small classic round black bomb held or floating, slight 3/4 angle.
Shiny round black body with a highlight spot. Short curved fuse at top with a small orange spark.
Matches Brotato weapon sprite style (simple, readable, slightly cartoonish).
Strong black outline (1-2 pixels), flat shading.
Palette: bomb black (#1A1A1A), highlight grey (#555555), fuse brown (#774400), spark orange (#FF8800).
Transparent background, bomb occupying ~55% of canvas, centered.
```

### 6. Icône arme — `bomb_icon.png` (96×96)

```
Pixel art item icon, Brotato game style, transparent background PNG, 96x96 pixels.
Classic round bomb icon: black sphere with a lit fuse, slight cartoon style.
Matches Brotato shop/codex weapon icon style (bold, clear, square format).
Strong black outline (2 pixels), vivid colors, flat shading with a glossy highlight spot.
Palette: bomb black (#1A1A1A), sphere highlight (#4A4A4A), fuse brown (#774400),
spark yellow-orange (#FFAA00), outline black (#000000).
Centered on canvas, bomb occupying ~75% of the icon area, transparent background.
```

### 7. Bombe posée — `bomb_entity_sprite.png` (48×48)

```
Pixel art entity/projectile sprite, Brotato game style, transparent background PNG, 48x48 pixels.
Round black bomb placed on the ground, viewed from a slight top-down 3/4 angle (matches Brotato enemy/item entities).
Short lit fuse, small animated-frame-ready design (static is fine).
Tiny scale: bomb occupies ~32x32 pixels centered in the 48x48 canvas.
Strong black outline (1 pixel at this scale), flat shading with a single highlight dot.
Palette: black (#111111), dark grey highlight (#444444), fuse brown (#663300), spark orange (#FF6600).
Transparent background, no shadow, no extra elements.
```

### 8. Preview Workshop — `bomberto_preview.png` (640×640)

> Remplace l'ancien `bombertoe_preview.png` (titre périmé « BOMBERTOE »). Seul le
> **titre change** : « BOMBERTOE » → « **BOMBERTO** ». La composition reste la même.

```
Steam Workshop preview thumbnail, 640x640, Brotato cartoon pixel-art style.
Dark green vignette background with a soft golden glow behind the character.
Center: the Bomberto potato character (white Bomberman helmet, large round eyes,
angry brows, holding a small black lit bomb).
Top: bold rounded title text "BOMBERTO" in bright yellow/gold with a dark outline.
Bottom row: the four tier-colored bombs (grey, blue, purple, red), left to right.
Bottom caption in white: "Pose des bombes - 4 tiers".
```

---

## Procédure de dépôt

### Chemins de dépôt des PNG

Déposer les PNG dans les dossiers suivants du mod :

**Personnage Bomberman :**
```
Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/
  bomberman_eyes.png
  bomberman_mouth.png
  bomberman_helmet.png
  bomberman_icon.png
```

**Arme Bombe :**
```
Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/
  bomb.png          (sprite tenu en jeu)
  bomb_icon.png     (icône boutique/codex)

Brotato/mods-unpacked/Tanith-Bomberman/content/entities/
  bomb_entity_sprite.png   (sprite de la bombe posée au sol)
```

### Mise à jour des `.tres`

Après dépôt des PNG, il faut mettre à jour les ressources `.tres` pour pointer vers les nouveaux fichiers :

- `content/characters/bomberman/bomberman_data.tres` → champ `icon` → `bomberman_icon.png`
- `content/characters/bomberman/` → créer des `ItemAppearanceData` `.tres` pour yeux, bouche, casque (à la façon de `apprentice_eyes_appearance.tres` etc.)
- `content/weapons/bomb/bomb_1_data.tres` (et niveaux 2-4) → champ `icon` → `bomb_icon.png`
- `content/entities/bomb_entity.tscn` → nœud Sprite → `texture` → `bomb_entity_sprite.png`

### Régénération des `.import`

**Obligatoire** après tout ajout ou remplacement de PNG :

1. Lancer l'éditeur Godot 3 avec le projet Brotato.
2. L'éditeur détecte les nouveaux fichiers et génère automatiquement les `.import` correspondants.
3. Vérifier que chaque PNG est importé en mode **2D** (pas 3D) et que la compression est désactivée (« Lossless »/« Vram Compressed = false ») pour préserver la netteté pixel-art.
4. Fermer l'éditeur. Les fichiers `.import` doivent être versionnés avec les PNG.

> **Ne pas versionner** les PNG sans leurs `.import` — le jeu ne peut pas charger les textures sans eux.
