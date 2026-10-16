#!/usr/bin/env bash
# Baut aus einer Markdown-Datei ein PDF/A: Markdown -> Typst (cmarker) -> PDF/A-3b.
# Der Body wird vom Template selbst per cmarker aus der (vorverarbeiteten) Quelle
# erzeugt; Pandoc/pygments/Lua werden nicht mehr benötigt.
#
# Usage: scripts/build.sh [SOURCE.md] [OUTPUT.pdf]
set -euo pipefail

# Aufruf-Verzeichnis merken, BEVOR wir in den Projekt-Root wechseln: relative
# Quell-/Ziel-Pfade beziehen sich auf das Verzeichnis, aus dem der Nutzer das
# Skript (bzw. rf-document) aufgerufen hat – nicht auf den Projekt-Root, in den
# wir gleich für template/fonts cd'en. Ohne das schlägt `rf-document foo.md` aus
# einem beliebigen Ordner mit "file not found" fehl.
orig_pwd="$(pwd)"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root_dir}"

# Relativen Pfad gegen das Aufruf-Verzeichnis zu einem absoluten machen.
# Existiert er dort nicht, unverändert lassen (Default example.md liegt im Root,
# und ein klarer Fehler beim Lesen ist besser als stilles Umbiegen).
resolve_from_pwd() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  if [[ -e "${orig_pwd}/$1" ]]; then printf '%s' "${orig_pwd}/$1"; else printf '%s' "$1"; fi ;;
  esac
}

# GUI-Start (Finder/Editor/.desktop) erbt nicht den Shell-PATH: den vom
# Installer gemerkten typst-Ordner (bin/rfd-tools.env) selbst voranstellen und
# ein im Installpfad abgelegtes typst-Binary bevorzugen. So läuft build.sh auch
# mit minimalem PATH (/usr/bin:/bin), nicht nur über den rf-document-Wrapper.
if [[ -f "${root_dir}/bin/rfd-tools.env" ]]; then
  # shellcheck source=/dev/null
  source "${root_dir}/bin/rfd-tools.env"
  if [[ -n "${RFD_TOOL_PATH:-}" ]]; then PATH="${RFD_TOOL_PATH}:${PATH}"; fi
fi
if [[ -z "${TYPST:-}" && -x "${root_dir}/bin/typst" ]]; then TYPST="${root_dir}/bin/typst"; fi
# Typst-Binary überschreibbar (z. B. zum Testen einer bestimmten Version).
typst_bin="${TYPST:-typst}"

# ---------------------------------------------------------------------------
# CLI-Flags: --help / --version (vor dem Typst-Check, damit --help auch ohne
# installiertes typst funktioniert) und Build-Schalter. Flags dürfen vor den
# Positionsargumenten stehen; der Rest wird als [SOURCE.md] [OUTPUT.pdf] weitergereicht.
# ---------------------------------------------------------------------------
rfd_version="$(cat "${root_dir}/VERSION" 2>/dev/null || printf 'unknown')"

print_version() {
  printf 'rf-document %s\n' "${rfd_version}"
  # Typst-Version mit ausgeben (Pflicht >= 0.15) – nur wenn auffindbar.
  if command -v "${typst_bin}" >/dev/null 2>&1; then
    "${typst_bin}" --version 2>/dev/null || true
  fi
}

