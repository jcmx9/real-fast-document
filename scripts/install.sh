#!/usr/bin/env bash
# Einrichtung von real-fast-document auf macOS/Linux. Idempotent.
#
#   scripts/install.sh             # Werkzeuge + Fonts + Rechtsklick-Integration
#   scripts/install.sh --uninstall # nur die Rechtsklick-Integration entfernen
#
# Werkzeuge: pandoc und typst (>= 0.15) über den System-Paketmanager; ist typst
# dort nicht (oder zu alt) verfügbar, wird das offizielle typst-Binary nach
# ./bin geladen und von build.sh via TYPST genutzt. Fonts: scripts/fetch-fonts.sh.
# Integration: macOS Finder Quick Action, Linux .desktop + MIME-Verknüpfung.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root_dir}"
os="$(uname -s)"
convert_script="${root_dir}/scripts/rfd-convert.sh"
service_name="Nach PDF-A (real-fast-document)"

log()  { printf '→ %s\n' "$*"; }
ok()   { printf '✓ %s\n' "$*"; }
warn() { printf '! %s\n' "$*" >&2; }
err()  { printf 'Error: %s\n' "$*" >&2; }

# --- Paketmanager -----------------------------------------------------------
detect_pm() {
  if command -v brew >/dev/null 2>&1; then echo brew; return; fi
  local pm
  for pm in apt-get dnf pacman zypper; do
    if command -v "${pm}" >/dev/null 2>&1; then echo "${pm}"; return; fi
  done
  echo ""
}

# Privilegierter Aufruf: als root direkt, sonst via sudo (falls vorhanden).
run_priv() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    err "Root-Rechte nötig, aber kein sudo gefunden – bitte als root ausführen oder sudo installieren."
    return 1
  fi
}

pm_install() {
  local pkg="$1" pm
  pm="$(detect_pm)"
  case "${pm}" in
    brew)    brew install "${pkg}" ;;
    apt-get) run_priv apt-get update -qq && run_priv apt-get install -y "${pkg}" ;;
    dnf)     run_priv dnf install -y "${pkg}" ;;
    pacman)  run_priv pacman -S --noconfirm "${pkg}" ;;
    zypper)  run_priv zypper install -y "${pkg}" ;;
    *)       return 1 ;;
  esac
}

# --- Werkzeuge --------------------------------------------------------------
ensure_pandoc() {
  if command -v pandoc >/dev/null 2>&1; then ok "pandoc vorhanden"; return; fi
  log "Installiere pandoc"
  if ! pm_install pandoc; then
    err "Kein unterstützter Paketmanager für pandoc gefunden."
    err "Bitte pandoc manuell installieren: https://pandoc.org/installing.html"
    exit 1
  fi
  ok "pandoc installiert"
}

typst_ge_015() {
  command -v "${1}" >/dev/null 2>&1 || return 1
  local v maj min
  v="$("${1}" --version 2>/dev/null | awk '{print $2}')"
  maj="${v%%.*}"; min="${v#*.}"; min="${min%%.*}"
  [[ "${maj}" =~ ^[0-9]+$ && "${min}" =~ ^[0-9]+$ ]] || return 1
  (( maj > 0 || min >= 15 ))
}

install_typst_binary() {
  # Offizielles statisches typst-Release nach ./bin (Fallback ohne PM-Paket).
  local arch target tarball url tmp
  case "$(uname -m)" in
    x86_64|amd64)  arch="x86_64" ;;
    arm64|aarch64) arch="aarch64" ;;
    *) err "Unbekannte Architektur $(uname -m) – typst bitte manuell installieren."; exit 1 ;;
  esac
  if [[ "${os}" == "Darwin" ]]; then target="${arch}-apple-darwin"; else target="${arch}-unknown-linux-musl"; fi
  tarball="typst-${target}.tar.xz"
  url="https://github.com/typst/typst/releases/latest/download/${tarball}"
  tmp="$(mktemp -d)"
  log "Lade typst-Binary (${target})"
  curl -fsSL "${url}" -o "${tmp}/${tarball}"
  tar -xJf "${tmp}/${tarball}" -C "${tmp}"
  mkdir -p "${root_dir}/bin"
  cp "${tmp}/typst-${target}/typst" "${root_dir}/bin/typst"
  chmod +x "${root_dir}/bin/typst"
  rm -rf "${tmp}"
  ok "typst-Binary -> ${root_dir}/bin/typst"
}

