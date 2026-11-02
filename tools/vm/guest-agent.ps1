<#
.SYNOPSIS
	Agent de tests dans la VM : surveille le dossier d'échange et exécute les tâches.

.DESCRIPTION
	Démarré à l'ouverture de session par la tâche planifiée « AutomotiveWorldAgent »
	(voir guest-setup.ps1), avec les droits LIMITÉS de l'utilisateur de la VM. Boucle :
	- écrit agent-heartbeat.json toutes les 5 s (l'hôte sait que la VM est prête) ;
	- prend une tâche jobs\<id>\job.ready en la renommant job.claimed (prise atomique) ;
	- copie la tâche en local, lance son job-runner.ps1, renvoie le rapport ;
	- écrit done.json en dernier.

	Écritures de l'agent, et seulement elles :
	- dossier d'échange (seul dossier partagé avec l'hôte, hors du dépôt) :
	  agent-heartbeat.json, jobs\<id>\job.claimed, jobs\<id>\report\, jobs\<id>\done.json ;
	- dans la VM : %LOCALAPPDATA%\AutomotiveWorldTests\ (copies de travail, journal, outil de capture).
	Il ne lit aucun mot de passe, ne contacte aucun service et ne modifie aucun réglage.
	La logique de test voyage avec chaque tâche (job-runner.ps1) : l'agent change rarement.
#>
param(
	[string]$Exchange = "\\vmware-host\Shared Folders\aw-vm-exchange",
	[string]$WorkRoot = (Join-Path $env:LOCALAPPDATA "AutomotiveWorldTests\work"),
	[int]$PollSec = 3,
	[switch]$Once
)

$ErrorActionPreference = "Continue"
$agentVersion = "2"
# Fichiers d'une tâche copiés en local (liste fermée).
$jobFiles = @("place.rbxl", "driver.luau", "job-runner.ps1", "job.json", "ScreenCapture.cs")
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
$logFile = Join-Path (Split-Path -Parent $WorkRoot) "agent.log"

function Write-Log([string]$message) {
	$line = "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $message
	Add-Content -Path $logFile -Value $line -Encoding UTF8
	Write-Host $line
}

function Write-JsonAtomic([string]$path, $object) {
	$tmp = "$path.tmp"
	$object | ConvertTo-Json -Depth 6 | Out-File -Encoding utf8 $tmp
	Move-Item -Force $tmp $path
}

function Invoke-Job([string]$jobDir) {
	$id = Split-Path -Leaf $jobDir
	$local = Join-Path $WorkRoot $id
	$reportShare = Join-Path $jobDir "report"
	$reportLocal = Join-Path $local "report"
	Write-Log "Tâche $id prise en charge"
	$started = Get-Date
	$code = -1
	$errorText = $null
	try {
		Remove-Item -Recurse -Force $local -ErrorAction SilentlyContinue
		New-Item -ItemType Directory -Force -Path $local | Out-Null
		foreach ($name in $jobFiles) {
			$source = Join-Path $jobDir $name
			if (Test-Path $source) { Copy-Item $source (Join-Path $local $name) -Force }
		}
		$job = Get-Content -Raw (Join-Path $local "job.json") | ConvertFrom-Json
		$runnerArgs = @(
			"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$(Join-Path $local 'job-runner.ps1')`"",
			"-JobDir", "`"$local`"", "-ReportDir", "`"$reportLocal`"", "-TimeoutSec", [string]$job.timeoutSec
		)
		if ($job.dryRun) { $runnerArgs += "-DryRun" }
		$p = Start-Process -FilePath "powershell.exe" -ArgumentList $runnerArgs -PassThru -Wait -WindowStyle Minimized
		$code = $p.ExitCode
		# Retour du rapport vers l'hôte.
		New-Item -ItemType Directory -Force -Path $reportShare | Out-Null
		Copy-Item -Recurse -Force (Join-Path $reportLocal "*") $reportShare
	} catch {
		$errorText = $_.Exception.Message
		Write-Log "Erreur tâche $id : $errorText"
	}
	Write-JsonAtomic (Join-Path $jobDir "done.json") ([pscustomobject]@{
		id = $id
		exitCode = $code
		error = $errorText
		seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
		guest = $env:COMPUTERNAME
		agentVersion = $agentVersion
	})
	Write-Log "Tâche $id terminée (code $code)"
}

Write-Log "Agent démarré (version $agentVersion), échange : $Exchange, travail : $WorkRoot"
$lastBeat = [datetime]::MinValue
while ($true) {
	if (Test-Path $Exchange) {
		if (((Get-Date) - $lastBeat).TotalSeconds -ge 5) {
			try {
				Write-JsonAtomic (Join-Path $Exchange "agent-heartbeat.json") ([pscustomobject]@{
					guest = $env:COMPUTERNAME; user = $env:USERNAME; at = (Get-Date).ToString("o")
					pid = $PID; agentVersion = $agentVersion; workRoot = $WorkRoot
				})
				$lastBeat = Get-Date
			} catch { Write-Log "Battement de cœur impossible : $($_.Exception.Message)" }
		}
		$jobsDir = Join-Path $Exchange "jobs"
		foreach ($ready in Get-ChildItem -Path $jobsDir -Filter "job.ready" -Recurse -Depth 1 -ErrorAction SilentlyContinue) {
			$claimed = Join-Path $ready.DirectoryName "job.claimed"
			try { Move-Item -Path $ready.FullName -Destination $claimed -ErrorAction Stop } catch { continue }
			Invoke-Job $ready.DirectoryName
		}
	}
	if ($Once) { break }
	Start-Sleep -Seconds $PollSec
}
