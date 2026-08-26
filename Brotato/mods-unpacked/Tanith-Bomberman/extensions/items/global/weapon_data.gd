extends "res://items/global/weapon_data.gd"
# Reprise de run : restaure les paramètres d'élément que la sérialisation perd.
#
# POURQUOI ICI : `WeaponStats.serialize()` (weapons/weapon_stats/weapon_stats.gd:206)
# ne liste PAS `speed_percent_modifier`, et `deserialize_and_merge` repart d'un
# `RangedWeaponStats.new()` neuf — le champ retombe donc à son défaut, 0. Conséquence
# antérieure au DLC : à la reprise d'une run, TOUTE Bombe de Glace perdait son
# ralentissement, maudite ou non.
#
# `player_run_data.gd:165-170` construit l'arme en dupliquant le .tres pristine PUIS
# en appelant `deserialize_and_merge` par-dessus. Se brancher juste après ce dernier
# est donc le seul endroit où l'on voit l'arme entièrement reconstituée, `is_cursed`
# et `curse_factor` compris (eux SONT sérialisés, cf. item_parent_data.gd:190-204).
#
# BombCurse.normalize recalculant tout depuis le pristine, il restaure la valeur de
# base ET réapplique la malédiction en un seul geste. Il est no-op sur toute arme
# qui n'est pas une bombe élémentaire : les autres mods ne voient rien passer.
#
# ⚠️ Nom de constante volontairement spécifique : deux extensions ModLoader du MÊME
# script vanilla partagent un espace de noms, et un `const` homonyme casserait
# silencieusement l'autre mod.

const BombCurse = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_curse.gd")


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	BombCurse.normalize(self, ItemService.get_element_safe(ItemService.weapons, my_id))
