# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Vue d'ensemble

Mod **Brotato** (jeu Godot 3.7) ajoutant un écran de **configuration du pool du magasin par joueur**, inséré entre la sélection du personnage et celle de l'arme. Le joueur y exclut des objets/armes pour qu'ils n'apparaissent jamais dans **sa** boutique de la run.

Le code source du mod vit dans `Brotato/mods-unpacked/Tanith-ShopConfig/`. Le reste de `Brotato/` est le **jeu décompilé** (~200 Mo, référence locale **non versionnée** — voir `.gitignore`). Seuls les dossiers de nos mods sont suivis par git.

Tout est écrit en **français** : commentaires, docs, libellés de commits. Les libellés UI sont bilingues FR/EN (helper `_t(en, fr)` dans `player_shop_config_panel.gd`).

## Commandes

**Tests unitaires** (runner GDScript autonome, pas de GUI ; code de sortie = nb d'échecs) :
```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-ShopConfig/test/run_tests.gd
```
Les tests ne couvrent que la **logique 100 % pure** (`pool_filter.gd`, `shop_config_store.gd`) : tout ce qui touche aux autoloads ModLoader ne peut pas se charger en headless et se vérifie **en jeu**.

**Test en jeu** : copier/symlinker le dossier du mod dans `mods-unpacked/` à côté du `.pck` du jeu, lancer Brotato, vérifier le flux. Le mod `Tanith-DevUnlockAll` déverrouille tous les persos en mémoire pour tester toutes les classes (le supprimer pour revenir à la normale).

**Déploiement** : Steam Workshop, item `3748276960` (cf. `docs/superpowers/WorkshopID.md`). Le `.zip` est mis en scène dans `dist/` (non versionné).

## Architecture

Godot 3 n'a pas de hooks de script → l'intégration se fait **uniquement par script extensions** ModLoader (`ModLoaderMod.install_script_extension`, déclarées dans `mod_main.gd`). Une extension `extends "res://chemin/vanilla.gd"` et surcharge des méthodes ; appeler le parent avec `.methode()`.

Le mod se branche sur **deux points d'accroche** du jeu vanilla :

1. **Insertion de l'écran** — `extensions/ui/menus/run/character_selection.gd` surcharge `_on_selections_completed()`. Au lieu de basculer vers la sélection d'arme, il reproduit le corps vanilla (ajout des persos) puis fait un **swap manuel de `current_scene`** vers `scenes/shop_config_screen.gd`. ⚠️ Ce corps est copié du vanilla (`character_selection.gd:211-223`) — **à revérifier si une MAJ de Brotato modifie cette fonction**.

2. **Filtrage du pool** — `extensions/singletons/item_service.gd` surcharge `get_player_shop_items()` (pose un drapeau de contexte « pioche magasin en cours ») et `get_pool()` (retire les IDs exclus du joueur courant, **uniquement** pendant ce contexte). Borné à la boutique : ne touche **jamais** aux item boxes ni au ban natif (`RunData.players_data[i].banned_items`).

**Flux de données** : l'écran de config écrit les exclusions dans un **store unique** (`singletons/shop_config_store.gd`, instance `Reference` tenue par l'extension `ItemService`, accès via `ItemService.get_shopconfig_store()`). Le store mappe `player_index -> {my_id: true}` et porte le contexte de pioche. À la pioche magasin, `get_pool` consulte le store.

**Mémoire de session (persistance)** : le store du singleton `ItemService` **conserve les exclusions toute la session de jeu** (mémoire run-à-run, **sans aucun fichier disque** ; nettoyage automatique à la fermeture). L'écran ne fait donc **plus** de `reset()` à l'ouverture ni au retour : à l'ouverture, chaque panneau est **pré-chargé** depuis `store.get_excluded(player_index)` (clé = slot joueur). La grille étant filtrée par perso, les ids mémorisés non affichables sont **gelés** (`_carried_excluded` dans le panneau) et re-fusionnés à l'export (`get_excluded_ids`) pour ne pas être perdus quand le slot rejoue un perso différent (calcul pur : `pool_filter.gd` `owned_ids`/`carried`). Le bouton « Tout réinitialiser » vide aussi le carry-over (= oublier la config du slot après validation).

**L'écran** (construit **intégralement en code**, pas de `.tscn`) :
- `scenes/shop_config_screen.gd` (`Control`) : scène autonome plein écran. Split **horizontal**, un `player_shop_config_panel` par joueur (calqué sur `weapon_selection.tscn`). Sortie via `change_scene` (vers arme, ou difficulté si aucun joueur n'a de slot d'arme).
- `scenes/player_shop_config_panel.gd` (`PanelContainer`) : un quadrant joueur — grille d'icônes objets/armes filtrée par compatibilité perso, filtres tier/classe, actions rapides, garde-fou (« garde au moins quelques éléments »), bouton Prêt. Réutilise le vrai `item_popup.tscn` du magasin pour l'infobulle.

**Coop** : la navigation manette par joueur passe par un `FocusEmulator` natif **par panneau** (`_setup_coop_focus` dans `shop_config_screen.gd`), chacun borné à son panneau (+ bouton Retour pour le joueur 0). En solo, focus Godot classique et `ui_cancel` = retour.

**Logique pure** (testable) : `content/logic/pool_filter.gd` (filtre sans dépendance jeu) et le store. `content/logic/mod_log.gd` est un logger désactivable via la config du mod (`debug_log`, défaut `false` ; drapeau stocké en méta sur `Engine` faute de static var en Godot 3).

## Conventions

- **Compatibilité perso** : pour masquer/exclure dans la grille, reproduire les tests du jeu — effets joueur (`no_melee_weapons_hash`, `no_ranged_weapons_hash`, `remove_shop_items_hash`…), bans de classe (`banned_items` + `banned_item_groups` via `ItemService.item_groups`), objets/armes de départ, `can_be_looted`, slots d'arme. Voir `_collect_compatible()`.
- **OptionButton** : sélectionner par **INDEX**, pas par id (`add_item(label, -1)` ferait collisionner les ids) — cf. `_TIER_VALUES` et `_selected_tier()`.
- **Identité d'un élément** : `ItemParentData.my_id : String` (et `my_id_hash : int`). `tier` est un enum, `WeaponData.type` distingue MELEE/RANGED.
- Référence des points d'intégration vanilla : `docs/superpowers/notes/integration-points.md`. Specs/plans dans `docs/superpowers/`.
