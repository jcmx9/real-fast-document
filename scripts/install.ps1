#requires -Version 5.1
<#
.SYNOPSIS
  Windows-Einrichtung von real-fast-document.
.DESCRIPTION
  Zwei Aufgaben:
    * Fonts   - laedt die Variable Source-Fonts ins Projekt (./fonts).
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

# Variable OTF (CFF2) der Source-Familien (Source Serif 4 / Sans 3 / Code Pro,
# je Roman/Upright + Italic) aus den Adobe-Upstream-Releases. Google Fonts
# liefert diese Familien nur als TTF; variable OTF gibt es nur bei Adobe.
# Typst >= 0.15 rendert variable OTF. Lizenz: SIL OFL 1.1.
$FontZips = @(
  @{ Url   = 'https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_Desktop.zip'
     Files = @('SourceSerif4Variable-Roman.otf', 'SourceSerif4Variable-Italic.otf') }
  @{ Url   = 'https://github.com/adobe-fonts/source-sans/releases/download/3.052R/VF-source-sans-3.052R.zip'
     Files = @('SourceSans3VF-Upright.otf', 'SourceSans3VF-Italic.otf') }
  @{ Url   = 'https://github.com/adobe-fonts/source-code-pro/releases/download/2.042R-u/1.062R-i/1.026R-vf/VF-source-code-VF-1.026R.zip'
     Files = @('SourceCodeVF-Upright.otf', 'SourceCodeVF-Italic.otf') }
)

function Install-Fonts {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  New-Item -ItemType Directory -Force -Path $FontDir | Out-Null

  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('rfd-fonts-' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  try {
    foreach ($z in $FontZips) {
      $zip = Join-Path $tmp ([IO.Path]::GetFileName($z.Url))
      Invoke-WebRequest -Uri $z.Url -OutFile $zip -UseBasicParsing
      $dest = Join-Path $tmp ([IO.Path]::GetFileNameWithoutExtension($zip))
      Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
      foreach ($file in $z.Files) {
        $src = Get-ChildItem -LiteralPath $dest -Recurse -Filter $file | Select-Object -First 1
        if (-not $src) { throw "Font nicht im Zip gefunden: $file" }
        Write-Host "-> $file"
        Copy-Item -LiteralPath $src.FullName -Destination (Join-Path $FontDir $file) -Force
      }
    }
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
  Write-Host "OK  Variable OTF -> $FontDir" -ForegroundColor Green
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
