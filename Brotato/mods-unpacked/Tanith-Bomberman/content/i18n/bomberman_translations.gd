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
#   WEAPON_BOMB_STORM       — nom de la Bombe de Foudre
#   WEAPON_BOMB_STORM_BOLTS — ligne d'infobulle « nb éclairs » (via NullEffect,
#                             {0} = nb_projectiles du tier)
#   WEAPON_BOMB_POISON      — nom de la Bombe de Poison
#   WEAPON_BOMB_POISON_DOT  — ligne d'infobulle du DOT, posée en text_key SUR le
#                             BurningEffect des bomb_poison_*_data.tres (Effect.get_text
#                             préfère text_key à key) : remplace le libellé natif
#                             EFFECT_BURNING pour dire « poison » au lieu de « brûlure ».
#                             Mêmes arguments que EFFECT_BURNING, fournis par
#                             BurningEffect.get_args() : {0} = durée (nb de ticks),
#                             {1} = dégâts par tick DÉJÀ scalés par l'ingénierie,
#                             {2} = icônes de scaling.
#   WEAPON_BOMB_LEECH       — nom de la Bombe Sangsue
#   WEAPON_BOMB_LEECH_DRAIN — ligne d'infobulle « PV drainés par explosion » (via NullEffect,
#                             {0} = plafond du tier). ⚠️ Doit rester cohérent avec
#                             BombLeech.CAP_BY_TIER (3/4/5/6).
#                             La ligne « Vol de vie X % » est, elle, affichée gratuitement
#                             par le vanilla (weapon_stats.gd:get_lifesteal_text).
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
	tr_en.add_message("WEAPON_BOMB_STORM", "Storm Bomb")
	tr_en.add_message("WEAPON_BOMB_STORM_BOLTS", "Strikes with {0} lightning bolts")
	tr_en.add_message("WEAPON_BOMB_POISON", "Poison Bomb")
	tr_en.add_message("WEAPON_BOMB_POISON_DOT", "Deals {0}x{1} ({2}) poison damage")
	tr_en.add_message("CHAL_BOMB_ICE", "Ice Handler")
	tr_en.add_message("CHAL_BOMB_ICE_DESC", "Get a tier IV Bomb.")
	tr_en.add_message("CHAL_BOMB_STORM", "Storm Handler")
	tr_en.add_message("CHAL_BOMB_STORM_DESC", "Get a tier IV Ice Bomb.")
	tr_en.add_message("CHAL_BOMB_POISON", "Poison Handler")
	tr_en.add_message("CHAL_BOMB_POISON_DESC", "Get a tier IV Storm Bomb.")
	tr_en.add_message("WEAPON_BOMB_LEECH", "Leech Bomb")
	tr_en.add_message("WEAPON_BOMB_LEECH_DRAIN", "Drains up to {0} HP per explosion")
	tr_en.add_message("CHAL_BOMB_LEECH", "Bomb Collector")
	tr_en.add_message("CHAL_BOMB_LEECH_DESC", "Hold the Bomb, Ice, Storm and Poison Bombs at the same time.")
	tr_en.add_message("BOMB_MIGRATION_TITLE", "New — bombs must be earned")
	tr_en.add_message("BOMB_MIGRATION_TEXT", "The Ice, Storm and Poison Bombs are now unlocked by completing challenges: take a bomb to tier IV to earn the next one.\n\nYou already own them. Lock them again to play through the progression, or keep them?")
	tr_en.add_message("BOMB_MIGRATION_PROGRESS", "Play the progression")
	tr_en.add_message("BOMB_MIGRATION_KEEP", "Keep my bombs")
	TranslationServer.add_translation(tr_en)

	var tr_fr := Translation.new()
	tr_fr.locale = "fr"
	tr_fr.add_message("CHARACTER_BOMBERMAN", "Bomberto")
	tr_fr.add_message("WEAPON_BOMB", "Bombe")
	tr_fr.add_message("WEAPON_BOMB_ICE", "Bombe de Glace")
	tr_fr.add_message("WEAPON_BOMB_ICE_SLOW", "Ralentit les ennemis de {0}%")
	tr_fr.add_message("WEAPON_BOMB_STORM", "Bombe de Foudre")
	tr_fr.add_message("WEAPON_BOMB_STORM_BOLTS", "Frappe en {0} éclairs")
	tr_fr.add_message("WEAPON_BOMB_POISON", "Bombe de Poison")
	tr_fr.add_message("WEAPON_BOMB_POISON_DOT", "Inflige {0}x{1} ({2}) dégâts de poison")
	tr_fr.add_message("CHAL_BOMB_ICE", "Artificier de glace")
	tr_fr.add_message("CHAL_BOMB_ICE_DESC", "Obtenez une Bombe de niveau IV.")
	tr_fr.add_message("CHAL_BOMB_STORM", "Artificier de foudre")
	tr_fr.add_message("CHAL_BOMB_STORM_DESC", "Obtenez une Bombe de Glace de niveau IV.")
	tr_fr.add_message("CHAL_BOMB_POISON", "Artificier de poison")
	tr_fr.add_message("CHAL_BOMB_POISON_DESC", "Obtenez une Bombe de Foudre de niveau IV.")
	tr_fr.add_message("WEAPON_BOMB_LEECH", "Bombe Sangsue")
	tr_fr.add_message("WEAPON_BOMB_LEECH_DRAIN", "Draine jusqu'à {0} PV par explosion")
	tr_fr.add_message("CHAL_BOMB_LEECH", "Collectionneur de bombes")
	tr_fr.add_message("CHAL_BOMB_LEECH_DESC", "Détenez en même temps la Bombe, la Bombe de Glace, la Bombe de Foudre et la Bombe de Poison.")
	tr_fr.add_message("BOMB_MIGRATION_TITLE", "Nouveauté — les bombes se méritent")
	tr_fr.add_message("BOMB_MIGRATION_TEXT", "Les bombes de Glace, de Foudre et de Poison se débloquent désormais en relevant des défis : montez une bombe au niveau IV pour gagner la suivante.\n\nVous les possédez déjà. Voulez-vous les reverrouiller pour vivre la progression, ou les conserver ?")
	tr_fr.add_message("BOMB_MIGRATION_PROGRESS", "Vivre la progression")
	tr_fr.add_message("BOMB_MIGRATION_KEEP", "Garder mes bombes")
	TranslationServer.add_translation(tr_fr)
