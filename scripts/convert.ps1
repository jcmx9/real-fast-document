#requires -Version 5.1
<#
.SYNOPSIS
  Konvertiert per "Senden an" eine oder mehrere Markdown-Dateien nach PDF/A-3b.
.DESCRIPTION
  Wird ueber die "Senden an"-Verknuepfung mit den ausgewaehlten .md-Dateien als
  Argumente aufgerufen. Die PDF wird im selben Verzeichnis wie die Quelle
  abgelegt. Template, Lua-Filter, Fonts und Logo liegen im Installpfad (= dem
  Projektordner ueber diesem scripts/-Verzeichnis); diese Datei bleibt dort.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
  [string[]]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$InstallRoot = Split-Path -Parent $PSScriptRoot
$Template    = Join-Path $InstallRoot 'template.typ'
$LuaFilter   = Join-Path (Join-Path $InstallRoot 'filters') 'meta-from-h1.lua'
$FontDir     = Join-Path $InstallRoot 'fonts'

# Einen YAML-Skalar zu 'true'/'false' normalisieren (YAML-1.1-Boolean-Menge,
# Obsidian-kompatibel; Superset von YAML 1.2). Akzeptiert true/false/yes/no/on/
# off/y/n in beliebiger Gross-/Kleinschreibung, entfernt umschliessende Quotes
# und einen Inline-Kommentar (' # ...'). Unbekannte Werte -> $null (Aufrufer warnt).
function ConvertTo-YamlBool {
  param([string]$Raw)
  $v = ($Raw -replace '\s#.*$', '').Trim().Trim('"', "'").ToLower()
  if ($v -in @('true', 'yes', 'on', 'y'))  { return 'true' }
  if ($v -in @('false', 'no', 'off', 'n')) { return 'false' }
  return $null
}

