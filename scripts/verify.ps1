# Vérifications locales NON INTRUSIVES du projet (Windows PowerShell 5.1+).
# Aucune fenêtre n'est ouverte, Roblox Studio n'est pas lancé, aucun service
# en ligne n'est contacté (sauf -DownloadRobloxTypes, explicite).
#
# Usage, depuis la racine du dépôt :
#   powershell -ExecutionPolicy Bypass -File scripts\verify.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -RobloxTypes C:\chemin\globalTypes.d.luau
#   powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -DownloadRobloxTypes

param(
    [string]$RobloxTypes = "",
    [switch]$DownloadRobloxTypes
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
New-Item -ItemType Directory -Force "build" | Out-Null

$results = New-Object System.Collections.ArrayList

function Invoke-Step([string]$name, [scriptblock]$block) {
    Write-Host ""
    Write-Host "=== $name ===" -ForegroundColor Cyan
    & $block
    $ok = ($LASTEXITCODE -eq 0)
    [void]$results.Add([pscustomobject]@{ Etape = $name; Resultat = $(if ($ok) { "OK" } else { "ECHEC ($LASTEXITCODE)" }) })
}

Invoke-Step "Rojo build" { rojo build -o build\AutomotiveWorld.rbxlx }
Invoke-Step "Selene (lint Roblox)" { selene src tests\studio\ServerSuite.server.luau tests\studio\ClientSuite.client.luau tests\studio\ScenarioServer.server.luau tests\studio\ScenarioClient.client.luau tests\studio\Driver.template.luau }
Invoke-Step "Pilote Studio (génération + compilation)" { lune run tests/studio/build-driver.luau build\driver-check.luau }
Invoke-Step "StyLua (format)" { stylua --check src tests\lune tests\studio }
Invoke-Step "Lune (tests hors Studio)" { lune run tests\lune\run.luau build\AutomotiveWorld.rbxlx }
Invoke-Step "Pytest (contrôles statiques)" { python -m pytest -q tests }

# Analyse de types complète : nécessite les définitions Roblox officielles de luau-lsp.
if ($DownloadRobloxTypes) {
    New-Item -ItemType Directory -Force ".tooling" | Out-Null
    $RobloxTypes = Join-Path $root ".tooling\globalTypes.d.luau"
    $url = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau"
    Write-Host "Téléchargement des définitions de types : $url"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $RobloxTypes
}
if ($RobloxTypes -ne "" -and (Test-Path $RobloxTypes)) {
    Invoke-Step "luau-lsp (typage strict)" {
        rojo sourcemap default.project.json -o sourcemap.json
        luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json "--definitions=@roblox=$RobloxTypes" src
    }
} else {
    Write-Host ""
    Write-Host "luau-lsp ignoré : fournir -RobloxTypes <globalTypes.d.luau> ou -DownloadRobloxTypes." -ForegroundColor Yellow
    [void]$results.Add([pscustomobject]@{ Etape = "luau-lsp (typage strict)"; Resultat = "NON EXÉCUTÉ" })
}

Write-Host ""
Write-Host "=== Synthèse ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize
if ($results | Where-Object { $_.Resultat -like "ECHEC*" }) { exit 1 }
exit 0
