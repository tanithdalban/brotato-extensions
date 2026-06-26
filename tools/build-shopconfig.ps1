# Construit le livrable Steam Workshop du mod Tanith-ShopConfig.
#
# Structure du .zip (telle que publiée sur l'item Workshop 3748276960) :
#   manifest.json, mod_main.gd, CHANGELOG.md, content/, extensions/, scenes/, singletons/  <- fichiers du mod à la RACINE du zip
# Pas de .import : ShopConfig est 100 % GDScript, sans texture à embarquer.
# Les entrées utilisent des SLASH '/' (Godot/ModLoader résout res:// en slash ; '\' casserait le montage).
# Le dev-only (test/, docs/) est exclu.
#
# Usage : powershell -File tools/build-shopconfig.ps1

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repo    = Split-Path -Parent $PSScriptRoot
$modName = 'Tanith-ShopConfig'
$modSrc  = Join-Path $repo "Brotato\mods-unpacked\$modName"
$stage   = Join-Path $env:TEMP "build-$modName"
$outZip  = Join-Path $repo "dist\$modName.zip"

# --- 1) Stage propre (fichiers du mod a la racine) ---
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

# Copie le code, en excluant le dev-only (test/, docs/)
foreach ($item in @('content','extensions','scenes','singletons','manifest.json','mod_main.gd','CHANGELOG.md')) {
  Copy-Item (Join-Path $modSrc $item) (Join-Path $stage $item) -Recurse -Force
}
$testDir = Join-Path $stage 'test'; if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
$docsDir = Join-Path $stage 'docs'; if (Test-Path $docsDir) { Remove-Item $docsDir -Recurse -Force }

# --- 2) Zip (entrees en slash '/') ---
New-Item -ItemType Directory -Force -Path (Split-Path $outZip) | Out-Null
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
