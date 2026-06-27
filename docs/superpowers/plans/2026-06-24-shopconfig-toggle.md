# Toggle écran config magasin — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter un `CheckButton` dans le panneau d'options de run (aux côtés de Sans fin / Coop) pour activer/désactiver l'écran de config du magasin, désactivé par défaut.

**Architecture:** Extension de `run_options_panel.gd` qui surcharge `init()` pour injecter dynamiquement un `CheckButton` dans le `VBoxContainer` existant. La valeur est stockée dans `ProgressData.settings["tanith_shopconfig_enabled"]` (clé injectée, même pattern que `endless_mode_toggled`). L'extension de `character_selection.gd` délègue au vanilla si le flag est `false`.

**Tech Stack:** GDScript / Godot 3.6, ModLoader `install_script_extension`

## Contraintes globales

- Tout le code est en GDScript (Godot 3.6) — pas de C#, pas de GDNative
- Commentaires en français
- Clé dans `ProgressData.settings` : `"tanith_shopconfig_enabled"`, type `bool`, défaut `false`
- Ne pas modifier les fichiers `.tscn` vanilla
- Le flag doit être lu par `ProgressData.settings.get("tanith_shopconfig_enabled", false)` (jamais accès direct sans `.get()` pour éviter les erreurs si la clé est absente)

---

## Fichiers concernés

| Action | Fichier |
|--------|---------|
| **Créer** | `Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/run_options_panel.gd` |
| **Modifier** | `Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd` |
| **Modifier** | `Brotato/mods-unpacked/Tanith-ShopConfig/mod_main.gd` |

---

## Tâche 1 — Créer l'extension `run_options_panel.gd`

**Files:**
- Create: `Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/run_options_panel.gd`

**Interfaces:**
- Consumes: `ProgressData.settings.get("tanith_shopconfig_enabled", false)` — lit la valeur actuelle
- Produces: écrit `ProgressData.settings["tanith_shopconfig_enabled"]` sur toggle ; bouton visible dans le panneau d'options de run

- [ ] **Étape 1 : Créer le fichier de l'extension**

Créer `Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/run_options_panel.gd` avec ce contenu exact :

```gdscript
extends "res://ui/menus/run/run_options_panel.gd"
# Ajoute un CheckButton "Config du magasin" dans le panneau d'options de run,
# sous CoopButton. La valeur est persistée dans ProgressData.settings.

func init() -> void:
	.init()
	var btn = CheckButton.new()
	btn.text = "Config du magasin / Shop Config"
	btn.pressed = ProgressData.settings.get("tanith_shopconfig_enabled", false)
	var _e = btn.connect("toggled", self, "_on_shopconfig_toggled")
	$"%CoopButton".get_parent().add_child(btn)


func _on_shopconfig_toggled(value: bool) -> void:
	ProgressData.settings["tanith_shopconfig_enabled"] = value
```

- [ ] **Étape 2 : Vérifier la structure du fichier créé**

Confirmer que le fichier existe :
```
ls Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/
```
Doit afficher `run_options_panel.gd` (et `character_selection.gd` existant).

- [ ] **Étape 3 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/run_options_panel.gd
git commit -m "feat(shopconfig): extension run_options_panel — bouton toggle config magasin"
```

---

## Tâche 2 — Court-circuit dans `character_selection.gd`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd`

**Interfaces:**
- Consumes: `ProgressData.settings.get("tanith_shopconfig_enabled", false)` — même clé que Tâche 1
- Produces: si `false` → appel de `._on_selections_completed()` (vanilla, redirige vers sélection d'arme) et `return` ; si `true` → comportement actuel inchangé

- [ ] **Étape 1 : Modifier `_on_selections_completed()`**

Dans `Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd`, remplacer la fonction `_on_selections_completed()` pour ajouter le guard en tête :

```gdscript
func _on_selections_completed() -> void:
	if not ProgressData.settings.get("tanith_shopconfig_enabled", false):
		._on_selections_completed()
		return

	if ProgressData.settings.zone_is_random:
		_setup_zone(ProgressData.settings.zone_selected)
	for player_index in RunData.get_player_count():
		var character = _player_characters[player_index]
		RunData.add_character(character, player_index)
	if Utils.on_nintendo_nx_or_ounce and RunData.is_coop_run:
		OS.set_max_controller_count(RunData.get_player_count())

	ModLog.info("bascule vers la scene de config du magasin")
	var screen = ScreenScript.new()
	screen.set_players(_shopconfig_players_info())
	_change_to_scene_node(screen)
```

Les 3 premières lignes (guard) sont le seul ajout. Le reste est identique au code existant.

- [ ] **Étape 2 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd
git commit -m "feat(shopconfig): skip l'écran de config si toggle désactivé"
```

---

## Tâche 3 — Enregistrer l'extension dans `mod_main.gd`

**Files:**
- Modify: `Brotato/mods-unpacked/Tanith-ShopConfig/mod_main.gd`

**Interfaces:**
- Produces: `run_options_panel.gd` chargé par ModLoader au démarrage du mod

- [ ] **Étape 1 : Ajouter l'appel `install_script_extension`**

Dans `mod_main.gd`, fonction `_install_extensions()`, ajouter la ligne pour le nouveau panneau **avant** l'extension `character_selection` (ordre de chargement) :

```gdscript
func _install_extensions() -> void:
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/run_options_panel.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-ShopConfig/extensions/singletons/item_service.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Tanith-ShopConfig/extensions/ui/menus/run/character_selection.gd")
```

- [ ] **Étape 2 : Commit**

```bash
git add Brotato/mods-unpacked/Tanith-ShopConfig/mod_main.gd
git commit -m "feat(shopconfig): enregistre l'extension run_options_panel dans mod_main"
```

---

## Vérification en jeu

Pas de tests unitaires possibles pour ce code (dépendances Godot/ModLoader). Vérification manuelle :

1. Lancer Brotato avec le mod chargé
2. Écran de sélection de run → le panneau d'options doit afficher un nouveau `CheckButton` "Config du magasin / Shop Config" **décoché** par défaut, sous CoopButton
3. **Toggle OFF (défaut)** : valider la sélection de perso → l'écran de config du magasin ne doit **pas** apparaître, la sélection d'arme vanilla s'ouvre directement
4. **Toggle ON** : cocher la case, valider → l'écran de config du magasin apparaît normalement
5. Quitter et relancer le jeu → la valeur du CheckButton doit être mémorisée (persistée dans `ProgressData.settings`)
6. **Mode coop** : tester avec 2 joueurs, les deux chemins (ON et OFF)
