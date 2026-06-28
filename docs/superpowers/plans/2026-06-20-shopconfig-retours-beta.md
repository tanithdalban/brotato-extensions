# Plan — Retours de beta test (mod ShopConfig)

## Context

Après un beta test du mod **Tanith-ShopConfig** (écran de config du pool magasin par
joueur), quatre ajustements UX/logique sont demandés. Tous portent sur le **panneau
joueur** et restent bornés à la boutique (aucun impact sur le ban natif ni les item
boxes). **Un seul fichier est concerné** :
`Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd`.

Les modules de logique pure (`pool_filter.gd`, `shop_config_store.gd`) et leurs tests
**restent inchangés** : l'exclusion par famille d'armes est « aplatie » en `my_id`
côté panneau (cf. change 3), donc le filtrage reste piloté par `my_id` comme aujourd'hui.

Décisions validées avec l'utilisateur :
1. Rangée d'actions **juste sous les filtres** (au-dessus des onglets Objets/Armes).
2. Popup d'info : **reproduire la mécanique native du magasin** — l'action d'entrée
   `ui_info` (touche `F` / bouton manette `Y`), par joueur, et **pas** un bouton
   à l'écran. Popup affichée par défaut.
3. Filtre de tier **ignoré pour les armes** (les armes restent toujours visibles).

---

## Change 1 — Remonter la rangée d'actions rapides

