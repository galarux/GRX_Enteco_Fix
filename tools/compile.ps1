$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$extensionsRoot = Join-Path $env:USERPROFILE '.vscode\extensions'

$alExtension = Get-ChildItem $extensionsRoot -Directory |
    Where-Object { $_.Name -like 'ms-dynamics-smb.al-*' } |
    Sort-Object Name -Descending |
    Select-Object -First 1

if (-not $alExtension) {
    throw 'AL extension not found in VS Code extensions folder.'
}

$alcPath = Join-Path $alExtension.FullName 'bin\win32\alc.exe'
$packageCachePath = Join-Path $projectRoot '.alpackages'
$outPath = Join-Path $projectRoot 'output\GalaruxGantt-compiled.app'

& $alcPath /project:$projectRoot /packagecachepath:$packageCachePath /out:$outPath