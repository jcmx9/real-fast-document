#!/usr/bin/env bash
# Dispatcher für die Rechtsklick-Integration (macOS Finder Quick Action /
# Linux .desktop). Wird mit einer oder mehreren .md-Dateien als Argumente
# aufgerufen, konvertiert jede via build.sh nach PDF/A (Ausgabe neben der Quelle)
# und meldet das Ergebnis per System-Notification. Terminal ist nicht nötig.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "${here}")"

# GUI-Start (Finder Quick Action / .desktop) erbt den Shell-PATH NICHT. install.sh
# hat das echte typst-Verzeichnis hier hinterlegt -> in den PATH holen.
if [[ -f "${root}/bin/rfd-tools.env" ]]; then
  # shellcheck disable=SC1091
  source "${root}/bin/rfd-tools.env"
  [[ -n "${RFD_TOOL_PATH:-}" ]] && export PATH="${RFD_TOOL_PATH}:${PATH}"
fi

# Gebündeltes typst-Binary (Linux-Fallback) bevorzugen, falls vorhanden.
if [[ -x "${root}/bin/typst" ]]; then
  export TYPST="${root}/bin/typst"
fi

notify() {
  local msg="$1"
  if [[ "$(uname -s)" == "Darwin" ]] && command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${msg}\" with title \"real·fast·document\"" >/dev/null 2>&1 || true
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "real·fast·document" "${msg}" || true
  fi
}

ok=0
fail=0
stripped=0
for f in "$@"; do
  # build.sh-Ausgabe abfangen (kein Terminal im GUI-Pfad), um daraus die Zahl
  # übersprungener Remote-Bilder zu lesen – sonst verschwänden sie unbemerkt.
  if log="$(bash "${root}/scripts/build.sh" "${f}" 2>&1)"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
  fi
  printf '%s\n' "${log}"
  n="$(printf '%s\n' "${log}" | grep -oE '[0-9]+ Remote-Bild' | head -1 | grep -oE '^[0-9]+' || true)"
  stripped=$((stripped + ${n:-0}))
done

msg="PDF/A: ${ok} erstellt, ${fail} fehlgeschlagen."
[[ "${stripped}" -gt 0 ]] && msg="${msg} ${stripped} Remote-Bild(er) übersprungen."
notify "${msg}"
[[ "${fail}" -eq 0 ]]
