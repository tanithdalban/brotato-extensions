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

func get_pool(item_tier: int, type: int) -> Array:
	var pool = .get_pool(item_tier, type)
	if _shopconfig_store.is_shop_draw_active():
		var excluded = _shopconfig_store.get_excluded(_shopconfig_store.current_shop_player())
		if excluded.size() > 0:
			pool = PoolFilter.filter(pool, excluded)
	return pool
