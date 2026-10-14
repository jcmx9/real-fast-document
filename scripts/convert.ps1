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

  Bewusst OHNE param()-Block: die Argumente werden selbst aus $args gelesen.
  Mit PowerShell-Parameterbindung ([CmdletBinding()]) wuerden POSIX-Optionen
  wie --no-source oder --hard-breaks (so ruft der Zettlr-Bote ueber den
  rf-document.cmd-Shim auf) als unbekannte Parameternamen abgelehnt.
#>

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
  rf-document [OPTIONS] SOURCE.md OUTPUT.pdf

Arguments:
  SOURCE.md    Zu rendernde Markdown-Quelle(n) (Default: example.md). Die PDF
               landet neben der Quelle; ein 'date:' im Frontmatter stellt das
               ISO-Datum voran (z.B. 2026-06-19_SOURCE.pdf) - abschaltbar mit
               'isodate_praefix: false'.
  OUTPUT.pdf   Bei genau einer Quelle: Ausgabepfad, wird exakt so geschrieben.

Options:
  --hard-breaks         Jede Zeile bleibt eine Zeile, wie im Editor getippt
                        (Frontmatter: hard_breaks: true)
  --no-source           Markdown-Quelle NICHT ins PDF einbetten (Kunden-PDFs;
                        Frontmatter: embed_source: false)
  -Version, --version   rf-document- und Typst-Version ausgeben und beenden
  -Help,    --help      Diese Hilfe ausgeben und beenden

Optionale YAML-Frontmatter-Schluessel:
  title, subtitle, client, author, date, isodate_praefix, toc, h1_break,
  print_filename, lang, header, watermark, logo, logo-height, embed_source,
  hard_breaks

Environment:
  RFD_NO_OPEN=1         Das PDF nach dem Build nicht oeffnen (Batch/Cron)
  RFD_BASE_DIR=ordner   Relative Bild-/Logopfade gelten relativ zu diesem Ordner
                        statt zum Ordner der Quelle (Zettlr: temporaere Kopie)
"@
}

# Argumente selbst auswerten (siehe Kopfkommentar): Optionen in POSIX- und
# PowerShell-Schreibweise, alles andere sind Pfade. Eine unbekannte Option
# endet wie in build.sh mit Exit 2.
$Version = $false; $Help = $false; $NoSource = $false; $HardBreaks = $false
$Path = @()
foreach ($a in $args) {
  $arg = [string]$a
  switch -CaseSensitive ($arg) {
    { $_ -in @('--version', '-V', '-Version', '-version') } { $Version = $true; continue }
    { $_ -in @('--help', '-h', '-Help', '-help', '-?') }    { $Help = $true; continue }
    '--no-source'   { $NoSource = $true; continue }
    '--hard-breaks' { $HardBreaks = $true; continue }
    default {
      if ($arg.StartsWith('-')) {
        [Console]::Error.WriteLine("Error: unbekannte Option $arg")
        [Console]::Error.WriteLine('Aufruf: rf-document --help')
        exit 2
      }
      $Path += $arg
    }
  }
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
# Pfad aus der Befehlszeile absolut machen. [IO.Path]::Combine statt
# Join-Path: Combine uebernimmt einen absoluten zweiten Pfad unveraendert,
# Join-Path haengt ihn an ("C:\Notizen\C:\...\notiz.pdf" -> GetFullPath:
# "Das angegebene Pfadformat wird nicht unterstuetzt"). Der Zettlr-Bote
# uebergibt Ein- und Ausgabe immer absolut, oft mit Leerzeichen.
function ConvertTo-FullPath {
  param([string]$P)
  return [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).Path, $P))
}

