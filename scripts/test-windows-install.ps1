#requires -Version 5.1
<#
.SYNOPSIS
  Windows-Test fuer Installation und Deinstallation (CI).
.DESCRIPTION
  Prueft, was test-windows.ps1 nicht abdeckt: install.ps1 -SendTo (Verknuepfung
  und ein simuliertes "Senden an"), install.ps1 -Uninstall, und bootstrap.ps1
  (Klonen, Einrichten, Bauen ueber den Shim, Deinstallieren, Schutz vor dem
  Loeschen eines fremden Ordners). bootstrap.ps1 laeuft dabei in einem
  Wegwerf-LOCALAPPDATA und klont den aktuellen main-Stand von GitHub.
  Voraussetzung: typst im PATH, Fonts + Packages im Projekt, git.

  Datei muss reines ASCII bleiben (Windows PowerShell 5.1 liest CP1252).
#>
$ErrorActionPreference = 'Continue'
$env:RFD_NO_OPEN = '1'

$Root      = Split-Path -Parent $PSScriptRoot
$Install   = Join-Path $PSScriptRoot 'install.ps1'
$Bootstrap = Join-Path $PSScriptRoot 'bootstrap.ps1'
$Convert   = Join-Path $PSScriptRoot 'convert.ps1'
$Fixtures  = Join-Path $Root 'tests\fixtures'
# Arbeitsordner auf dem Laufwerk der Installation (Typst liest nur dort).
$Work      = Join-Path (Split-Path -Parent $Root) 'rfd install test'
$LnkPath   = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::SendTo)) 'Nach PDF-A (real-fast-document).lnk'
$Shim      = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\rf-document.cmd'
$failed    = 0

function Fail([string]$msg) { Write-Host "FEHLER: $msg" -ForegroundColor Red; $script:failed++ }
function Ok([string]$msg)   { Write-Host "ok   $msg" }

# Skript so aufrufen wie Explorer bzw. der Shim (powershell -File).
function Invoke-Ps {
  param([string]$File, [string[]]$ArgList = @())
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $File @ArgList 2>&1 | Out-String
  return @{ Code = $LASTEXITCODE; Text = $out }
}

function Test-PdfA([string]$pdf) {
  if (-not (Test-Path -LiteralPath $pdf -PathType Leaf)) { return $false }
  $raw = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($pdf))
  return $raw.Contains('part>3</pdfaid:part')
}

if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force }
$noteDir = Join-Path $Work 'Notiz Ordner'
New-Item -ItemType Directory -Force -Path $noteDir | Out-Null
Copy-Item -LiteralPath (Join-Path $Fixtures 'client-meta.md') -Destination (Join-Path $noteDir 'meine notiz.md')
Copy-Item -LiteralPath (Join-Path $Fixtures 'logo.png') -Destination $noteDir
$note = Join-Path $noteDir 'meine notiz.md'