# Werkzeugpfade merken: GUI-gestartete Skripte (Finder Quick Action, .desktop)
# erben den Shell-PATH NICHT. Daher beim Einrichten (PATH korrekt) die echten
# Verzeichnisse von typst/pandoc in bin/rfd-tools.env festhalten; der Dispatcher
# und der CLI-Wrapper ergänzen damit ihren PATH.
write_tools_env() {
  local tp pp tdir pdir
  tp="$(command -v typst 2>/dev/null || true)"
  if [[ -x "${root_dir}/bin/typst" ]]; then tp="${root_dir}/bin/typst"; fi
  pp="$(command -v pandoc 2>/dev/null || true)"
  tdir="$(cd "$(dirname "${tp:-/usr/bin/typst}")" 2>/dev/null && pwd || echo /usr/bin)"
  pdir="$(cd "$(dirname "${pp:-/usr/bin/pandoc}")" 2>/dev/null && pwd || echo /usr/bin)"
  mkdir -p "${root_dir}/bin"
  printf 'RFD_TOOL_PATH="%s"\n' "${tdir}:${pdir}" > "${root_dir}/bin/rfd-tools.env"
  ok "Werkzeugpfade gemerkt -> bin/rfd-tools.env (${tdir}:${pdir})"
}

ensure_typst() {
  if typst_ge_015 typst; then ok "typst (>= 0.15) vorhanden"; return; fi
  if [[ -x "${root_dir}/bin/typst" ]] && typst_ge_015 "${root_dir}/bin/typst"; then
    ok "gebündeltes typst (./bin) vorhanden"; return
  fi
  log "Installiere typst"
  if pm_install typst >/dev/null 2>&1 && typst_ge_015 typst; then
    ok "typst über Paketmanager installiert"
  else
    warn "typst nicht (oder zu alt) über Paketmanager – nutze Binär-Fallback"
    install_typst_binary
  fi
}

# --- Rechtsklick-Integration: macOS ----------------------------------------
install_macos() {
  local svc_dir="${HOME}/Library/Services" bundle
  bundle="${svc_dir}/${service_name}.workflow"
  mkdir -p "${bundle}/Contents"
  cat > "${bundle}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict><key>default</key><string>${service_name}</string></dict>
			<key>NSMessage</key><string>runWorkflowAsService</string>
			<key>NSRequiredContext</key>
			<dict><key>NSApplicationIdentifier</key><string>com.apple.finder</string></dict>
			<key>NSSendFileTypes</key>
			<array><string>public.item</string></array>
		</dict>
	</array>
</dict>
</plist>
PLIST
  cat > "${bundle}/Contents/document.wflow" <<'WFLOW'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key><string>521</string>
	<key>AMApplicationVersion</key><string>2.10</string>
	<key>AMDocumentVersion</key><string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key><string>List</string>
					<key>Optional</key><false/>
					<key>Types</key><array><string>com.apple.cocoa.path</string></array>
				</dict>
				<key>AMActionVersion</key><string>2.0.3</string>
				<key>AMApplication</key><array><string>Automator</string></array>
				<key>AMProvides</key>
				<dict>
					<key>Container</key><string>List</string>
					<key>Types</key><array><string>com.apple.cocoa.path</string></array>
				</dict>
				<key>ActionBundlePath</key><string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key><string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key><string>"__CONVERT__" "$@"</string>
					<key>CheckedForUserDefaultShell</key><true/>
					<key>inputMethod</key><integer>1</integer>
					<key>shell</key><string>/bin/bash</string>
					<key>source</key><string></string>
				</dict>
				<key>BundleIdentifier</key><string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key><string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key><false/>
				<key>CanShowWhenRun</key><true/>
				<key>Category</key><array><string>AMCategoryUtilities</string></array>
				<key>Class Name</key><string>RunShellScriptAction</string>
				<key>InputUUID</key><string>1A1A1A1A-0000-0000-0000-000000000001</string>
				<key>Keywords</key><array><string>Shell</string></array>
				<key>OutputUUID</key><string>2B2B2B2B-0000-0000-0000-000000000002</string>
				<key>UUID</key><string>3C3C3C3C-0000-0000-0000-000000000003</string>
				<key>UnlocalizedApplications</key><array><string>Automator</string></array>
				<key>arguments</key><dict/>
				<key>isViewVisible</key><integer>1</integer>
			</dict>
			<key>isViewVisible</key><integer>1</integer>
		</dict>
	</array>
	<key>connectors</key><dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>serviceApplicationBundleID</key><string>com.apple.finder</string>
		<key>serviceApplicationPath</key><string>/System/Library/CoreServices/Finder.app</string>
		<key>serviceInputTypeIdentifier</key><string>com.apple.Automator.fileSystemObject</string>
		<key>serviceOutputTypeIdentifier</key><string>com.apple.Automator.nothing</string>
		<key>serviceProcessesInput</key><integer>0</integer>
		<key>presentationMode</key><integer>11</integer>
		<key>processesInput</key><integer>0</integer>
		<key>systemImageName</key><string>NSActionTemplate</string>
		<key>useAutomaticInputType</key><integer>0</integer>
		<key>workflowTypeIdentifier</key><string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW
  # Platzhalter durch den echten Konverterpfad ersetzen.
  /usr/bin/sed -i '' "s|__CONVERT__|${convert_script}|g" "${bundle}/Contents/document.wflow"
  # Dienst neu registrieren (best effort).
  /System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
  ok "Quick Action installiert -> ${bundle}"
  log 'Erscheint im Finder-Rechtsklick unter „Dienste/Quick Actions“ (ggf. Finder neu starten).'
}

