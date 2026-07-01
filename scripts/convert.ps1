#requires -Version 5.1
<#
.SYNOPSIS
  Konvertiert per "Senden an" eine oder mehrere Markdown-Dateien nach PDF/A-3b.
.DESCRIPTION
  Wird ueber die "Senden an"-Verknuepfung mit den ausgewaehlten .md-Dateien als
  Argumente aufgerufen. Die PDF wird im selben Verzeichnis wie die Quelle
  abgelegt. Template, Fonts, Logo und die Typst-Packages (vendor/) liegen im
  Installpfad (= dem Projektordner ueber diesem scripts/-Verzeichnis). Pandoc
  wird NICHT mehr benoetigt; die Markdown-Konvertierung macht cmarker in Typst.

  Hinweis: Diese Datei muss reines ASCII bleiben (kein BOM) - Windows
  PowerShell 5.1 liest sie sonst in CP1252 falsch.
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
$FontDir     = Join-Path $InstallRoot 'fonts'
# Typst-Root: das Laufwerks-Wurzelverzeichnis des Installpfads. Damit sind
# vendor/, fonts/ und template stets lesbar; die Quelle sollte auf demselben
# Laufwerk liegen (Normalfall unter Windows).
$Root        = [IO.Path]::GetPathRoot($InstallRoot)

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

