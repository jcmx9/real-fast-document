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
  [switch]$Version,
  [switch]$Help,
  [Parameter(ValueFromRemainingArguments = $true)]
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

# ---------------------------------------------------------------------------
# CLI-Flags: -Version / -Help (PowerShell-nativ) sowie zusaetzlich die POSIX-
# Formen --version/-V und --help/-h, damit 'rf-document --version' plattform-
# gleich wie unter macOS/Linux funktioniert (spiegelt scripts/build.sh).
# ---------------------------------------------------------------------------
$RfdVersion = (Get-Content -LiteralPath (Join-Path $InstallRoot 'VERSION') -ErrorAction SilentlyContinue |
  Select-Object -First 1)
if (-not $RfdVersion) { $RfdVersion = 'unknown' }

function Show-RfdHelp {
  Write-Host @"
rf-document $RfdVersion - Markdown -> Corporate PDF/A-3b (via Typst, kein Pandoc)

Usage:
  rf-document [OPTIONS] [SOURCE.md ...]

Arguments:
  SOURCE.md    Zu rendernde Markdown-Quelle(n) (Default: example.md). Die PDF
               landet neben der Quelle; ein 'date:' im Frontmatter stellt das
               ISO-Datum voran (z.B. 2026-06-19_SOURCE.pdf) - abschaltbar mit
               'isodate_praefix: false'.

Options:
  -Version, --version   rf-document- und Typst-Version ausgeben und beenden
  -Help,    --help      Diese Hilfe ausgeben und beenden

Optionale YAML-Frontmatter-Schluessel:
  title, date, isodate_praefix, toc, h1_break, print_filename, lang, header, watermark

Environment:
  RFD_NO_OPEN=1   Das PDF nach dem Build nicht oeffnen (Batch/Cron)
"@
}

# POSIX-Formen aus den Restargumenten herausfiltern (die PS-Switches -Version/
# -Help binden bereits selbst).
if ($Path) {
  if (($Path -contains '--version') -or ($Path -contains '-V')) { $Version = $true }
  if (($Path -contains '--help')    -or ($Path -contains '-h')) { $Help    = $true }
  $Path = @($Path | Where-Object { $_ -notin @('--version', '-V', '--help', '-h') })
}

if ($Version) {
  Write-Host "rf-document $RfdVersion"
  if (Get-Command 'typst' -ErrorAction SilentlyContinue) { & typst --version }
  exit 0
}
if ($Help) { Show-RfdHelp; exit 0 }

# Ohne Argument: example.md aus dem Installpfad bauen (Paritaet zu build.sh).
if (-not $Path -or $Path.Count -eq 0) {
  $Path = @(Join-Path $InstallRoot 'example.md')
}

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

