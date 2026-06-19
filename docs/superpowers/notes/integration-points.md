# Points d'intégration natifs — reconnaissance (Task 0.2)

> Source : Brotato décompilé dans `./Brotato/`. Réalisé le 2026-06-19.

## Versions & environnement

- **Moteur** : Godot **3.7** (build Brotato ; en-tête `.pck` GDPC, pack_format=1, 3.7.0). Éditeur de dev : Godot 3.6.2 standard.
- **ModLoader** : **bundlé officiellement** dans `res://addons/mod_loader/`. Classes : `ModLoaderMod` (`api/mod.gd`), `ModLoaderLog` (`api/log.gd`), `ModLoaderConfig` (`api/config.gd`), `ModManifest`, `ModConfig`. Autoloads `ModLoaderStore` + `ModLoader` (project.godot:2755-2756). UI mods : `res://ui/menus/pages/mods/menu_mods.gd`.
- **GUT** : **bundlé** dans `res://addons/gut/` (`GutTest` = `res://addons/gut/test.gd`). Tests du jeu sous `res://tests/`. → pas besoin d'installer GUT.
- **Godot 3** : pas de script hooks → intégration par **script extensions** uniquement.

## Autoloads (singletons) utiles (project.godot:2749+)

- `ItemService` = `res://singletons/item_service.tscn` (script `singletons/item_service.gd`, `extends Node`, **pas de class_name** → extensible sans souci).
- `WeaponService` = `res://singletons/weapon_service.gd`.
- `RunData` = `res://singletons/run_data.tscn` (script `singletons/run_data.gd`).
- `MenuData` = `res://singletons/menu_data.gd` (détient les chemins de scènes de menu, ex. `weapon_selection_scene`).
- `CoopService`, `ProgressData`, `Utils`, `Keys`, `Text`.

## CONTENT_LIST — listes vivantes objets/armes

`ItemService` (item_service.gd:50-60) expose, en `export(Array, Resource)` :
- `items` (Array de `ItemData`), `weapons` (Array de `WeaponData`), `consumables`, `characters`, `upgrades`, `sets`, `difficulties`, `icons`...
- Lookups : `_item_id_lookup`, `_weapon_id_lookup` (Dictionary). Helper `get_element(list, id)` et `get_pool(tier, type)`.
- `const NB_SHOP_ITEMS := 4` (taille du magasin).