# 1) install.ps1 -SendTo: Verknuepfung zeigt auf powershell.exe -File convert.ps1.
$r = Invoke-Ps $Install @('-SendTo')
if ($r.Code -ne 0 -or -not (Test-Path -LiteralPath $LnkPath)) {
  Fail "-SendTo: keine Verknuepfung ($LnkPath), Exit $($r.Code)`n$($r.Text)"
} else {
  $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut($LnkPath)
  if ($lnk.TargetPath -notmatch 'powershell\.exe$') { Fail "-SendTo: falsches Ziel $($lnk.TargetPath)" }
  elseif (-not $lnk.Arguments.Contains("-File `"$Convert`"")) { Fail "-SendTo: falsche Argumente $($lnk.Arguments)" }
  else { Ok '-SendTo: Verknuepfung -> powershell.exe -File convert.ps1' }
}

# 2) "Senden an" nachspielen: Explorer haengt nur die Datei an. PDF neben der
#    Notiz, mit ISO-Praefix aus date: 12.10.2026.
$r = Invoke-Ps $Convert @($note)
$sendPdf = Join-Path $noteDir '2026-10-12_meine notiz.pdf'
if ($r.Code -ne 0) { Fail "Senden an: Exit $($r.Code)`n$($r.Text)" }
elseif (-not (Test-PdfA $sendPdf)) { Fail "Senden an: PDF fehlt neben der Notiz ($sendPdf)`n$($r.Text)" }
else { Ok 'Senden an: PDF neben der Notiz mit ISO-Praefix' }

# 3) install.ps1 -Uninstall: Verknuepfung und Shim sind weg.
$r = Invoke-Ps $Install @('-Uninstall')
if ($r.Code -ne 0) { Fail "-Uninstall: Exit $($r.Code)`n$($r.Text)" }
elseif (Test-Path -LiteralPath $LnkPath) { Fail '-Uninstall: Verknuepfung noch da' }
elseif (Test-Path -LiteralPath $Shim) { Fail '-Uninstall: rf-document.cmd noch da' }
else { Ok '-Uninstall: Verknuepfung und Terminal-Befehl entfernt' }

# 4) bootstrap.ps1 in einem Wegwerf-LOCALAPPDATA (mit Leerzeichen).
$savedAppData = $env:LOCALAPPDATA
$env:LOCALAPPDATA = Join-Path $Work 'App Data'
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
$inst     = Join-Path $env:LOCALAPPDATA 'real-fast-document'
$fakeShim = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\rf-document.cmd'
$r = Invoke-Ps $Bootstrap
if ($r.Code -ne 0) { Fail "bootstrap: Exit $($r.Code)`n$($r.Text)" }
elseif (-not (Test-Path -LiteralPath (Join-Path $inst '.git'))) { Fail "bootstrap: kein Klon in $inst`n$($r.Text)" }
elseif (-not (Test-Path -LiteralPath (Join-Path $inst 'fonts\SourceSans3VF-Upright.otf'))) { Fail "bootstrap: Fonts fehlen`n$($r.Text)" }
elseif (-not (Test-Path -LiteralPath (Join-Path $inst 'vendor\cmarker\typst.toml'))) { Fail "bootstrap: Packages fehlen`n$($r.Text)" }
elseif (-not (Test-Path -LiteralPath $fakeShim)) { Fail "bootstrap: rf-document.cmd fehlt`n$($r.Text)" }
elseif (-not (Test-Path -LiteralPath $LnkPath)) { Fail "bootstrap: Verknuepfung fehlt`n$($r.Text)" }
else { Ok 'bootstrap: Klon, Fonts, Packages, Terminal-Befehl, Senden an' }

# 5) Bauen ueber den frisch installierten Shim.
$bootPdf = Join-Path $Work 'per bootstrap.pdf'
if (Test-Path -LiteralPath $fakeShim) {
  $out = & $fakeShim $note $bootPdf 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { Fail "bootstrap-Shim: Exit $LASTEXITCODE`n$out" }
  elseif (-not (Test-PdfA $bootPdf)) { Fail "bootstrap-Shim: PDF fehlt`n$out" }
  else { Ok 'bootstrap-Installation baut ueber rf-document.cmd' }
}

# 6) bootstrap.ps1 -Uninstall: Installordner, Shim und Verknuepfung sind weg;
#    ein zweiter Aufruf meldet nur "Nichts zu deinstallieren".
$r = Invoke-Ps $Bootstrap @('-Uninstall')
if ($r.Code -ne 0) { Fail "bootstrap -Uninstall: Exit $($r.Code)`n$($r.Text)" }
elseif (Test-Path -LiteralPath $inst) { Fail 'bootstrap -Uninstall: Installordner noch da' }
elseif (Test-Path -LiteralPath $fakeShim) { Fail 'bootstrap -Uninstall: rf-document.cmd noch da' }
elseif (Test-Path -LiteralPath $LnkPath) { Fail 'bootstrap -Uninstall: Verknuepfung noch da' }
else { Ok 'bootstrap -Uninstall: alles entfernt' }
$r = Invoke-Ps $Bootstrap @('-Uninstall')
if ($r.Code -ne 0 -or $r.Text -notmatch 'Nichts zu deinstallieren') { Fail "bootstrap -Uninstall ohne Installation: Exit $($r.Code)`n$($r.Text)" }
else { Ok 'bootstrap -Uninstall ohne Installation: nichts geloescht' }

# 7) Schutz: ein git-Ordner mit fremdem origin wird nicht geloescht.
New-Item -ItemType Directory -Force -Path $inst | Out-Null
& git -C $inst init -q 2>&1 | Out-Null
& git -C $inst remote add origin 'https://example.invalid/anderes-projekt.git' 2>&1 | Out-Null
$r = Invoke-Ps $Bootstrap @('-Uninstall')
if (-not (Test-Path -LiteralPath (Join-Path $inst '.git'))) { Fail 'bootstrap -Uninstall: fremder Ordner geloescht' }
elseif ($r.Text -notmatch 'kein real-fast-document-Klon') { Fail "bootstrap -Uninstall: keine Schutzmeldung`n$($r.Text)" }
else { Ok 'bootstrap -Uninstall: fremder git-Ordner bleibt' }

$env:LOCALAPPDATA = $savedAppData
Set-Location $Root
Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue

if ($failed -gt 0) { Write-Host "$failed Test(s) fehlgeschlagen." -ForegroundColor Red; exit 1 }
Write-Host 'Alle Installations-Tests bestanden.' -ForegroundColor Green
