# Outils — construction du livrable Bombertoe

Le mod **Bombertoe** (dossier technique `Tanith-Bomberman`) se distribue sur le
Steam Workshop sous forme d'un `.zip`. Ce dossier contient le script qui le
construit de façon reproductible.

## `build-bomberman.ps1`

Produit `dist/Tanith-Bomberman.zip`, prêt à téléverser sur le Workshop.

### Prérequis : régénérer le cache d'import des textures

Le `.zip` doit embarquer le cache d'import Godot (`.import/<png>-<hash>.stex` +
`.md5`) de chaque texture **import-based** (icône du perso + sprites d'apparence
eyes / mouth / torso). Ce cache est **gitignoré** (`*.import`), donc il faut le
(re)générer **après toute modification d'un de ces `.png`** :

```
"Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window --editor
```

⚠️ **Pas de `--quit`** : il interromprait le thread de scan avant l'import.
Laisser tourner ~60–90 s (le temps que le scan importe les textures), puis fermer
le process. Vérifier qu'un `.stex` a bien été (re)généré : le `source_md5` dans
`Brotato/.import/<png>-<hash>.stex` doit correspondre au md5 du `.png`.

> Les sprites de bombe (`content/weapons/bomb/skins/*.png`) sont chargés **au
> runtime** (`load()`), pas par cache d'import — ils n'ont pas besoin de cette
> étape.

### Construire le `.zip`

```
powershell -File tools/build-bomberman.ps1
```

Le script :
1. **Met en scène** `content/`, `extensions/`, `manifest.json`, `mod_main.gd`,
   `CHANGELOG_FR.md`, `CHANGELOG_EN.md` dans `%TEMP%\build-Tanith-Bomberman\mods-unpacked\Tanith-Bomberman\`
   (exclut `test/`, `docs/`, et les sauvegardes `*.pngold`).
2. **Embarque le cache d'import** : pour chaque `*.png.import`, lit le nom du
   `.stex` et copie le `.stex` + `.md5` correspondants dans `.import/` à la
   racine du stage. Échoue si un `.stex` manque (→ relancer l'étape éditeur).
3. **Zippe** avec des entrées en slash `/` (Godot résout `res://` en slash ;
   un `\` casserait le montage côté ModLoader).

Structure résultante du `.zip` (imposée par ModLoader Godot 3 / Brotato) :

```
mods-unpacked/Tanith-Bomberman/...   → monté à res://mods-unpacked/...
.import/<png>-<hash>.stex (+ .md5)   → monté à res://.import/...
```

### Téléverser sur le Workshop

Le `.zip` se dépose dans l'item Workshop existant (cf.
`Brotato/mods-unpacked/Tanith-Bomberman/docs/MARKET_ID.md`). Un item Workshop est
un **dossier** contenant le `.zip` ; ModLoader le monte via
`load_resource_pack(zip)` puis scanne `res://mods-unpacked/`.

### Vérifier le `.zip` (optionnel)

```
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; \
  $z=[System.IO.Compression.ZipFile]::OpenRead('dist\Tanith-Bomberman.zip'); \
  $z.Entries | ForEach-Object { $_.FullName }; $z.Dispose()"
```

Contrôles : aucun backslash dans les noms, présence de `mods-unpacked/...` **et**
de `.import/*.stex`, pas de fuite de `test/` ou `docs/`.
