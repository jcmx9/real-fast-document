#requires -Version 5.1
<#
.SYNOPSIS
  Windows-Rauchtest fuer convert.ps1 und den rf-document.cmd-Shim (CI).
.DESCRIPTION
  Spielt den Zettlr-Export nach: absolute Ein- und Ausgabepfade mit
  Leerzeichen, Aufruf aus einem fremden Arbeitsverzeichnis, POSIX-Optionen
  (--no-source, --hard-breaks), temporaere Kopie mit RFD_BASE_DIR sowie die
  Exit-Codes. Voraussetzung: typst im PATH, Fonts + Packages im Projekt
  (install.ps1 -Fonts -Packages) und der Shim (install.ps1 -Cli).

  Datei muss reines ASCII bleiben (Windows PowerShell 5.1 liest CP1252).
#>
$ErrorActionPreference = 'Continue'
$env:RFD_NO_OPEN = '1'

$Root     = Split-Path -Parent $PSScriptRoot
$Convert  = Join-Path $PSScriptRoot 'convert.ps1'
$Fixtures = Join-Path $Root 'tests\fixtures'
$Shim     = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\rf-document.cmd'
# Arbeitsordner auf dem Laufwerk der Installation (Typst liest nur dort).
$Work     = Join-Path (Split-Path -Parent $Root) 'rfd win test'
$failed   = 0

function Fail([string]$msg) { Write-Host "FEHLER: $msg" -ForegroundColor Red; $script:failed++ }
function Ok([string]$msg)   { Write-Host "ok   $msg" }

# convert.ps1 so aufrufen wie der Shim (powershell -File), Ausgabe einsammeln.
function Invoke-Convert {
  param([string[]]$ArgList)
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Convert @ArgList 2>&1 | Out-String
  return @{ Code = $LASTEXITCODE; Text = $out }
}

function Test-PdfA([string]$pdf) {
  if (-not (Test-Path -LiteralPath $pdf -PathType Leaf)) { return $false }
  $raw = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($pdf))
  return $raw.Contains('part>3</pdfaid:part')
}

if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force }
$inDir  = Join-Path $Work 'Notiz Ordner'
$outDir = Join-Path $Work 'Aus gabe'
New-Item -ItemType Directory -Force -Path (Join-Path $inDir 'bilder'), $outDir | Out-Null
Copy-Item -LiteralPath (Join-Path $Fixtures 'client-meta.md') -Destination (Join-Path $inDir 'meine notiz.md')
Copy-Item -LiteralPath (Join-Path $Fixtures 'logo.png') -Destination $inDir
Copy-Item -LiteralPath (Join-Path $Fixtures 'edge-cases.md') -Destination (Join-Path $inDir 'mit bild.md')
Copy-Item -LiteralPath (Join-Path $Fixtures 'bilder\screenshot.png') -Destination (Join-Path $inDir 'bilder')
$note = Join-Path $inDir 'meine notiz.md'

# Fremdes Arbeitsverzeichnis (Zettlr startet nicht im Notizordner).
Set-Location ([IO.Path]::GetPathRoot($Root))

# 1) Absolute Pfade mit Leerzeichen + POSIX-Optionen: PDF genau am Zielpfad,
#    kein ISO-Praefix trotz date: im Frontmatter.
$target = Join-Path $outDir 'mein pdf.pdf'
$r = Invoke-Convert @('--no-source', '--hard-breaks', $note, $target)
if ($r.Code -ne 0) { Fail "convert.ps1 mit absoluten Pfaden: Exit $($r.Code)`n$($r.Text)" }
elseif (-not (Test-PdfA $target)) { Fail "PDF fehlt am Zielpfad oder ist kein PDF/A-3: $target`n$($r.Text)" }
elseif (Get-ChildItem -LiteralPath $outDir -Filter '2026-*') { Fail 'ISO-Praefix trotz ausdruecklicher Ausgabe' }
else { Ok 'convert.ps1: absolute Pfade mit Leerzeichen, --no-source, --hard-breaks' }

# 2) Ueber den rf-document.cmd-Shim (so ruft der Zettlr-Bote auf).
$target2 = Join-Path $outDir 'per shim.pdf'
if (Test-Path -LiteralPath $Shim) {
  $out = & $Shim --no-source $note $target2 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { Fail "Shim: Exit $LASTEXITCODE`n$out" }
  elseif (-not (Test-PdfA $target2)) { Fail "Shim: PDF fehlt am Zielpfad`n$out" }
  else { Ok 'rf-document.cmd: absolute Pfade mit Leerzeichen' }
} else { Fail "Shim nicht gefunden: $Shim" }

