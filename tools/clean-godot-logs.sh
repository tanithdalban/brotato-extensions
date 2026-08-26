#!/usr/bin/env bash
# Purge les logs Godot produits par les runners de tests.
#
# POURQUOI (piège non évident) : le runner écrit dans le MÊME dossier de logs
# que le jeu (`%APPDATA%\Brotato\logs\`). Au démarrage, Brotato lit le dernier
# log horodaté — donc celui du runner — et `singletons/crash_reporter.gd:53-61`
# considère qu'un mod a fait planter la session précédente dès qu'il y trouve
# une ligne contenant « ERROR: » dont elle-même ou la suivante mentionne
# « mods-unpacked ». Or « SCRIPT ERROR: » contient « ERROR: », et les erreurs
# headless (`get_tree().current_scene` nul dans progress_data.gd) portent le
# chemin de nos extensions. Résultat : le jeu affiche « le mod X a planté, mods
# désactivés » (main_menu.gd:308-321) et coupe les mods sur les profils Steam et
# Epic (crash_reporter.gd:94-98). Faux positif intégral.
#
# Supprimer `godot.log` est indispensable : ce n'est pas lui que le jeu lit,
# mais il est RECOPIÉ en log horodaté au lancement suivant — c'est par là que le
# poison arrive. On ne touche pas aux logs d'une vraie session de jeu.
set -euo pipefail

resolve_logs_dir() {
  local appdata="${APPDATA:-}"

  # Sous WSL, APPDATA n'existe pas : on le demande à Windows via l'interop.
  if [ -z "$appdata" ] && command -v cmd.exe >/dev/null 2>&1; then
    appdata="$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r\n')"
  fi

  [ -n "$appdata" ] || return 1

  # Chemin Windows -> chemin POSIX (no-op sous Git Bash, qui donne déjà /c/...).
  if [[ "$appdata" == *'\'* ]]; then
    if command -v wslpath >/dev/null 2>&1; then
      appdata="$(wslpath -u "$appdata")"
    else
      appdata="/$(echo "$appdata" | sed 's|\\|/|g; s|^\([A-Za-z]\):|\L\1|')"
    fi
  fi

  echo "$appdata/Brotato/logs"
}

LOGS_DIR="$(resolve_logs_dir || true)"

if [ -z "$LOGS_DIR" ] || [ ! -d "$LOGS_DIR" ]; then
  echo "Dossier de logs Brotato introuvable, rien à purger." >&2
  exit 0
fi

removed=0
for log in "$LOGS_DIR"/godot*.log; do
  [ -e "$log" ] || continue
  # Signature d'un lancement de runner, jamais présente dans une vraie partie.
  if grep -qa "run_tests\|tests, .* .*chec" "$log" 2>/dev/null; then
    rm -f "$log"
    removed=$((removed + 1))
  fi
done

echo "Logs de test purgés : $removed (dossier : $LOGS_DIR)"
