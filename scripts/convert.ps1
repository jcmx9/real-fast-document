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

function Convert-One {
  param([string]$Src)

  $Src = (Resolve-Path -LiteralPath $Src).Path
  if ([IO.Path]::GetExtension($Src) -notin @('.md', '.markdown')) {
    throw "Keine Markdown-Datei: $Src"
  }

  $srcDir = Split-Path -Parent $Src
  $base   = [IO.Path]::GetFileNameWithoutExtension($Src)
  $mdLeaf = Split-Path -Leaf $Src
  $outPdf = Join-Path $srcDir "$base.pdf"
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
    Write-Host "Hinweis: kein Logo im Installpfad – baue ohne Logo." -ForegroundColor Yellow
  }

  try {
    & pandoc $Src --from markdown --to typst --standalone `
      --template $Template --lua-filter $LuaFilter `
      --syntax-highlighting pygments --output $typ
    if ($LASTEXITCODE) { throw "pandoc-Fehler ($LASTEXITCODE)" }

    & typst compile $typ $outPdf `
      --font-path $FontDir --ignore-system-fonts `
      --pdf-standard a-3b `
      --input "filename=$base.pdf" `
      --input "logo=$logoArg" `
      --input "source=$mdLeaf"
    if ($LASTEXITCODE) { throw "typst-Fehler ($LASTEXITCODE)" }

    Write-Host "OK  $outPdf" -ForegroundColor Green
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
