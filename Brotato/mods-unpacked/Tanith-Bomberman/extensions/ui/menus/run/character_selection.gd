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

# Le dialogue de migration actuellement ouvert (null sinon). Sert à le refermer si la
# coop démarre, et à ne jamais en empiler deux.
var _bomberman_migration_dialog = null


func _ready() -> void:
	._ready()

	# L'écran porte SA PROPRE vérité sur le mode de jeu : le CheckButton coop émet
	# `coop_initialized(active)` à CHAQUE bascule, et c'est l'intention RÉELLE du
	# joueur pour la run à venir. `RunData.is_coop_run`, lui, ne reflète à cet instant
	# que le mode de la run PRÉCÉDENTE (`play_mode` n'est pas remis à zéro entre deux
	# runs) — s'y fier seul priverait du popup le joueur dont la dernière partie était
	# en coop et qui revient jouer en solo.
	#
	# On s'abonne EN PLUS du vanilla (plusieurs abonnés à un même signal est légal ;
	# on ne touche pas à sa connexion). `_coop_button` est un `onready` du script
	# vanilla : il n'existe qu'APRÈS `._ready()`.
	if _coop_button != null:
		var _e = _coop_button.connect("coop_initialized", self, "_on_bomberman_coop_toggled")

	_bomberman_try_propose_migration()


# Propose la migration si, et seulement si, on est en solo et qu'il reste des bombes
# possédées mais non gagnées. Idempotent : ne rouvre jamais un dialogue déjà ouvert.
func _bomberman_try_propose_migration() -> void:
	if RunData.is_coop_run:
		return
	if _bomberman_migration_dialog != null:
		return

	var pending: Array = _unearned_bombs()
	if pending.empty():
		return

	call_deferred("_show_migration_popup", pending)


# Bascule du bouton coop de l'écran.
#
# - Coop ACTIVÉE : on referme le dialogue sans RIEN persister. Les joueurs rejoignent
#   la partie avec leurs manettes sur cet écran, et un popup natif capte n'importe
#   quel device : l'invité répondrait à la place de l'hôte, sur la sauvegarde de
#   l'hôte, et le choix est irréversible. La question sera reposée plus tard, en solo.
# - Coop DÉSACTIVÉE : le joueur revient au solo (typiquement, sa run précédente était
#   en coop, donc `_ready()` s'était abstenu). C'est le moment de lui proposer.
func _on_bomberman_coop_toggled(active: bool) -> void:
	if active:
		_bomberman_close_migration_dialog()
	else:
		_bomberman_try_propose_migration()


func _bomberman_close_migration_dialog() -> void:
	if _bomberman_migration_dialog == null:
		return

	if is_instance_valid(_bomberman_migration_dialog):
		_bomberman_migration_dialog.hide()
		_bomberman_migration_dialog.queue_free()

	_bomberman_migration_dialog = null


# Le dialogue s'est fermé, quelle qu'en soit la raison (réponse, Échap, coop qui
# démarre) : on libère la référence pour qu'une bascule ultérieure puisse reproposer.
func _on_bomberman_migration_dialog_hidden() -> void:
	if _bomberman_migration_dialog != null and is_instance_valid(_bomberman_migration_dialog):
		_bomberman_migration_dialog.queue_free()

	_bomberman_migration_dialog = null


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
	# La proposition est différée (call_deferred) : la coop a pu démarrer entre-temps,
	# ou un dialogue avoir déjà été ouvert. On revalide.
	if RunData.is_coop_run or _bomberman_migration_dialog != null:
		return

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
	dialog.connect("popup_hide", self, "_on_bomberman_migration_dialog_hidden")

	_bomberman_migration_dialog = dialog
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
