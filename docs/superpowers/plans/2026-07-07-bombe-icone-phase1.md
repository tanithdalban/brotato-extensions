# Nouveau skin de la Bombe (Phase 1) — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer l'ancien skin de la Bombe (sprites colorés par tier) par `bombe_normale.png` (bombe noire classique, constante sur tous les tiers), **partout** : icône de boutique/inventaire (avec un **disque de fond coloré à la rareté du tier**) ET sprite en jeu (arme tenue + bombe posée + troll bombe, **sans** fond).

**Architecture:** On refond `bomb_skin.gd` autour d'un seul asset (`bombe_normale.png`) : une fonction construit l'**icône** (bombe composée sur un disque coloré), une autre le **sprite en jeu** (bombe redimensionnée, sans fond). La couleur du disque vient des **couleurs officielles du jeu** (`ItemService.get_color_from_tier`). Les anciennes fonctions de skin coloré par tier (mortes) sont supprimées. On repointe les 4 sites d'appel.

**Différenciation des tiers en jeu (déjà assurée par le vanilla) :** l'arme tenue reçoit un **contour coloré par rareté** via `weapon.gd:update_highlighting()` (→ `ItemService.get_color_from_tier`) ; notre bombe noire en hérite automatiquement (T2/T3/T4 = bleu/violet/rouge ; T1 sans contour). La carte de boutique a aussi son cadre de rareté vanilla. Notre disque de fond d'icône **renforce** cette lecture avec la même palette. La **bombe posée** (non-arme) n'a pas d'outline : appearance constante assumée en Phase 1.

