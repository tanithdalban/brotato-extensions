---
name: livrer-un-mod
description: À utiliser quand on prépare, construit ou publie une nouvelle version d'un mod Brotato de ce repo (ShopConfig, Bomberman, WaveRollback) — « génère le livrable », « fais la release », monter la version, zip Workshop, notes de version, ou après un correctif prêt à partir sur le Steam Workshop.
---

# Livrer un mod

## Principe

Une livraison = **une branche partie de `master`** qui contient, dans le même lot : le correctif, la version, les deux journaux, les notes Workshop et les tests ; puis un zip **vérifié** et une validation en jeu **avec ET sans DLC**. Rien n'est « livré » tant que le zip n'a pas été inspecté et que la copie Workshop souscrite n'a pas été testée.

## Les mods

| Mod | Dossier | ID Workshop (fichier) | Build |
|---|---|---|---|
| ShopConfig | `Brotato/mods-unpacked/Tanith-ShopConfig/` | `WorkshopID.md` | `tools/build-shopconfig.ps1` |
| Bomberman | `Brotato/mods-unpacked/Tanith-Bomberman/` | `docs/MARKET_ID.md` | `tools/build-bomberman.ps1` (embarque les `.stex`, cf. `tools/README.md`) |
| WaveRollback | `Brotato/mods-unpacked/Tanith-WaveRollback/` (branche `feat/waverollback`) | pas encore publié | **aucun script** : en écrire un sur le modèle de ShopConfig avant la 1re livraison |

Toujours lire l'ID dans le fichier : ne jamais le recopier de mémoire.

## Étapes

1. **Branche** depuis `master` à jour : `fix/<sujet>` ou `feat/<sujet>`.
2. **Version** dans `manifest.json` (`version_number`), en semver : correctif = patch.
3. **Journaux** : nouvelle section `## [X.Y.Z] — AAAA-MM-JJ` en tête de `CHANGELOG_FR.md` ET `CHANGELOG_EN.md` (même contenu, ton joueur, pas de jargon de code).
4. **Notes Workshop** : `docs/workshop-changenotes_X.Y.Z.txt`, BBCode, bloc `[h1]🇬🇧 English[/h1]` puis `[hr][/hr]` puis `[h1]🇫🇷 Français[/h1]` — copier la structure de la version précédente. Dans le même commit que le correctif, pas après.
5. **Tests** : `./run-tests.sh` / `./run-tests-bomberman.sh` / `./run-tests-waverollback.sh` (ce dernier n'existe que sur `feat/waverollback`). Exiger « 0 échec(s) » **ET** un total de tests égal à l'ancien + les nouveaux : une `SCRIPT ERROR` interrompt la fonction de test sans compter d'échec.
6. **Validation en jeu** (éditeur : `Godot…exe --path Brotato --editor`, F5), sur une **nouvelle run** (une run reprise restaure le contenu DLC de sa sauvegarde) :
   - avec les DLC ;
   - **sans DLC** : vider `owned_dlc_ids` dans `Brotato/singletons/debug_service.gd:49` (plateforme locale), puis remettre `["abyssal_terrors", "primal_dread"]` ;
   - vérifier `godot.log` : la bonne version dans le manifeste chargé, aucune `SCRIPT ERROR` ;
   - regarder ce que la correction touche **concrètement** (contenu de la boutique, etc.), pas seulement « ça ne plante pas ».
7. **Build** depuis WSL : `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tools/build-<mod>.ps1)"` → `dist/Tanith-<Mod>.zip` + dossier d'upload `D:\SteamLibrary\steamapps\common\Brotato\mods-unpacked\Tanith-<Mod>\` (zip + `preview.png`).
8. **Inspecter le zip** (python `zipfile`) : entrées sous `mods-unpacked/Tanith-<Mod>/`, aucun `\`, ni `test/` ni `docs/`, `version_number` attendu, présence du code corrigé ; pour Bomberman, les `.stex` sous `.import/`.
9. **Commit** (message en français, `fix(<mod>): … (X.Y.Z)`), puis **demander** avant de fusionner : `git merge --no-ff <branche> -m "Merge branch '<branche>' (<Mod> X.Y.Z : <résumé>)"` sur `master`.
10. **Push** — demander d'abord — avec le git **Windows** : `git.exe push origin master` (le git WSL n'a pas d'identifiants).
11. **Après l'upload** (fait par l'utilisateur, notes = fichier de l'étape 4) : tester la **copie souscrite** sur Steam. Le dossier `D:\…\mods-unpacked\` n'est jamais lu par le jeu Steam.

## Erreurs fréquentes

| Erreur | Conséquence | Parade |
|---|---|---|
| Valider seulement avec les DLC | Bomberman 3.1.1 : bombes absentes de la boutique, masqué par les armes DLC | Étape 6, les deux configurations |
| Lire « 0 échec(s) » sans le total | Test cassé par une `SCRIPT ERROR` compté comme réussi | Comparer le nombre de tests |
| Tester une run reprise | Contenu DLC restauré malgré `owned_dlc_ids` vide | Nouvelle run |
| Notes Workshop en commit séparé | Livraison incomplète, branche `docs/…` après coup | Étape 4 dans le commit du correctif |
| `.sh` qui échoue sur `$'\r'` / faux « M » | Fins de ligne CRLF posées par le git Windows | Repasser en LF ; git.exe seulement pour push/fetch |
| `.git/index.lock` présent | Git de l'éditeur en cours | Relancer après un délai, ne jamais supprimer le verrou |
| Popup « le mod a planté » au lancement suivant | `crash_reporter.gd` lit un log contenant `SCRIPT ERROR` + `mods-unpacked` | `tools/clean-godot-logs.sh` après une session de test en erreur |
| Cache `.stex` absent (Bomberman) | `build-bomberman.ps1` échoue « Cache d'import incomplet » | Régénérer via l'éditeur (`tools/README.md`) |