# Einen Windows-Pfad in einen Typst-tauglichen Pfad wandeln. Typst loest die
# --input-Pfade (read/image/pdf.attach/docdir) INTERN ueber sein virtuelles
# Dateisystem RELATIV zu --root auf. Zwei Regeln gelten dort:
#   1. keine Backslashes            -> '\' zu '/'
#   2. kein Laufwerksbuchstabe      -> fuehrendes 'C:' entfernen, sodass der
#      ("path contains invalid          Pfad wurzel-relativ mit '/' beginnt
#       component `C:`")                 ('C:\Users\x' -> '/Users/x')
# Das spiegelt build.sh (macOS/Linux: --root / + '/'-absolute Pfade). --root ist
# das Laufwerks-Wurzelverzeichnis (siehe $Root), daher gilt die Annahme, dass
# Quelle UND Installpfad auf demselben Laufwerk liegen. Reine CLI-fs-Argumente
# (Template, Ausgabe, --root, --font-path) sind NICHT betroffen.
function ConvertTo-TypstPath {
  param([string]$Path)
  if (-not $Path) { return '' }
  return ($Path -replace '\\', '/') -replace '^[A-Za-z]:', ''
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
        $k = $i + 2
        # Pandoc-Fortsetzungszeilen der Definition (eingerueckt, nicht-leer, kein
        # neuer ':'-Eintrag) anhaengen -> EINE Zeile im <dd>. Ohne das landet die
        # 2. Beschreibungszeile als Fliesstext am linken Rand.
        while ($k -lt $n -and -not (& $isBlank $L[$k]) -and $L[$k] -match '^[ \t]+' -and $L[$k] -notmatch '^[ \t]*:[ \t]+') {
          $def = $def + ' ' + ($L[$k] -replace '^[ \t]+', '')
          $k++
        }
        $out.Add("<dt>$term</dt>"); $out.Add('<dd>'); $out.Add(''); $out.Add($def); $out.Add('</dd>')
        $i = $k
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
  # UTF-8 explizit lesen: Windows PowerShell 5.1 liest Get-Content sonst in der
  # ANSI-Codepage (CP1252) und verstuemmelt UTF-8-Umlaute (ae/oe/ue/ss -> Mojibake).
  # ReadAllLines mit UTF8Encoding erkennt/entfernt ein evtl. BOM automatisch und
  # passt so zum BOM-losen UTF-8-Schreiben des Render-Temps (siehe WriteAllText).
  $lines  = [IO.File]::ReadAllLines($Src, (New-Object Text.UTF8Encoding $false))

  # Optionalen YAML-Frontmatter (fuehrender ---...---) parsen: title/date/isodate_praefix/
  # lang/toc/h1_break/print_filename/header/watermark. Bool-Schluessel werden YAML-1.1-konform gelesen
  # (siehe ConvertTo-YamlBool); ein erkannter Schluessel mit ungueltigem Wert
  # warnt und behaelt den Default.
  $fmDate = ''; $fmIsodatePraefix = ''; $fmToc = 'auto'; $fmBreak = 'auto'; $fmShowname = 'true'; $fmLang = 'de'
  $fmHeader = ''; $fmWatermark = ''; $fmTitle = ''
  if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
    for ($i = 1; $i -lt $lines.Count; $i++) {
      if ($lines[$i].Trim() -eq '---') { break }
      if ($lines[$i] -match '^date:\s*(.+?)\s*$') {
        $fmDate = $Matches[1].Trim('"', "'")
      }
      elseif ($lines[$i] -match '^isodate_praefix:\s*(.+?)\s*$') {
        $b = ConvertTo-YamlBool $Matches[1]
        if ($b) { $fmIsodatePraefix = $b } else { Write-Warning "Ungueltiger Wert fuer 'isodate_praefix': '$($Matches[1])' - ignoriert (true/false)." }
      }
      elseif ($lines[$i] -match '^lang:\s*(.+?)\s*$') {
        $fmLang = $Matches[1].Trim('"', "'")
      }
      elseif ($lines[$i] -match '^header:\s*(.+?)\s*$') {
        $fmHeader = $Matches[1].Trim('"', "'")
      }
      elseif ($lines[$i] -match '^watermark:\s*(.+?)\s*$') {
        $fmWatermark = $Matches[1].Trim('"', "'")
      }
      elseif ($lines[$i] -match '^toc:\s*(.+?)\s*$') {
        $b = ConvertTo-YamlBool $Matches[1]
        if ($b) { $fmToc = $b } else { Write-Warning "Ungueltiger Wert fuer 'toc': '$($Matches[1])' - ignoriert (true/false)." }
      }
      elseif ($lines[$i] -match '^h1_break:\s*(.+?)\s*$') {
        $b = ConvertTo-YamlBool $Matches[1]
        if ($b) { $fmBreak = $b } else { Write-Warning "Ungueltiger Wert fuer 'h1_break': '$($Matches[1])' - ignoriert (true/false)." }
      }
      elseif ($lines[$i] -match '^title:\s*(.+?)\s*$') {
        $fmTitle = $Matches[1].Trim('"', "'")
      }
      elseif ($lines[$i] -match '^print_filename:\s*(.+?)\s*$') {
        $b = ConvertTo-YamlBool $Matches[1]
        if ($b) { $fmShowname = $b } else { Write-Warning "Ungueltiger Wert fuer 'print_filename': '$($Matches[1])' - ignoriert (true/false)." }
      }
    }
  }

  # Ausgabename: bei gesetztem Datum ISO-Praefix (sortierbar), sonst Basename.
  # 'isodate_praefix: false' schaltet das Praefix ab (Datum bleibt in der Fusszeile).
  $outName = if ($fmDate -and $fmIsodatePraefix -ne 'false') { "$($fmDate)_$base.pdf" } else { "$base.pdf" }
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

  # Laufzeit-Eingaben fuers Template. PDF/A-Metadatentitel: title: falls gesetzt,
  # sonst Basisname; doctitle = sichtbarer Titel (nur aus title:). --root deckt
  # das Laufwerk ab, damit absolute Pfade (Quelle, Anhang, Bilder) lesbar sind.
  $titleMeta = if ($fmTitle) { $fmTitle } else { $base }
  # Pfad-Inputs, die Typst INTERN aufloest (read/image/pdf.attach + docdir),
  # in wurzel-relative Typst-Pfade wandeln (Backslashes -> '/', Laufwerk weg);
  # siehe ConvertTo-TypstPath. Die CLI-fs-Argumente bleiben unveraendert.
  $srcFwd       = ConvertTo-TypstPath $Src
  $renderFwd    = ConvertTo-TypstPath $renderTmp
  $srcDirFwd    = ConvertTo-TypstPath $srcDir
  $logoFwd      = ConvertTo-TypstPath $logoArg
  $inputs = @(
    '--input', "filename=$outName",
    '--input', "title=$titleMeta",
    '--input', "doctitle=$fmTitle",
    '--input', "logo=$logoFwd",
    '--input', "source=$renderFwd",
    '--input', "attach=$srcFwd",
    '--input', "docdir=$srcDirFwd",
    '--input', "date=$fmDate",
    '--input', "toc=$fmToc",
    '--input', "h1_break=$fmBreak",
    '--input', "showname=$fmShowname",
    '--input', "lang=$fmLang",
    '--input', "header=$fmHeader",
    '--input', "watermark=$fmWatermark"
  )

  # Reproduzierbarer Metadaten-Zeitstempel: ohne Frontmatter-date: nutzt das Template
  # date: auto -> Typst schriebe sonst den Build-Zeitpunkt in CreateDate/ModifyDate.
  # SOURCE_DATE_EPOCH (Quell-mtime) macht das deterministisch = letzte Aenderungszeit
  # der Quelle statt "jetzt"; Typst respektiert die Variable fuer date: auto. Ist ein
  # date: gesetzt, pinnt das Template direkt. Ein vom Aufrufer gesetzter Wert gewinnt.
  if (-not $env:SOURCE_DATE_EPOCH) {
    $mtimeUtc = (Get-Item -LiteralPath $Src).LastWriteTimeUtc
    $env:SOURCE_DATE_EPOCH = [string]([DateTimeOffset]$mtimeUtc).ToUnixTimeSeconds()
  }

  try {
    & typst compile $Template $outPdf `
      --font-path $FontDir --ignore-system-fonts `
      --root $Root `
      --pdf-standard a-3b `
      @inputs
    if ($LASTEXITCODE) { throw "typst-Fehler ($LASTEXITCODE)" }

    # Uebersprungene Remote-Bilder zaehlen: das Template markiert jedes gestrippte
    # Bild mit einem unsichtbaren Metadatum <rfd-remote-skip>; per typst eval
    # auszaehlen (typst query ist ab Typst 0.15 deprecated). Gleiche Inputs, damit
    # die Kompilierung identisch ist; query(...).len() liefert direkt die Zahl.
    $q = & typst eval --in $Template 'query(<rfd-remote-skip>).len()' `
      --font-path $FontDir --ignore-system-fonts --root $Root @inputs 2>$null
    $stripped = 0
    [void][int]::TryParse((($q -join '').Trim()), [ref]$stripped)

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