# 3) Temporaere Kopie + RFD_BASE_DIR: Bilder relativ zum Originalordner.
$copyDir = Join-Path $Work 'temp kopie'
New-Item -ItemType Directory -Force -Path $copyDir | Out-Null
Copy-Item -LiteralPath (Join-Path $inDir 'mit bild.md') -Destination $copyDir
$env:RFD_BASE_DIR = $inDir
$target3 = Join-Path $outDir 'basis.pdf'
$r = Invoke-Convert @((Join-Path $copyDir 'mit bild.md'), $target3)
Remove-Item Env:\RFD_BASE_DIR
if ($r.Code -ne 0) { Fail "RFD_BASE_DIR: Exit $($r.Code)`n$($r.Text)" }
elseif ($r.Text -match 'nicht gefunden') { Fail "RFD_BASE_DIR: Bild nicht gefunden`n$($r.Text)" }
elseif (-not (Test-PdfA $target3)) { Fail 'RFD_BASE_DIR: PDF fehlt' }
else { Ok 'RFD_BASE_DIR (temporaere Kopie)' }

# 3b) Notiz auf einem ANDEREN Laufwerk als rf-document (Nachtrag Punkt 2):
#     Auf dem Runner liegt das Repo auf D:, %TEMP% auf C:. Notiz mit relativem
#     Bild und Leerzeichen im Pfad, Ausgabe ebenfalls dort; ein zweites Bild per
#     absolutem Pfad auf dem Repo-Laufwerk. Bereitstellungsordner muss danach weg.
$otherRoot = [IO.Path]::GetPathRoot([IO.Path]::GetTempPath())
if ($otherRoot -ne [IO.Path]::GetPathRoot($Root)) {
  $drvDir  = Join-Path ([IO.Path]::GetTempPath()) 'rfd andere platte\Notizen mit Leerzeichen'
  $drvOut  = Join-Path ([IO.Path]::GetTempPath()) 'rfd andere platte\Export Ziel'
  New-Item -ItemType Directory -Force -Path (Join-Path $drvDir 'bilder'), $drvOut | Out-Null
  Copy-Item -LiteralPath (Join-Path $Fixtures 'bilder\screenshot.png') -Destination (Join-Path $drvDir 'bilder')
  Copy-Item -LiteralPath (Join-Path $Fixtures 'logo.png') -Destination $drvDir
  $absImg = (Join-Path $Fixtures 'bilder\screenshot.png')
  $noteText = "---`ntitle: `"Andere Platte`"`nlogo: logo.png`n---`n`n# Kapitel`n`n![Relativ](bilder/screenshot.png)`n`n![Absolut auf dem Repo-Laufwerk]($absImg)`n`nText nach den Bildern.`n"
  [IO.File]::WriteAllText((Join-Path $drvDir 'notiz.md'), $noteText, (New-Object Text.UTF8Encoding $false))
  $drvPdf = Join-Path $drvOut 'notiz.pdf'
  $r = Invoke-Convert @((Join-Path $drvDir 'notiz.md'), $drvPdf)
  $leftover = @(Get-ChildItem -LiteralPath $Root -Directory -Filter '.rfd-stage-*' -Force -ErrorAction SilentlyContinue)
  if ($r.Code -ne 0) { Fail "anderes Laufwerk: Exit $($r.Code)`n$($r.Text)" }
  elseif (-not (Test-PdfA $drvPdf)) { Fail "anderes Laufwerk: PDF fehlt am Zielpfad`n$($r.Text)" }
  elseif ($r.Text -match 'nicht gefunden') { Fail "anderes Laufwerk: Bild/Logo nicht gefunden`n$($r.Text)" }
  elseif ($leftover.Count -gt 0) { Fail "anderes Laufwerk: Bereitstellungsordner nicht entfernt" }
  else { Ok "Notiz auf anderem Laufwerk ($otherRoot) als rf-document ($([IO.Path]::GetPathRoot($Root)))" }
} else {
  Write-Host "skip anderes Laufwerk (TEMP und Repo auf demselben Laufwerk)"
}

# 4) Fehlende Quelle: Exit 1, verstaendliche Meldung.
$r = Invoke-Convert @((Join-Path $inDir 'gibt es nicht.md'), (Join-Path $outDir 'x.pdf'))
if ($r.Code -ne 1 -or $r.Text -notmatch 'Quelle nicht gefunden') { Fail "fehlende Quelle: Exit $($r.Code)`n$($r.Text)" }
else { Ok 'Exit 1 bei fehlender Quelle' }

# 5) Unbekannte Option: Exit 2.
$r = Invoke-Convert @('--gibt-es-nicht')
if ($r.Code -ne 2) { Fail "unbekannte Option: Exit $($r.Code)`n$($r.Text)" } else { Ok 'Exit 2 bei unbekannter Option' }

# 6) --version und -Version.
foreach ($v in @('--version', '-Version')) {
  $r = Invoke-Convert @($v)
  if ($r.Code -ne 0 -or $r.Text -notmatch 'rf-document') { Fail "$v`: Exit $($r.Code)`n$($r.Text)" } else { Ok $v }
}

if ($failed -gt 0) { Write-Host "$failed Test(s) fehlgeschlagen." -ForegroundColor Red; exit 1 }
Write-Host 'Alle Windows-Tests bestanden.' -ForegroundColor Green
