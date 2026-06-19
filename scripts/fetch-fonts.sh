#!/usr/bin/env bash
# Lädt die variablen OTF (CFF2) der Source-Familien nach ./fonts
# (Source Serif 4 / Sans 3 / Code Pro, je Roman/Upright + Italic) aus den
# Adobe-Upstream-Releases.
#
# Hinweis zur Quelle: Google Fonts (github.com/google/fonts) verteilt diese
# Familien ausschließlich als TTF; variable OTF gibt es nur bei Adobe.
#
# Typst >= 0.15 rendert variable OTF; die wght-Achse liefert den Semibold-
# Schnitt der Überschriften. Lizenz: SIL Open Font License 1.1.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
font_dir="${root_dir}/fonts"
mkdir -p "${font_dir}"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# Lädt ein Release-Zip und extrahiert die genannten Glob-Muster flach nach ./fonts.
fetch() {
  local url="$1"
  shift
  local zip
  zip="${tmp}/$(basename "${url}")"
  curl -fsSL "${url}" -o "${zip}"
  unzip -o -j "${zip}" "$@" -d "${font_dir}" >/dev/null
}

echo "→ Source Serif 4 (Roman + Italic)"
fetch "https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_Desktop.zip" \
  '*/VAR/SourceSerif4Variable-Roman.otf' '*/VAR/SourceSerif4Variable-Italic.otf'

echo "→ Source Sans 3 (Upright + Italic)"
fetch "https://github.com/adobe-fonts/source-sans/releases/download/3.052R/VF-source-sans-3.052R.zip" \
  'VF/SourceSans3VF-Upright.otf' 'VF/SourceSans3VF-Italic.otf'

echo "→ Source Code Pro (Upright + Italic)"
fetch "https://github.com/adobe-fonts/source-code-pro/releases/download/2.042R-u/1.062R-i/1.026R-vf/VF-source-code-VF-1.026R.zip" \
  'VF/SourceCodeVF-Upright.otf' 'VF/SourceCodeVF-Italic.otf'

echo "✓ Variable OTF in ${font_dir}"
