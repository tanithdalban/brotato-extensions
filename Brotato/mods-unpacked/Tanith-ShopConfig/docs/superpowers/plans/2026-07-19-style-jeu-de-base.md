# Restylage ShopConfig au thème du jeu de base — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Donner à l'écran de configuration du magasin le look du jeu de base en posant `base_theme.tres` sur le Control racine de la scène (propagation Godot), 100 % par code au runtime.

**Architecture:** En Godot 3, `Control.theme` se propage à toute la descendance du SceneTree. L'écran (`shop_config_screen.gd`, un `Control`) est l'ancêtre de tous les panneaux joueurs et de l'overlay des dropdowns → une seule affectation de thème habille l'ensemble. Les overrides explicites existants (police du bouton Prêt, modulate des onglets) l'emportent et restent intacts. Une passe de réglage de densité, conditionnelle au rendu coop 4 joueurs, ajuste polices/espacements sans jamais toucher au thème.

**Tech Stack:** GDScript (Godot 3.6/3.7), mod Brotato via ModLoader. Ressource de thème vanilla : `res://resources/themes/base_theme.tres`.

## Global Constraints

- Tout en **français** : commentaires, docs, libellés de commits. (CLAUDE.md)
- **Aucun éditeur Godot ouvert, aucun `.tres` modifié, aucune régénération de ressource** — sinon risque de corruption du jeu décompilé. Changement purement runtime. (spec)
- **Ne pas toucher** la logique pure (`content/logic/pool_filter.gd`, `singletons/shop_config_store.gd`) ni le flux d'exclusion/pool.
- **Ne pas défaire** les overrides existants : `font_35_outline` du bouton Prêt, `modulate = 0.5` des onglets inactifs, coche verte, voile d'exclusion + croix, popup magasin.
- **Fond conservé** : `ColorRect` sombre `Color(0.06, 0.06, 0.08, 1.0)` de `shop_config_screen._build_ui`. Pas de fond « magasin ».
- Tests unitaires via `./run-tests.sh` (WSL/Linux) ; code de sortie = nb d'échecs. La logique pure ne doit pas régresser (rester vert). Le rendu se vérifie **en jeu**.

---

### Task 1: Poser `base_theme.tres` sur le Control racine de l'écran

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.gd`

**Interfaces:**
- Consumes: rien (première et seule pose de thème).
- Produces: l'écran et toute sa descendance (bouton Retour, panneaux joueurs, barres de filtres, dropdowns maison, onglets, boutons d'action, avertissement, bouton Prêt) héritent du thème vanilla. Aucune API publique nouvelle.

**Contexte du fichier** (état actuel, `shop_config_screen.gd`) — bloc de consts en tête :

```gdscript
const PanelScript = preload("res://mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd")
const InterceptorScript = preload("res://mods-unpacked/Tanith-ShopConfig/scenes/tab_switch_interceptor.gd")
const ModLog = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/mod_log.gd")
```

et le début de `_build_ui()` :

```gdscript
func _build_ui() -> void:
	# Fond opaque plein écran : la scène n'a rien derrière elle, mais le split
	# laisse des espaces transparents — ce fond garantit un écran net.
	var background = ColorRect.new()
```

- [ ] **Step 1: Ajouter la constante du thème**

Dans le bloc de consts en tête de `shop_config_screen.gd`, ajouter après la ligne `ModLog` :

```gdscript
# Thème du jeu de base : posé sur le Control racine de l'écran, Godot 3 le
# propage à TOUTE la descendance (panneaux, dropdowns, boutons, labels). Pose
# 100 % runtime — aucun éditeur, aucun .tres modifié -> aucun risque de corruption.
const BaseTheme := preload("res://resources/themes/base_theme.tres")
```

- [ ] **Step 2: Poser le thème au début de `_build_ui()`**

Insérer l'affectation en toute première instruction de `_build_ui()`, avant le `ColorRect` de fond :

```gdscript
func _build_ui() -> void:
	# Look du jeu de base : le thème se propage à tous les enfants ajoutés
	# ci-dessous (et dans les panneaux). Les overrides explicites (police du
	# bouton Prêt, modulate des onglets) l'emportent et restent intacts.
	theme = BaseTheme

	# Fond opaque plein écran : la scène n'a rien derrière elle, mais le split
	# laisse des espaces transparents — ce fond garantit un écran net.
	var background = ColorRect.new()
