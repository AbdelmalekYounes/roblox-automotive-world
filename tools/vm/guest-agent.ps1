<#
.SYNOPSIS
	Agent de tests dans la VM : surveille le dossier d'échange et exécute les tâches.

.DESCRIPTION
	Démarré à l'ouverture de session par la tâche planifiée « AutomotiveWorldAgent »
	(voir guest-setup.ps1). Boucle :
	- écrit agent-heartbeat.json toutes les 5 s (l'hôte sait que la VM est prête) ;
	- prend une tâche jobs\<id>\job.ready en la renommant job.claimed (prise atomique) ;
	- copie la tâche en local, lance son job-runner.ps1, renvoie le rapport ;
	- écrit done.json en dernier.
	La logique de test voyage avec chaque tâche (job-runner.ps1) : l'agent change rarement.
	Il ne lit aucun mot de passe et ne contacte aucun service.
#>
param(
	[string]$Exchange = "\\vmware-host\Shared Folders\roblox-automotive-world-starter\build\vm-exchange",
	[string]$WorkRoot = "C:\AWTests\work",
	[int]$PollSec = 3,
	[switch]$Once
)

$ErrorActionPreference = "Continue"
$agentVersion = "1"
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
		foreach ($name in @("place.rbxl", "driver.luau", "job-runner.ps1", "job.json", "capture-screens.ps1")) {
			$source = Join-Path $jobDir $name
			if (Test-Path $source) { Copy-Item $source (Join-Path $local $name) -Force }
		}
		$job = Get-Content -Raw (Join-Path $local "job.json") | ConvertFrom-Json
		$runnerArgs = @(
			"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $local "job-runner.ps1"),
			"-JobDir", $local, "-ReportDir", $reportLocal, "-TimeoutSec", [string]$job.timeoutSec
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

Write-Log "Agent démarré (version $agentVersion), échange : $Exchange"
$lastBeat = [datetime]::MinValue
while ($true) {
	if (Test-Path $Exchange) {
		if (((Get-Date) - $lastBeat).TotalSeconds -ge 5) {
			try {
				Write-JsonAtomic (Join-Path $Exchange "agent-heartbeat.json") ([pscustomobject]@{
					guest = $env:COMPUTERNAME; user = $env:USERNAME; at = (Get-Date).ToString("o")
					pid = $PID; agentVersion = $agentVersion
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
