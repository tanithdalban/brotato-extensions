# Construit le livrable Steam Workshop du mod Tanith-Bomberman.
#
# Structure du .zip (impératif pour ModLoader Godot 3 / Brotato) :
#   mods-unpacked/Tanith-Bomberman/...   <- monté à res://mods-unpacked/... (ModLoader y cherche le mod)
#   .import/<png>-<hash>.stex (+ .md5)   <- monté à res://.import/... (cache d'import des textures,
#                                            comme dans un .pck exporté ; les .png.import y renvoient)
# Les noms d'entrées utilisent des SLASH '/' (Godot résout res:// en slash ; '\' casserait le montage).
#
# Usage : powershell -File tools/build-bomberman.ps1
#         powershell -File tools/build-bomberman.ps1 -DeployDir 'X:\...\Brotato\mods-unpacked'
#
# Apres le zip, depose le livrable en local pour test : copie le .zip + la
# preview (bombertoe_preview.png -> preview.png) dans <DeployDir>\Tanith-Bomberman\.
# Ignore silencieusement si le dossier Steam n'existe pas (autre machine / CI).
param(
  [string]$DeployDir = 'D:\SteamLibrary\steamapps\common\Brotato\mods-unpacked'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repo    = Split-Path -Parent $PSScriptRoot
$modName = 'Tanith-Bomberman'
$modSrc  = Join-Path $repo "Brotato\mods-unpacked\$modName"
$importSrc = Join-Path $repo 'Brotato\.import'
$stage   = Join-Path $env:TEMP "build-$modName"
$outZip  = Join-Path $repo "dist\$modName.zip"

# --- 1) Stage propre ---
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
$modStage = Join-Path $stage "mods-unpacked\$modName"
New-Item -ItemType Directory -Force -Path $modStage | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $stage '.import') | Out-Null

# Copie le code/les assets, en excluant le dev-only (test/, docs/, sauvegardes *.pngold)
foreach ($item in @('content','extensions','manifest.json','mod_main.gd','CHANGELOG_FR.md','CHANGELOG_EN.md')) {
  Copy-Item (Join-Path $modSrc $item) (Join-Path $modStage $item) -Recurse -Force
}
Get-ChildItem $modStage -Recurse -Include '*.pngold' | Remove-Item -Force
# Contact sheet de l'icône animée = vérif visuelle dev-only, jamais chargée en jeu
# (on retire aussi son .png.import pour ne pas embarquer un .stex orphelin).
Get-ChildItem $modStage -Recurse -Include '_contact_sheet.png','_contact_sheet.png.import' | Remove-Item -Force
$testDir = Join-Path $modStage 'test'; if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
$docsDir = Join-Path $modStage 'docs'; if (Test-Path $docsDir) { Remove-Item $docsDir -Recurse -Force }

# --- 2) Embarque le cache d'import (.stex + .md5) de chaque texture, hash lu dans le .png.import ---
$importStage = Join-Path $stage '.import'
$missing = @()
Get-ChildItem $modStage -Recurse -Filter '*.png.import' | ForEach-Object {
  $m = Select-String -Path $_.FullName -Pattern 'path="res://\.import/([^"]+\.stex)"' | Select-Object -First 1
  if (-not $m) { $missing += "pas de stex dans $($_.Name)"; return }
  $stex = $m.Matches[0].Groups[1].Value
  $base = [System.IO.Path]::GetFileNameWithoutExtension($stex)  # <png>-<hash>
  foreach ($ext in @('stex','md5')) {
    $f = Join-Path $importSrc "$base.$ext"
    if (Test-Path $f) { Copy-Item $f $importStage -Force }
    elseif ($ext -eq 'stex') { $missing += "manquant: $base.stex (régénère le cache d'import dans l'éditeur Godot)" }
  }
}
if ($missing.Count) { $missing | ForEach-Object { Write-Warning $_ }; throw "Cache d'import incomplet." }

# --- 3) Zip (entrées en slash '/') ---
if ([System.IO.File]::Exists($outZip)) { [System.IO.File]::Delete($outZip) }
$bs = [char]92
$fs = [System.IO.File]::Open($outZip, [System.IO.FileMode]::CreateNew)
$arch = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
$baseLen = ((Resolve-Path $stage).Path).Length + 1
Get-ChildItem $stage -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($baseLen).Replace($bs, '/')
  $entry = $arch.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
  $es = $entry.Open()
  $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
  $es.Write($bytes, 0, $bytes.Length); $es.Close()
}
$arch.Dispose(); $fs.Close()
Write-Output ("OK -> {0}  ({1} KB)" -f $outZip, [math]::Round((Get-Item $outZip).Length/1KB, 1))

# --- 4) Depot local (Steam) : zip + preview.png dans mods-unpacked\Tanith-Bomberman\ ---
if (Test-Path $DeployDir) {
  $dest = Join-Path $DeployDir $modName
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Copy-Item $outZip (Join-Path $dest "$modName.zip") -Force
  $preview = Join-Path $modSrc 'bomberto_preview.png'
  if (Test-Path $preview) { Copy-Item $preview (Join-Path $dest 'preview.png') -Force }
  else { Write-Warning ("preview introuvable : {0}" -f $preview) }
  Write-Output ("Depose -> {0}" -f $dest)
} else {
  Write-Warning ("Dossier de depot introuvable, etape ignoree : {0}" -f $DeployDir)
}