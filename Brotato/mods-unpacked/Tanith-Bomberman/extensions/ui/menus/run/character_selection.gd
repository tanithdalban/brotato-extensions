extends "res://ui/menus/run/character_selection.gd"
# Propose UNE FOIS aux joueurs qui possèdent déjà les bombes élémentaires de les
# reverrouiller pour vivre la chaîne de défis.
#
# ⚠️ SOLO UNIQUEMENT : le choix engage la sauvegarde du PROPRIÉTAIRE du jeu. En couch
# coop, un popup natif capte n'importe quel device (la leçon qui a fait retirer les
# OptionButton de ShopConfig) : la manette d'un invité pourrait reverrouiller la
# progression de l'hôte. On règle le problème par la géométrie, pas par la technique.
#
# ⚠️ ShopConfig étend DÉJÀ ce script. ModLoader empile les extensions : l'appel au
# parent (._ready()) préserve la chaîne.
#
# ⚠️ NOM DE CONSTANTE : ShopConfig déclare aussi un `const ModLog` dans SA propre
# extension de ce même script vanilla. Les extensions ModLoader d'un même fichier
# se comportent comme des classes empilées : deux consts homonymes dans deux
# extensions différentes du même script cassent le rechargement de la seconde
# installée (« The member "ModLog" already exists in a parent class »), constaté
# en test (le mod chargé en second, ShopConfig, ne compile alors plus DU TOUT).
# D'où le nom local `BombermanModLog`, pour ne jamais collisionner avec un autre mod.
const BombermanModLog = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/mod_log.gd")
const BombChallenges = preload("res://mods-unpacked/Tanith-Bomberman/content/logic/bomb_challenges.gd")


func _ready() -> void:
	._ready()

	# ⚠️ Ce test ne filtre que le cas évident : à cet instant, RunData.is_coop_run
	# reflète encore le mode de la run PRÉCÉDENTE (RunData.play_mode n'est pas remis
	# à zéro entre les runs). Les joueurs coop rejoignent la partie sur CET écran,
	# APRÈS ce _ready() : un second appui pourrait démarrer la coop pendant que le
	# popup est déjà affiché. D'où la re-vérification dans chaque gestionnaire de
	# réponse (_on_migration_relock / _on_migration_keep), seule garantie fiable.
	# Limite connue et ASSUMÉE : un joueur dont la run précédente était en coop ne
	# verra donc pas le popup à sa première visite de cet écran en solo ; il le
	# verra à la visite suivante. Désagrément mineur, pas un risque : on ne cherche
	# pas à le contourner.
	if RunData.is_coop_run:
		return

	var pending: Array = _unearned_bombs()
	if pending.empty():
		return

	call_deferred("_show_migration_popup", pending)


# Les bombes possédées mais non gagnées (calcul pur dans BombChallenges).
func _unearned_bombs() -> Array:
	var unlocked := []
	var completed := []

	for chal_id in BombChallenges.REWARD:
		var weapon_id: String = BombChallenges.REWARD[chal_id]
		if ProgressData.weapons_unlocked.has(Keys.generate_hash(weapon_id)):
			unlocked.append(weapon_id)
		if ChallengeService.is_challenge_completed(Keys.generate_hash(chal_id)):
			completed.append(chal_id)

	return BombChallenges.unearned_bombs(unlocked, completed)


func _show_migration_popup(pending: Array) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.window_title = tr("BOMB_MIGRATION_TITLE")
	dialog.dialog_text = tr("BOMB_MIGRATION_TEXT")
	dialog.get_ok().text = tr("BOMB_MIGRATION_PROGRESS")
	dialog.get_cancel().text = tr("BOMB_MIGRATION_KEEP")

	# Le Label interne n'a pas l'autowrap par défaut en Godot 3 : sans lui,
	# popup_centered() sans taille dimensionne la fenêtre sur BOMB_MIGRATION_TEXT
	# comme une seule ligne (~200 caractères) => dialogue démesuré, boutons
	# potentiellement inatteignables. On force le retour à la ligne et une taille
	# raisonnable.
	dialog.get_label().autowrap = true
	dialog.rect_min_size = Vector2(700, 0)

	# Échapper ferme sans choisir : la question sera reposée au prochain lancement.
	dialog.connect("confirmed", self, "_on_migration_relock", [pending])
	dialog.get_cancel().connect("pressed", self, "_on_migration_keep", [pending])

	add_child(dialog)
	dialog.popup_centered(Vector2(700, 260))

	# AcceptDialog focalise son bouton OK à l'ouverture. Ici, OK = « Vivre la
	# progression » = REVERROUILLER, destructif et irréversible : un joueur qui
	# enchaîne les menus en martelant A/Entrée effacerait ses bombes sans avoir
	# rien lu. L'option SÛRE (« Garder mes bombes ») doit être le défaut.
	dialog.get_cancel().grab_focus()


# « Vivre la progression » : on retire les bombes non gagnées de la sauvegarde.
func _on_migration_relock(pending: Array) -> void:
	# Les joueurs coop rejoignent la partie SUR cet écran, après le _ready() qui a
	# affiché ce popup : si la coop a démarré entre-temps, RunData.is_coop_run est
	# désormais vrai et cette réponse pourrait venir de la manette d'un invité qui
	# appuyait pour rejoindre, pas de l'hôte. On ne persiste RIEN dans ce cas : la
	# question sera reposée plus tard, pour l'hôte, en solo.
	if RunData.is_coop_run:
		return

	for weapon_id in pending:
		ProgressData.weapons_unlocked.erase(Keys.generate_hash(weapon_id))
		BombermanModLog.info("bombe reverrouillée: " + str(weapon_id))

	ProgressData.save()

	# Les pools sont reconstruits au démarrage de la run, mais on les rafraîchit tout
	# de suite : c'est ce que fait le jeu lui-même quand il active/désactive un DLC
	# (global/dlc_data.gd:102).
	ItemService.init_unlocked_pool()


# « Garder mes bombes » : on marque leurs défis comme complétés, pour que la
# progression reste cohérente (l'écran Progression les montre comme gagnés) et que
# la chaîne ne se redéclenche jamais pour ce joueur.
#
# ⚠️ On écrit DIRECTEMENT dans ProgressData plutôt que d'appeler
# ChallengeService.complete_challenge() : celui-ci émet le signal challenge_completed,
# qui déclencherait trois pop-ups « Défi accompli » sur l'écran de sélection.
func _on_migration_keep(pending: Array) -> void:
	# Même garde-fou que _on_migration_relock : voir son commentaire.
	if RunData.is_coop_run:
		return

	for weapon_id in pending:
		for chal_id in BombChallenges.REWARD:
			if BombChallenges.REWARD[chal_id] != weapon_id:
				continue
			var chal_hash: int = Keys.generate_hash(chal_id)
			if not ProgressData.challenges_completed.has(chal_hash):
				ProgressData.challenges_completed.append(chal_hash)

	ProgressData.save()
	BombermanModLog.info("migration: le joueur garde ses bombes")