Dans `_build_ui()`, déplacer le bloc `actions` (HBox contenant *Tout réinitialiser*,
*Tout désélectionner*, *Exclure tout l'affiché*) pour qu'il soit ajouté **juste après
`filter_bar`** et **avant** `tab_bar` (les onglets Objets/Armes).

- Ordre cible des enfants du `root` : header → `filter_bar` → `actions` → `tab_bar`
  → `_tabs` (grilles) → `_warning_label` → `_ready_button`.
- Simple réordonnancement du code existant (`player_shop_config_panel.gd:224-238`
  remonte au-dessus de `player_shop_config_panel.gd:204`). `_exclude_shown_button`
  reste créé avant tout appel à `_on_filter_changed`.

## Change 2 — Désactivation de la popup d'info (mécanique native)

Reproduire **exactement** la mécanique du magasin coop
(`ui/menus/shop/coop_item_popup.gd:36-42`) : l'action d'entrée **`ui_info`** (par
joueur, via `Utils.is_player_info_pressed(event, player_index)` →
`utils.gd:697`) bascule un drapeau **persistant** `_hide_popup`. Aucun bouton à
l'écran : c'est la même touche/manette (`F` / `Y`) que dans la boutique.

- Nouvelle var `_hide_popup := false` (par panneau → un état par joueur, comme le
  magasin coop où chaque popup teste son `player_index`).
- Ajouter `func _input(event)` au panneau :
  ```
  if Utils.is_player_info_pressed(event, _player_index):
      _hide_popup = not _hide_popup
      if _hide_popup:
          if _popup != null: _popup.hide()
      elif _focused_entry != null:
          _popup.display_item_data(_focused_entry, _focused_attach)
  ```
  Chaque panneau reçoit l'événement global et ne réagit qu'à **son** `_player_index`
  (faithful au coop, marche en solo comme en coop).
- Mémoriser le focus courant : dans `_on_cell_focused(entry, btn)`
  (`player_shop_config_panel.gd:358`), stocker `_focused_entry = entry` /
  `_focused_attach = btn`, et n'afficher la popup que si `not _hide_popup`. Dans
  `_on_cell_unfocused()`, remettre `_focused_entry = null`.
- Optionnel : un petit libellé d'aide (via `_t`) près des filtres rappelant la touche,
  à l'image du `ButtonHint` (`input_string="ui_info"`) du magasin.

## Change 3 — Une arme n'apparaît qu'une fois (raretés confondues)

Les armes Brotato ont une `WeaponData` distincte par tier (même `weapon_id` de
famille, `my_id` par tier — cf. `weapon_data.gd:6`). On déduplique par **famille**.

Approche « représentant + expansion à l'export » (garde `pool_filter` inchangé) :

- **Collecte** (`_collect_compatible`, `player_shop_config_panel.gd:86-101`) : grouper
  les armes compatibles par `fkey = weapon.weapon_id if weapon.weapon_id != "" else
  weapon.my_id`. Conserver **un seul représentant** par famille = le tier le plus bas
  (`weapon.tier` minimal). N'ajouter que les représentants à `_all_entries`.
- Construire deux maps :
  - `_all_weapon_ids_by_family` : `fkey -> [tous les my_id de cette famille]`, en
    balayant **toute** `ItemService.weapons` (inclure tous les tiers, même non
    lootables : les exclure est sans effet et garantit que la famille entière sort du
    pool).
  - `_repr_by_family` : `fkey -> my_id du représentant` (pour le garde-fou change 4).
- **Export** (`get_excluded_ids`, `player_shop_config_panel.gd:536`) : pour chaque clé
  exclue, si l'entrée est une `WeaponData`, émettre **tous** les `my_id` de sa famille
  (`_all_weapon_ids_by_family[fkey]`) ; sinon émettre le `my_id` de l'objet tel quel.
  Ainsi le store/pool reçoit des `my_id` plats et `pool_filter` retire tous les tiers.
- **Filtre de tier ignoré pour les armes** : dans `_matches_filter`
  (`player_shop_config_panel.gd:414`), n'appliquer le test de tier que si
  `not _is_weapon(entry)` ; toujours appliquer `_matches_class`.

Le reste (icône `entry.get_icon()`, classes via `stats.scaling_stats`, popup) marche
tel quel sur le représentant. Les comptes `get_total_count()` / `_excluded.size()` /
`_has_any_in_pool()` raisonnent désormais en **familles** (un représentant = une
unité), ce qui est cohérent.

## Change 4 — Armes de départ : affichées, mais garde-fou « au moins une sélectionnée »

- **Ne plus exclure les armes de départ de la liste** : scinder l'actuel
  `_starting_ids()` (`player_shop_config_panel.gd:108-118`) en deux :
  - `_starting_item_ids(character_data)` (objets de départ) → conservé, **toujours
    sauté** dans la boucle objets (comportement inchangé).
  - La boucle armes ne saute **plus** les armes de départ.
- **Garde-fou** : construire `_starting_weapon_family_keys` = ensemble des `fkey` des
  `character_data.starting_weapons`. Ajouter `_starting_weapon_ok()` :
  - `true` si l'ensemble est vide (perso sans arme de départ → garde-fou N/A) ;
  - sinon `true` dès qu'une famille de départ n'est **pas** exclue. Une famille non
    affichée (`_repr_by_family` ne la contient pas) compte comme disponible → `true`.
  - `false` seulement si **toutes** les familles d'armes de départ affichées sont
    exclues.
- **Intégration validation** :
  - `is_ready()` (`:533`) → `... and _starting_weapon_ok()`.
  - `_on_ready_toggled()` (`:390`) → bloquer aussi si `not _starting_weapon_ok()`.
  - `_refresh_state()` (`:517`) → si pool non vide mais `_starting_weapon_ok()` faux,
    afficher un avertissement dédié, ex. `_t("Keep at least one of your starting
    weapons.", "Garde au moins une de tes armes de départ.")`, désactiver Prêt et
    émettre `ready_changed(false)`.

---

## Fichiers modifiés

- `Brotato/mods-unpacked/Tanith-ShopConfig/scenes/player_shop_config_panel.gd`
  (unique fichier touché).

Aucune modification de `pool_filter.gd`, `shop_config_store.gd`,
`extensions/singletons/item_service.gd`, `shop_config_screen.gd` ni des tests.

## Vérification

1. **Tests unitaires** (doivent rester verts, logique pure inchangée) :
   ```
   "Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" \
     --path Brotato --no-window \
     -s res://mods-unpacked/Tanith-ShopConfig/test/run_tests.gd
   ```
2. **Test en jeu** (copier/symlinker le mod dans `mods-unpacked/`, lancer Brotato) —
   solo **et** coop :
   - Change 1 : la rangée d'actions est sous les filtres, au-dessus des onglets ;
     navigation focus/manette OK.
   - Change 2 : la touche `ui_info` (`F` / `Y` manette) coupe/rétablit la popup d'info ;
     état initial = affichée ; en coop, chaque joueur bascule **sa** popup ; l'état
     persiste quand on change d'icône.
   - Change 3 : une arme n'apparaît qu'une fois (vérifier un fusil multi-tiers, ex.
     SMG/Pistolet) ; le filtre de tier ne masque plus les armes ; exclure une arme la
     retire **à tous ses tiers** dans la boutique en run.
   - Change 4 : les armes de départ apparaissent et sont cochables ; exclure toutes les
     armes de départ bloque « Prêt » avec l'avertissement dédié ; en laisser au moins
     une débloque la validation.
   - Vérifier qu'un perso **sans slot d'arme** (ex. Dompteur) n'affiche aucune arme et
     valide sans blocage (garde-fou N/A).
