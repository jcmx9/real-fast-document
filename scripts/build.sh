#!/usr/bin/env bash
# Baut aus einer Markdown-Datei ein PDF/A: Markdown -> Pandoc (+Lua) -> Typst -> PDF/A-3b.
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
typ="${base}.typ"
standard="a-3b"

# Einen YAML-Skalar zu "true"/"false" normalisieren (YAML-1.1-Boolean-Menge,
# Obsidian-kompatibel; Superset von YAML 1.2). Akzeptiert true/false/yes/no/on/
# off/y/n in beliebiger Groß-/Kleinschreibung, entfernt umschließende Quotes und
# einen Inline-Kommentar (` # ...`). Unbekannte Werte -> leer (Aufrufer warnt).
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

# Optionalen YAML-Frontmatter (führender ---...---) parsen: nur diese vier
# Schlüssel, CRLF-tolerant. toc/h2-break/filename werden YAML-1.1-konform als
# Boolean gelesen (siehe yaml_bool); ein erkannter Schlüssel mit ungültigem Wert
# warnt und behält den Default. (if-Blöcke statt `[[ ]] && x=`, sonst beendet
# set -e das Skript, sobald eine Bedingung falsch ist.)
fm_date=""
fm_toc="auto"
fm_break="auto"
fm_showname="true"
if [[ "$(head -n 1 "${src}" | tr -d '\r')" == "---" ]]; then
  block="$(awk 'NR==1 { next } /^---[[:space:]]*$/ { exit } { print }' "${src}" | tr -d '\r')"
  while IFS= read -r line; do
    case "${line}" in
      date:*)
        fm_date="$(printf '%s' "${line#date:}" \
          | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//")"
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
      filename:*)
        b="$(yaml_bool "${line#filename:}")"
        if [[ -n "${b}" ]]; then fm_showname="${b}"
        else echo "Warnung: ungültiger Wert für 'filename' im Frontmatter: '${line#filename:}' – ignoriert (true/false)." >&2; fi
        ;;
    esac
  done <<< "${block}"
fi

# Ausgabe: explizites zweites Argument gewinnt (relativ zum aktuellen Verzeichnis).
# Sonst landet die PDF NEBEN der Quelle (nicht im Projekt-Root, in den build.sh
# für template/fonts cd't); bei gesetztem Datum mit ISO-Präfix (sortierbar).
src_dir="$(cd "$(dirname "${src}")" && pwd)"
src_abs="${src_dir}/$(basename "${src}")"
if [[ -n "${2:-}" ]]; then
  # Zielpfad existiert noch nicht -> immer gegen das Aufruf-Verzeichnis (nicht
  # die Existenzprüfung von resolve_from_pwd, die für Lese-Pfade gedacht ist).
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
# Optional: ohne Logo wird ohne Logo gebaut (logo bleibt leer).
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

# 1) Markdown -> Typst (Layout aus template.typ, Titel aus erstem H1 via Lua)
# Highlight-Flag je nach pandoc-Version: neuere kennen --syntax-highlighting,
# ältere (z. B. Debian-stable, 3.1.x) nur das ältere --highlight-style. Eines
# passt immer; so vermeiden wir sowohl Fehler als auch Deprecation-Warnungen.
hl_flag=(--highlight-style pygments)
if pandoc --help 2>&1 | grep -q -- '--syntax-highlighting'; then
  hl_flag=(--syntax-highlighting pygments)
fi

pandoc "${src}" \
  --from markdown \
  --to typst \
  --standalone \
  --template template.typ \
  --lua-filter filters/meta-from-h1.lua \
  "${hl_flag[@]}" \
  --output "${typ}"

# 2) Typst -> PDF/A-3b (Dateiname & Logo als Laufzeit-Inputs)
# --root / : Typst behandelt absolute Pfade projektwurzel-relativ und sperrt
# Lesezugriffe außerhalb der Wurzel; für die eingebettete Quelle (die überall
# liegen kann) muss die Wurzel den absoluten Quellpfad einschließen.
"${typst_bin}" compile "${typ}" "${out}" \
  "${font_arg[@]}" \
  --root / \
  --pdf-standard "${standard}" \
  --input "filename=$(basename "${out}")" \
  --input "logo=${logo}" \
  --input "source=${src_abs}" \
  --input "date=${fm_date}" \
  --input "toc=${fm_toc}" \
  --input "h2-break=${fm_break}" \
  --input "showname=${fm_showname}"

echo "✓ ${out} erzeugt (PDF/A-3b)"