function Convert-One {
  param([string]$Src)

  $Src = (Resolve-Path -LiteralPath $Src).Path
  if ([IO.Path]::GetExtension($Src) -notin @('.md', '.markdown')) {
    throw "Keine Markdown-Datei: $Src"
  }

  $srcDir = Split-Path -Parent $Src
  $base   = [IO.Path]::GetFileNameWithoutExtension($Src)
  $mdLeaf = Split-Path -Leaf $Src

  # Optionalen YAML-Frontmatter (fuehrender ---...---) parsen: nur diese vier
  # Schluessel; toc/h2-break/filename werden YAML-1.1-konform als Boolean gelesen
  # (siehe ConvertTo-YamlBool); ein erkannter Schluessel mit ungueltigem Wert
  # warnt und behaelt den Default.
  $fmDate = ''; $fmToc = 'auto'; $fmBreak = 'auto'; $fmShowname = 'true'
  $lines = Get-Content -LiteralPath $Src
  if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
    for ($i = 1; $i -lt $lines.Count; $i++) {
      if ($lines[$i].Trim() -eq '---') { break }
      if ($lines[$i] -match '^date:\s*(.+?)\s*$') {
        $fmDate = $Matches[1].Trim('"', "'")
      }
      elseif ($lines[$i] -match '^toc:\s*(.+?)\s*$') {
        $b = ConvertTo-YamlBool $Matches[1]
        if ($b) { $fmToc = $b } else { Write-Warning "Ungueltiger Wert fuer 'toc': '$($Matches[1])' - ignoriert (true/false)." }
      }
      elseif ($lines[$i] -match '^h2-break:\s*(.+?)\s*$') {
        $b = ConvertTo-YamlBool $Matches[1]
        if ($b) { $fmBreak = $b } else { Write-Warning "Ungueltiger Wert fuer 'h2-break': '$($Matches[1])' - ignoriert (true/false)." }
      }
      elseif ($lines[$i] -match '^filename:\s*(.+?)\s*$') {
        $b = ConvertTo-YamlBool $Matches[1]
        if ($b) { $fmShowname = $b } else { Write-Warning "Ungueltiger Wert fuer 'filename': '$($Matches[1])' - ignoriert (true/false)." }
      }
    }
  }

  # Ausgabename: bei gesetztem Datum ISO-Praefix (sortierbar), sonst Basename.
  $outName = if ($fmDate) { "$($fmDate)_$base.pdf" } else { "$base.pdf" }
  $outPdf  = Join-Path $srcDir $outName
  # Temporaere Dateien im Quellverzeichnis (= Typst-Root), dot-praefixiert.
  $typ    = Join-Path $srcDir ".rfd-$base.typ"

  # Logo: erstes vorhandenes svg/png/jpg im Installpfad, temporaer ins Quellverz.
  # Optional: ohne Logo wird ohne Logo gebaut.
  $logoSrc = @('logo.svg', 'logo.png', 'logo.jpg') |
    ForEach-Object { Join-Path $InstallRoot $_ } |
    Where-Object   { Test-Path -LiteralPath $_ } |
    Select-Object  -First 1
  $logoTmp = ''
  $logoArg = ''
  if ($logoSrc) {
    $logoTmp = Join-Path $srcDir (".rfd-logo" + [IO.Path]::GetExtension($logoSrc))
    Copy-Item -LiteralPath $logoSrc -Destination $logoTmp -Force
    $logoArg = Split-Path -Leaf $logoTmp
  } else {
    Write-Host "Hinweis: kein Logo im Installpfad - baue ohne Logo." -ForegroundColor Yellow
  }

  try {
    # Highlight-Flag je nach pandoc-Version (neuere: --syntax-highlighting,
    # aeltere: --highlight-style). Eines passt immer.
    $hlFlag = if ((& pandoc --help 2>&1) -match '--syntax-highlighting') {
      @('--syntax-highlighting', 'pygments')
    } else {
      @('--highlight-style', 'pygments')
    }
    # pandoc-Ausgabe abfangen, um vom Lua-Filter uebersprungene Remote-Bilder zu
    # zaehlen (fuer den Hinweis), aber unveraendert durchreichen - auch im
    # Fehlerfall, sonst bliebe eine Filter-Fehlermeldung unsichtbar.
    $pandocOut = & pandoc $Src --from markdown --to typst --standalone `
      --template $Template --lua-filter $LuaFilter `
      @hlFlag --output $typ 2>&1
    $pandocRc = $LASTEXITCODE
    foreach ($line in $pandocOut) { Write-Host $line }
    if ($pandocRc) { throw "pandoc-Fehler ($pandocRc)" }
    $stripped = @($pandocOut | Where-Object { "$_" -match 'Remote-Bild entfernt' }).Count

    & typst compile $typ $outPdf `
      --font-path $FontDir --ignore-system-fonts `
      --pdf-standard a-3b `
      --input "filename=$outName" `
      --input "logo=$logoArg" `
      --input "source=$mdLeaf" `
      --input "date=$fmDate" `
      --input "toc=$fmToc" `
      --input "h2-break=$fmBreak" `
      --input "showname=$fmShowname"
    if ($LASTEXITCODE) { throw "typst-Fehler ($LASTEXITCODE)" }

    Write-Host "OK  $outPdf" -ForegroundColor Green
    if ($stripped -gt 0) {
      Write-Host "Hinweis: $stripped Remote-Bild(er) uebersprungen (kein Netzzugriff in Typst)." -ForegroundColor Yellow
    }

    # Erzeugte PDF automatisch oeffnen (immer). Opt-out ueber RFD_NO_OPEN=1.
    if (-not $env:RFD_NO_OPEN) { Start-Process -FilePath $outPdf }
  }
  finally {
    Remove-Item -LiteralPath $typ -ErrorAction SilentlyContinue
    if ($logoTmp) { Remove-Item -LiteralPath $logoTmp -ErrorAction SilentlyContinue }
  }
}

try {
  foreach ($tool in 'pandoc', 'typst') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
      throw "$tool nicht gefunden. Installation: winget install --id " +
            $(if ($tool -eq 'pandoc') { 'JohnMacFarlane.Pandoc' } else { 'Typst.Typst' }) + ' -e'
    }
  }
  foreach ($p in $Path) { Convert-One $p }
}
catch {
  Write-Host "Fehler: $($_.Exception.Message)" -ForegroundColor Red
  [void](Read-Host 'Enter zum Schliessen')
  exit 1
}
