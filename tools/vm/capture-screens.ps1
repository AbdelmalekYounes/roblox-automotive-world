<#
.SYNOPSIS
	Captures d'écran périodiques DE LA VM pendant une tâche de test (optionnel).

.DESCRIPTION
	Lancé par job-runner.ps1 dans un processus séparé. S'arrête quand le fichier
	StopFile apparaît ou après MaxShots captures. Écrit des JPEG réduits de moitié.
	Windows Defender peut bloquer ce script (capture d'écran depuis PowerShell) :
	dans ce cas les tests se déroulent quand même et le rapport l'indique.
	Ne jamais l'exécuter sur un poste de travail : il capture l'écran entier.
#>
param(
	[Parameter(Mandatory = $true)][string]$OutDir,
	[Parameter(Mandatory = $true)][string]$StopFile,
	[double]$IntervalSec = 2,
	[int]$MaxShots = 600
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters 1
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]70)

$count = 0
while (-not (Test-Path $StopFile) -and $count -lt $MaxShots) {
	$bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
	$full = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
	$graphics = [System.Drawing.Graphics]::FromImage($full)
	try {
		$graphics.CopyFromScreen($bounds.Left, $bounds.Top, 0, 0, $full.Size)
		$small = New-Object System.Drawing.Bitmap ([int]($bounds.Width / 2)), ([int]($bounds.Height / 2))
		$smallGraphics = [System.Drawing.Graphics]::FromImage($small)
		$smallGraphics.DrawImage($full, 0, 0, $small.Width, $small.Height)
		$count++
		$small.Save((Join-Path $OutDir ("{0:D4}.jpg" -f $count)), $codec, $encoderParams)
		$smallGraphics.Dispose()
		$small.Dispose()
	} catch {
		# Écran verrouillé ou indisponible : on réessaie au tour suivant.
	} finally {
		$graphics.Dispose()
		$full.Dispose()
	}
	Start-Sleep -Milliseconds ([int]($IntervalSec * 1000))
}
