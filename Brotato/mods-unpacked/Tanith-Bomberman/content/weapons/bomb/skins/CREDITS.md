# Skins de bombe — crédits

Sprites de bombe colorés (`bomb_gray.png`, `bomb_blue.png`, `bomb_purple.png`,
`bomb_red.png`) : dérivés du set **« CC0 Explosive Icons »** (sous-pack *Chrisblue*,
`bomb_01_*`), source : <https://opengameart.org/content/cc0-explosive-icons>.

- **Licence : CC0 1.0** (domaine public, aucune attribution requise — crédit
  laissé ici par courtoisie).
- Auteurs : AntumDeluge (collection) / Chrisblue (recolors).
- Modification : source 32×32 mise à l'échelle ×3 vers 96×96 en *nearest-neighbor*
  (pixel-art net), une couleur par tier (rareté Brotato : T1 gray, T2 blue,
  T3 purple, T4 red).

Chargés au **runtime** via `bomb_skin.gd` (`Image.load` → `ImageTexture`,
`flags=0`), donc sans dépendre du cache d'import Godot (`.import`/`.stex`).