print_help() {
  cat <<EOF
rf-document ${rfd_version} — Markdown -> Corporate-PDF/A-3b (via Typst, kein Pandoc)

Usage:
  rf-document [OPTIONS] [SOURCE.md] [OUTPUT.pdf]
  bash scripts/build.sh [OPTIONS] [SOURCE.md] [OUTPUT.pdf]

Arguments:
  SOURCE.md    Zu rendernde Markdown-Quelle (Default: example.md)
  OUTPUT.pdf   Ausgabepfad, wird exakt so geschrieben. Ohne Angabe: neben der
               Quelle; ein 'date:' im Frontmatter stellt das ISO-Datum voran,
               z. B. 2026-06-19_SOURCE.pdf – abschaltbar mit 'isodate_praefix: false'

Options:
  --hard-breaks   Jede Zeile bleibt eine Zeile, wie im Editor getippt (Standard;
                  Frontmatter: hard_breaks: true)
  --soft-breaks   Einzelne Zeilenumbrüche werden zu Leerzeichen (CommonMark, für
                  umbrochenen Fließtext; Frontmatter: hard_breaks: false)
  --no-source     Markdown-Quelle NICHT ins PDF einbetten (z. B. für Kunden-PDFs;
                  Frontmatter: embed_source: false)
  -V, --version   rf-document- und Typst-Version ausgeben und beenden
  -h, --help      Diese Hilfe ausgeben und beenden

Optionale YAML-Frontmatter-Schlüssel:
  title, subtitle, client, author, date, isodate_praefix, toc, h1_break,
  print_filename, lang, header, watermark, logo, logo-height, embed_source,
  hard_breaks

Exit-Code 0 nur bei Erfolg; Fehler und Warnungen gehen auf stderr.

Environment:
  RFD_NO_OPEN=1         Das PDF nach dem Build nicht öffnen (Batch/Cron)
  RFD_BASE_DIR=ordner   Relative Bild-/Logopfade gelten relativ zu diesem Ordner
                        statt zum Ordner der Quelle (temporäre Kopie)
  TYPST=/pfad           Bestimmtes typst-Binary verwenden (>= 0.15 erforderlich)
EOF
}

cli_embed=""
cli_breaks=""
positional=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)    print_help; exit 0 ;;
    -V|--version) print_version; exit 0 ;;
    --no-source)  cli_embed="false"; shift ;;
    --hard-breaks) cli_breaks="true"; shift ;;
    --soft-breaks) cli_breaks="false"; shift ;;
    --)           shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done; break ;;
    -*)           printf 'Error: unbekannte Option %s\n' "$1" >&2
                  printf "Aufruf: rf-document --help\n" >&2; exit 2 ;;
    *)            positional+=("$1"); shift ;;
  esac
done
# Positionsargumente wiederherstellen (set-u-sicher, auch für bash 3.2/macOS).
if [ "${#positional[@]}" -gt 0 ]; then set -- "${positional[@]}"; else set --; fi

if ! command -v "${typst_bin}" >/dev/null 2>&1; then
  echo "Error: typst nicht gefunden (${typst_bin}). Installation: bash scripts/install.sh" >&2
  exit 1
fi
# Variable Fonts brauchen Typst >= 0.15.
ver="$("${typst_bin}" --version | awk '{print $2}')"
ver_major="${ver%%.*}"
ver_minor="${ver#*.}"; ver_minor="${ver_minor%%.*}"
if (( ver_major == 0 && ver_minor < 15 )); then
  echo "Error: Typst >= 0.15 nötig (Variable Fonts), gefunden ${ver}" >&2
  exit 1
fi

src="$(resolve_from_pwd "${1:-example.md}")"
if [[ ! -f "${src}" ]]; then
  echo "Error: Quelle nicht gefunden: ${src}" >&2
  exit 1
fi
base="$(basename "${src%.*}")"
standard="a-3b"

# ---------------------------------------------------------------------------
# Optionalen YAML-Frontmatter (führender ---...---) parsen, CRLF-tolerant.
# Bool-Schlüssel YAML-1.1 gelesen (siehe yaml_bool); ein erkannter Schlüssel mit
# ungültigem Wert warnt und behält den Default. Leere Werte ("" oder nichts)
# werden ignoriert, nie ein Fehler. Die Markdown-Vorverarbeitung selbst macht
# das Template (lib/markdown.typ), nicht dieses Skript.
# ---------------------------------------------------------------------------
# Einen YAML-Skalar zu "true"/"false" normalisieren (YAML-1.1-Boolean-Menge,
# Obsidian-kompatibel; Superset von YAML 1.2). Unbekannte Werte -> leer.
yaml_bool() {
  local v="$1"
  v="$(printf '%s' "${v}" | sed -e 's/[[:space:]]#.*$//' \
                                -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                                -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//" \
                                -e 's/[[:space:]]*$//')"
  case "$(printf '%s' "${v}" | tr '[:upper:]' '[:lower:]')" in
    true|yes|on|y)  printf 'true'  ;;
    false|no|off|n) printf 'false' ;;
    *)              printf ''       ;;
  esac
}

