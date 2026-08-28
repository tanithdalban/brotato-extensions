extends SceneTree
# Runner de tests autonome (GUT non embarqué dans le build Brotato).
# Lancer : Godot --path Brotato --no-window -s res://mods-unpacked/Tanith-ShopConfig/test/run_tests.gd
# Code de sortie = nombre d'échecs (0 = tout passe).

# NB : on ne preload PAS mod_log.gd ici — il référence le global ModLoaderLog
# qui ne peut pas se charger dans ce harness headless (les autoloads ModLoader
# du jeu entrent en cyclic-load hors du vrai runtime). mod_log est trivial
# (Engine.meta) et se vérifie en jeu. Ici on teste les unités 100 % pures.
const PoolFilter = preload("res://mods-unpacked/Tanith-ShopConfig/content/logic/pool_filter.gd")
const Store = preload("res://mods-unpacked/Tanith-ShopConfig/singletons/shop_config_store.gd")

var _failures := 0
var _count := 0

class StubItem:
	extends Reference
	var my_id := ""
	func _init(id):
		my_id = id


func _init():
	print("=== ShopConfig tests ===")
	_test_pool_filter()
	_test_owned_and_carried()
	_test_store()
	_test_class_key_signs()
	print("=== %d tests, %d échec(s) ===" % [_count, _failures])
	quit(_failures)


func _check(cond, name):
	_count += 1
	if not cond:
		_failures += 1
		print("FAIL: ", name)
	else:
		print("ok  : ", name)


func _items(ids):
	var out = []
	for id in ids:
		out.append(StubItem.new(id))
	return out


func _ids(items):
	var out = []
	for it in items:
		out.append(it.my_id)
	return out


func _test_pool_filter():
	_check(_ids(PoolFilter.filter(_items(["a", "b", "c"]), {"b": true})) == ["a", "c"], "pool_filter: retire les exclus")
	_check(_ids(PoolFilter.filter(_items(["a", "b"]), {"zzz": true})) == ["a", "b"], "pool_filter: id inconnu ignoré")
	_check(_ids(PoolFilter.filter(_items(["a", "b"]), {})) == ["a", "b"], "pool_filter: exclusions vides = tout")
	_check(PoolFilter.filter(_items(["a", "b"]), {"a": true, "b": true}).size() == 0, "pool_filter: tout exclu = vide")
	var candidates = _items(["a", "b"])
	PoolFilter.filter(candidates, {"a": true})
	_check(candidates.size() == 2, "pool_filter: n'altère pas l'entrée")


func _test_owned_and_carried():
	# owned_ids : objet -> {my_id} ; arme -> tous les ids de la famille.
	var owned = PoolFilter.owned_ids(["item_a"], [["wpn_t1", "wpn_t2", "wpn_t3"]])
	_check(owned.hash() == {"item_a": true, "wpn_t1": true, "wpn_t2": true, "wpn_t3": true}.hash(), "owned_ids: objet + famille d'arme aplatie")
	_check(PoolFilter.owned_ids([], []).hash() == {}.hash(), "owned_ids: vide")
	# carried : ids mémorisés non affichables -> conservés ; affichables -> écartés.
	var saved = {"item_a": true, "wpn_t1": true, "wpn_t2": true, "ghost": true}
	var carried = PoolFilter.carried(saved, owned)
	_check(carried.hash() == {"ghost": true}.hash(), "carried: garde l'id non affiché, écarte les affichés")
	_check(PoolFilter.carried({}, owned).hash() == {}.hash(), "carried: rien à reporter si saved vide")
	_check(PoolFilter.carried(saved, {}).hash() == saved.hash(), "carried: tout reporté si rien d'affiché")