# Preprocessing (spiegelt scripts/build.sh): Frontmatter fuer Typst entfernen,
# loose Task-Listen zu tight normalisieren (cmarker 0.1.9 crasht sonst; Upstream-Fix in SabrinaJewson/cmarker.typ#71, noch nicht > 0.1.9 released) und
# Pandoc-Definitionslisten in HTML <dl> (Block-Form, damit Inline-Markdown in
# der Definition rendert) uebersetzen.
function ConvertTo-RenderMarkdown {
  param([string[]]$Lines)
  $isBlank = { param($s) $s -match '^[ \t]*$' }
  $isTask  = { param($s) $s -match '^[ \t]*[-*+][ \t]+\[[ xX]\]' }

  # 1) Frontmatter am Dateianfang entfernen
  $body = New-Object System.Collections.Generic.List[string]
  $fm = $false; $first = $true
  foreach ($raw in $Lines) {
    $l = $raw -replace "`r$", ''
    if ($first) { $first = $false; if ($l -match '^---[ \t]*$') { $fm = $true; continue } }
    if ($fm) { if ($l -match '^(---|\.\.\.)[ \t]*$') { $fm = $false }; continue }
    $body.Add($l)
  }
  $L = $body.ToArray(); $n = $L.Count
  $out = New-Object System.Collections.Generic.List[string]

  $i = 0
  while ($i -lt $n) {
    # Definitionsliste: Begriff (Blockanfang) + Folgezeile ': Definition'.
    if (-not (& $isBlank $L[$i]) -and $L[$i] -notmatch '^:' `
        -and ($i -eq 0 -or (& $isBlank $L[$i - 1])) `
        -and ($i + 1 -lt $n) -and $L[$i + 1] -match '^:[ \t]+') {
      $out.Add('<dl>')
      while ($true) {
        if (($i -ge $n) -or (& $isBlank $L[$i]) -or ($L[$i] -match '^:') `
            -or ($i + 1 -ge $n) -or ($L[$i + 1] -notmatch '^:[ \t]+')) { break }
        $term = $L[$i]
        $def  = $L[$i + 1] -replace '^:[ \t]+', ''
        $out.Add("<dt>$term</dt>"); $out.Add('<dd>'); $out.Add(''); $out.Add($def); $out.Add('</dd>')
        $i += 2
        $j = $i; while ($j -lt $n -and (& $isBlank $L[$j])) { $j++ }
        if ($j -lt $n -and $L[$j] -notmatch '^:' -and ($j + 1 -lt $n) -and $L[$j + 1] -match '^:[ \t]+') { $i = $j }
      }
      $out.Add('</dl>')
      continue
    }
    # Loose Task-Liste -> tight: Leerzeile entfernen, wenn die umgebenden
    # nicht-leeren Zeilen beide Task-Items sind.
    if (& $isBlank $L[$i]) {
      $p = $i - 1; while ($p -ge 0 -and (& $isBlank $L[$p])) { $p-- }
      $q = $i + 1; while ($q -lt $n -and (& $isBlank $L[$q])) { $q++ }
      if ($p -ge 0 -and $q -lt $n -and (& $isTask $L[$p]) -and (& $isTask $L[$q])) { $i++; continue }
    }
    $out.Add($L[$i]); $i++
  }
  return (($out -join "`n") + "`n")
}

function Convert-One {
  param([string]$Src)

  $Src = (Resolve-Path -LiteralPath $Src).Path
  if ([IO.Path]::GetExtension($Src) -notin @('.md', '.markdown')) {
    throw "Keine Markdown-Datei: $Src"
  }

  $srcDir = Split-Path -Parent $Src
  $base   = [IO.Path]::GetFileNameWithoutExtension($Src)
  $lines  = Get-Content -LiteralPath $Src

  # Optionalen YAML-Frontmatter (fuehrender ---...---) parsen: date/lang/toc/
  # h2-break/print_filename. Die Bool-Schluessel werden YAML-1.1-konform gelesen
  # (siehe ConvertTo-YamlBool); ein erkannter Schluessel mit ungueltigem Wert
  # warnt und behaelt den Default.
  $fmDate = ''; $fmToc = 'auto'; $fmBreak = 'auto'; $fmShowname = 'true'; $fmLang = 'de'
  if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
    for ($i = 1; $i -lt $lines.Count; $i++) {
      if ($lines[$i].Trim() -eq '---') { break }
      if ($lines[$i] -match '^date:\s*(.+?)\s*$') {
        $fmDate = $Matches[1].Trim('"', "'")
      }
      elseif ($lines[$i] -match '^lang:\s*(.+?)\s*$') {
        $fmLang = $Matches[1].Trim('"', "'")
      }
      elseif ($lines[$i] -match '^toc:\s*(.+?)\s*$') {
        $b = ConvertTo-YamlBool $Matches[1]
        if ($b) { $fmToc = $b } else { Write-Warning "Ungueltiger Wert fuer 'toc': '$($Matches[1])' - ignoriert (true/false)." }
      }
      elseif ($lines[$i] -match '^h2-break:\s*(.+?)\s*$') {
        $b = ConvertTo-YamlBool $Matches[1]
        if ($b) { $fmBreak = $b } else { Write-Warning "Ungueltiger Wert fuer 'h2-break': '$($Matches[1])' - ignoriert (true/false)." }
      }
      elseif ($lines[$i] -match '^print_filename:\s*(.+?)\s*$') {
        $b = ConvertTo-YamlBool $Matches[1]
        if ($b) { $fmShowname = $b } else { Write-Warning "Ungueltiger Wert fuer 'print_filename': '$($Matches[1])' - ignoriert (true/false)." }
      }
    }
  }

  # Ausgabename: bei gesetztem Datum ISO-Praefix (sortierbar), sonst Basename.
  $outName = if ($fmDate) { "$($fmDate)_$base.pdf" } else { "$base.pdf" }
  $outPdf  = Join-Path $srcDir $outName

  # Vorverarbeitete Render-Quelle (temporaer, dot-praefixiert im Quellverzeichnis);
  # die eingebettete Quelle (pdf.attach) bleibt die Original-.md.
  $renderTmp = Join-Path $srcDir ".rfd-$base.md"
  [IO.File]::WriteAllText($renderTmp, (ConvertTo-RenderMarkdown $lines), (New-Object Text.UTF8Encoding $false))

  # Logo: erstes vorhandenes svg/png/jpg im Installpfad (absolut uebergeben).
  $logoArg = @('logo.svg', 'logo.png', 'logo.jpg') |
    ForEach-Object { Join-Path $InstallRoot $_ } |
    Where-Object   { Test-Path -LiteralPath $_ } |
    Select-Object  -First 1
  if (-not $logoArg) {
    $logoArg = ''
    Write-Host "Hinweis: kein Logo im Installpfad - baue ohne Logo." -ForegroundColor Yellow
  }

  # Laufzeit-Eingaben fuers Template. title = .md-Basisname (PDF/A verlangt einen
  # Dokumenttitel). --root deckt das Laufwerk ab, damit absolute Pfade (Quelle,
  # Anhang, Bilder) lesbar sind.
  $inputs = @(
    '--input', "filename=$outName",
    '--input', "title=$base",
    '--input', "logo=$logoArg",
    '--input', "source=$renderTmp",
    '--input', "attach=$Src",
    '--input', "docdir=$srcDir",
    '--input', "date=$fmDate",
    '--input', "toc=$fmToc",
    '--input', "h2-break=$fmBreak",
    '--input', "showname=$fmShowname",
    '--input', "lang=$fmLang"
  )

  try {
    & typst compile $Template $outPdf `
      --font-path $FontDir --ignore-system-fonts `
      --root $Root `
      --pdf-standard a-3b `
      @inputs
    if ($LASTEXITCODE) { throw "typst-Fehler ($LASTEXITCODE)" }

    # Uebersprungene Remote-Bilder zaehlen: das Template markiert jedes gestrippte
    # Bild mit einem unsichtbaren Metadatum <rfd-remote-skip>; per typst query
    # auslesen (gleiche Inputs, damit die Kompilierung identisch ist).
    $q = & typst query $Template '<rfd-remote-skip>' `
      --font-path $FontDir --ignore-system-fonts --root $Root --field value @inputs 2>$null
    $stripped = ([regex]::Matches(($q -join ''), 'rfd-remote-skip')).Count

    Write-Host "OK  $outPdf" -ForegroundColor Green
    if ($stripped -gt 0) {
      Write-Host "Hinweis: $stripped Remote-Bild(er) uebersprungen (kein Netzzugriff in Typst)." -ForegroundColor Yellow
    }

    # Erzeugte PDF automatisch oeffnen (immer). Opt-out ueber RFD_NO_OPEN=1.
    if (-not $env:RFD_NO_OPEN) { Start-Process -FilePath $outPdf }
  }
  finally {
    Remove-Item -LiteralPath $renderTmp -ErrorAction SilentlyContinue
  }
}

try {
  if (-not (Get-Command 'typst' -ErrorAction SilentlyContinue)) {
    throw 'typst nicht gefunden. Installation: winget install --id Typst.Typst -e'
  }
  foreach ($p in $Path) { Convert-One $p }
}
catch {
  Write-Host "Fehler: $($_.Exception.Message)" -ForegroundColor Red
  [void](Read-Host 'Enter zum Schliessen')
  exit 1
}