**Métadonnées d'un élément** — `ItemParentData` (`items/global/item_parent_data.gd`), base de `ItemData`/`WeaponData`/`CharacterData`/`ConsumableData` :
- `my_id : String` (l'ID ; **confirmé**), `my_id_hash : int` (= `Keys.generate_hash(my_id)`).
- `icon : Texture` (via `get_icon()` → SkinManager), `name : String` (via `get_name_text()` → `tr(name)`).
- `tier : enum Tier { COMMON, UNCOMMON, RARE, LEGENDARY, DANGER_4, DANGER_5, NIGHTMARE }`.
- Catégorie/tags : pas de champ « tags » direct ; type via helpers `is_structure_item()`, `is_pet_item()`, `get_category()`. **Armes** : `WeaponData.type` (`WeaponType.MELEE`/`RANGED`) — confirmé (item_service.gd:350). Classes/sets d'armes via `RunData.get_player_sets` / `WeaponData` (champs exacts à confirmer si on filtre par set).

## SHOP_POOL — génération du pool du magasin (point d'accroche n°1)

- Entrée magasin par joueur : **`ItemService.get_player_shop_items(wave, player_index, args: ItemServiceGetShopItemsArgs) -> Array`** (item_service.gd:222). Appelée depuis `BaseShop` (`ui/menus/shop/base_shop.gd:368`, `args = ItemServiceGetShopItemsArgs.new(_shop_items, player_index)`).
- Le tirage réel de chaque élément : **`ItemService._get_rand_item_for_wave(wave, player_index, type, args: GetRandItemForWaveArgs) -> ItemParentData`** (item_service.gd:301). C'est le **chokepoint** :
  - `var player_character = RunData.get_player_character(player_index)` (perso dispo ici).
  - `item_tier = get_tier_from_wave(wave, player_index, args.increase_tier)` → **probabilité naturelle de tier** (intacte si on ne fait que retirer des candidats).
  - `var pool = get_pool(item_tier, type)` + `backup_pool`.
  - **Retrait du ban natif** (item_service.gd:314-328) : `var banned_items = RunData.players_data[player_index].banned_items` puis `pool = remove_element_by_id(pool, ...)`. ← modèle EXACT à imiter.
  - Puis retrait des `args.excluded_items` (anti-doublons du magasin courant).
  - Puis filtres armes par effets joueur (no_melee/no_ranged/no_duplicate/no_structures).

**Stratégie mod** : étendre `item_service.gd`, surcharger `_get_rand_item_for_wave`, et **après** avoir appelé le parent **non** — plutôt **ré-implémenter le retrait** en ajoutant, à la même étape que `banned_items`, le retrait de nos IDs exclus lus dans notre store (par `player_index`). Comme `_get_rand_item_for_wave` est privé et long, alternative plus propre : surcharger **`get_pool(item_tier, type)`** ne suffit pas (pas de player_index). Donc cible = `_get_rand_item_for_wave`. *Décision de portée* : filtrer ici impacte **tous** les tirages d'objets (magasin + item box), cohérent avec « je ne veux pas cet objet dans ma run » et avec le comportement du ban natif. Si on veut **strictement le magasin**, filtrer plutôt dans `get_player_shop_items`. → à trancher au design.

## MENU_NAV — insertion entre sélection perso et sélection arme (point d'accroche n°2)

- **`CharacterSelection._on_selections_completed()`** (`ui/menus/run/character_selection.gd:211`), appelée quand tous les joueurs ont validé leur perso :
  ```gdscript
  func _on_selections_completed() -> void:
      ...
      for player_index in RunData.get_player_count():
          var character = _player_characters[player_index]
          RunData.add_character(character, player_index)
      ...
      if RunData.some_player_has_weapon_slots():
          _change_scene(MenuData.weapon_selection_scene)   # ← ligne 220
      else:
          RunData.add_starting_items_and_weapons()
          _change_scene(MenuData.difficulty_selection_scene)
  ```
- `CharacterSelection` **a un `class_name`** (project.godot:309) — l'extension par chemin reste possible avec le ModLoader Brotato (à valider au runtime).
- Persos par joueur dispo : `_player_characters[player_index]` (membre) ou `RunData.get_player_character(player_index)` après `add_character`.

**Stratégie mod** : étendre `character_selection.gd`, surcharger `_on_selections_completed()` : reproduire l'ajout des persos (boucle 214-216), puis **afficher notre écran de config** ; à sa validation, exécuter la suite (`if some_player_has_weapon_slots: _change_scene(weapon_selection_scene) else ...`). `_change_scene` est héritée de `BaseSelection`. (Alternative : surcharger `_change_scene` et intercepter quand la cible == `MenuData.weapon_selection_scene`.)

## Exclusion native (NE PAS TOUCHER)

- Stockage : **`RunData.players_data[player_index].banned_items`** (Array d'IDs/hashes), retirée du pool dans `_get_rand_item_for_wave` (item_service.gd:314-328).
- UI native : `BanButton` (`res://ui/menus/run/ban_button.gd`), limite 8, + `CoopBanShopHint`. Notre mod garde un **store séparé** et n'écrit jamais ici.

## CHAR_COMPAT — éléments interdits selon le perso (pour filtrer la grille)

Les restrictions par perso sont appliquées au tirage via des **effets joueur** (`RunData.get_player_effect(Keys.*, player_index)`), pas une simple liste. Pertinents (vus dans `_get_rand_item_for_wave`) :
- Armes : `no_melee_weapons_hash`, `no_ranged_weapons_hash` (filtrent par `weapon.type`), `min_weapon_tier_hash`/`max_weapon_tier_hash` (clamp tier).
- Objets : `remove_shop_items_hash` (ex. contient `structure_hash` → pas d'objets structure), divers effets spécifiques perso.
- Pour la grille : reproduire ces mêmes tests pour masquer ce que le perso ne peut jamais obtenir. (Le ban natif `banned_items` est la feature 8-slots du joueur, distincte de la compat perso.)

## Restes mineurs à confirmer (n'empêchent pas l'architecture)

- Dossier de dépôt des mods unpacked (probable `mods-unpacked/` à côté du `.pck` ; confirmer via `ModLoaderStore`/menu mods).
- Champs exacts de `WeaponData` pour un éventuel filtre par set/classe d'arme.
- Comportement précis de `remove_element_by_id` vs hash (item_service.gd:319-328).