# Einen YAML-String-Skalar säubern: Whitespace weg; in Anführungszeichen gilt
# der Inhalt bis zum schließenden Zeichen, sonst wird ein Inline-Kommentar
# (" # …") abgeschnitten. Eine Inline-Liste [a, "b"] wird zu "a, b" (Autoren).
yaml_str() {
  local v
  v="$(printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  case "${v}" in
    \"*) v="${v#\"}"; v="${v%%\"*}" ;;
    \'*) v="${v#\'}"; v="${v%%\'*}" ;;
    \[*)
      v="${v#\[}"; v="${v%%\]*}"
      v="$(printf '%s' "${v}" | sed -e 's/["'\'']//g' -e 's/[[:space:]]*,[[:space:]]*/, /g' \
                                  -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      ;;
    *) v="$(printf '%s' "${v}" | sed -e 's/[[:space:]]#.*$//' -e 's/[[:space:]]*$//')" ;;
  esac
  printf '%s' "${v}"
}

# Bool-Schlüssel auswerten: gibt true/false (bzw. auto, wenn erlaubt) aus.
# Leerer Wert -> ignorieren (Exit 1, keine Warnung); ungültiger Wert ->
# Warnung + Exit 1, der Default bleibt.
fm_bool() {
  local key="$1" raw="$2" allow_auto="${3:-}" v b
  v="$(yaml_str "${raw}")"
  [[ -n "${v}" ]] || return 1
  if [[ -n "${allow_auto}" && "$(printf '%s' "${v}" | tr '[:upper:]' '[:lower:]')" == "auto" ]]; then
    printf 'auto'
    return 0
  fi
  b="$(yaml_bool "${v}")"
  if [[ -n "${b}" ]]; then printf '%s' "${b}"; return 0; fi
  echo "Warnung: ungültiger Wert für '${key}' im Frontmatter: '${v}' – ignoriert (true/false${allow_auto:+/auto})." >&2
  return 1
}

# Umgebungsvariable lesen; USER<->USERNAME und HOME<->USERPROFILE als Rückfall
# (Notizen, die unter Windows geschrieben wurden, und umgekehrt).
env_lookup() {
  local v
  v="$(printenv "$1" 2>/dev/null || true)"
  if [[ -z "${v}" ]]; then
    case "$1" in
      USER)        v="${USERNAME:-}" ;;
      USERNAME)    v="${USER:-}" ;;
      HOME)        v="${USERPROFILE:-}" ;;
      USERPROFILE) v="${HOME:-}" ;;
    esac
  fi
  printf '%s' "${v}"
}

