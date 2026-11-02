<#
.SYNOPSIS
	Préparation de la VM de test (à lancer DANS la VM, depuis le compte qui s'ouvre
	automatiquement, dans un PowerShell administrateur). Relançable sans risque.

.DESCRIPTION
	- Refuse de s'exécuter hors d'une machine virtuelle VMware.
	- Copie l'agent dans %LOCALAPPDATA%\AutomotiveWorldTests\agent et l'enregistre au démarrage
	  de session (tâche planifiée « AutomotiveWorldAgent », utilisateur courant, droits LIMITÉS).
	  Une ancienne tâche du même nom est remplacée (nouveau dossier d'échange).
	- Désactive la mise en veille et l'extinction d'écran DE LA VM (captures non noires).
	- Ne touche à AUCUNE autre tâche planifiée : les agents d'autres projets sont seulement
	  listés. Pour en arrêter et désactiver un (sans le supprimer), le nommer explicitement :
	  -StopTasks NomDeLaTache.
	- Ne modifie AUCUN réglage de sécurité (antivirus, pare-feu, comptes). Indique si une
	  ancienne exclusion Microsoft Defender « C:\AWTests » existe : elle n'est plus utilisée
	  par ce projet et peut être retirée par le propriétaire de la VM.
	- Démarre l'agent immédiatement.
	Rien n'est installé : la place et le pilote sont construits sur l'hôte.
	Aucun mot de passe n'est lu ni stocké.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File "\\vmware-host\Shared Folders\aw-vm-exchange\setup\guest-setup.ps1"
#>
param(
	[string]$Exchange = "\\vmware-host\Shared Folders\aw-vm-exchange",
	[string[]]$StopTasks = @()
)

$ErrorActionPreference = "Stop"

$system = Get-CimInstance Win32_ComputerSystem
if ("$($system.Manufacturer) $($system.Model)" -notmatch "VMware") {
	throw "Ce script ne s'exécute que dans une machine virtuelle VMware (détecté : $($system.Manufacturer) $($system.Model))."
}
if (-not (Test-Path $Exchange)) {
	throw "Dossier d'échange introuvable : $Exchange (dossier partagé « aw-vm-exchange » actif dans VMware ?)."
}

$baseDir = Join-Path $env:LOCALAPPDATA "AutomotiveWorldTests"
$agentDir = Join-Path $baseDir "agent"
New-Item -ItemType Directory -Force -Path $agentDir | Out-Null
$agent = Join-Path $agentDir "guest-agent.ps1"
Copy-Item (Join-Path $PSScriptRoot "guest-agent.ps1") $agent -Force
Write-Host "Agent copié : $agent"

$user = "$env:USERDOMAIN\$env:USERNAME"
$taskName = "AutomotiveWorldAgent"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
	-Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$agent`" -Exchange `"$Exchange`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries `
	-DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
# Arrêt de l'ancienne instance de NOTRE agent (version 1, lancée depuis C:\AWTests).
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
	Where-Object { $_.CommandLine -like "*guest-agent.ps1*" -and $_.ProcessId -ne $PID } |
	ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "Tâche planifiée « $taskName » enregistrée pour $user (droits limités), échange : $Exchange"

# Alimentation et écran de la VM uniquement.
foreach ($setting in @("monitor-timeout-ac", "standby-timeout-ac", "hibernate-timeout-ac")) {
	& powercfg /change $setting 0
}
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name ScreenSaveActive -Value "0"
Write-Host "Veille et extinction d'écran désactivées dans la VM"

$studio = Get-ChildItem (Join-Path $env:LOCALAPPDATA "Roblox\Versions") -Filter "RobloxStudioBeta.exe" -Recurse -ErrorAction SilentlyContinue |
	Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($studio) { Write-Host "Roblox Studio trouvé : $($studio.FullName)" }
else { Write-Warning "Roblox Studio introuvable pour ce compte : installe-le et connecte-toi avant les tests." }

# Autres agents : listés, jamais modifiés sans demande explicite (-StopTasks).
$others = @(Get-ScheduledTask -ErrorAction SilentlyContinue |
		Where-Object { $_.TaskName -like "*Agent*" -and $_.TaskName -ne $taskName -and $_.TaskPath -eq "\" })
foreach ($other in $others) {
	if ($StopTasks -contains $other.TaskName) {
		Stop-ScheduledTask -TaskName $other.TaskName -ErrorAction SilentlyContinue
		Disable-ScheduledTask -TaskName $other.TaskName | Out-Null
		Write-Host "Tâche « $($other.TaskName) » arrêtée et désactivée à ta demande (réactivable : Enable-ScheduledTask -TaskName $($other.TaskName))."
	} else {
		Write-Host "Autre agent présent, laissé tel quel : « $($other.TaskName) » (état : $($other.State))."
	}
}

# Exclusion Defender de l'ancienne version : signalée, jamais modifiée ici.
try {
	$exclusions = @((Get-MpPreference).ExclusionPath)
	if ($exclusions -contains "C:\AWTests") {
		Write-Host ("Exclusion Microsoft Defender « C:\AWTests » encore présente : ce projet ne l'utilise plus " +
			"(captures par un outil compilé hors de ce dossier). Pour la retirer : Remove-MpPreference -ExclusionPath 'C:\AWTests'")
	}
} catch {
	Write-Host "Exclusions Defender non lisibles (PowerShell non administrateur ?) : rien à faire pour ce projet."
}

Start-ScheduledTask -TaskName $taskName
Write-Host "Agent démarré. Vérification côté hôte : test-vm.cmd -NoVmControl -DryRun"
