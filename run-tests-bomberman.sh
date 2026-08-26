#!/usr/bin/env bash
# Lance les tests unitaires (logique pure) du mod Tanith-Bomberman.
#
# Jumeau de run-tests.sh, qui lance ceux de Tanith-ShopConfig : les deux mods
# ont leur PROPRE runner, il n'y a pas de suite commune.
#
# Code de sortie = nombre d'échecs (0 = tout vert). Les erreurs moteur
# affichées APRÈS « N tests, M échec(s) » sont la fermeture des autoloads
# du jeu (DLC, cursor…) et n'affectent pas le résultat.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT="$ROOT/Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe"

if [ ! -e "$GODOT" ]; then
  echo "Godot introuvable : $GODOT" >&2
  echo "Place le dossier Godot_v3.6.2-stable_win64.exe/ à la racine du repo." >&2
  exit 127
fi
[ -x "$GODOT" ] || chmod +x "$GODOT"

cd "$ROOT"
status=0
"$GODOT" --path Brotato --no-window \
  -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd "$@" || status=$?

# Purge obligatoire : sans elle, Brotato lit le log de ce runner au lancement
# suivant et affiche « le mod Tanith-Bomberman a planté, mods désactivés ».
# Voir tools/clean-godot-logs.sh.
[ -x "$ROOT/tools/clean-godot-logs.sh" ] || chmod +x "$ROOT/tools/clean-godot-logs.sh" 2>/dev/null || true
"$ROOT/tools/clean-godot-logs.sh" || true

exit $status
