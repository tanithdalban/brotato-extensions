extends "res://singletons/item_service.gd"
# Filtrage du pool du magasin, borné à la boutique.
# On retire les IDs exclus du joueur courant, uniquement pendant get_player_shop_items
# (drapeau de contexte), pour ne PAS toucher les autres tirages (boîtes à objets).
# Ne touche jamais au ban natif (RunData.players_data[i].banned_items).

const PoolFilter = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/pool_filter.gd")
const ShopConfigStore = preload("res://mods-unpacked/Tanith-ShopConfig/singletons/shop_config_store.gd")

var _shopconfig_store = ShopConfigStore.new()

func get_shopconfig_store():
	return _shopconfig_store

func get_player_shop_items(wave: int, player_index: int, args) -> Array:
	_shopconfig_store.begin_shop_draw(player_index)
	var result = .get_player_shop_items(wave, player_index, args)
	_shopconfig_store.end_shop_draw()
	return result

# Retire les éléments exclus du pool tiré. Borné au contexte boutique.
func get_pool(item_tier: int, type: int) -> Array:
	var pool = .get_pool(item_tier, type)
	if _shopconfig_store.is_shop_draw_active():
		var excluded = _shopconfig_store.get_excluded(_shopconfig_store.current_shop_player())
		if excluded.size() > 0:
			pool = PoolFilter.filter(pool, excluded)
	return pool

# Garde-fou contre la fuite par le fallback vanilla.
# _get_rand_item_for_wave (vanilla) retire de SON pool les éléments déjà dans le
# shop (anti-doublon). Si le joueur a restreint la boutique à un seul élément
# (ex. la bombe), le 2e slot vide le pool ET le backup, puis vanilla retombe sur
# _tiers_data[tier][type] en accès DIRECT, NON filtré (item_service.gd:462),
# réintroduisant un élément EXCLU. get_pool ne peut pas l'intercepter (accès
# direct). On enveloppe donc le tirage : si l'élément rendu est exclu, on le
# remplace par un élément AUTORISÉ (doublon toléré, c'est le but d'une boutique
# mono-élément).
func _get_rand_item_for_wave(wave: int, player_index: int, type: int, args) -> ItemParentData:
	var elt = ._get_rand_item_for_wave(wave, player_index, type, args)
	if not _shopconfig_store.is_shop_draw_active() or elt == null:
		return elt
	var excluded = _shopconfig_store.get_excluded(_shopconfig_store.current_shop_player())
	if excluded.size() == 0 or not excluded.has(elt.my_id):
		return elt
	var replacement = _allowed_replacement(type, excluded, args)
	return replacement if replacement != null else elt

# Un élément autorisé pour remplacer une fuite : même type d'abord (tous tiers),
# sinon l'autre type (boutique entièrement exclue d'un côté → on remplit avec ce
# qui reste autorisé). On préfère un élément pas déjà dans le shop ; à défaut on
# tolère le doublon (cas « je ne garde que la bombe »).
func _allowed_replacement(type: int, excluded: Dictionary, args):
	var allowed = _allowed_cross_tier(type, excluded)
	if allowed.size() == 0:
		var other = TierData.ITEMS if type == TierData.WEAPONS else TierData.WEAPONS
		allowed = _allowed_cross_tier(other, excluded)
	if allowed.size() == 0:
		return null
	var already := {}
	for pair in args.excluded_items:
		already[pair[0].my_id] = true
	var fresh := []
	for it in allowed:
		if not already.has(it.my_id):
			fresh.append(it)
	var src = fresh if fresh.size() > 0 else allowed
	return Utils.get_rand_element(src)

# Tous les éléments NON exclus du type donné, tous tiers confondus.
# `.get_pool` (parent) garde l'éventuel filtrage d'un autre mod (ex. Bomberman
# réduit les armes aux seules bombes) puisque le drapeau de tirage reste actif.
func _allowed_cross_tier(type: int, excluded: Dictionary) -> Array:
	var all_tiers := []
	for tier in _tiers_data.size():
		all_tiers += .get_pool(tier, type)
	return PoolFilter.filter(all_tiers, excluded)