# Pfad aus einer Notiz aufbereiten: ~, ${VAR}, $VAR und %VAR% ersetzen,
# %XX-Kodierung (z. B. %20) auflösen, Backslashes -> '/'. Ohne eval: es wird
# nichts ausgeführt, nur Variablen eingesetzt.
expand_path() {
  local p="$1" name hex guard=0
  # shellcheck disable=SC2088 # literales ~ am Pfadanfang erkennen, nicht expandieren
  case "${p}" in "~"|"~/"*|"~\\"*) p="$(env_lookup HOME)${p:1}" ;; esac
  # shellcheck disable=SC2016 # Regex für literale $-Variablen, keine Expansion gewollt
  local re_brace='\$\{([A-Za-z_][A-Za-z0-9_]*)\}' re_plain='\$([A-Za-z_][A-Za-z0-9_]*)'
  local re_win='%([A-Za-z_][A-Za-z0-9_]*)%' re_hex='%([0-9A-Fa-f]{2})'
  while [[ "${p}" =~ ${re_brace} ]] && (( guard++ < 20 )); do
    name="${BASH_REMATCH[1]}"; p="${p/"\${${name}}"/"$(env_lookup "${name}")"}"
  done
  while [[ "${p}" =~ ${re_plain} ]] && (( guard++ < 40 )); do
    name="${BASH_REMATCH[1]}"; p="${p/"\$${name}"/"$(env_lookup "${name}")"}"
  done
  while [[ "${p}" =~ ${re_win} ]] && (( guard++ < 60 )); do
    name="${BASH_REMATCH[1]}"; p="${p/"%${name}%"/"$(env_lookup "${name}")"}"
  done
  while [[ "${p}" =~ ${re_hex} ]] && (( guard++ < 200 )); do
    hex="${BASH_REMATCH[1]}"
    # shellcheck disable=SC2059 # \xHH aus geprüften Hex-Ziffern
    p="${p/"%${hex}"/"$(printf "\\x${hex}")"}"
  done
  printf '%s' "${p//\\//}"
}

# Frontmatter-Datum (ISO 2026-10-13 oder deutsch 13.10.2026) -> ISO; sonst leer.
iso_date() {
  local d="$1" re_iso='^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})$' re_de='^([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{4})$'
  if [[ "${d}" =~ ${re_iso} ]]; then
    printf '%s-%02d-%02d' "${BASH_REMATCH[1]}" "$((10#${BASH_REMATCH[2]}))" "$((10#${BASH_REMATCH[3]}))"
  elif [[ "${d}" =~ ${re_de} ]]; then
    printf '%s-%02d-%02d' "${BASH_REMATCH[3]}" "$((10#${BASH_REMATCH[2]}))" "$((10#${BASH_REMATCH[1]}))"
  fi
}

