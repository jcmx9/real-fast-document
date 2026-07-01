#!/usr/bin/env bash
# Ein-Zeiler-Bootstrap für real-fast-document (macOS/Linux).
#
#   curl -fsSL https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.sh | bash
#
# Klont das Repo nach ~/.local/share/real-fast-document (oder aktualisiert es per
# git pull) und ruft scripts/install.sh auf: Werkzeug (typst) über den
# Paketmanager, Fonts + Typst-Packages ins Projekt, Rechtsklick-Integration.
# Einzige Vorbedingung ist ein installiertes git. Zielordner via RFD_HOME.
set -euo pipefail

repo_url="https://github.com/jcmx9/real-fast-document.git"
install_dir="${RFD_HOME:-${XDG_DATA_HOME:-${HOME}/.local/share}/real-fast-document}"

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git nicht gefunden – bitte zuerst git installieren." >&2
  case "$(uname -s)" in
    Darwin) echo "  macOS: xcode-select --install   (oder: brew install git)" >&2 ;;
    Linux)  echo "  Linux: sudo apt install git  /  sudo dnf install git  /  sudo pacman -S git" >&2 ;;
  esac
  exit 1
fi

if [[ -d "${install_dir}/.git" ]]; then
  echo "→ Aktualisiere ${install_dir}"
  git -C "${install_dir}" pull --ff-only
else
  echo "→ Klone real-fast-document nach ${install_dir}"
  mkdir -p "$(dirname "${install_dir}")"
  git clone --depth 1 "${repo_url}" "${install_dir}"
fi

echo "→ Starte Einrichtung"
exec bash "${install_dir}/scripts/install.sh" "$@"
