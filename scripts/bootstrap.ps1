<#
.SYNOPSIS
  Ein-Zeiler-Bootstrap fuer real-fast-document (Windows).
.DESCRIPTION
  Installieren / Aktualisieren:
    irm https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.ps1 | iex
  Deinstallieren ("Senden an", Terminal-Befehl UND Installordner):
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.ps1))) -Uninstall

  Klont das Repo nach %LOCALAPPDATA%\real-fast-document (oder aktualisiert es per
  git pull) und ruft install.ps1 auf: Werkzeug (typst) via winget, Fonts +
  Typst-Packages ins Projekt und die "Senden an"-Verknuepfung. Vorbedingung: git.
#>
param([switch]$Uninstall)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoUrl    = 'https://github.com/jcmx9/real-fast-document.git'
$InstallDir = Join-Path $env:LOCALAPPDATA 'real-fast-document'

# Deinstallation: Verknuepfung + Terminal-Befehl ueber install.ps1 entfernen,
# danach den Installordner loeschen. Sicherheitsnetz: geloescht wird nur ein
# git-Klon dieses Projekts (origin enthaelt "real-fast-document").
if ($Uninstall) {
  if (-not (Test-Path -LiteralPath (Join-Path $InstallDir '.git'))) {
    Write-Host "Nichts zu deinstallieren: $InstallDir ist keine Installation."
    return
  }
  $origin = ''
  if (Get-Command git -ErrorAction SilentlyContinue) { $origin = (git -C $InstallDir remote get-url origin 2>$null) -join '' }
  if ($origin -notmatch 'real-fast-document') {
    Write-Host "Error: $InstallDir ist kein real-fast-document-Klon (origin: $origin) - Abbruch." -ForegroundColor Red
    return
  }
  Write-Host "-> Entferne Verknuepfung und Terminal-Befehl"
  & (Join-Path $InstallDir 'scripts\install.ps1') -Uninstall
  Write-Host "-> Loesche $InstallDir"
  Set-Location $env:USERPROFILE
  Remove-Item -LiteralPath $InstallDir -Recurse -Force
  Write-Host "OK  real-fast-document deinstalliert (typst bleibt; es gehoert winget)." -ForegroundColor Green
  return
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "Error: git nicht gefunden. Installation: winget install --id Git.Git -e" -ForegroundColor Red
  exit 1
}

if (Test-Path (Join-Path $InstallDir '.git')) {
  Write-Host "-> Aktualisiere $InstallDir"
  git -C $InstallDir pull --ff-only
} else {
  Write-Host "-> Klone real-fast-document nach $InstallDir"
  git clone --depth 1 $RepoUrl $InstallDir
}

Write-Host "-> Starte Einrichtung"
& (Join-Path $InstallDir 'scripts\install.ps1')
