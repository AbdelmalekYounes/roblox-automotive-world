<#
.SYNOPSIS
	Restreint le partage hôte → VM au seul dossier d'échange des tests (hors du dépôt).

.DESCRIPTION
	Sans -Apply : affiche les dossiers partagés actuels de la VM et ce qui serait fait.
	Avec -Apply (VM démarrée, VMware Tools actifs), via vmrun et sans aucun identifiant :
	1. crée le dossier d'échange s'il n'existe pas et y publie setup\ (scripts de la VM) ;
	2. partage ce dossier avec la VM sous le nom « aw-vm-exchange » (lecture/écriture :
	   la VM doit y déposer ses rapports) ;
	3. avec -RemoveRepoShare, retire le partage « roblox-automotive-world-starter » qui
	   donnait à la VM un accès en écriture à TOUT le dépôt.
	Ensuite, dans la VM, relancer une fois (PowerShell administrateur) :
	  powershell -ExecutionPolicy Bypass -File "\\vmware-host\Shared Folders\aw-vm-exchange\setup\guest-setup.ps1"
	(host-run.ps1 publie ce script dans le dossier d'échange à chaque exécution).
	Ce script ne modifie que la configuration des dossiers partagés de cette VM.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\vm\configure-share.ps1
	powershell -ExecutionPolicy Bypass -File tools\vm\configure-share.ps1 -Apply -RemoveRepoShare
#>
param(
	[string]$Vmx = "E:\VMS\ROBLOX DEV\ROBLOX DEV.vmx",
	[string]$Exchange,
	[string]$ShareName = "aw-vm-exchange",
	[string]$RepoShareName = "roblox-automotive-world-starter",
	[switch]$RemoveRepoShare,
	[switch]$Apply
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $Exchange) { $Exchange = Join-Path (Split-Path -Parent $Root) "aw-vm-exchange" }
$Exchange = [IO.Path]::GetFullPath($Exchange)
if ($Exchange.StartsWith([IO.Path]::GetFullPath($Root), [StringComparison]::OrdinalIgnoreCase)) {
	throw "Le dossier d'échange doit être HORS du dépôt : $Exchange"
}

$vmrun = @("${env:ProgramFiles(x86)}\VMware\VMware Workstation\vmrun.exe",
	"$env:ProgramFiles\VMware\VMware Workstation\vmrun.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $vmrun) { throw "vmrun.exe introuvable." }
if (-not (Test-Path $Vmx)) { throw "Fichier .vmx introuvable : $Vmx" }

Write-Host "Dossiers partagés actuels ($Vmx) :"
Get-Content $Vmx | Where-Object { $_ -match '^sharedFolder\d+\.(guestName|hostPath|writeAccess)' } | ForEach-Object { Write-Host "  $_" }
Write-Host ""
Write-Host "Prévu : partager « $Exchange » sous « $ShareName »."
if ($RemoveRepoShare) { Write-Host "Prévu : retirer le partage « $RepoShareName » (dépôt)." }
if (-not $Apply) {
	Write-Host "Aucune modification (ajouter -Apply pour appliquer)."
	exit 0
}

New-Item -ItemType Directory -Force -Path $Exchange | Out-Null
# Scripts d'installation à lancer ensuite dans la VM.
$setupDir = Join-Path $Exchange "setup"
New-Item -ItemType Directory -Force -Path $setupDir | Out-Null
foreach ($name in @("guest-setup.ps1", "guest-agent.ps1")) {
	Copy-Item (Join-Path $PSScriptRoot $name) (Join-Path $setupDir $name) -Force
}
& $vmrun -T ws enableSharedFolders $Vmx | Out-Null
& $vmrun -T ws addSharedFolder $Vmx $ShareName $Exchange
if ($LASTEXITCODE -ne 0) { throw "vmrun addSharedFolder a échoué (code $LASTEXITCODE). La VM est-elle démarrée ?" }
& $vmrun -T ws setSharedFolderState $Vmx $ShareName $Exchange writable
if ($RemoveRepoShare) {
	& $vmrun -T ws removeSharedFolder $Vmx $RepoShareName
	if ($LASTEXITCODE -ne 0) { Write-Warning "Retrait du partage « $RepoShareName » : code $LASTEXITCODE." }
}
Write-Host ""
Write-Host "Dossiers partagés après modification :"
Get-Content $Vmx | Where-Object { $_ -match '^sharedFolder\d+\.(guestName|hostPath|writeAccess)' } | ForEach-Object { Write-Host "  $_" }
