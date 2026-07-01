<#
.SYNOPSIS
  Ein-Zeiler-Bootstrap fuer real-fast-document (Windows).
.DESCRIPTION
  irm https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.ps1 | iex

  Klont das Repo nach %LOCALAPPDATA%\real-fast-document (oder aktualisiert es per
  git pull) und ruft install.ps1 auf: Werkzeug (typst) via winget, Fonts +
  Typst-Packages ins Projekt und die "Senden an"-Verknuepfung. Vorbedingung: git.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoUrl    = 'https://github.com/jcmx9/real-fast-document.git'
$InstallDir = Join-Path $env:LOCALAPPDATA 'real-fast-document'

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