```

- [ ] **Step 3: Vérifier que la logique pure ne régresse pas**

Run: `./run-tests.sh`
Expected: la ligne de synthèse « N tests, 0 échec(s) » (aucun échec). Les erreurs moteur affichées APRÈS cette ligne (fermeture des autoloads : DLC, cursor…) sont normales et n'affectent pas le résultat. Code de sortie 0.

Rationale : cette tâche ne touche que la construction de l'UI (non chargeable en headless) ; le test confirme uniquement l'absence de régression sur la logique pure, qui doit rester verte.

- [ ] **Step 4: Vérifier le rendu en jeu (solo)**

Manuel (le rendu n'est pas testable en headless — cf. CLAUDE.md). Copier/symlinker le mod dans `mods-unpacked/` à côté du `.pck`, lancer Brotato, démarrer une run **solo** jusqu'à l'écran de config du magasin (entre perso et arme). Vérifier :
- panneau habillé au thème Brotato (panneau arrondi semi-transparent, polices du jeu) au lieu du gris Godot ;
- **dropdowns de filtres tier/classe** rendus au skin natif (objectif visé) ;
- onglets Objets/Armes, boutons Réinitialiser / Exclure-Inclure, avertissement, bouton **Prêt** habillés ;
- overrides intacts : bouton Prêt en grande police outline, onglet inactif atténué, coche verte à « Prêt », voile + croix « X » sur une case exclue ;
- fond sombre conservé.

- [ ] **Step 5: Commit**

```bash
git add Brotato/mods-unpacked/Tanith-ShopConfig/scenes/shop_config_screen.gd
git commit -m "feat(shopconfig): applique le thème du jeu de base à l'écran

Pose base_theme.tres sur le Control racine (propagation Godot 3) : panneaux,
dropdowns, onglets, boutons et labels adoptent le look Brotato. 100 % runtime,
aucun .tres modifié. Overrides existants (police Prêt, modulate onglets) intacts.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Passe de réglage de densité (conditionnelle au rendu coop 4 joueurs)

**Files:**
- Modify (si nécessaire) : `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd`

**Interfaces:**
- Consumes: le thème posé en Task 1 (polices/marges plus grandes).
- Produces: aucun changement d'API. Uniquement des overrides de police/espacement compacts sur les éléments denses d'un panneau.

**Déclencheur** : cette tâche ne s'applique **que si** l'observation en jeu (Step 1) montre un débordement ou un tassement en coop 2–4 joueurs. Si le rendu tient, marquer la tâche « no_change_needed » et sauter aux Steps 4–5 (vérif + rien à committer).

**Contexte du fichier** (`player_shop_config_panel.gd`) — bloc de consts en tête (extrait) :

```gdscript
const KEY_HINT_ICON_SIZE := Vector2(32, 32)
```

et le champ de filtre construit dans `_build_dropdown` :

```gdscript
func _build_dropdown(which, labels) -> Button:
	var field = Button.new()
	field.clip_text = true
	field.rect_min_size = Vector2(150, 0)
```

- [ ] **Step 1: Observer le rendu en coop 4 joueurs**

Manuel. Lancer une run **coop à 4 joueurs** (activer `Tanith-DevUnlockAll` si besoin de personnages) jusqu'à l'écran de config. Le split horizontal met 4 panneaux côte à côte. Constater si :
- les barres de filtres / hints de touches débordent horizontalement d'un panneau ;
- les boutons d'action se chevauchent ou sont coupés ;
- le bouton Prêt / l'avertissement poussent la grille hors de l'écran.

Si **rien** ne déborde : aller au Step 4 (rien à faire, `no_change_needed`).
Si ça déborde : appliquer les Steps 2–3 ciblés sur les éléments fautifs observés.

- [ ] **Step 2: Ajouter une police compacte et l'appliquer aux éléments denses**

Dans le bloc de consts en tête de `player_shop_config_panel.gd`, ajouter (à côté de `ReadyFont`) :

