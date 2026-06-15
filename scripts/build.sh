#!/usr/bin/env bash
# Baut aus einer Markdown-Datei ein PDF/A: Markdown -> Pandoc (+Lua) -> Typst -> PDF/A-3b.
#
# Usage: scripts/build.sh [SOURCE.md] [OUTPUT.pdf]
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root_dir}"

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

src="${1:-example.md}"
base="$(basename "${src%.*}")"
out="${2:-${base}.pdf}"
typ="${base}.typ"
standard="a-3b"

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
pandoc "${src}" \
  --from markdown \
  --to typst \
  --standalone \
  --template template.typ \
  --lua-filter filters/meta-from-h1.lua \
  --syntax-highlighting pygments \
  --output "${typ}"

# 2) Typst -> PDF/A-3b (Dateiname & Logo als Laufzeit-Inputs)
"${typst_bin}" compile "${typ}" "${out}" \
  "${font_arg[@]}" \
  --pdf-standard "${standard}" \
  --input "filename=$(basename "${out}")" \
  --input "logo=${logo}" \
  --input "source=${src}"

echo "✓ ${out} erzeugt (PDF/A-3b)"
