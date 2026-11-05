<#
.SYNOPSIS
	Lance les tests Roblox Studio dans la VM VMware, sans rien afficher sur ton bureau
	et sans utiliser ta souris ni ton clavier.

.DESCRIPTION
	1. Vérifie que la VM tourne (la démarre sans fenêtre si elle n'est pas chiffrée) et
	   signale tout dossier partagé qui exposerait le dépôt à la VM.
	2. Attend le battement de cœur de l'agent de la VM.
	3. Construit la place (Rojo) et le pilote de tests (Lune) dans une tâche du dossier
	   d'échange, situé HORS du dépôt (par défaut ..\aw-vm-exchange) : la VM ne voit et
	   n'écrit que ce dossier.
	4. Attend done.json, puis écrit le rapport (report.md) et une copie dans
	   build\test-reports\latest-vm.md. Les fichiers renvoyés par la VM sont lus comme des
	   DONNÉES : l'hôte n'exécute jamais rien qui provienne du dossier d'échange.
	vmrun ne sert qu'à démarrer/lister/suspendre la VM : aucun identifiant n'est utilisé.
	Aucune place n'est publiée : Studio ouvre un fichier local, en mode script.

.EXAMPLE
	test-vm.cmd
	test-vm.cmd -Sessions solo
	test-vm.cmd -NoVmControl -DryRun      (test du protocole, sans Studio)
	test-vm.cmd -Place OpenWorld -Sessions monde   (place monde ouvert, lot 0.3)
#>
param(
	[string]$Vmx,
	[string]$Exchange,
	[ValidateSet("Dev", "OpenWorld")]
	[string]$Place = "Dev",
	[string[]]$Sessions = @("solo", "multijoueur", "latence", "scenarios", "collision", "collision_latence", "lot02"),
	[int]$TimeoutSec = 1500,
	[int]$AgentWaitSec = 240,
	[switch]$NoVmControl,
	[switch]$Suspend,
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $Root
$configPath = Join-Path $Root "build\vm-config.json"
$config = if (Test-Path $configPath) { Get-Content -Raw $configPath | ConvertFrom-Json } else { $null }
if (-not $Exchange -and $config -and $config.exchange) { $Exchange = $config.exchange }
if (-not $Exchange) { $Exchange = Join-Path (Split-Path -Parent $Root) "aw-vm-exchange" }
$exchange = [IO.Path]::GetFullPath($Exchange)
$jobsDir = Join-Path $exchange "jobs"
New-Item -ItemType Directory -Force -Path $jobsDir | Out-Null

# Scripts d'installation publiés dans le dossier d'échange (lecture par la VM).
$setupDir = Join-Path $exchange "setup"
New-Item -ItemType Directory -Force -Path $setupDir | Out-Null
foreach ($name in @("guest-setup.ps1", "guest-agent.ps1")) {
	Copy-Item (Join-Path $PSScriptRoot $name) (Join-Path $setupDir $name) -Force
}

# Dossiers partagés déclarés dans le .vmx : aucun ne doit contenir le dépôt.
function Test-SharedFolders([string]$vmxPath) {
	$repo = [IO.Path]::GetFullPath($Root).TrimEnd("\") + "\"
	foreach ($line in Get-Content $vmxPath) {
		if ($line -match '^sharedFolder\d+\.hostPath\s*=\s*"(.*)"') {
			$shared = [IO.Path]::GetFullPath($Matches[1]).TrimEnd("\") + "\"
			if ($repo.StartsWith($shared, [StringComparison]::OrdinalIgnoreCase)) {
				Write-Warning ("Le dossier partagé « $($Matches[1]) » expose le dépôt à la VM (écriture possible). " +
					"Voir tools\vm\configure-share.ps1 et docs\VM_TESTS.md.")
			}
		}
	}
}

function Find-Vmrun {
	foreach ($candidate in @(
			"${env:ProgramFiles(x86)}\VMware\VMware Workstation\vmrun.exe",
			"$env:ProgramFiles\VMware\VMware Workstation\vmrun.exe")) {
		if (Test-Path $candidate) { return $candidate }
	}
	return $null
}

# 1. VM
$startedByUs = $false
$vmrun = $null
if (-not $NoVmControl) {
	$vmrun = Find-Vmrun
	if (-not $vmrun) { throw "vmrun.exe introuvable : VMware Workstation est-il installé ?" }
	if (-not $Vmx -and $config) { $Vmx = $config.vmx }
	if (-not $Vmx) { $Vmx = "E:\VMS\ROBLOX DEV\ROBLOX DEV.vmx" }
	if (-not (Test-Path $Vmx)) { throw "Fichier .vmx introuvable : $Vmx (option -Vmx)." }
	[pscustomobject]@{ vmx = $Vmx; exchange = $exchange } | ConvertTo-Json | Out-File -Encoding utf8 $configPath
	Test-SharedFolders $Vmx

	$running = (& $vmrun -T ws list) -join "`n"
	if ($running -notmatch [regex]::Escape($Vmx)) {
		if (Select-String -Path $Vmx -Pattern '^encryption\.keySafe' -Quiet) {
			throw ("La VM est chiffrée (TPM virtuel) : vmrun ne peut pas la démarrer sans son mot de passe, " +
				"qui n'est jamais stocké ici. Démarre-la une fois dans VMware Workstation, puis ferme la fenêtre " +
				"de Workstation en choisissant « Run in Background », et relance test-vm.cmd.")
		}
		Write-Host "Démarrage de la VM sans fenêtre…"
		& $vmrun -T ws start $Vmx nogui
		if ($LASTEXITCODE -ne 0) { throw "vmrun start a échoué (code $LASTEXITCODE)." }
		$startedByUs = $true
	} else {
		Write-Host "VM déjà démarrée."
	}
}

# 2. Agent de la VM
$heartbeat = Join-Path $exchange "agent-heartbeat.json"
$deadline = (Get-Date).AddSeconds($AgentWaitSec)
$agentOk = $false
Write-Host "Attente de l'agent de la VM…"
while ((Get-Date) -lt $deadline) {
	if (Test-Path $heartbeat) {
		$age = ((Get-Date) - (Get-Item $heartbeat).LastWriteTime).TotalSeconds
		if ($age -lt 30) { $agentOk = $true; break }
	}
	Start-Sleep -Seconds 3
}
if (-not $agentOk) {
	throw ("L'agent de la VM ne répond pas (aucun battement de cœur récent dans $heartbeat). " +
		"Vérifier : session Windows ouverte automatiquement dans la VM, dossier partagé « aw-vm-exchange » " +
		"actif ($exchange), et préparation faite dans la VM (setup\guest-setup.ps1, voir docs/VM_TESTS.md).")
}
$beat = Get-Content -Raw $heartbeat | ConvertFrom-Json
Write-Host "Agent prêt : invité $($beat.guest), utilisateur $($beat.user), version $($beat.agentVersion)."

# 3. Tâche
$id = Get-Date -Format "yyyyMMdd-HHmmss"
$jobDir = Join-Path $jobsDir $id
New-Item -ItemType Directory -Force -Path $jobDir | Out-Null
if ($Place -eq "OpenWorld") {
	# Lot 0.3 : carte générée hors ligne, puis place monde ouvert (StreamingEnabled).
	& rojo build -o "build\AutomotiveWorld.rbxlx"
	if ($LASTEXITCODE -ne 0) { throw "rojo build a échoué." }
	& lune run tools/world/build-world.luau "build\AutomotiveWorld.rbxlx" "build\world\OpenWorld.rbxm"
	if ($LASTEXITCODE -ne 0) { throw "La génération de la carte a échoué." }
	& rojo build openworld.project.json -o (Join-Path $jobDir "place.rbxl")
} else {
	& rojo build -o (Join-Path $jobDir "place.rbxl")
}
if ($LASTEXITCODE -ne 0) { throw "rojo build a échoué." }
& lune run tests/studio/build-driver.luau (Join-Path $jobDir "driver.luau") ($Sessions -join ",")
if ($LASTEXITCODE -ne 0) { throw "La génération du pilote de tests a échoué." }
Copy-Item (Join-Path $PSScriptRoot "job-runner.ps1") (Join-Path $jobDir "job-runner.ps1")
Copy-Item (Join-Path $PSScriptRoot "ScreenCapture.cs") (Join-Path $jobDir "ScreenCapture.cs")
$commit = (& git rev-parse --short HEAD 2>$null)
[pscustomobject]@{
	id = $id; sessions = $Sessions; place = $Place; timeoutSec = $TimeoutSec; dryRun = [bool]$DryRun
	commit = $commit; createdAt = (Get-Date).ToString("o")
} | ConvertTo-Json | Out-File -Encoding utf8 (Join-Path $jobDir "job.json")
New-Item -ItemType File -Path (Join-Path $jobDir "job.ready") | Out-Null
Write-Host "Tâche $id déposée (place $Place, sessions : $($Sessions -join ', '), commit $commit)."

# 4. Résultat
$done = Join-Path $jobDir "done.json"
$deadline = (Get-Date).AddSeconds($TimeoutSec + 120)
$claimedSeen = $false
while (-not (Test-Path $done)) {
	if ((Get-Date) -gt $deadline) { throw "Pas de résultat après $($TimeoutSec + 120) s (tâche $id)." }
	if (-not $claimedSeen -and (Test-Path (Join-Path $jobDir "job.claimed"))) {
		$claimedSeen = $true
		Write-Host "Tâche prise en charge par la VM, tests en cours…"
	}
	Start-Sleep -Seconds 3
}
$doneInfo = Get-Content -Raw $done | ConvertFrom-Json
$reportDir = Join-Path $jobDir "report"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Force -Path $reportDir | Out-Null }
$summary = & (Join-Path $PSScriptRoot "make-report.ps1") -ReportDir $reportDir -JobId $id
$latestDir = Join-Path $Root "build\test-reports"
New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
Copy-Item (Join-Path $reportDir "report.md") (Join-Path $latestDir "latest-vm.md") -Force

if ($Suspend -and $startedByUs) {
	Write-Host "Mise en veille de la VM…"
	& $vmrun -T ws suspend $Vmx | Out-Null
}

Write-Host ""
Write-Host ("Résultat VM : code agent {0}, {1} réussi(s), {2} échec(s), {3} limite(s) connue(s), {4} session(s), terminé={5}" -f `
		$doneInfo.exitCode, $summary.Passed, $summary.Failed, $summary.Known, $summary.Sessions, $summary.Complete)
if ($doneInfo.error) { Write-Host "Erreur agent : $($doneInfo.error)" -ForegroundColor Red }
Write-Host "Rapport : $(Join-Path $reportDir 'report.md')"
if ($summary.Failed -gt 0 -or -not $summary.Complete -or $doneInfo.exitCode -ne 0) { exit 1 }
exit 0
