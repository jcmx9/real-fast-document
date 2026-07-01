#!/usr/bin/env bash
# Lädt die Typst-Packages cmarker (Markdown -> Typst) und mitex (LaTeX-Math ->
# Typst) aus der Typst-Preview-Registry nach ./vendor und importiert sie im
# Template per Relativpfad. So bleibt der Build nach der Installation offline und
# reproduzierbar (kein Registry-Zugriff zur Build-Zeit) – analog zu den
# gebündelten Fonts in ./fonts.
#
# Beide Packages sind self-contained (eigene *.wasm, nur lokale Imports); es
# genügt, ihren Inhalt flach ins jeweilige vendor-Verzeichnis zu entpacken.
set -euo pipefail

# Versionen zentral gepinnt (mit template.typ-Import konsistent halten).
CMARKER_VERSION="0.1.9"
MITEX_VERSION="0.2.7"

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vendor_dir="${root_dir}/vendor"
mkdir -p "${vendor_dir}"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# Lädt ein Package-Tarball aus der Registry und entpackt es flach nach
# ./vendor/<name> (die Tarballs tragen die Package-Dateien im Wurzelverzeichnis).
fetch_pkg() {
  local name="$1" version="$2"
  local url="https://packages.typst.org/preview/${name}-${version}.tar.gz"
  local dest="${vendor_dir}/${name}"
  local tgz="${tmp}/${name}-${version}.tar.gz"
  echo "→ ${name} ${version}"
  curl -fsSL "${url}" -o "${tgz}"
  rm -rf "${dest}"
  mkdir -p "${dest}"
  tar -xzf "${tgz}" -C "${dest}"
}

fetch_pkg cmarker "${CMARKER_VERSION}"
fetch_pkg mitex "${MITEX_VERSION}"

echo "✓ Typst-Packages in ${vendor_dir} (cmarker ${CMARKER_VERSION}, mitex ${MITEX_VERSION})"
