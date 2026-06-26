#!/usr/bin/env bash
# Lance les tests unitaires (logique pure) du mod Tanith-ShopConfig.
#
# Utilise le Godot 3.6.2 livré dans le repo. Sous WSL/Linux, le binaire
# Windows tourne via l'interop ; il faut juste le bit exécutable (posé ici
# au besoin). Aucun Godot natif Linux 3.6.2 n'existe en téléchargement.
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

# --path relatif : on se place à la racine pour que Godot trouve Brotato/.
cd "$ROOT"
exec "$GODOT" --path Brotato --no-window \
  -s res://mods-unpacked/Tanith-ShopConfig/test/run_tests.gd "$@"
