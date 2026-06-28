# Traductions codées en dur pour le mod Bomberman.
# Raison : ModLoaderMod.add_translation(path) appelle load(path) et attend
# un objet Translation COMPILÉ (.translation binaire généré par l'éditeur Godot).
# Sans éditeur disponible, on crée les objets Translation directement en code
# et on les enregistre via TranslationServer.add_translation().
#
# Clés fournies :
#   CHARACTER_BOMBERMAN  — nom du personnage (affiché via tr(name) dans item_parent_data.gd)
#   WEAPON_BOMB          — nom de l'arme    (idem)
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
	TranslationServer.add_translation(tr_en)

	var tr_fr := Translation.new()
	tr_fr.locale = "fr"
	tr_fr.add_message("CHARACTER_BOMBERMAN", "Bomberto")
	tr_fr.add_message("WEAPON_BOMB", "Bombe")
	TranslationServer.add_translation(tr_fr)
