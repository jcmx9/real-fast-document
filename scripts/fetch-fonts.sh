#!/usr/bin/env bash
# Lädt die benötigten Variable Fonts nach ./fonts (Source Serif 4 / Sans 3 /
# Code Pro, je Roman + Italic) von Google Fonts.
#
# Typst >= 0.15 unterstützt Variable Fonts; die wght-Achse liefert u. a. den
# Semibold-Schnitt der Überschriften. Lizenz: SIL Open Font License 1.1.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
font_dir="${root_dir}/fonts"
base="https://raw.githubusercontent.com/google/fonts/main/ofl"

mkdir -p "${font_dir}"

fonts=(
  "sourceserif4/SourceSerif4[opsz,wght].ttf"
  "sourceserif4/SourceSerif4-Italic[opsz,wght].ttf"
  "sourcesans3/SourceSans3[wght].ttf"
  "sourcesans3/SourceSans3-Italic[wght].ttf"
  "sourcecodepro/SourceCodePro[wght].ttf"
  "sourcecodepro/SourceCodePro-Italic[wght].ttf"
)

url_encode() {
  printf '%s' "$1" | sed 's/\[/%5B/g; s/\]/%5D/g'
}

for rel in "${fonts[@]}"; do
  out="${font_dir}/$(basename "${rel}")"
  url="${base}/$(url_encode "${rel}")"
  echo "→ ${out##*/}"
  curl -fsSL "${url}" -o "${out}"
done

echo "✓ Variable Fonts in ${font_dir}"
