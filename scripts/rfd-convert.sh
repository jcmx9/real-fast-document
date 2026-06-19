#!/usr/bin/env bash
# Dispatcher für die Rechtsklick-Integration (macOS Finder Quick Action /
# Linux .desktop). Wird mit einer oder mehreren .md-Dateien als Argumente
# aufgerufen, konvertiert jede via build.sh nach PDF/A (Ausgabe neben der Quelle)
# und meldet das Ergebnis per System-Notification. Terminal ist nicht nötig.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "${here}")"

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
for f in "$@"; do
  if bash "${root}/scripts/build.sh" "${f}"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
  fi
done

notify "PDF/A: ${ok} erstellt, ${fail} fehlgeschlagen."
[[ "${fail}" -eq 0 ]]
