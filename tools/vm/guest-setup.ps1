<#
.SYNOPSIS
	Préparation UNIQUE de la VM de test (à lancer DANS la VM, depuis le compte qui
	s'ouvre automatiquement, dans un PowerShell administrateur).

.DESCRIPTION
	- Refuse de s'exécuter hors d'une machine virtuelle VMware.
	- Copie l'agent dans C:\AWTests\agent et l'enregistre au démarrage de session
	  (tâche planifiée « AutomotiveWorldAgent », pour l'utilisateur courant).
	- Désactive la mise en veille et l'extinction d'écran DE LA VM (captures non noires).
	- Démarre l'agent immédiatement.
	Rien n'est installé : la place et le pilote sont construits sur l'hôte.
	Aucun mot de passe n'est lu ni stocké.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File "\\vmware-host\Shared Folders\roblox-automotive-world-starter\tools\vm\guest-setup.ps1"
#>
param(
	[string]$Exchange = "\\vmware-host\Shared Folders\roblox-automotive-world-starter\build\vm-exchange"
)

$ErrorActionPreference = "Stop"

$system = Get-CimInstance Win32_ComputerSystem
if ("$($system.Manufacturer) $($system.Model)" -notmatch "VMware") {
	throw "Ce script ne s'exécute que dans une machine virtuelle VMware (détecté : $($system.Manufacturer) $($system.Model))."
}
if (-not (Test-Path $Exchange)) {
	New-Item -ItemType Directory -Force -Path $Exchange | Out-Null
}

$agentDir = "C:\AWTests\agent"
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
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "Tâche planifiée « $taskName » enregistrée pour $user"

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

if (Get-ScheduledTask -TaskName "MimicHuntersAgent" -ErrorAction SilentlyContinue) {
	Write-Host "Note : la tâche « MimicHuntersAgent » d'un autre projet existe ; elle n'est pas modifiée."
}

Start-ScheduledTask -TaskName $taskName
Write-Host "Agent démarré. Vérification côté hôte : test-vm.cmd -NoVmControl"