fm_date=""
fm_isodate_praefix=""
fm_toc="auto"
fm_break="auto"
fm_showname="true"
fm_lang="de"
fm_header=""
fm_watermark=""
fm_title=""
fm_subtitle=""
fm_client=""
fm_author=""
fm_logo=""
fm_logo_height=""
fm_embed="true"
fm_breaks="true"
if [[ "$(head -n 1 "${src}" | tr -d '\r')" == "---" ]]; then
  block="$(awk 'NR==1 { next } /^(---|\.\.\.)[[:space:]]*$/ { exit } { print }' "${src}" | tr -d '\r')"
  while IFS= read -r line; do
    case "${line}" in
      date:*)            fm_date="$(yaml_str "${line#date:}")" ;;
      isodate_praefix:*)
        if b="$(fm_bool isodate_praefix "${line#isodate_praefix:}")"; then fm_isodate_praefix="${b}"; fi
        ;;
      lang:*)
        v="$(yaml_str "${line#lang:}")"
        if [[ -n "${v}" ]]; then fm_lang="${v}"; fi
        ;;
      header:*)          fm_header="$(yaml_str "${line#header:}")" ;;
      watermark:*)       fm_watermark="$(yaml_str "${line#watermark:}")" ;;
      toc:*)
        if b="$(fm_bool toc "${line#toc:}" auto)"; then fm_toc="${b}"; fi
        ;;
      h1_break:*)
        if b="$(fm_bool h1_break "${line#h1_break:}" auto)"; then fm_break="${b}"; fi
        ;;
      title:*)           fm_title="$(yaml_str "${line#title:}")" ;;
      subtitle:*)        fm_subtitle="$(yaml_str "${line#subtitle:}")" ;;
      client:*)          fm_client="$(yaml_str "${line#client:}")" ;;
      author:*)          fm_author="$(yaml_str "${line#author:}")" ;;
      logo:*)            fm_logo="$(yaml_str "${line#logo:}")" ;;
      logo-height:*)     fm_logo_height="$(yaml_str "${line#logo-height:}")" ;;
      print_filename:*)
        if b="$(fm_bool print_filename "${line#print_filename:}")"; then fm_showname="${b}"; fi
        ;;
      hard_breaks:*)
        if b="$(fm_bool hard_breaks "${line#hard_breaks:}")"; then fm_breaks="${b}"; fi
        ;;
      embed_source:*)
        if b="$(fm_bool embed_source "${line#embed_source:}")"; then fm_embed="${b}"; fi
        ;;
    esac
  done <<< "${block}"
fi
# Die CLI-Optionen gewinnen über das Frontmatter.
if [[ -n "${cli_embed}" ]]; then fm_embed="${cli_embed}"; fi
if [[ -n "${cli_breaks}" ]]; then fm_breaks="${cli_breaks}"; fi

# ---------------------------------------------------------------------------
# Ausgabepfad: explizites zweites Argument gewinnt (relativ zum Aufruf-Verz.)
# und wird exakt so geschrieben. Sonst NEBEN der Quelle; bei erkennbarem Datum
# mit ISO-Präfix (sortierbar), außer 'isodate_praefix: false' schaltet das
# Präfix ab (Datum bleibt in der Fußzeile).
# ---------------------------------------------------------------------------
src_dir="$(cd "$(dirname "${src}")" && pwd)"
src_abs="${src_dir}/$(basename "${src}")"

# Basisordner für relative Bild- und Logopfade: RFD_BASE_DIR, falls gesetzt
# (Editoren übergeben bei ungespeicherten Änderungen eine temporäre Kopie der
# Notiz, die Bilder liegen aber neben dem Original), sonst der Ordner der Quelle.
# Ein relativer RFD_BASE_DIR gilt relativ zum Aufrufverzeichnis.
base_dir="${src_dir}"
if [[ -n "${RFD_BASE_DIR:-}" ]]; then
  case "${RFD_BASE_DIR}" in /*) cand="${RFD_BASE_DIR}" ;; *) cand="${orig_pwd}/${RFD_BASE_DIR}" ;; esac
  if [[ -d "${cand}" ]]; then
    base_dir="$(cd "${cand}" && pwd)"
  else
    echo "Warnung: RFD_BASE_DIR ist kein Ordner: ${RFD_BASE_DIR} – nutze den Ordner der Quelle." >&2
  fi
fi
date_iso="$(iso_date "${fm_date}")"
if [[ -n "${2:-}" ]]; then
  case "${2}" in
    /*) out="${2}" ;;
    *)  out="${orig_pwd}/${2}" ;;
  esac
elif [[ -n "${date_iso}" && "${fm_isodate_praefix}" != "false" ]]; then
  out="${src_dir}/${date_iso}_${base}.pdf"
else
  out="${src_dir}/${base}.pdf"
fi

# Logo nur mit logo: im Frontmatter (ohne Schlüssel oder leer: kein Logo). Der
# Wert ist eine Datei .svg/.png/.jpg/.jpeg. Absolut (auch über ~ oder $HOME) ->
# genau diese Datei; relativ -> zuerst im Ordner der Notiz (bzw. RFD_BASE_DIR),
# dann im Benutzerordner, dann im Programmordner. Nichts gefunden -> ohne Logo,
# nur ein Hinweis, nie ein Fehler.
logo=""
if [[ -n "${fm_logo}" ]]; then
  ext="$(printf '%s' "${fm_logo##*.}" | tr '[:upper:]' '[:lower:]')"
  case "${fm_logo}" in
    http://*|https://*|//*|data:*)
      echo "Hinweis: Remote-Logo wird nicht geladen (kein Netzzugriff): ${fm_logo}" >&2 ;;
    *)
      case "${ext}" in
        svg|png|jpg|jpeg)
          note_logo="$(expand_path "${fm_logo}")"
          case "${note_logo}" in
            /*) [[ -f "${note_logo}" ]] && logo="${note_logo}" ;;
            *)
              for dir in "${base_dir}" "${HOME:-}" "${root_dir}"; do
                if [[ -n "${dir}" && -f "${dir}/${note_logo}" ]]; then
                  logo="${dir}/${note_logo}"
                  break
                fi
              done
              ;;
          esac
          [[ -n "${logo}" ]] ||
            echo "Hinweis: Logo nicht gefunden: ${fm_logo} – baue ohne Logo." >&2
          ;;
        *)
          echo "Hinweis: Logo muss .svg, .png, .jpg oder .jpeg sein: ${fm_logo} – baue ohne Logo." >&2 ;;
      esac
      ;;
  esac
fi

font_arg=()
[[ -d fonts ]] && font_arg=(--font-path fonts --ignore-system-fonts)

attach=""
if [[ "${fm_embed}" != "false" ]]; then attach="${src_abs}"; fi

# Laufzeit-Eingaben fürs Template. --root / : Typst behandelt absolute Pfade
# projektwurzel-relativ und sperrt Lesezugriffe außerhalb; für Quelle, Bilder
# und Logo (die überall liegen können) muss die Wurzel den absoluten Pfad umfassen.
# title = Rückfall-Metadatentitel (.md-Basisname); doctitle = Frontmatter title:.
typst_inputs=(
  --input "filename=$(basename "${out}")"
  --input "title=${base}"
  --input "doctitle=${fm_title}"
  --input "subtitle=${fm_subtitle}"
  --input "client=${fm_client}"
  --input "author=${fm_author}"
  --input "logo=${logo}"
  --input "logo_height=${fm_logo_height}"
  --input "source=${src_abs}"
  --input "attach=${attach}"
  --input "docdir=${base_dir}"
  --input "date=${fm_date}"
  --input "toc=${fm_toc}"
  --input "h1_break=${fm_break}"
  --input "showname=${fm_showname}"
  --input "lang=${fm_lang}"
  --input "header=${fm_header}"
  --input "watermark=${fm_watermark}"
  --input "hard_breaks=${fm_breaks}"
)

# Reproduzierbarer Metadaten-Zeitstempel: ohne Frontmatter-date: nutzt das Template
# date: auto -> Typst schriebe sonst den *Build-Zeitpunkt* in CreateDate/ModifyDate.
# SOURCE_DATE_EPOCH (Quell-mtime) macht das deterministisch = letzte Änderungszeit
# der Quelle statt "jetzt"; Typst respektiert die Variable für date: auto. Ist ein
# date: gesetzt, pinnt das Template direkt und ignoriert dies. Ein vom Aufrufer
# gesetzter Wert gewinnt. stat unterscheidet sich zwischen GNU und BSD, und die
# Flags kollidieren: GNU 'stat -f' bedeutet *Dateisystem-Status* (liefert für eine
# gültige Datei einen mehrzeiligen Blob mit Exit 0!), BSD 'stat -f %m' die mtime.
# Daher GNU (-c %Y) ZUERST versuchen (schlägt auf BSD sauber fehl -> Fallback auf
# BSD -f %m); Ergebnis defensiv auf reine Ziffern prüfen, sonst 0.
if [[ -z "${SOURCE_DATE_EPOCH:-}" ]]; then
  src_epoch="$(stat -c %Y "${src}" 2>/dev/null || stat -f %m "${src}" 2>/dev/null || echo 0)"
  [[ "${src_epoch}" =~ ^[0-9]+$ ]] || src_epoch=0
  SOURCE_DATE_EPOCH="${src_epoch}"
fi
export SOURCE_DATE_EPOCH

# ---------------------------------------------------------------------------
# Bilder prüfen (Probe-Durchlauf). Typst kann weder Umgebungsvariablen lesen noch
# prüfen, ob eine Datei existiert – ein fehlendes Bild bräche den Build ab. Daher:
# Template im Probe-Modus (lädt keine Bilder) per `typst eval` nach allen
# Bildquellen fragen (+ Zahl der Remote-Bilder), hier ~/$VAR/${VAR}/%VAR%
# ersetzen, relativ zur Notiz auflösen, Existenz prüfen und die Zuordnung als
# JSON übergeben. Fehlende Bilder erscheinen im PDF als „[Bild fehlt: pfad]".
# ---------------------------------------------------------------------------
images_json="$(mktemp -t rfd-images.XXXXXX)"
cleanup() { rm -f "${images_json}"; }
trap cleanup EXIT

# JSON-String-Literal aus typst eval in Klartextzeilen zerlegen (\n, \t, \",
# \\ und \/ werden aufgelöst; \uXXXX kommt in Pfaden praktisch nicht vor).
json_string_lines() {
  awk '{
    s = $0; sub(/^[ \t]*"/, "", s); sub(/"[ \t]*$/, "", s)
    out = ""; n = length(s); i = 1
    while (i <= n) {
      c = substr(s, i, 1)
      if (c == "\\") {
        d = substr(s, i + 1, 1)
        if (d == "n") out = out "\n"
        else if (d == "t") out = out "\t"
        else if (d == "u") { out = out "?"; i += 4 }
        else out = out d
        i += 2
      } else { out = out c; i++ }
    }
    printf "%s", out
  }'
}

json_escape() {
  local v="$1"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  v="${v//$'\t'/\\t}"
  printf '"%s"' "${v}"
}

probe_expr='str(query(<rfd-remote-skip>).len()) + "\n" + query(<rfd-image>).map(m => m.value + "\n").dedup().sum(default: "")'
probe="$("${typst_bin}" eval --in template.typ "${probe_expr}" \
  "${font_arg[@]}" --root / "${typst_inputs[@]}" --input probe=true 2>/dev/null || true)"
stripped=0
image_entries=""
first=1
while IFS= read -r raw; do
  if (( first )); then stripped="${raw:-0}"; first=0; continue; fi
  [[ -n "${raw}" ]] || continue
  img="$(expand_path "${raw}")"
  case "${img}" in /*) ;; *) img="${base_dir}/${img}" ;; esac
  if [[ -f "${img}" ]]; then
    resolved="$(json_escape "${img}")"
  else
    echo "Warnung: Bild nicht gefunden: ${raw}" >&2
    resolved='""'
  fi
  image_entries="${image_entries:+${image_entries},}$(json_escape "${raw}"): ${resolved}"
done < <(printf '%s' "${probe}" | json_string_lines)
[[ "${stripped}" =~ ^[0-9]+$ ]] || stripped=0
printf '{%s}\n' "${image_entries}" > "${images_json}"
typst_inputs+=(--input "images=${images_json}")

# Markdown -> PDF/A-3b (Template ruft cmarker auf der vorverarbeiteten Quelle).
"${typst_bin}" compile template.typ "${out}" \
  "${font_arg[@]}" \
  --root / \
  --pdf-standard "${standard}" \
  "${typst_inputs[@]}"

echo "✓ ${out} erzeugt (PDF/A-3b)"
# Remote-Bilder zählt der Probe-Durchlauf oben (<rfd-remote-skip>); die Zeile
# ist der Parse-Vertrag für rfd-convert.sh – nicht umformulieren.
if [[ "${stripped:-0}" -gt 0 ]]; then
  echo "Hinweis: ${stripped} Remote-Bild(er) übersprungen (kein Netzzugriff in Typst)."
fi

# Erzeugte PDF automatisch öffnen (immer). Opt-out über RFD_NO_OPEN=1 (z. B. für
# Batch-/Cron-Läufe). Im Hintergrund gestartet, damit das Skript sofort endet.
if [[ -z "${RFD_NO_OPEN:-}" ]]; then
  case "$(uname -s)" in
    Darwin) opener="open" ;;
    *)      opener="xdg-open" ;;
  esac
  if command -v "${opener}" >/dev/null 2>&1; then
    "${opener}" "${out}" >/dev/null 2>&1 &
  fi
fi
