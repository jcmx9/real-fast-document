#requires -Version 5.1
<#
.SYNOPSIS
  Windows-Einrichtung von real-fast-document.
.DESCRIPTION
  Zwei Aufgaben:
    * Fonts   - laedt die statischen Source-Fonts ins Projekt (./fonts).
    * SendTo  - legt eine "Senden an"-Verknuepfung an, die eine .md per
                convert.ps1 nach PDF/A wandelt und im Quellverzeichnis ablegt.

  Die gesamte Logik (template.typ, filters/, fonts/, convert.ps1) bleibt im
  Installpfad. Im System landet ausschliesslich die Verknuepfung, die auf
  convert.ps1 im Installpfad zeigt.
.PARAMETER Fonts
  Nur die Fonts ins Projekt laden.
.PARAMETER SendTo
  Nur die "Senden an"-Verknuepfung anlegen.
.PARAMETER Uninstall
  Die "Senden an"-Verknuepfung wieder entfernen.
.EXAMPLE
  ./scripts/install.ps1                # Fonts + SendTo
  ./scripts/install.ps1 -Fonts         # nur Fonts laden
  ./scripts/install.ps1 -SendTo        # nur Verknuepfung anlegen
  ./scripts/install.ps1 -Uninstall     # Verknuepfung entfernen
#>
[CmdletBinding()]
param(
  [switch]$Fonts,
  [switch]$SendTo,
  [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot   = Split-Path -Parent $PSScriptRoot
$FontDir       = Join-Path $ProjectRoot 'fonts'
$ConvertScript = Join-Path $PSScriptRoot 'convert.ps1'
$ShortcutName  = 'Nach PDF-A (real-fast-document).lnk'

# Variable Fonts (Source Serif 4 / Sans 3 / Code Pro, je Roman + Italic) von
# Google Fonts. Typst >= 0.15 unterstuetzt Variable Fonts. Lizenz: SIL OFL 1.1.
$FontUrls = @(
  'https://raw.githubusercontent.com/google/fonts/main/ofl/sourceserif4/SourceSerif4%5Bopsz,wght%5D.ttf'
  'https://raw.githubusercontent.com/google/fonts/main/ofl/sourceserif4/SourceSerif4-Italic%5Bopsz,wght%5D.ttf'
  'https://raw.githubusercontent.com/google/fonts/main/ofl/sourcesans3/SourceSans3%5Bwght%5D.ttf'
  'https://raw.githubusercontent.com/google/fonts/main/ofl/sourcesans3/SourceSans3-Italic%5Bwght%5D.ttf'
  'https://raw.githubusercontent.com/google/fonts/main/ofl/sourcecodepro/SourceCodePro%5Bwght%5D.ttf'
  'https://raw.githubusercontent.com/google/fonts/main/ofl/sourcecodepro/SourceCodePro-Italic%5Bwght%5D.ttf'
)

function Install-Fonts {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  New-Item -ItemType Directory -Force -Path $FontDir | Out-Null

  foreach ($url in $FontUrls) {
    $name = [Uri]::UnescapeDataString((Split-Path -Leaf $url))
    $dest = Join-Path $FontDir $name
    Write-Host "-> $name"
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
  }
  Write-Host "OK  Variable Fonts -> $FontDir" -ForegroundColor Green
}

function Get-SendToDir {
  $dir = [Environment]::GetFolderPath([Environment+SpecialFolder]::SendTo)
  if (-not $dir) { $dir = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo' }
  return $dir
}

function Install-SendTo {
  if (-not (Test-Path -LiteralPath $ConvertScript)) {
    throw "convert.ps1 nicht gefunden: $ConvertScript"
  }
  $lnkPath = Join-Path (Get-SendToDir) $ShortcutName
  $psExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

  $ws = New-Object -ComObject WScript.Shell
  $lnk = $ws.CreateShortcut($lnkPath)
  $lnk.TargetPath       = $psExe
  # Die gesendete(n) Datei(en) haengt Windows als Argument(e) hinten an.
  $lnk.Arguments        = "-NoProfile -ExecutionPolicy Bypass -File `"$ConvertScript`""
  $lnk.WorkingDirectory = $ProjectRoot
  $lnk.IconLocation     = "$psExe,0"
  $lnk.Description       = 'Markdown -> PDF/A-3b (Ablage im Quellverzeichnis)'
  $lnk.Save()

  Write-Host "OK  Verknuepfung -> $lnkPath" -ForegroundColor Green
  Write-Host "    Ziel: convert.ps1 im Installpfad ($ConvertScript)"
}

function Uninstall-SendTo {
  $lnkPath = Join-Path (Get-SendToDir) $ShortcutName
  if (Test-Path -LiteralPath $lnkPath) {
    Remove-Item -LiteralPath $lnkPath -Force
    Write-Host "OK  Verknuepfung entfernt: $lnkPath" -ForegroundColor Green
  } else {
    Write-Host "Keine Verknuepfung vorhanden: $lnkPath"
  }
}

if ($Uninstall) {
  Uninstall-SendTo
  return
}

# Ohne Schalter: beides einrichten.
if (-not $Fonts -and -not $SendTo) { $Fonts = $true; $SendTo = $true }

if ($Fonts)  { Install-Fonts }
if ($SendTo) { Install-SendTo }
