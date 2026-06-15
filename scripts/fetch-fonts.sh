#!/usr/bin/env bash
# Bündelt die benötigten *statischen* Source-Fonts (Adobe OTF) nach ./fonts.
# Typst 0.14 unterstützt KEINE Variable Fonts – daher statische Schnitte.
#
# Strategie: zuerst aus den systemweit installierten Fonts kopieren
# (~/Library/Fonts, /Library/Fonts). Sind sie dort nicht vorhanden, von den
# offiziellen Adobe-Releases laden:
#   https://github.com/adobe-fonts/source-serif/releases
#   https://github.com/adobe-fonts/source-sans/releases
#   https://github.com/adobe-fonts/source-code-pro/releases
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
font_dir="${root_dir}/fonts"
mkdir -p "${font_dir}"

# Nur die Basis-Familien (kein Caption/Display/SmText/Subhead), nur statische OTF.
# Pattern matcht z. B. SourceSerif4-Semibold.otf, SourceSans3-It.otf, ...
patterns=(
  'SourceSerif4-*.otf'
  'SourceSans3-*.otf'
  'SourceCodePro-*.otf'
)

search_dirs=("${HOME}/Library/Fonts" "/Library/Fonts")
copied=0

for pat in "${patterns[@]}"; do
  for dir in "${search_dirs[@]}"; do
    [[ -d "${dir}" ]] || continue
    while IFS= read -r -d '' f; do
      cp -f "${f}" "${font_dir}/"
      copied=$((copied + 1))
    done < <(find "${dir}" -maxdepth 1 -name "${pat}" -print0 2>/dev/null)
  done
done

if [[ "${copied}" -eq 0 ]]; then
  echo "✗ Keine statischen Source-Fonts im System gefunden." >&2
  echo "  Bitte von den Adobe-Releases (siehe Script-Header) laden und nach" >&2
  echo "  ${font_dir} entpacken (Basis-Familien, statische OTF)." >&2
  exit 1
fi

echo "✓ ${copied} Font-Dateien nach ${font_dir} kopiert"