func _test_store():
	var s = Store.new()
	_check(s.get_excluded(0).hash() == {}.hash(), "store: défaut vide")
	s.set_excluded(0, {"a": true})
	_check(s.get_excluded(0).hash() == {"a": true}.hash(), "store: set/get")
	s.set_excluded(1, {"b": true})
	_check(s.get_excluded(0).hash() == {"a": true}.hash() and s.get_excluded(1).hash() == {"b": true}.hash(), "store: joueurs indépendants")
	var src = {"a": true}
	s.set_excluded(2, src)
	src["b"] = true
	_check(s.get_excluded(2).hash() == {"a": true}.hash(), "store: stocke une copie")
	s.begin_shop_draw(0)
	s.reset()
	_check(s.get_excluded(0).hash() == {}.hash() and not s.is_shop_draw_active(), "store: reset")
	s.set_excluded(0, {"a": true})
	_check(s.has_any_available(0, 3), "store: has_any_available vrai si reste")
	s.set_excluded(0, {"a": true, "b": true})
	_check(not s.has_any_available(0, 2), "store: has_any_available faux si tout exclu")
	_check(not s.is_shop_draw_active(), "store: contexte inactif au départ")
	s.begin_shop_draw(2)
	_check(s.is_shop_draw_active() and s.current_shop_player() == 2, "store: begin_shop_draw")
	s.end_shop_draw()
	_check(not s.is_shop_draw_active() and s.current_shop_player() == -1, "store: end_shop_draw")


# Signe d'une « classe » (stat) : une clé n'est retenue que si l'attribut est
# POSITIF, c.-à-d. si le jeu afficherait l'effet comme un bonus. On reproduit
# la résolution de Effect.get_sign (items/global/effect.gd).
func _test_class_key_signs():
	# POSITIVE explicite : le jeu l'annonce bonus même quand la valeur est
	# négative (Coupon : items_price = -5 ; Escargot : enemy_speed = -8).
	_check(PoolFilter.is_positive_sign(PoolFilter.SIGN_POSITIVE, -5), "signe: POSITIVE explicite retenu malgré une valeur négative")
	_check(PoolFilter.is_positive_sign(PoolFilter.SIGN_POSITIVE, 2), "signe: POSITIVE explicite retenu")
	# NEGATIVE explicite : malus, même annoncé avec une valeur positive.
	_check(not PoolFilter.is_positive_sign(PoolFilter.SIGN_NEGATIVE, 5), "signe: NEGATIVE explicite écarté")
	# NEUTRAL et OVERRIDE ne sont pas des bonus affichés.
	_check(not PoolFilter.is_positive_sign(PoolFilter.SIGN_NEUTRAL, 5), "signe: NEUTRAL écarté")
	_check(not PoolFilter.is_positive_sign(PoolFilter.SIGN_OVERRIDE, 35), "signe: OVERRIDE écarté")
	# FROM_VALUE (défaut de très loin le plus courant) : le signe suit la valeur.
	_check(PoolFilter.is_positive_sign(PoolFilter.SIGN_FROM_VALUE, 8), "signe: FROM_VALUE positif retenu")
	_check(not PoolFilter.is_positive_sign(PoolFilter.SIGN_FROM_VALUE, -10), "signe: FROM_VALUE négatif écarté (le cas du -10 % dégâts à distance)")
	_check(not PoolFilter.is_positive_sign(PoolFilter.SIGN_FROM_VALUE, 0), "signe: FROM_VALUE nul écarté")
	# FROM_ARG : aucun cas dans les données du jeu ; repli sur la valeur.
	_check(PoolFilter.is_positive_sign(PoolFilter.SIGN_FROM_ARG, 3), "signe: FROM_ARG positif retenu (repli)")
	_check(not PoolFilter.is_positive_sign(PoolFilter.SIGN_FROM_ARG, -3), "signe: FROM_ARG négatif écarté (repli)")
	# Signe inconnu (donnée moddée/inattendue) : on n'invente pas un bonus.
	_check(not PoolFilter.is_positive_sign(42, 5), "signe: valeur d'enum inconnue écartée")

	# Armes : pas de notion de signe, seul le scaling compte (4 armes lourdes
	# du jeu ont un stat_attack_speed négatif).
	_check(PoolFilter.is_positive_scaling(1.0), "scaling: positif retenu")
	_check(not PoolFilter.is_positive_scaling(-0.5), "scaling: négatif écarté")
	_check(not PoolFilter.is_positive_scaling(0.0), "scaling: nul écarté")
