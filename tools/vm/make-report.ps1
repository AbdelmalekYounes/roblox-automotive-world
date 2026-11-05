<#
.SYNOPSIS
	Transforme la sortie d'une tâche VM (lignes « @@AW@@ {json} », result.json) en rapport Markdown.

.OUTPUTS
	Écrit report.md dans ReportDir et renvoie un objet { Passed; Failed; Sessions; Complete }.
#>
param(
	[Parameter(Mandatory = $true)][string]$ReportDir,
	[string]$JobId = ""
)

$ErrorActionPreference = "Stop"
$outputLog = Join-Path $ReportDir "studio-output.log"
$resultFile = Join-Path $ReportDir "result.json"
$lines = New-Object System.Collections.Generic.List[string]
$passed = 0; $failed = 0; $known = 0; $sessionCount = 0; $complete = $false

function Add-Line([string]$text) { $lines.Add($text) }
function Format-Detail($detail) {
	if ($null -eq $detail) { return "" }
	return ([string]$detail).Replace("|", "\|").Replace("`r", " ").Replace("`n", " ")
}
function Add-Steps($steps) {
	Add-Line "| Résultat | Contrôle | Détail |"
	Add-Line "|---|---|---|"
	foreach ($step in @($steps)) {
		if ($null -eq $step) { continue }
		$detail = Format-Detail $step.detail
		if ($step.ok) { $script:passed++; $mark = "✅" }
		elseif ($step.known) { $script:known++; $mark = "⚠️"; $detail = "$detail — **limite connue** : $(Format-Detail $step.known)" }
		else { $script:failed++; $mark = "❌" }
		Add-Line ("| {0} | ``{1}`` | {2} |" -f $mark, $step.name, $detail)
	}
	Add-Line ""
}

Add-Line "# Rapport de tests Roblox Studio (VM) $JobId"
Add-Line ""
Add-Line "_Généré automatiquement à partir de la sortie réelle de Studio. Chaque ligne correspond à une observation faite dans le moteur Roblox pendant la session indiquée._"
Add-Line ""

if (Test-Path $resultFile) {
	$run = Get-Content -Raw $resultFile | ConvertFrom-Json
	Add-Line "| Exécution | Valeur |"
	Add-Line "|---|---|"
	Add-Line "| Studio | $($run.studio) |"
	Add-Line "| Machine invitée / écran | $($run.guest) / $($run.screen) |"
	Add-Line "| Durée | $($run.seconds) s |"
	Add-Line "| Délai dépassé | $($run.timedOut) |"
	Add-Line "| Captures d'écran | $($run.screenshots) (dossier screenshots) — état : $($run.captures) |"
	if ($run.dryRun) { Add-Line "| **Mode** | **DryRun : sortie factice, AUCUN test Studio réel** |" }
	Add-Line ""
}

$events = @()
if (Test-Path $outputLog) {
	# Erreurs Luau du pilote ou des sessions : ligne de message suivie de « Stack Begin ».
	$all = @(Get-Content -Encoding UTF8 $outputLog)
	$scriptErrors = @()
	for ($i = 1; $i -lt $all.Count; $i++) {
		if ($all[$i] -eq "Stack Begin") { $scriptErrors += ($all[$i - 1] + " " + ($all[$i + 1] -replace "^Script ", "")) }
	}
	if ($scriptErrors.Count -gt 0) {
		$failed += $scriptErrors.Count
		Add-Line "### ❌ Erreurs de script dans la sortie Studio"
		foreach ($e in $scriptErrors) { Add-Line ("- ``{0}``" -f $e) }
		Add-Line ""
	}
}
if (Test-Path $outputLog) {
	foreach ($raw in Get-Content -Encoding UTF8 $outputLog) {
		$index = $raw.IndexOf("@@AW@@ ")
		if ($index -lt 0) { continue }
		try { $events += ($raw.Substring($index + 7) | ConvertFrom-Json) } catch { }
	}
} else {
	Add-Line "**Aucune sortie Studio (studio-output.log absent).**"
}

foreach ($event in $events) {
	switch ($event.kind) {
		"start" { Add-Line "Version Roblox : ``$($event.data.studio)``"; Add-Line "" }
		"end" { $complete = $true }
		"session" {
			$sessionCount++
			$s = $event.data
			Add-Line ("## Session « {0} »" -f $s.name)
			Add-Line ""
			$latency = if ($s.delayMs) { " ; latence demandée $($s.delayMs) ms (réglage appliqué : $($s.delayApplied))" } else { "" }
			Add-Line ("Durée {0:N1} s, tentatives {1}{2}" -f [double]$s.seconds, $s.attempts, $latency)
			Add-Line ""
			if (-not $s.ok -or $null -eq $s.result -or $s.result -is [string]) {
				$script:failed++
				Add-Line ("❌ Session sans résultat : {0}" -f (Format-Detail $s.result))
				Add-Line ""
				continue
			}
			Add-Line "### Serveur"
			Add-Steps $s.result.server
			$clients = $s.result.clients
			if ($clients) {
				foreach ($property in $clients.PSObject.Properties) {
					$client = $property.Value
					Add-Line ("### Client {0} — {1}" -f $property.Name, $client.vehicle)
					Add-Steps $client.steps
					if ($client.measures) {
						Add-Line "| Mesure (moteur Roblox) | Valeur |"
						Add-Line "|---|---|"
						foreach ($m in $client.measures.PSObject.Properties) {
							$value = if ($m.Value -is [double]) { "{0:N2}" -f $m.Value } else { [string]$m.Value }
							Add-Line "| $($m.Name) | $value |"
						}
						Add-Line ""
					}
				}
			} else {
				$script:failed++
				Add-Line "❌ Aucun rapport client reçu."
				Add-Line ""
			}
		}
	}
}

if (-not $complete) {
	$failed++
	Add-Line "❌ **Le pilote ne s'est pas terminé** (pas de ligne « end ») : voir studio-output.log, studio-logs et les captures."
	Add-Line ""
}
Add-Line ("**Synthèse : {0} contrôle(s) réussi(s), {1} échec(s), {2} limite(s) connue(s) ⚠️, {3} session(s).**" -f $passed, $failed, $known, $sessionCount)
Add-Line ""
Add-Line "Non couvert automatiquement : lecture réelle du clavier et de la manette (commandes injectées par le point d'accès de test), ressenti de conduite, lisibilité, son. Voir les captures pour le rendu."

[IO.File]::WriteAllLines((Join-Path $ReportDir "report.md"), $lines, (New-Object Text.UTF8Encoding $true))
[pscustomobject]@{ Passed = $passed; Failed = $failed; Known = $known; Sessions = $sessionCount; Complete = $complete }