uninstall_macos() {
  local bundle="${HOME}/Library/Services/${service_name}.workflow"
  if [[ -d "${bundle}" ]]; then
    rm -rf "${bundle}"
    /System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
    ok "Quick Action entfernt"
  else
    log "Keine Quick Action vorhanden"
  fi
}

# --- Rechtsklick-Integration: Linux ----------------------------------------
install_linux() {
  local apps_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"
  local desktop="${apps_dir}/real-fast-document.desktop"
  mkdir -p "${apps_dir}"
  cat > "${desktop}" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Nach PDF-A (real-fast-document)
Comment=Markdown nach PDF/A-3b konvertieren
Exec=${convert_script} %F
MimeType=text/markdown;
NoDisplay=true
Terminal=false
DESKTOP
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${apps_dir}" >/dev/null 2>&1 || true
  fi
  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default real-fast-document.desktop text/markdown >/dev/null 2>&1 || true
  fi
  ok ".desktop installiert -> ${desktop}"
  log 'Im Dateimanager: .md-Datei rechtsklicken -> „Öffnen mit → Nach PDF-A“.'
}

uninstall_linux() {
  local desktop="${XDG_DATA_HOME:-${HOME}/.local/share}/applications/real-fast-document.desktop"
  if [[ -f "${desktop}" ]]; then
    rm -f "${desktop}"
    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$(dirname "${desktop}")" >/dev/null 2>&1 || true
    ok ".desktop entfernt"
  else
    log "Kein .desktop vorhanden"
  fi
}

install_integration() {
  chmod +x "${convert_script}" "${root_dir}/scripts/build.sh"
  if [[ "${os}" == "Darwin" ]]; then install_macos; else install_linux; fi
}

uninstall_integration() {
  if [[ "${os}" == "Darwin" ]]; then uninstall_macos; else uninstall_linux; fi
}

# --- Globaler Terminal-Befehl: rf-document ---------------------------------
cli_dir="${XDG_BIN_HOME:-${HOME}/.local/bin}"
cli_path="${cli_dir}/rf-document"

install_cli() {
  mkdir -p "${cli_dir}"
  # Echter Wrapper mit fest eingebackenem Installpfad (ein Symlink würde die
  # BASH_SOURCE-Pfadauflösung von build.sh brechen). Setzt das gebündelte
  # typst-Binary, falls vorhanden.
  cat > "${cli_path}" <<EOF
#!/usr/bin/env bash
# Auto-generiert von real-fast-document/scripts/install.sh — globaler Wrapper.
if [[ -f "${root_dir}/bin/rfd-tools.env" ]]; then source "${root_dir}/bin/rfd-tools.env"; export PATH="\${RFD_TOOL_PATH}:\$PATH"; fi
if [[ -x "${root_dir}/bin/typst" ]]; then export TYPST="\${TYPST:-${root_dir}/bin/typst}"; fi
exec bash "${root_dir}/scripts/build.sh" "\$@"
EOF
  chmod +x "${cli_path}"
  ok "Terminal-Befehl installiert -> ${cli_path}"
  case ":${PATH}:" in
    *":${cli_dir}:"*) log 'Aufruf: rf-document datei.md' ;;
    *) warn "${cli_dir} ist nicht im PATH. Ergänze in deiner Shell-Konfiguration:"
       warn "  export PATH=\"${cli_dir}:\$PATH\"" ;;
  esac
}

uninstall_cli() {
  if [[ -f "${cli_path}" ]]; then
    rm -f "${cli_path}"
    ok "Terminal-Befehl entfernt"
  else
    log "Kein Terminal-Befehl vorhanden"
  fi
}

# --- Ablauf -----------------------------------------------------------------
case "${1:-install}" in
  --uninstall|uninstall)
    uninstall_integration
    uninstall_cli
    rm -f "${root_dir}/bin/rfd-tools.env"
    ;;
  install)
    ensure_pandoc
    ensure_typst
    log "Lade Fonts"
    bash scripts/fetch-fonts.sh
    write_tools_env
    install_integration
    install_cli
    ok "Einrichtung abgeschlossen."
    ;;
  *)
    err "Unbekanntes Argument: ${1}"
    echo "Verwendung: scripts/install.sh [--uninstall]" >&2
    exit 1
    ;;
esac