**Tech Stack:** GDScript (Godot 3.6.2), API `Image`/`ImageTexture` (compositing + resize runtime, hors cache d'import), ModLoader script extensions.

## Global Constraints

- Tout en **français** : commentaires, docs, libellés de commits.
- Chargement **runtime** par `Image.load` (contourne le cache d'import Godot), comme l'actuel `bomb_skin.gd`. Aucun `.import` pour ce sprite.
- **Fond coloré = uniquement l'icône** de boutique/inventaire. Le sprite en jeu (tenu / posé / troll) = bombe **sans fond**.
- Skin **constant sur tous les tiers** pour la Bombe : en jeu le tier se lit via l'outline vanilla ; sur l'icône via le disque de fond.
- Couleur du disque = `ItemService.get_color_from_tier(tier)` (palette officielle, respecte les réglages joueur), avec **repli gris** quand elle vaut blanc (tier commun).
- Dégradation propre : si un chargement échoue (asset absent / headless), la fonction rend `null` et l'appelant garde l'existant (chaque site a un garde `if ... != null`).
- Ne modifier **que** : `bomb_skin.gd`, `item_service.gd`, `bomb_weapon.gd`, `bomb_entity.gd`, `troll_bomb.gd`, `run_tests.gd`, + asset/manifest/changelog. Ne pas toucher aux `.tres` d'armes ni à la logique d'explosion.
- Runner de tests **du Bomberman** (≠ `./run-tests.sh` de ShopConfig) :
  `"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd`
  Code de sortie = nombre d'échecs.
- ⚠️ Lancer Godot sur `Brotato` peut altérer des `ext_resource` PNG de certains `.tres` du jeu décompilé (note mémoire « corruption jeu décompilé »). Notre code charge `bombe_normale.png` via `Image.load` (pas un `ext_resource`) : pas de risque ajouté ; en cas de casse d'autres `.tres`, appliquer la restauration GDRE.

---

### Task 1: Refonte de `bomb_skin.gd` (asset + nouvelle API + tests)

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bombe_normale.png` (copie de `screens/bombe_normale.png`)
- Modify (réécriture): `Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd`
- Test: `Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd`

**Interfaces:**
- Consumes: API `Image` uniquement.
- Produces :
  - `BombSkin.icon_background_color(tier_color: Color) -> Color` (repli gris si blanc ; sinon passe-plat)
  - `BombSkin.build_normal_icon(tier_color: Color) -> Texture` (icône = bombe + disque coloré ; `null` si échec)
  - `BombSkin.build_normal_world_texture() -> Texture` (sprite en jeu, 48×48, sans fond ; `null` si échec)
  - `BombSkin._load(path) -> Texture` (conservée : utilisée par `animated_icon.gd` et la face de la troll bombe)
  - Constante exposée : `BombSkin.COMMON_BG`
  - **Supprime** (mortes) : `color_for_tier`, `texture_path`, `world_texture_path`, `load_texture`, `load_world_texture`, `_COLORS`, `_SKINS_DIR`, `_MAX_TIER`.

- [ ] **Step 1: Copier l'asset dans le mod**

Run:
```bash
cp "screens/bombe_normale.png" "Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bombe_normale.png"
```
Expected: `ls Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bombe_normale.png` réussit.

- [ ] **Step 2: Mettre à jour les tests (échec attendu)**

Dans `test/run_tests.gd`, remplacer l'appel `_test_bomb_skin()` dans `_init()` par `_test_bomb_icon_background()`, puis **supprimer** la fonction `_test_bomb_skin()` et la remplacer par :

```gdscript
func _test_bomb_icon_background():
	# Repli gris quand la couleur de rareté vaut blanc (tier commun).
	_check(BombSkin.icon_background_color(Color.white) == BombSkin.COMMON_BG, "icone: fond blanc (commun) -> gris")
	# Sinon, on conserve la couleur de rareté du jeu telle quelle.
	var red := Color(1.0, 0.231, 0.231, 1.0)
	_check(BombSkin.icon_background_color(red) == red, "icone: fond rareté conservé (rouge)")
	var purple := Color(0.678, 0.353, 1.0, 1.0)
	_check(BombSkin.icon_background_color(purple) == purple, "icone: fond rareté conservé (violet)")
```

- [ ] **Step 3: Lancer les tests pour vérifier l'échec**

Run:
```bash
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: échec — `icon_background_color`/`COMMON_BG` non définis (erreur de script), code de sortie ≠ 0.

- [ ] **Step 4: Réécrire `bomb_skin.gd`**

Remplacer **tout** le contenu de `content/logic/bomb_skin.gd` par :

```gdscript
extends Reference
# Skin de la Bombe : un seul visuel (bombe_normale.png), constant sur tous les
# tiers. En jeu, le tier reste lisible via le CONTOUR coloré que le jeu applique
# déjà à l'arme tenue (weapon.gd:update_highlighting -> ItemService.get_color_from_tier).
# Sur l'ICÔNE de boutique, on ajoute un disque de fond coloré à la rareté du tier.
#
# - icon_background_color(tier_color) -> couleur du disque (repli gris si blanc).
# - build_normal_icon(tier_color)     -> icône = bombe sur disque coloré.
# - build_normal_world_texture()      -> sprite EN JEU (tenu / posé / troll), sans fond.
# - _load(path)                       -> loader runtime générique (réutilisé ailleurs).
#
# Chargement runtime (Image.load) : contourne le cache d'import Godot. Textures
# créées avec FILTER+MIPMAPS pour un rendu lisse (sprite cartoon non pixel-art).

const _NORMAL_ICON_PATH := "res://mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bombe_normale.png"
const _WORLD_SIZE := 48  # taille du sprite en jeu (ancienne taille des skins colorés)

# Repli quand la couleur de rareté vaut blanc (tier commun) : gris clair lisible.
const COMMON_BG := Color(0.72, 0.72, 0.72, 1.0)

# Couleur du disque de fond de l'icône : la couleur de rareté fournie par le jeu
# (ItemService.get_color_from_tier), avec repli gris si elle vaut blanc.
static func icon_background_color(tier_color: Color) -> Color:
	if tier_color == Color.white:
		return COMMON_BG
	return tier_color

# Icône de boutique/inventaire : bombe_normale composée sur un disque coloré.
# `tier_color` = couleur de rareté du tier (fournie par l'appelant). Null si
# l'asset ne charge pas (headless / absent).
static func build_normal_icon(tier_color: Color) -> Texture:
	var sprite_img := _load_image(_NORMAL_ICON_PATH)
	if sprite_img == null:
		return null
	var w := sprite_img.get_width()
	var h := sprite_img.get_height()
	var bg := _make_disc(w, h, icon_background_color(tier_color))
	bg.blend_rect(sprite_img, Rect2(0, 0, w, h), Vector2(0, 0))
	var tex := ImageTexture.new()
	tex.create_from_image(bg, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS)
	return tex

# Sprite EN JEU (arme tenue / bombe posée / corps de la troll bombe) : la bombe
# seule, redimensionnée à _WORLD_SIZE, SANS fond. Null si l'asset ne charge pas.
static func build_normal_world_texture() -> Texture:
	var img := _load_image(_NORMAL_ICON_PATH)
	if img == null:
		return null
	if img.get_width() != _WORLD_SIZE or img.get_height() != _WORLD_SIZE:
		img.resize(_WORLD_SIZE, _WORLD_SIZE, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS)
	return tex

# Loader runtime générique -> Texture (rétro-compat : animated_icon, face troll).
static func _load(path: String) -> Texture:
	var img := _load_image(path)
	if img == null:
		return null
	var tex := ImageTexture.new()
	tex.create_from_image(img, 0)
	return tex

# Charge un PNG en Image RGBA (hors cache d'import). Null si introuvable.
static func _load_image(path: String) -> Image:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img

# Disque plein centré de la couleur donnée (rayon = 92% du demi-côté),
# reste transparent. Image RGBA de w×h.
static func _make_disc(w: int, h: int, color: Color) -> Image:
	var img := Image.new()
	img.create(w, h, false, Image.FORMAT_RGBA8)
	img.lock()
	var cx := w / 2.0
	var cy := h / 2.0
	var r := min(w, h) * 0.5 * 0.92
	var r2 := r * r
	var transparent := Color(0, 0, 0, 0)
	for y in range(h):
		for x in range(w):
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, transparent)
	img.unlock()
	return img
```

- [ ] **Step 5: Lancer les tests pour vérifier le succès**

Run:
```bash
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===`, code de sortie 0 (les `icone: ...` passent ; aucun test ne référence plus les fonctions supprimées).

- [ ] **Step 6: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bombe_normale.png \
        Brotato/mods-unpacked/Tanith-Bomberman/content/logic/bomb_skin.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/test/run_tests.gd
git commit -m "refactor(bomberman): skin de bombe unique (bombe_normale) + fond d'icône à la rareté

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Repointer les 4 sites d'appel

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd:39-42`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd:18-19`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd:51-53`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.gd:80`

**Interfaces:**
- Consumes: `build_normal_icon(tier_color)`, `build_normal_world_texture()` (Task 1) ; `get_color_from_tier(tier)` (méthode héritée du vanilla `item_service.gd`).
- Produces: rien (branchement final).

- [ ] **Step 1: `item_service.gd` — icône de boutique**

Remplacer :
```gdscript
			# Icône colorée par tier (chargée au runtime, hors cache d'import).
			# On mute la WeaponData partagée : le magasin/inventaire lit son icon.
			var skin = BombSkin.load_texture(w.tier)
			if skin != null:
				w.icon = skin
```
par :
```gdscript
			# Icône : bombe_normale sur un disque coloré à la rareté du tier
			# (couleur officielle du jeu). Runtime, hors cache d'import. Null
			# (headless/asset absent) => on garde l'icône du .tres.
			var skin = BombSkin.build_normal_icon(get_color_from_tier(w.tier))
			if skin != null:
				w.icon = skin
```

- [ ] **Step 2: `bomb_weapon.gd` — arme tenue**

Remplacer (dans `_ready()`):
```gdscript
	var skin = BombSkin.load_world_texture(tier)
	if skin != null:
		sprite.texture = skin
```
par :
```gdscript
	var skin = BombSkin.build_normal_world_texture()
	if skin != null:
		sprite.texture = skin
```

- [ ] **Step 3: `bomb_entity.gd` — bombe posée**

Remplacer :
```gdscript
	var skin = BombSkin.load_world_texture(p_tier)
	if skin != null and is_instance_valid(_sprite):
		_sprite.texture = skin
```
par :
```gdscript
	var skin = BombSkin.build_normal_world_texture()
	if skin != null and is_instance_valid(_sprite):
		_sprite.texture = skin
```

- [ ] **Step 4: `troll_bomb.gd` — corps de la troll bombe**

Remplacer (ligne 80):
```gdscript
	var body_tex = BombSkin.load_world_texture(p_tier)
```
par :
```gdscript
	var body_tex = BombSkin.build_normal_world_texture()
```
(Le paramètre `p_tier` de `arm()` reste : il sert encore ailleurs dans la troll bombe ; seul le skin devient constant.)

- [ ] **Step 5: Vérifier que les tests headless passent toujours**

Run:
```bash
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```
Expected: `=== N tests, 0 échec(s) ===` (ces sites ne sont pas testés en headless ; on vérifie l'absence de régression / erreur de chargement de script).

- [ ] **Step 6: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/extensions/singletons/item_service.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/content/weapons/bomb/bomb_weapon.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/content/entities/bomb_entity.gd \
        Brotato/mods-unpacked/Tanith-Bomberman/content/entities/troll_bomb.gd
git commit -m "feat(bomberman): applique le nouveau skin de bombe (icône + en jeu + troll)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Vérification en jeu + changelog + version

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/manifest.json`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/CHANGELOG_FR.md`
- Modify: `Brotato/mods-unpacked/Tanith-Bomberman/CHANGELOG_EN.md`

**Interfaces:**
- Consumes: le mod complet chargé en jeu.
- Produces: rien.

- [ ] **Step 1: Test en jeu (manuel)**

Copier/symlinker le mod à côté du `.pck`, lancer Brotato, sélectionner **Bomberto**, entrer en vague, ouvrir la **boutique**. Vérifier :
- **Icône boutique** de la Bombe = **bombe noire** sur un **disque coloré** qui suit le **tier** (gris/commun → bleu → violet → rouge ; monter en vague / réamorcer pour voir les tiers hauts).
- **Arme tenue** = bombe noire avec **contour coloré par rareté** (T2/T3/T4 ; T1 sans contour) — vérifie que l'outline vanilla fonctionne bien avec le nouveau sprite.
- **Bombe posée** au sol = bombe noire (constante, sans fond), taille cohérente avec l'ancienne.
- **Troll bombe** (si réveil) = corps noir + face de troll par-dessus.
- Aucune erreur moteur `bomb_skin` / chargement de sprite dans la console.

Si régression `.tres` du jeu vanilla (icônes/checkboxes cassées), appliquer la restauration GDRE (note mémoire) — non lié à ce changement.

- [ ] **Step 2: Bump de version + changelogs**

`manifest.json` : `"version_number"` `"1.5.1"` → `"1.6.0"`.

En tête de `CHANGELOG_FR.md` :
```markdown
## 1.6.0
- Nouveau skin de la Bombe : bombe noire classique partout (icône, arme tenue, bombe posée). Le niveau (tier) se lit via le contour coloré en jeu et un fond coloré sur l'icône de boutique.
```
En tête de `CHANGELOG_EN.md` :
```markdown
## 1.6.0
- New Bomb skin: classic black bomb everywhere (icon, held weapon, placed bomb). Tier reads via the in-game rarity outline and a colored background on the shop icon.
```

- [ ] **Step 3: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-Bomberman/manifest.json \
        Brotato/mods-unpacked/Tanith-Bomberman/CHANGELOG_FR.md \
        Brotato/mods-unpacked/Tanith-Bomberman/CHANGELOG_EN.md
git commit -m "chore(bomberman): release 1.6.0 (nouveau skin de bombe)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Feuille de route (phases suivantes — plans séparés, une session chacune)

Spec complet : `docs/superpowers/specs/2026-07-07-bombes-elementaires-design.md`.

- **Phase 2 — Infra « bombe à effet » + Bombe de Glace** : `bomb_element.gd`
  (`weapon_id → élément`), `bomb_entity` mode effet (0 dégât AoE, pas de
  trollbombe), opacité d'AOE réglable (config du mod), `shop_pool` par préfixe
  `weapon_bomb` ; Glace = slow via `speed_percent_modifier`, visuel `Glace.png`.
  Généralisera `build_normal_icon`/`build_normal_world_texture` en `(élément, tier)`.
- **Phase 3 — Bombe de Poison** : DOT scalé ingénierie + feu vert (extension
  `burning_particles.gd`), visuels `poisonbomb_1..4`.
- **Phase 4 — Bombe de Foudre** : effet Tyler (burst d'éclairs en cercle via
  `spawn_projectile`), visuels `stormbomb_1..4`.

## Self-Review (fait)

- **Couverture** : nouveau skin partout (icône + en jeu) → Tasks 1-2 (4 sites
  repointés) ; fond limité à l'icône → `build_normal_icon` vs
  `build_normal_world_texture` ; différenciation des tiers en jeu → outline
  vanilla (documenté, vérifié en Task 3 Step 1).
- **Placeholders** : aucun ; code complet fourni (y compris la réécriture de
  `bomb_skin.gd`).
- **Cohérence des types** : `build_normal_icon(Color) -> Texture`,
  `build_normal_world_texture() -> Texture`, `icon_background_color(Color) ->
  Color` employées à l'identique en Task 2 ; `get_color_from_tier(int) -> Color`
  héritée du vanilla ; `_load` conservée ; `COMMON_BG` défini en Task 1 et testé.
- **Code mort** : les fonctions de skin coloré supprimées ne sont plus
  référencées (grep : seuls les 4 sites + tests, tous mis à jour).
```
