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
    # prog in [0,1] : éclosion concentrique orange -> jaune -> cœur blanc.
    # ORDRE IMPORTANT : disques pleins dessinés du PLUS GRAND au plus petit, sinon
    # le grand orange recouvre le cœur clair et on ne voit qu'un blob plat.
    rmax = 32
    for col, frac in [((255, 140, 40, 205), 1.0),
                      ((255, 210, 80, 235), 0.68),
                      ((255, 255, 245, 255), 0.36)]:
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
