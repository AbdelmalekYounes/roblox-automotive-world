<#
.SYNOPSIS
	Exécute UNE tâche de test Roblox Studio dans la VM (copié dans chaque tâche par l'hôte).

.DESCRIPTION
	Lancé par guest-agent.ps1 dans la session Windows de la VM :
	1. Trouve Roblox Studio (version la plus récente installée).
	2. Lance Studio en mode script :
	   --task RunScript --localPlaceFile place.rbxl --runScriptFile driver.luau
	   --outputFile studio-output.log --quitAfterExecution
	   (l'extension .log du fichier de sortie est obligatoire).
	3. Démarre en parallèle, si possible, les captures d'écran (capture-screens.ps1).
	4. Au-delà du délai, n'arrête QUE les processus Studio lancés par ce script.
	5. Dépose sortie, journaux Studio, captures et result.json dans ReportDir.

	Aucune entrée clavier/souris n'est simulée. -DryRun remplace Studio par une
	sortie factice et ne capture pas l'écran (test du protocole, y compris sur l'hôte).
#>
param(
	[Parameter(Mandatory = $true)][string]$JobDir,
	[Parameter(Mandatory = $true)][string]$ReportDir,
	[int]$TimeoutSec = 1200,
	[double]$ShotIntervalSec = 2,
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
$shotsDir = Join-Path $ReportDir "screenshots"
New-Item -ItemType Directory -Force -Path $shotsDir | Out-Null

function Find-Studio {
	$versions = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
	$candidates = Get-ChildItem -Path $versions -Filter "RobloxStudioBeta.exe" -Recurse -ErrorAction SilentlyContinue |
		Sort-Object LastWriteTime -Descending
	if ($candidates) { return $candidates[0].FullName }
	return $null
}

function Get-Descendants([int]$parentId) {
	$all = Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId
	$result = New-Object System.Collections.Generic.List[int]
	$queue = New-Object System.Collections.Generic.Queue[int]
	$queue.Enqueue($parentId)
	while ($queue.Count -gt 0) {
		$id = $queue.Dequeue()
		foreach ($p in $all | Where-Object { $_.ParentProcessId -eq $id }) {
			$result.Add([int]$p.ProcessId)
			$queue.Enqueue([int]$p.ProcessId)
		}
	}
	return $result
}

$place = Join-Path $JobDir "place.rbxl"
$driver = Join-Path $JobDir "driver.luau"
$outputLog = Join-Path $JobDir "studio-output.log"
$started = Get-Date
$studio = $null
$timedOut = $false
$exitCode = $null
$captureStatus = "non demandées"

if ($DryRun) {
	# Sortie factice au même format que Studio (protocole uniquement).
	$fake = @(
		'@@AW@@ {"kind":"start","data":{"studio":"dry-run","sessions":[{"Name":"solo","Players":1}]}}',
		'@@AW@@ {"kind":"session","data":{"name":"solo","ok":true,"attempts":1,"seconds":1.5,"result":{"session":"solo","players":1,"server":[{"name":"serveur.zone_creee","ok":true,"detail":"factice"}],"clients":{"-1":{"vehicle":"VehiculeEssai_1","steps":[{"name":"client.demarrage","ok":true}],"measures":{"zero_a_cent_s":9.1}}}}}}',
		'@@AW@@ {"kind":"end","data":{}}'
	)
	[IO.File]::WriteAllLines($outputLog, $fake, (New-Object Text.UTF8Encoding $false))
	$exitCode = 0
	$captureStatus = "désactivées (DryRun)"
} else {
	$studio = Find-Studio
	if (-not $studio) { throw "Roblox Studio introuvable dans $env:LOCALAPPDATA\Roblox\Versions" }

	# Captures d'écran dans un processus séparé et facultatif.
	$stopFile = Join-Path $JobDir "capture.stop"
	$captureErr = Join-Path $JobDir "capture-stderr.txt"
	$captureScript = Join-Path $JobDir "capture-screens.ps1"
	$capture = $null
	if (Test-Path $captureScript) {
		$capture = Start-Process -FilePath "powershell.exe" -WindowStyle Hidden -PassThru `
			-RedirectStandardError $captureErr `
			-ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$captureScript`"",
			"-OutDir", "`"$shotsDir`"", "-StopFile", "`"$stopFile`"", "-IntervalSec", [string]$ShotIntervalSec)
	}

	$arguments = @(
		"--task", "RunScript",
		"--localPlaceFile", "`"$place`"",
		"--runScriptFile", "`"$driver`"",
		"--outputFile", "`"$outputLog`"",
		"--quitAfterExecution"
	)
	$process = Start-Process -FilePath $studio -ArgumentList $arguments -PassThru
	$launchedIds = New-Object System.Collections.Generic.HashSet[int]
	[void]$launchedIds.Add($process.Id)
	while (-not $process.HasExited) {
		foreach ($child in Get-Descendants $process.Id) { [void]$launchedIds.Add($child) }
		if (((Get-Date) - $started).TotalSeconds -gt $TimeoutSec) {
			$timedOut = $true
			# On n'arrête que les processus lancés par ce script (et leurs enfants).
			foreach ($id in $launchedIds) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
			break
		}
		Start-Sleep -Milliseconds 500
	}
	if ($process.HasExited) { $exitCode = $process.ExitCode }
	# Les clients du test multijoueur peuvent survivre quelques secondes.
	Start-Sleep -Seconds 2
	foreach ($id in $launchedIds) {
		$p = Get-Process -Id $id -ErrorAction SilentlyContinue
		if ($p -and $p.ProcessName -like "RobloxStudio*") { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
	}

	if ($capture) {
		New-Item -ItemType File -Force -Path $stopFile | Out-Null
		if (-not $capture.WaitForExit(10000)) { Stop-Process -Id $capture.Id -Force -ErrorAction SilentlyContinue }
		$stderr = if (Test-Path $captureErr) { Get-Content -Raw $captureErr } else { "" }
		if ($stderr -match "malveillant|malicious|antivirus") { $captureStatus = "bloquées par l'antivirus de la VM" }
		elseif ($stderr) { $captureStatus = "échec : " + ($stderr -split "`n")[0] }
		else { $captureStatus = "ok" }
	} else {
		$captureStatus = "script de capture absent"
	}
}

# Sortie et journaux Studio produits pendant la tâche.
if (Test-Path $outputLog) { Copy-Item $outputLog (Join-Path $ReportDir "studio-output.log") -Force }
$logsDir = Join-Path $env:LOCALAPPDATA "Roblox\logs"
if ((-not $DryRun) -and (Test-Path $logsDir)) {
	$studioLogs = Join-Path $ReportDir "studio-logs"
	New-Item -ItemType Directory -Force -Path $studioLogs | Out-Null
	Get-ChildItem $logsDir -File -ErrorAction SilentlyContinue |
		Where-Object { $_.LastWriteTime -ge $started.AddSeconds(-5) } |
		Sort-Object LastWriteTime -Descending | Select-Object -First 8 |
		ForEach-Object { Copy-Item $_.FullName $studioLogs -Force -ErrorAction SilentlyContinue }
}

$result = [pscustomobject]@{
	studio = $studio
	dryRun = [bool]$DryRun
	exitCode = $exitCode
	timedOut = $timedOut
	seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
	screenshots = @(Get-ChildItem $shotsDir -Filter *.jpg -ErrorAction SilentlyContinue).Count
	captures = $captureStatus
	guest = $env:COMPUTERNAME
}
$result | ConvertTo-Json | Out-File -Encoding utf8 (Join-Path $ReportDir "result.json")
if ($timedOut) { exit 3 }
exit 0