```gdscript
# Police compacte pour les éléments denses (filtres, hints) quand le thème du
# jeu élargit tout : évite le débordement du split coop 4 joueurs. Appliquée
# uniquement là où l'observation en jeu le réclame (cf. plan, passe de réglage).
const CompactFont := preload("res://resources/fonts/actual/base/font_22.tres")
```

Puis, dans `_build_dropdown`, forcer la police compacte sur le champ de filtre, juste après sa création :

```gdscript
func _build_dropdown(which, labels) -> Button:
	var field = Button.new()
	field.clip_text = true
	field.rect_min_size = Vector2(150, 0)
	field.add_font_override("font", CompactFont)
```

Et sur chaque option de la liste (dans la boucle `for i in labels.size():` du même `_build_dropdown`), après `it.text = labels[i]` :

```gdscript
		var it = Button.new()
		it.text = labels[i]
		it.add_font_override("font", CompactFont)
```

Si les **hints de touches** débordent, appliquer aussi la police compacte au label de repli dans `_make_key_hint`, après `lbl.text = text_fallback` :

```gdscript
		var lbl = Label.new()
		lbl.text = text_fallback
		lbl.add_font_override("font", CompactFont)
```

et au suffixe, après `sfx.text = " " + suffix` :

```gdscript
		var sfx = Label.new()
		sfx.text = " " + suffix
		sfx.add_font_override("font", CompactFont)
```

N'appliquer que les sous-blocs correspondant aux éléments réellement fautifs (YAGNI : ne pas rapetisser ce qui tient déjà).

- [ ] **Step 3: Réduire l'espacement des barres denses (si encore serré)**

Si après le Step 2 les barres restent tassées, réduire leur séparation. Dans `_build_ui`, sur les conteneurs concernés (`filter_bar`, `actions`, `tab_bar`), ajouter après leur création (exemple pour `filter_bar`) :

```gdscript
	var filter_bar = HBoxContainer.new()
	filter_bar.add_constant_override("separation", 4)
	root.add_child(filter_bar)
```

Appliquer le même `add_constant_override("separation", 4)` uniquement aux barres observées comme fautives.

- [ ] **Step 4: Vérifier — logique pure + rendu**

Run: `./run-tests.sh`
Expected: « N tests, 0 échec(s) », code de sortie 0 (les overrides de police/espacement ne touchent pas la logique pure).

Puis, manuel en jeu : rejouer coop 4 joueurs → les 4 panneaux tiennent à l'écran sans débordement ni chevauchement ; navigation manette et dropdowns inchangés ; solo toujours correct (police compacte lisible).

- [ ] **Step 5: Commit (seulement si Steps 2–3 ont modifié du code)**

Si `no_change_needed` (rien n'a débordé) : ne rien committer, la tâche est close.

Sinon :

```bash
git add Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd
git commit -m "fix(shopconfig): densité coop 4J après pose du thème

Police compacte (font_22) sur filtres/hints et séparation resserrée sur les
barres denses, pour que les 4 panneaux tiennent dans le split coop. Overrides
ciblés uniquement — le thème lui-même n'est pas touché.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Couverture de la spec :**
- « Pose du thème » → Task 1. ✅
- « Ce qui reste intact » (overrides) → Task 1 Step 4 le vérifie explicitement, contrainte globale l'interdit de défaire. ✅
- « Fond conservé » → contrainte globale + Task 1 ne touche pas au `ColorRect`. ✅
- « Point de vigilance densité / passe de réglage » → Task 2 (conditionnelle). ✅
- « Aucun risque de corruption / runtime » → contrainte globale, aucune tâche n'ouvre l'éditeur ni n'édite de `.tres`. ✅
- « Tests pure verts + rendu en jeu » → Steps de vérif dans les deux tâches. ✅

**Placeholders :** aucun « TBD/TODO ». Chaque step de code montre le code exact et son contexte. Task 2 est conditionnelle mais fournit le code concret complet — pas un placeholder.

**Cohérence des types/noms :** `BaseTheme` (const, Task 1), `CompactFont` (const, Task 2) ; chemins de ressources vanilla exacts (`base_theme.tres`, `font_22.tres`). Fonctions référencées (`_build_ui`, `_build_dropdown`, `_make_key_hint`) existent dans les fichiers cités. Cohérent.
