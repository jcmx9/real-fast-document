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

# Typst-Binary überschreibbar (z. B. zum Testen einer bestimmten Version).
typst_bin="${TYPST:-typst}"

# Variable Fonts brauchen Typst >= 0.15.
ver="$("${typst_bin}" --version | awk '{print $2}')"
ver_major="${ver%%.*}"
ver_minor="${ver#*.}"; ver_minor="${ver_minor%%.*}"
if (( ver_major == 0 && ver_minor < 15 )); then
  echo "Error: Typst >= 0.15 nötig (Variable Fonts), gefunden ${ver}" >&2
  exit 1
fi

src="$(resolve_from_pwd "${1:-example.md}")"
base="$(basename "${src%.*}")"
standard="a-3b"

# Vorverarbeitete Render-Quelle: Frontmatter wird für Typst entfernt, loose
# Task-Listen zu tight normalisiert (cmarker 0.1.9 crasht sonst; Upstream-Fix in SabrinaJewson/cmarker.typ#71, noch nicht > 0.1.9 released) und Pandoc-
# Definitionslisten in HTML <dl> übersetzt (cmarker kennt nur <dl>). Die
# EINGEBETTETE Quelle (pdf.attach) bleibt die unveränderte Original-.md.
render_tmp="$(mktemp -t rfd-render.XXXXXX)"
cleanup() { rm -f "${render_tmp}"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Optionalen YAML-Frontmatter (führender ---...---) parsen: date/toc/h2-break/
# print_filename/lang, CRLF-tolerant. Die Bool-Schlüssel werden YAML-1.1-konform
# gelesen (siehe yaml_bool); ein erkannter Schlüssel mit ungültigem Wert warnt
# und behält den Default.
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

# Einen YAML-String-Skalar säubern (Whitespace + umschließende Quotes weg).
yaml_str() {
  printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                         -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//"
}

fm_date=""
fm_toc="auto"
fm_break="auto"
fm_showname="true"
fm_lang="de"
if [[ "$(head -n 1 "${src}" | tr -d '\r')" == "---" ]]; then
  block="$(awk 'NR==1 { next } /^---[[:space:]]*$/ { exit } { print }' "${src}" | tr -d '\r')"
  while IFS= read -r line; do
    case "${line}" in
      date:*)
        fm_date="$(yaml_str "${line#date:}")"
        ;;
      lang:*)
        v="$(yaml_str "${line#lang:}")"
        if [[ -n "${v}" ]]; then fm_lang="${v}"; fi
        ;;
      toc:*)
        b="$(yaml_bool "${line#toc:}")"
        if [[ -n "${b}" ]]; then fm_toc="${b}"
        else echo "Warnung: ungültiger Wert für 'toc' im Frontmatter: '${line#toc:}' – ignoriert (true/false)." >&2; fi
        ;;
      h2-break:*)
        b="$(yaml_bool "${line#h2-break:}")"
        if [[ -n "${b}" ]]; then fm_break="${b}"
        else echo "Warnung: ungültiger Wert für 'h2-break' im Frontmatter: '${line#h2-break:}' – ignoriert (true/false)." >&2; fi
        ;;
      print_filename:*)
        b="$(yaml_bool "${line#print_filename:}")"
        if [[ -n "${b}" ]]; then fm_showname="${b}"
        else echo "Warnung: ungültiger Wert für 'print_filename' im Frontmatter: '${line#print_filename:}' – ignoriert (true/false)." >&2; fi
        ;;
    esac
  done <<< "${block}"
fi

# ---------------------------------------------------------------------------
# Preprocessing: Frontmatter strippen, Task-Listen tighten, Deflisten -> <dl>.
# ---------------------------------------------------------------------------
awk '
function is_blank(s) { return s ~ /^[ \t]*$/ }
function is_task(s)  { return s ~ /^[ \t]*[-*+][ \t]+\[[ xX]\]/ }
{
  line = $0
  sub(/\r$/, "", line)                                   # CRLF-tolerant
  if (NR == 1 && line ~ /^---[ \t]*$/) { fm = 1; next }  # Frontmatter-Start
  if (fm == 1) { if (line ~ /^(---|\.\.\.)[ \t]*$/) fm = 0; next }
  L[++n] = line
}
END {
  i = 1
  while (i <= n) {
    # Definitionsliste: Begriff (Blockanfang) + Folgezeile ": Definition".
    # Ausgabe als HTML <dl> in Block-Form (Leerzeile nach <dd>, damit Inline-
    # Markdown in der Definition rendert – inline crasht cmarker es zu Literal).
    if (!is_blank(L[i]) && L[i] !~ /^:/ && (i == 1 || is_blank(L[i-1])) \
        && i+1 <= n && L[i+1] ~ /^:[ \t]+/) {
      print "<dl>"
      while (1) {
        if (is_blank(L[i]) || L[i] ~ /^:/ || i+1 > n || L[i+1] !~ /^:[ \t]+/) break
        term = L[i]
        def = L[i+1]; sub(/^:[ \t]+/, "", def)
        print "<dt>" term "</dt>"
        print "<dd>"
        print ""
        print def
        print "</dd>"
        i += 2
        j = i; while (j <= n && is_blank(L[j])) j++          # Leerzeilen zwischen Paaren
        if (j <= n && L[j] !~ /^:/ && j+1 <= n && L[j+1] ~ /^:[ \t]+/) i = j
      }
      print "</dl>"
      continue
    }
    # Loose Task-Liste -> tight: Leerzeile entfernen, wenn die umgebenden
    # nicht-leeren Zeilen beide Task-Items sind.
    if (is_blank(L[i])) {
      p = i-1; while (p >= 1 && is_blank(L[p])) p--
      q = i+1; while (q <= n && is_blank(L[q])) q++
      if (p >= 1 && q <= n && is_task(L[p]) && is_task(L[q])) { i++; continue }
    }
    print L[i]
    i++
  }
}
' "${src}" > "${render_tmp}"

# ---------------------------------------------------------------------------
# Ausgabepfad: explizites zweites Argument gewinnt (relativ zum Aufruf-Verz.).
# Sonst NEBEN der Quelle; bei gesetztem Datum mit ISO-Präfix (sortierbar).
# ---------------------------------------------------------------------------
src_dir="$(cd "$(dirname "${src}")" && pwd)"
src_abs="${src_dir}/$(basename "${src}")"
if [[ -n "${2:-}" ]]; then
  case "${2}" in
    /*) out="${2}" ;;
    *)  out="${orig_pwd}/${2}" ;;
  esac
elif [[ -n "${fm_date}" ]]; then
  out="${src_dir}/${fm_date}_${base}.pdf"
else
  out="${src_dir}/${base}.pdf"
fi

# Logo: erstes vorhandenes in fester Reihenfolge svg -> png -> jpg.
logo=""
for candidate in logo.svg logo.png logo.jpg; do
  if [[ -f "${candidate}" ]]; then
    logo="${candidate}"
    break
  fi
done
if [[ -z "${logo}" ]]; then
  echo "Hinweis: kein Logo gefunden (logo.svg | logo.png | logo.jpg) – baue ohne Logo." >&2
fi

font_arg=()
[[ -d fonts ]] && font_arg=(--font-path fonts --ignore-system-fonts)

# Laufzeit-Eingaben fürs Template. --root / : Typst behandelt absolute Pfade
# projektwurzel-relativ und sperrt Lesezugriffe außerhalb; für die eingebettete
# Quelle (die überall liegen kann) muss die Wurzel den absoluten Pfad umfassen.
# title = .md-Basisname (PDF/A verlangt einen Dokumenttitel).
typst_inputs=(
  --input "filename=$(basename "${out}")"
  --input "title=${base}"
  --input "logo=${logo}"
  --input "source=${render_tmp}"
  --input "attach=${src_abs}"
  --input "docdir=${src_dir}"
  --input "date=${fm_date}"
  --input "toc=${fm_toc}"
  --input "h2-break=${fm_break}"
  --input "showname=${fm_showname}"
  --input "lang=${fm_lang}"
)

# Markdown -> PDF/A-3b (Template ruft cmarker auf der vorverarbeiteten Quelle).
"${typst_bin}" compile template.typ "${out}" \
  "${font_arg[@]}" \
  --root / \
  --pdf-standard "${standard}" \
  "${typst_inputs[@]}"

# Übersprungene Remote-Bilder zählen: das Template markiert jedes gestrippte
# Bild mit einem unsichtbaren Metadatum <rfd-remote-skip>; per `typst query`
# auslesen (gleiche Inputs, damit die Kompilierung identisch ist).
stripped="$("${typst_bin}" query template.typ "<rfd-remote-skip>" \
  "${font_arg[@]}" --root / --field value "${typst_inputs[@]}" 2>/dev/null \
  | grep -o 'rfd-remote-skip' | wc -l | tr -d ' ' || true)"

echo "✓ ${out} erzeugt (PDF/A-3b)"
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
