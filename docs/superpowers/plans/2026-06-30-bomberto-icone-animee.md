# Icône animée de Bomberto — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** Animer l'icône du perso Bomberto dans l'écran de sélection : la mèche se consume → explosion punchy + sursaut → retour image de départ, en boucle.

**Architecture :** Frames PNG générées hors-ligne (PIL), chargées au runtime via `Image.load` (hors cache d'import) et empilées dans une `AnimatedTexture` posée sur `character.icon`. En Godot 3.x, `AnimatedTexture extends Texture` → drop-in dans le `TextureRect` de la sélection, qui anime tout seul et boucle automatiquement.

**Tech Stack :** Godot 3.6.2 / GDScript ; ModLoader (script extension `ItemService`) ; Python 3 + Pillow pour la génération de frames.

## Global Constraints

- **Langue** : tout en français (commentaires, docs, libellés de commits).
- **Tests** : runner GDScript autonome, **logique 100 % pure uniquement** (les autoloads ModLoader/jeu ne se chargent pas headless). Tout ce qui touche `AnimatedTexture`/`Image.load`/autoloads se vérifie **EN JEU**.
- **Commande test-runner Bomberman** (≠ `./run-tests.sh` qui lance ShopConfig) :
  `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
  (depuis la racine repo ; résultat = ligne `=== N tests, M échec(s) ===`, viser `0 échec(s)` ; erreurs moteur APRÈS = teardown autoloads, sans effet).
- **⚠️ Corruption du jeu décompilé** : lancer Godot sur `Brotato/` (jeu OU test-runner) peut supprimer des `ext_resource` PNG de certains `.tres`. Garder une sauvegarde / savoir restaurer via GDRE avant de lancer.
- **Périmètre strict** : écran de sélection de perso uniquement. Ne pas toucher au corps en jeu ni au HUD.
- **`AnimatedTexture` (Godot 3.x)** : max **256 frames** (`frames`), `fps` (float), `set_frame_texture(i, tex)`. **Boucle automatiquement** (pas de propriété `oneshot` en 3.x).
- **Réutiliser** `content/logic/bomb_skin.gd` `_load(path)` pour le chargement runtime des PNG (ne pas réécrire `Image.load`).
- **Réaction = squash-jump procédural** (mouvement/déformation), PAS d'expression faciale peinte (l'icône est une image plate).

## Structure des fichiers

- **Créer** `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/animated_icon.gd` — helpers purs (`clamp_fps`, `usable_frame_count`) + assemblage runtime `build()`. Responsabilité unique : produire une `AnimatedTexture` bouclée.
- **Modifier** `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd` — ajoute les tests purs des helpers.
- **Créer** `tools/make_bomberto_icon_frames.py` — générateur PIL des frames (NON embarqué dans le mod).
- **Générer** `Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/icon_anim/frame_00.png` … `frame_17.png` (18 frames) — produites par le script ci-dessus.
- **Modifier** `Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd` — point d'accroche `_ready()` : `character.icon = AnimatedIcon.build(...)`.

> Tous les chemins de commande ci-dessous supposent le **répertoire courant = racine repo** (`…/brotato-extension`).

---

### Task 1 : Helpers purs de l'icône animée (TDD headless)

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/animated_icon.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Consumes: rien.
- Produces : `const MIN_FPS := 1.0`, `const MAX_FRAMES := 256` ; `static func clamp_fps(fps: float) -> float` ; `static func usable_frame_count(n: int) -> int`.

- [ ] **Step 1 : Écrire le test qui échoue**

Dans `test/run_tests.gd`, ajouter le preload en tête (à côté des autres `const`) :

```gdscript
const AnimatedIcon = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/animated_icon.gd")
```

Ajouter l'appel dans `_init()` (après `_test_troll_keep_distance()`) :

```gdscript
	_test_animated_icon_helpers()
```

Ajouter la fonction de test (près des autres `_test_*`) :

```gdscript
func _test_animated_icon_helpers():
	# clamp_fps : plancher à MIN_FPS, sinon inchangé.
	_check(_approx(AnimatedIcon.clamp_fps(12.0), 12.0), "anim: fps 12 inchangé")
	_check(_approx(AnimatedIcon.clamp_fps(0.0), AnimatedIcon.MIN_FPS), "anim: fps 0 => plancher")
	_check(_approx(AnimatedIcon.clamp_fps(-5.0), AnimatedIcon.MIN_FPS), "anim: fps négatif => plancher")
	# usable_frame_count : borné [0, MAX_FRAMES].
	_check(AnimatedIcon.usable_frame_count(18) == 18, "anim: 18 frames inchangé")
	_check(AnimatedIcon.usable_frame_count(0) == 0, "anim: 0 frame => 0")
	_check(AnimatedIcon.usable_frame_count(-3) == 0, "anim: négatif => 0")
	_check(AnimatedIcon.usable_frame_count(300) == AnimatedIcon.MAX_FRAMES, "anim: au-delà de 256 => 256")
```

- [ ] **Step 2 : Lancer le test pour vérifier l'échec**

Run : `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected : échec au chargement (preload d'un script inexistant → parse error sur `animated_icon.gd`).

- [ ] **Step 3 : Écrire l'implémentation minimale**

Créer `content/logic/animated_icon.gd` :

```gdscript
extends Reference
# Construit une AnimatedTexture bouclée pour l'icône animée d'un perso.
# Partie PURE (clamp_fps / usable_frame_count) testable headless ; l'assemblage
# build() charge les PNG au runtime (cf. bomb_skin) -> vérifié EN JEU.

const MIN_FPS := 1.0
const MAX_FRAMES := 256  # limite dure d'AnimatedTexture en Godot 3.x

# fps borné en bas à MIN_FPS (un fps <= 0 figerait l'animation).
static func clamp_fps(fps: float) -> float:
	return fps if fps > MIN_FPS else MIN_FPS

# Nombre de frames réellement posables sur une AnimatedTexture, borné [0, 256].
static func usable_frame_count(n: int) -> int:
	if n < 0:
		return 0
	if n > MAX_FRAMES:
		return MAX_FRAMES
	return n
```

- [ ] **Step 4 : Lancer le test pour vérifier le succès**

Run : `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected : ligne `=== N tests, 0 échec(s) ===` (N = 69 + 7 = 76).

- [ ] **Step 5 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/animated_icon.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "feat(bomberman): helpers purs de l'icône animée (clamp_fps, usable_frame_count)"
```

---

### Task 2 : Assemblage runtime `build()` (vérifié en jeu)

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/animated_icon.gd`

**Interfaces:**
- Consumes : `clamp_fps`, `usable_frame_count` (Task 1) ; `bomb_skin._load(path) -> Texture`.
- Produces : `static func build(frame_paths: Array, fps: float) -> AnimatedTexture` (null si aucune frame chargeable).

> **Pas de test headless** : `AnimatedTexture` + `Image.load` dépendent du runtime moteur (cf. Global Constraints). Cette fonction est exercée EN JEU à la Task 4. C'est cohérent avec `bomb_skin` (`color_for_tier` testé pur / `load_texture` vérifié en jeu).

- [ ] **Step 1 : Ajouter le preload de BombSkin**

En tête de `animated_icon.gd`, après les `const MIN_FPS/MAX_FRAMES` :

```gdscript
const BombSkin = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd")
```

- [ ] **Step 2 : Implémenter `build()`**

Ajouter à la fin de `animated_icon.gd` :

```gdscript
# Construit une AnimatedTexture bouclée à partir d'une liste de chemins PNG.
# Chaque frame est chargée au runtime via bomb_skin._load (Image.load, hors
# cache d'import). Les chemins introuvables sont ignorés. Retourne null si
# aucune frame n'a pu être chargée (l'appelant garde alors l'icône statique).
static func build(frame_paths: Array, fps: float) -> AnimatedTexture:
	var textures := []
	for path in frame_paths:
		var tex = BombSkin._load(path)
		if tex != null:
			textures.append(tex)
	var count := usable_frame_count(textures.size())
	if count == 0:
		return null
	var anim := AnimatedTexture.new()
	anim.frames = count
	anim.fps = clamp_fps(fps)
	for i in count:
		anim.set_frame_texture(i, textures[i])
	return anim
```

- [ ] **Step 3 : Vérif statique du parse (non-régression des tests purs)**

Run : `"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
Expected : `=== 76 tests, 0 échec(s) ===` (les tests purs passent toujours ; `build()` n'est pas exercé ici mais le fichier doit parser).

- [ ] **Step 4 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/logic/animated_icon.gd
git commit -m "feat(bomberman): assemblage runtime build() de l'AnimatedTexture (vérifié en jeu)"
```

---

### Task 3 : Générateur de frames PIL + frames

**Files:**
- Create: `tools/make_bomberto_icon_frames.py`
- Create (généré) : `Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/icon_anim/frame_00.png` … `frame_17.png`

**Interfaces:**
- Consumes : assets `content/characters/bomberman/bomberman_icon.png` (96×96), `content/weapons/bomb/skins/bomb_gray_48.png` (48×48).
- Produces : 18 PNG 96×96 nommées `frame_%02d.png` ; un `_contact_sheet.png` (vérif visuelle, NON livré dans le mod).

> **Explosion 100 % procédurale** (pas de dépendance au halo vanilla, qui vit dans le jeu décompilé gitignoré). Les constantes de position (`BOMB_*`, `FUSE_*`) sont une **première passe** : à ajuster en regardant le contact sheet (Step 3).

- [ ] **Step 1 : Écrire le script**

Créer `tools/make_bomberto_icon_frames.py` :

```python
#!/usr/bin/env python3
# Génère les frames de l'icône animée de Bomberto (sélection de perso).
# NON embarqué dans le mod. Repro : python tools/make_bomberto_icon_frames.py
# Sortie : content/characters/bomberman/icon_anim/frame_00.png .. frame_17.png
#          + _contact_sheet.png (vérif visuelle uniquement).
# NB Windows : passer des chemins en C:/... (un chemin Bash /c/... est lu
# C:\c\... par Python). Le script utilise des chemins relatifs résolus depuis
# son propre emplacement, donc aucune saisie manuelle de chemin.
import os, math
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.join(HERE, "..", "Brotato", "mods-unpacked", "Tanith-Bomberman")
CONTENT = os.path.join(MOD, "content")
OUT = os.path.join(CONTENT, "characters", "bomberman", "icon_anim")
os.makedirs(OUT, exist_ok=True)

CANVAS = 96
FRAMES = 18

# Phases (indices de frame) : idle 0-1, mèche 2-11, explosion 12-15, settle 16-17.
IDLE_END = 2
FUSE_END = 12
BOOM_END = 16

# Bombe agrandie au 1er plan bas-centre.
BOMB_SCALE = 1.20            # 48 -> ~58 px
BOMB_X = 19                  # coin haut-gauche de la bombe placée
BOMB_Y = 36
# Mèche dessinée par-dessus (contrôle total de la "consommation").
FUSE_BASE = (CANVAS // 2 + 2, BOMB_Y + 6)   # départ de la mèche (sur la bombe)
FUSE_LEN = 16                                # longueur pleine (px)
FUSE_DX = 6                                  # courbure horizontale du sommet

char = Image.open(os.path.join(CONTENT, "characters", "bomberman", "bomberman_icon.png")).convert("RGBA")
bomb = Image.open(os.path.join(CONTENT, "weapons", "bomb", "skins", "bomb_gray_48.png")).convert("RGBA")
bomb_big = bomb.resize((round(48 * BOMB_SCALE),) * 2, Image.NEAREST)

def fuse_point(t):
    # t in [0,1] : 0 = base (sur la bombe), 1 = sommet de la mèche.
    x = FUSE_BASE[0] + FUSE_DX * t
    y = FUSE_BASE[1] - FUSE_LEN * t
    return (x, y)

def draw_spark(d, p, r=2):
    d.ellipse([p[0]-r-1, p[1]-r-1, p[0]+r+1, p[1]+r+1], fill=(255, 230, 120, 180))
    d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=(255, 255, 240, 255))

def draw_fuse(d, top_t):
    # Mèche de la base jusqu'à top_t (consommation : top_t décroît).
    steps = 10
    pts = [fuse_point(top_t * i / steps) for i in range(steps + 1)]
    d.line(pts, fill=(40, 30, 20, 255), width=2)

def base_frame():
    return char.copy()

def settle_char(img, k):
    # squash-jump : k in [0,1] intensité ; remonte + écrase verticalement.
    if k <= 0:
        img.alpha_composite(char, (0, 0))
        return
    sq = max(0.80, 1.0 - 0.18 * k)
    h = round(CANVAS * sq)
    squashed = char.resize((CANVAS, h), Image.NEAREST)
    dy = -round(8 * k)
    img.alpha_composite(squashed, (0, CANVAS - h + dy))

def draw_explosion(d, center, prog):
    # prog in [0,1] : anneaux concentriques blanc/jaune/orange qui grandissent.
    rmax = 30
    for col, frac in [((255, 255, 255, 230), 0.45),
                      ((255, 220, 90, 220), 0.75),
                      ((255, 140, 40, 200), 1.0)]:
        r = rmax * prog * frac
        d.ellipse([center[0]-r, center[1]-r, center[0]+r, center[1]+r], fill=col)

def render(i):
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    bomb_center = (BOMB_X + bomb_big.width // 2, BOMB_Y + bomb_big.height // 2)
    if i < IDLE_END:
        img.alpha_composite(char, (0, 0))
        img.alpha_composite(bomb_big, (BOMB_X, BOMB_Y))
        d = ImageDraw.Draw(img)
        draw_fuse(d, 1.0)
        draw_spark(d, fuse_point(1.0))
    elif i < FUSE_END:
        t = (i - IDLE_END) / (FUSE_END - IDLE_END - 1)  # 0 -> 1
        top = 1.0 - t                                    # mèche qui raccourcit
        img.alpha_composite(char, (0, 0))
        img.alpha_composite(bomb_big, (BOMB_X, BOMB_Y))
        d = ImageDraw.Draw(img)
        draw_fuse(d, max(top, 0.0))
        draw_spark(d, fuse_point(max(top, 0.0)))
    elif i < BOOM_END:
        prog = (i - FUSE_END + 1) / (BOOM_END - FUSE_END)  # 0.25 -> 1
        k = 1.0 - 0.5 * (i - FUSE_END) / (BOOM_END - FUSE_END)
        settle_char(img, k)
        d = ImageDraw.Draw(img)
        draw_explosion(d, bomb_center, prog)
        if i == FUSE_END:  # flash plein cadre sur la 1re frame de boom
            flash = Image.new("RGBA", (CANVAS, CANVAS), (255, 255, 255, 150))
            img.alpha_composite(flash, (0, 0))
    else:
        # settle : le perso revient au repos ET la bombe se reconstitue (mèche
        # pleine) pour boucler proprement vers la frame 0 (sinon "pop" visuel).
        fade = (i - BOOM_END + 1) / (FRAMES - BOOM_END + 1)  # 1/3, 2/3
        img.alpha_composite(char, (0, 0))
        img.alpha_composite(bomb_big, (BOMB_X, BOMB_Y))
        d = ImageDraw.Draw(img)
        draw_fuse(d, 1.0)
        draw_spark(d, fuse_point(1.0))
        # anneau résiduel translucide qui disparaît (reliquat de l'explosion)
        r = 26 * (1.0 - fade)
        if r > 1:
            d.ellipse([bomb_center[0]-r, bomb_center[1]-r, bomb_center[0]+r, bomb_center[1]+r],
                      fill=(255, 160, 60, int(90 * (1.0 - fade))))
    return img

frames = [render(i) for i in range(FRAMES)]
for i, f in enumerate(frames):
    f.save(os.path.join(OUT, "frame_%02d.png" % i))

# Contact sheet (6 colonnes) pour vérif visuelle — NON livré dans le mod.
cols = 6
rows = (FRAMES + cols - 1) // cols
sheet = Image.new("RGBA", (cols * CANVAS, rows * CANVAS), (30, 30, 40, 255))
for i, f in enumerate(frames):
    sheet.alpha_composite(f, ((i % cols) * CANVAS, (i // cols) * CANVAS))
sheet.save(os.path.join(OUT, "_contact_sheet.png"))
print("OK : %d frames + _contact_sheet.png dans %s" % (FRAMES, OUT))
```

- [ ] **Step 2 : Générer les frames**

Run : `python tools/make_bomberto_icon_frames.py`
Expected : `OK : 18 frames + _contact_sheet.png dans …icon_anim`.

- [ ] **Step 3 : Vérification visuelle (manuelle)**

Ouvrir `Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/icon_anim/_contact_sheet.png`.
Vérifier : (a) Bomberto reconnaissable derrière la bombe ; (b) l'étincelle descend et la mèche raccourcit sur les frames 2→11 ; (c) explosion lisible (flash + anneaux) frames 12→15 avec sursaut du perso ; (d) frame 17 ≈ frame 0 (boucle propre).
**Si un placement est faux** (bombe/mèche mal posée), ajuster les constantes `BOMB_*` / `FUSE_*` en tête de script et relancer le Step 2. Itérer jusqu'à lecture nette.

- [ ] **Step 4 : Commit**

```bash
git add tools/make_bomberto_icon_frames.py \
        Brotato/mods-unpacked/Tanith-Bomberman/content/characters/bomberman/icon_anim/
git commit -m "feat(bomberman): générateur PIL + 18 frames de l'icône animée de Bomberto"
```

> ⚠️ Le `_contact_sheet.png` est versionné avec les frames mais NON chargé par le mod (aucun code n'y renvoie). Le laisser, ou l'ajouter aux exclusions de `tools/build-bomberman.ps1` si on veut l'écarter du `.zip` Workshop.

---

### Task 4 : Branchement dans `ItemService._ready()` (vérifié en jeu)

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd`

**Interfaces:**
- Consumes : `AnimatedIcon.build(frame_paths, fps)` (Task 2) ; les frames de la Task 3.
- Produces : `character.icon` = `AnimatedTexture` (sélection de perso).

> **Pas de test headless** (autoloads). Vérifié EN JEU au Step 3.

- [ ] **Step 1 : Ajouter preload + constantes**

Dans `extensions/singletons/item_service.gd`, après les `const` existants (vers la ligne 10) :

```gdscript
const AnimatedIcon = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/animated_icon.gd")
const _ICON_ANIM_DIR := "res://mods-unpacked/Tanith-Bomberman/content/characters/bomberman/icon_anim"
const _ICON_ANIM_FRAMES := 18
const _ICON_ANIM_FPS := 12.0
```

- [ ] **Step 2 : Poser l'icône animée sur le perso**

Dans `_ready()`, juste après le bloc qui enregistre le perso (après `characters.append(character)` / `ModLog.info("perso enregistré…")`, avant `_unlock_modded_content()`), insérer :

```gdscript
	# Icône ANIMÉE dans la sélection de perso : mèche -> explosion -> boucle.
	# AnimatedTexture hérite de Texture -> drop-in dans le TextureRect de l'écran,
	# qui anime et boucle tout seul. Frames chargées au runtime (hors cache
	# d'import, comme bomb_skin). Si rien ne charge, build() rend null et on
	# garde l'icône statique du .tres (dégradation propre).
	if character != null:
		var anim_paths := []
		for i in _ICON_ANIM_FRAMES:
			anim_paths.append("%s/frame_%02d.png" % [_ICON_ANIM_DIR, i])
		var anim = AnimatedIcon.build(anim_paths, _ICON_ANIM_FPS)
		if anim != null:
			character.icon = anim
			ModLog.info("icône animée posée sur Bomberto (%d frames)" % _ICON_ANIM_FRAMES)
```

- [ ] **Step 3 : Vérification EN JEU (manuelle)**

Lancer Brotato avec le mod (+ `Tanith-DevUnlockAll` si besoin), aller à la sélection de perso :
- l'icône de Bomberto **s'anime et boucle** (mèche → explosion → reset) ;
- pas de figement sur la 1ʳᵉ frame (si figé → la sélection ne lit pas `get_icon()`/`.icon`, ou un cache fige l'icône : tracer dans `item_description.gd`) ;
- les autres persos sont inchangés ;
- solo OK (coop facultatif : même écran).

- [ ] **Step 4 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd
git commit -m "feat(bomberman): pose l'icône animée de Bomberto en sélection de perso"
```

---

## Notes de fin

- **Packaging Workshop** : les frames `icon_anim/` sont chargées au runtime via `Image.load` (comme les skins de bombe) → **pas besoin de `.stex`** dans le `.zip`, mais elles doivent être **incluses comme fichiers** sous `mods-unpacked/.../content/`. `tools/build-bomberman.ps1` stage déjà `content/` (en excluant `test/`/`docs/`) → elles partent automatiquement. ⚠️ Même réserve que `bomb_skin` : `Image.load(res://)` marche en local et *probablement* depuis le `.zip` monté par ModLoader (non formellement vérifié sur build exporté).
- **Bump de version** : après vérif en jeu, bumper `manifest.json` (mineur) + `CHANGELOG_FR/EN.md`. Hors périmètre de ce plan (à faire au moment du déploiement).