# Genau zwei Argumente, das zweite eine .pdf: ausdruecklicher Ausgabepfad
# (Paritaet zu 'build.sh SOURCE.md OUTPUT.pdf', z. B. fuer den Zettlr-Export).
$ExplicitOut = ''
if ($Path.Count -eq 2 -and [IO.Path]::GetExtension($Path[1]) -eq '.pdf') {
  $ExplicitOut = ConvertTo-FullPath $Path[1]
  $Path = @($Path[0])
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

# Einen YAML-String-Skalar saeubern (spiegelt yaml_str in build.sh): in
# Anfuehrungszeichen gilt der Inhalt bis zum schliessenden Zeichen, sonst wird
# ein Inline-Kommentar (' # ...') abgeschnitten. Eine Inline-Liste [a, "b"]
# wird zu "a, b" (z. B. mehrere Autoren).
function ConvertTo-YamlStr {
  param([string]$Raw)
  $v = $Raw.Trim()
  if ($v -match '^"([^"]*)') { return $Matches[1] }
  if ($v -match "^'([^']*)") { return $Matches[1] }
  if ($v -match '^\[([^\]]*)') {
    return (($Matches[1] -replace '["'']', '') -split '\s*,\s*' |
      ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ', '
  }
  return ($v -replace '\s#.*$', '').Trim()
}

# Bool-Schluessel auswerten (spiegelt fm_bool in build.sh): 'true'/'false'
# (bzw. 'auto', wenn erlaubt). Leerer Wert -> $null ohne Warnung; ungueltiger
# Wert -> Warnung + $null, der Default bleibt.
function Get-FmBool {
  param([string]$Key, [string]$Raw, [switch]$AllowAuto)
  $v = ConvertTo-YamlStr $Raw
  if (-not $v) { return $null }
  if ($AllowAuto -and $v.ToLower() -eq 'auto') { return 'auto' }
  $b = ConvertTo-YamlBool $v
  if ($b) { return $b }
  $allowed = if ($AllowAuto) { 'true/false/auto' } else { 'true/false' }
  Write-Warning "Ungueltiger Wert fuer '$Key': '$v' - ignoriert ($allowed)."
  return $null
}

# Umgebungsvariable lesen; USER<->USERNAME und HOME<->USERPROFILE als Rueckfall.
function Get-EnvFallback {
  param([string]$Name)
  $v = [Environment]::GetEnvironmentVariable($Name)
  if (-not $v) {
    $alt = @{ USER = 'USERNAME'; USERNAME = 'USER'; HOME = 'USERPROFILE'; USERPROFILE = 'HOME' }[$Name]
    if ($alt) { $v = [Environment]::GetEnvironmentVariable($alt) }
  }
  if (-not $v) { $v = '' }
  return $v
}

# Pfad aus einer Notiz aufbereiten (spiegelt expand_path in build.sh): ~,
# ${VAR}, $VAR und %VAR% ersetzen, %XX-Kodierung aufloesen. Nichts wird
# ausgefuehrt, nur Variablen eingesetzt.
function Expand-NotePath {
  param([string]$P)
  if ($P -eq '~' -or $P -match '^~[\\/]') { $P = (Get-EnvFallback 'HOME') + $P.Substring(1) }
  $P = [regex]::Replace($P, '\$\{([A-Za-z_][A-Za-z0-9_]*)\}', { param($m) Get-EnvFallback $m.Groups[1].Value })
  $P = [regex]::Replace($P, '\$([A-Za-z_][A-Za-z0-9_]*)', { param($m) Get-EnvFallback $m.Groups[1].Value })
  $P = [regex]::Replace($P, '%([A-Za-z_][A-Za-z0-9_]*)%', { param($m) Get-EnvFallback $m.Groups[1].Value })
  $P = [regex]::Replace($P, '%([0-9A-Fa-f]{2})', { param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
  return $P
}

# Frontmatter-Datum (ISO 2026-10-13 oder deutsch 13.10.2026) -> ISO; sonst ''.
function ConvertTo-IsoDate {
  param([string]$D)
  if ($D -match '^(\d{4})-(\d{1,2})-(\d{1,2})$') { return ('{0}-{1:D2}-{2:D2}' -f $Matches[1], [int]$Matches[2], [int]$Matches[3]) }
  if ($D -match '^(\d{1,2})\.(\d{1,2})\.(\d{4})$') { return ('{0}-{1:D2}-{2:D2}' -f $Matches[3], [int]$Matches[2], [int]$Matches[1]) }
  return ''
}

# Typst liest nur unterhalb von --root (= Laufwerk der Installation, weil
# template.typ, lib/ und vendor/ dort liegen muessen). Eine Notiz, ein Bild oder
# ein Logo auf einem anderen Laufwerk (Notiz auf D:, rf-document unter C:\Users\
# ...\AppData) wird deshalb fuer den Build in einen temporaeren Ordner innerhalb
# der Installation kopiert ("Bereitstellung"); der Ordner wird danach entfernt.
# Pfade auf dem Installationslaufwerk bleiben unveraendert.
$script:StageDir = ''
$script:StageCount = 0
function Get-TypstReadable {
  param([string]$Path, [string]$Name = '')
  if (-not $Path) { return $Path }
  if ([IO.Path]::GetPathRoot($Path) -eq $Root) { return $Path }
  if (-not $script:StageDir) {
    $script:StageDir = Join-Path $InstallRoot ('.rfd-stage-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:StageDir | Out-Null
  }
  if (-not $Name) {
    $script:StageCount++
    $Name = ('datei-' + $script:StageCount + [IO.Path]::GetExtension($Path))
  }
  $target = Join-Path $script:StageDir $Name
  Copy-Item -LiteralPath $Path -Destination $target -Force
  return $target
}

function Convert-One {
  param([string]$Src)

  $Src = ConvertTo-FullPath $Src
  if (-not (Test-Path -LiteralPath $Src -PathType Leaf)) {
    throw "Quelle nicht gefunden: $Src"
  }
  if ([IO.Path]::GetExtension($Src) -notin @('.md', '.markdown')) {
    throw "Keine Markdown-Datei: $Src"
  }

  $srcDir = Split-Path -Parent $Src
  # Basisordner fuer relative Bild- und Logopfade: RFD_BASE_DIR, falls gesetzt
  # (Zettlr uebergibt bei ungespeicherten Aenderungen eine temporaere Kopie der
  # Notiz, die Bilder liegen aber neben dem Original), sonst der Ordner der Quelle.
  $baseDir = $srcDir
  if ($env:RFD_BASE_DIR) {
    $b = ConvertTo-FullPath $env:RFD_BASE_DIR
    if (Test-Path -LiteralPath $b -PathType Container) { $baseDir = $b }
    else { Write-Warning "RFD_BASE_DIR ist kein Ordner: $($env:RFD_BASE_DIR) - nutze den Ordner der Quelle." }
  }
  $base   = [IO.Path]::GetFileNameWithoutExtension($Src)
  # UTF-8 explizit lesen: Windows PowerShell 5.1 liest Get-Content sonst in der
  # ANSI-Codepage (CP1252) und verstuemmelt UTF-8-Umlaute (ae/oe/ue/ss -> Mojibake).
  # ReadAllLines mit UTF8Encoding erkennt/entfernt ein evtl. BOM automatisch und
  # passt so zum BOM-losen UTF-8-Schreiben des Render-Temps (siehe WriteAllText).
  # Nur fuer das Frontmatter; die Markdown-Vorverarbeitung macht das Template
  # (lib/markdown.typ) und liest die Quelle selbst.
  $lines  = [IO.File]::ReadAllLines($Src, (New-Object Text.UTF8Encoding $false))

  # Optionalen YAML-Frontmatter (fuehrender ---...---) parsen. Bool-Schluessel
  # werden YAML-1.1-konform gelesen (siehe ConvertTo-YamlBool); ein erkannter
  # Schluessel mit ungueltigem Wert warnt und behaelt den Default. Leere Werte
  # werden ignoriert, nie ein Fehler.
  $fmDate = ''; $fmIsodatePraefix = ''; $fmToc = 'auto'; $fmBreak = 'auto'; $fmShowname = 'true'; $fmLang = 'de'
  $fmHeader = ''; $fmWatermark = ''; $fmTitle = ''
  $fmSubtitle = ''; $fmClient = ''; $fmAuthor = ''; $fmLogo = ''; $fmLogoHeight = ''; $fmEmbed = 'true'; $fmBreaks = 'false'
  if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
    for ($i = 1; $i -lt $lines.Count; $i++) {
      if ($lines[$i].Trim() -in @('---', '...')) { break }
      $line = $lines[$i]
      if ($line -notmatch '^([A-Za-z_-]+):(.*)$') { continue }
      $key = $Matches[1]; $raw = $Matches[2]
      switch ($key) {
        'date'            { $fmDate = ConvertTo-YamlStr $raw }
        'title'           { $fmTitle = ConvertTo-YamlStr $raw }
        'subtitle'        { $fmSubtitle = ConvertTo-YamlStr $raw }
        'client'          { $fmClient = ConvertTo-YamlStr $raw }
        'author'          { $fmAuthor = ConvertTo-YamlStr $raw }
        'logo'            { $fmLogo = ConvertTo-YamlStr $raw }
        'logo-height'     { $fmLogoHeight = ConvertTo-YamlStr $raw }
        'header'          { $fmHeader = ConvertTo-YamlStr $raw }
        'watermark'       { $fmWatermark = ConvertTo-YamlStr $raw }
        'lang'            { $v = ConvertTo-YamlStr $raw; if ($v) { $fmLang = $v } }
        'isodate_praefix' { $b = Get-FmBool $key $raw; if ($b) { $fmIsodatePraefix = $b } }
        'toc'             { $b = Get-FmBool $key $raw -AllowAuto; if ($b) { $fmToc = $b } }
        'h1_break'        { $b = Get-FmBool $key $raw -AllowAuto; if ($b) { $fmBreak = $b } }
        'print_filename'  { $b = Get-FmBool $key $raw; if ($b) { $fmShowname = $b } }
        'hard_breaks'     { $b = Get-FmBool $key $raw; if ($b) { $fmBreaks = $b } }
        'embed_source'    { $b = Get-FmBool $key $raw; if ($b) { $fmEmbed = $b } }
      }
    }
  }

  if ($NoSource) { $fmEmbed = 'false' }
  if ($HardBreaks) { $fmBreaks = 'true' }

  # Ausgabe: ausdruecklicher Pfad gewinnt (exakt, ohne Praefix). Sonst neben der
  # Quelle; bei erkennbarem Datum ISO-Praefix (sortierbar), ausser
  # 'isodate_praefix: false' (Datum bleibt in der Fusszeile).
  $dateIso = ConvertTo-IsoDate $fmDate
  if ($ExplicitOut) {
    $outPdf = $ExplicitOut
  } else {
    $outName = if ($dateIso -and $fmIsodatePraefix -ne 'false') { "$($dateIso)_$base.pdf" } else { "$base.pdf" }
    $outPdf  = Join-Path $srcDir $outName
  }
  $outName = Split-Path -Leaf $outPdf

  # Logo: Frontmatter logo: (pro Notiz, relativ zur Notiz oder absolut) vor dem
  # ersten vorhandenen svg/png/jpg im Installpfad. Ein fehlendes Notiz-Logo
  # bricht nie ab: Warnung, dann Standard-Logo.
  $logoArg = $null
  if ($fmLogo) {
    if ($fmLogo -match '^(https?:)?//|^data:') {
      Write-Warning "Remote-Logo wird nicht geladen (kein Netzzugriff): $fmLogo"
    } else {
      $noteLogo = Expand-NotePath $fmLogo
      if (-not [IO.Path]::IsPathRooted($noteLogo)) { $noteLogo = Join-Path $baseDir $noteLogo }
      if (Test-Path -LiteralPath $noteLogo -PathType Leaf) { $logoArg = $noteLogo }
      else { Write-Warning "Logo nicht gefunden: $fmLogo - nutze das Standard-Logo." }
    }
  }
  if (-not $logoArg) {
    $logoArg = @('logo.svg', 'logo.png', 'logo.jpg') |
      ForEach-Object { Join-Path $InstallRoot $_ } |
      Where-Object   { Test-Path -LiteralPath $_ } |
      Select-Object  -First 1
  }
  if (-not $logoArg) {
    $logoArg = ''
    Write-Host "Hinweis: kein Logo im Installpfad - baue ohne Logo." -ForegroundColor Yellow
  }

  # Laufzeit-Eingaben fuers Template. title = Rueckfall-Metadatentitel
  # (Basisname); doctitle = Frontmatter title:. --root deckt das Laufwerk ab,
  # damit absolute Pfade (Quelle, Anhang, Bilder) lesbar sind.
  # Pfad-Inputs, die Typst INTERN aufloest (read/image/pdf.attach + docdir),
  # in wurzel-relative Typst-Pfade wandeln (Backslashes -> '/', Laufwerk weg);
  # siehe ConvertTo-TypstPath. Die CLI-fs-Argumente bleiben unveraendert.
  # Quelle und Logo fuer Typst erreichbar machen (anderes Laufwerk -> Kopie in
  # der Installation). Die Kopie der Quelle traegt ihren Dateinamen: so bleibt der
  # Anhang im PDF unter dem Originalnamen und mit dem Originalinhalt.
  $script:StageDir = ''; $script:StageCount = 0
  $typstSrc     = Get-TypstReadable $Src ([IO.Path]::GetFileName($Src))
  $typstLogo    = Get-TypstReadable $logoArg
  $typstBase    = if ([IO.Path]::GetPathRoot($baseDir) -eq $Root) { $baseDir } else { Split-Path -Parent $typstSrc }
  $srcFwd       = ConvertTo-TypstPath $typstSrc
  $srcDirFwd    = ConvertTo-TypstPath $typstBase
  $logoFwd      = ConvertTo-TypstPath $typstLogo
  $attachFwd    = if ($fmEmbed -ne 'false') { $srcFwd } else { '' }
  $inputs = @(
    '--input', "filename=$outName",
    '--input', "title=$base",
    '--input', "doctitle=$fmTitle",
    '--input', "subtitle=$fmSubtitle",
    '--input', "client=$fmClient",
    '--input', "author=$fmAuthor",
    '--input', "logo=$logoFwd",
    '--input', "logo_height=$fmLogoHeight",
    '--input', "source=$srcFwd",
    '--input', "attach=$attachFwd",
    '--input', "docdir=$srcDirFwd",
    '--input', "date=$fmDate",
    '--input', "toc=$fmToc",
    '--input', "h1_break=$fmBreak",
    '--input', "showname=$fmShowname",
    '--input', "lang=$fmLang",
    '--input', "header=$fmHeader",
    '--input', "watermark=$fmWatermark",
    '--input', "hard_breaks=$fmBreaks"
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

  # Bilder pruefen (Probe-Durchlauf, spiegelt build.sh): Typst kann weder
  # Umgebungsvariablen lesen noch pruefen, ob eine Datei existiert. Das Template
  # meldet im Probe-Modus alle Bildquellen (+ Zahl der Remote-Bilder); hier
  # ~/$VAR/${VAR}/%VAR% ersetzen, relativ zur Notiz aufloesen und pruefen. Ein
  # fehlendes Bild erscheint im PDF als "[Bild fehlt: pfad]". Ein Bild auf einem
  # anderen Laufwerk als --root wird bereitgestellt (siehe Get-TypstReadable).
  # Der Ausdruck enthaelt bewusst KEINE doppelten Anfuehrungszeichen:
  # Windows PowerShell 5.1 reicht sie an externe Programme nicht korrekt weiter.
  $probeExpr = '(str(query(<rfd-remote-skip>).len()),) + query(<rfd-image>).map(m => m.value).dedup()'
  $probeJson = & typst eval --in $Template $probeExpr `
    --font-path $FontDir --ignore-system-fonts --root $Root @inputs --input probe=true 2>$null
  $probe = @()
  try { $probe = @((($probeJson -join "`n") | ConvertFrom-Json) | ForEach-Object { $_ }) } catch { $probe = @() }
  $stripped = 0
  $imageMap = @{}
  if ($probe.Count -gt 0) {
    [void][int]::TryParse([string]$probe[0], [ref]$stripped)
    foreach ($raw in ($probe | Select-Object -Skip 1)) {
      $img = Expand-NotePath ([string]$raw)
      if (-not [IO.Path]::IsPathRooted($img)) { $img = Join-Path $baseDir $img }
      $img = [IO.Path]::GetFullPath($img)
      if (Test-Path -LiteralPath $img -PathType Leaf) {
        # Bild auf einem anderen Laufwerk: fuer Typst in die Installation kopieren
        $imageMap[[string]$raw] = ConvertTo-TypstPath (Get-TypstReadable $img)
      } else {
        Write-Warning "Bild nicht gefunden: $raw"
        $imageMap[[string]$raw] = ''
      }
    }
  }
  # Im Installordner statt im Temp-Ordner ablegen: Typst liest nur auf dem
  # Laufwerk von --root (= Laufwerk der Installation); %TEMP% kann woanders liegen.
  $imagesJson = Join-Path $InstallRoot ('.rfd-images-' + [Guid]::NewGuid().ToString('N') + '.json')
  [IO.File]::WriteAllText($imagesJson, ($imageMap | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding $false))
  $inputs += @('--input', ('images=' + (ConvertTo-TypstPath $imagesJson)))

  try {
    & typst compile $Template $outPdf `
      --font-path $FontDir --ignore-system-fonts `
      --root $Root `
      --pdf-standard a-3b `
      @inputs
    if ($LASTEXITCODE) { throw "typst-Fehler ($LASTEXITCODE)" }
  }
  finally {
    Remove-Item -LiteralPath $imagesJson -ErrorAction SilentlyContinue
    if ($script:StageDir) { Remove-Item -LiteralPath $script:StageDir -Recurse -Force -ErrorAction SilentlyContinue }
  }

  Write-Host "OK  $outPdf" -ForegroundColor Green
  if ($stripped -gt 0) {
    Write-Host "Hinweis: $stripped Remote-Bild(er) uebersprungen (kein Netzzugriff in Typst)." -ForegroundColor Yellow
  }

  # Erzeugte PDF automatisch oeffnen (immer). Opt-out ueber RFD_NO_OPEN=1.
  if (-not $env:RFD_NO_OPEN) { Start-Process -FilePath $outPdf }
}

try {
  if (-not (Get-Command 'typst' -ErrorAction SilentlyContinue)) {
    throw 'typst nicht gefunden. Installation: winget install --id Typst.Typst -e'
  }
  foreach ($p in $Path) { Convert-One $p }
}
catch {
  # Fehler auf stderr (Aufrufer wie Zettlr zeigen ihn an). Nur im interaktiven
  # "Senden an"-Fall auf Enter warten - mit ausdruecklicher Ausgabe oder
  # RFD_NO_OPEN laeuft das Skript unbeaufsichtigt und darf nicht haengen.
  [Console]::Error.WriteLine("Fehler: $($_.Exception.Message)")
  # Bereitstellung auch bei einem Abbruch vor dem Kompilieren entfernen
  if ($script:StageDir) { Remove-Item -LiteralPath $script:StageDir -Recurse -Force -ErrorAction SilentlyContinue }
  if (-not $ExplicitOut -and -not $env:RFD_NO_OPEN) { [void](Read-Host 'Enter zum Schliessen') }
  exit 1
}
