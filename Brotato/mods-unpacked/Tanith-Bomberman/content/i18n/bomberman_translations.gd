# Traductions codées en dur pour le mod Bomberman.
# Raison : ModLoaderMod.add_translation(path) appelle load(path) et attend
# un objet Translation COMPILÉ (.translation binaire généré par l'éditeur Godot).
# Sans éditeur disponible, on crée les objets Translation directement en code
# et on les enregistre via TranslationServer.add_translation().
#
# Clés fournies :
#   CHARACTER_BOMBERMAN  — nom du personnage (affiché via tr(name) dans item_parent_data.gd)
#   WEAPON_BOMB          — nom de l'arme    (idem)
#   WEAPON_BOMB_ICE      — nom de la Bombe de Glace
#   WEAPON_BOMB_ICE_SLOW — ligne d'infobulle « % ralentissement » (via NullEffect,
#                          {0} = valeur ; le % est dans la chaîne car la clé n'est
#                          pas dans les tables keys_needing_percent de text.gd)
#
# Note sur les descriptions : dans Brotato, les descriptions d'objets/personnages
# sont construites à partir du tableau effects[] (EffectLine), PAS depuis une clé
# "NOM_DESC". La clé EXPLOSION_DAMAGE existe déjà dans les traductions vanilla
# (elle couvre l'effet % Explosion Damage de bomberman_explosion_effect.tres).
# Aucune clé _DESC personnalisée n'est nécessaire.

extends Reference

static func register() -> void:
	var tr_en := Translation.new()
	tr_en.locale = "en"
	tr_en.add_message("CHARACTER_BOMBERMAN", "Bomberto")
	tr_en.add_message("WEAPON_BOMB", "Bomb")
	tr_en.add_message("WEAPON_BOMB_ICE", "Ice Bomb")
	tr_en.add_message("WEAPON_BOMB_ICE_SLOW", "Slows enemies by {0}%")
	TranslationServer.add_translation(tr_en)

	var tr_fr := Translation.new()
	tr_fr.locale = "fr"
	tr_fr.add_message("CHARACTER_BOMBERMAN", "Bomberto")
	tr_fr.add_message("WEAPON_BOMB", "Bombe")
	tr_fr.add_message("WEAPON_BOMB_ICE", "Bombe de Glace")
	tr_fr.add_message("WEAPON_BOMB_ICE_SLOW", "Ralentit les ennemis de {0}%")
	TranslationServer.add_translation(tr_fr)
