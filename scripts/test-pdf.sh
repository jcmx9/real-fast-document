#!/usr/bin/env bash
# End-to-End-Test: baut die Testnotizen aus tests/fixtures/ mit build.sh und
# prüft den Text der erzeugten PDFs (pdftotext oder mutool) sowie die
# Schnittstelle (Ausgabepfad, Exit-Codes, eingebettete Quelle, minimaler PATH).
#
# Usage: bash scripts/test-pdf.sh
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly root_dir
readonly build="${root_dir}/scripts/build.sh"
readonly fixtures="${root_dir}/tests/fixtures"
export RFD_NO_OPEN=1

out_dir="$(mktemp -d)"
cleanup() { rm -rf "${out_dir}"; }
trap cleanup EXIT

die() {
  printf 'FEHLER: %s\n' "$*" >&2
  exit 1
}

pdf_text() {
  if command -v pdftotext >/dev/null 2>&1; then
    pdftotext -layout "$1" -
  elif command -v mutool >/dev/null 2>&1; then
    mutool draw -q -F txt "$1"
  else
    die "pdftotext (poppler) oder mutool (mupdf) wird benötigt"
  fi
}

# Namen der eingebetteten Dateien (leer, wenn keine).
attachments() {
  mutool show "$1" trailer/Root/Names/EmbeddedFiles 2>/dev/null | grep -o '([^)]*)' | tr -d '()' || true
}

# render <fixture> [build-optionen…]: baut aus dem Fixture-Ordner heraus (wie
# Zettlr: Arbeitsverzeichnis = Ordner der Notiz) und gibt den PDF-Text aus.
render() {
  local name="$1" pdf="${out_dir}/${1%.md}.pdf"
  shift
  (cd "${fixtures}" && bash "${build}" "$@" "${name}" "${pdf}" >/dev/null 2>"${out_dir}/${name}.err") ||
    die "${name}: Export fehlgeschlagen: $(cat "${out_dir}/${name}.err")"
  [[ -s "${pdf}" ]] || die "${name}: leeres PDF"
  strings "${pdf}" | grep -q 'part>3</pdfaid:part' || die "${name}: kein PDF/A-3"
  pdf_text "${pdf}"
}

# expect <name> <text> <string>…: jeder String muss im Text vorkommen.
expect() {
  local name="$1" text="$2" s
  shift 2
  for s in "$@"; do
    grep -qF -- "${s}" <<<"${text}" || die "${name}: fehlt \"${s}\""
  done
}

# expect_compact <name> <text> <string>…: wie expect, aber ohne Leerraum
# verglichen – für gesperrten Text (tracking), den die Extraktion zerlegt.
expect_compact() {
  local name="$1" text s
  text="$(tr -d '[:space:]' <<<"$2")"
  shift 2
  for s in "$@"; do
    grep -qF -- "$(tr -d '[:space:]' <<<"${s}")" <<<"${text}" || die "${name}: fehlt \"${s}\""
  done
}

# expect_line <name> <text> <string>…: der String steht als eigene Zeile
# (nur Leerraum davor/danach) – prüft Zeilenumbrüche im Layout.
expect_line() {
  local name="$1" text="$2" s
  shift 2
  for s in "$@"; do
    awk -v want="${s}" '{ sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "") } $0 == want { found = 1 } END { exit !found }' \
      <<<"${text}" || die "${name}: \"${s}\" steht nicht als eigene Zeile"
  done
}

# reject <name> <text> <string>…: kein String darf im Text vorkommen.
reject() {
  local name="$1" text="$2" s
  shift 2
  for s in "$@"; do
    if grep -qF -- "${s}" <<<"${text}"; then
      die "${name}: unerwartet \"${s}\""
    fi
  done
}

ok() { printf 'ok   %s\n' "$*"; }

# xmax <pdf> <wort>: rechte Kante (pt) jedes Vorkommens des Wortes (pdftotext -bbox).
xmax() {
  pdftotext -bbox "$1" - | grep -F ">$2<" | sed -E 's/.*xMax="([0-9.]+)".*/\1/'
}

test_fixtures() {
  local text

  # Hastig getippte Notiz ohne Titel/Front Matter darf nie scheitern.
  text="$(render edge-cases.md)"
  expect edge-cases.md "${text}" "Notiz ohne Titel" "Überschrift direkt auf Ebene drei" "leer links" \
    "Aufgabe ohne alles" "edge-cases.pdf"
  ok edge-cases.md

  # Leere Felder werden ignoriert (kein Fehler, kein leerer Rest).
  text="$(render empty-fields.md)"
  expect_compact empty-fields.md "${text}" "MUSTER GMBH"
  expect empty-fields.md "${text}" "Leere Kopfdaten" "Alle optionalen Felder sind leer."
  ok empty-fields.md

  # Titel + Untertitel aus dem Front Matter, mehrere Kapitel, Fußzeile ohne Kunde.
  text="$(render yaml-title.md)"
  expect yaml-title.md "${text}" "Kick-off: Relaunch" "Workshop" "Ziele" "Unterpunkt" "Aufgaben" \
    "Kick-off: Relaunch · Workshop"
  reject yaml-title.md "${text}" "$(date +%d.%m.%Y)"
  ok yaml-title.md

  # Kunde, deutsches Datum, Autorenliste, Fußzeile "Kunde · Titel"; leerer
  # Untertitel und ungültige logo-height (50 %) werden ignoriert.
  text="$(render client-meta.md)"
  expect_compact client-meta.md "${text}" "MUSTER GMBH"
  expect client-meta.md "${text}" "Kick-off" "12. Oktober 2026 · jcmx9, Ben Probe" \
    "Muster GmbH · Kick-off" "Seite 1 / 1"
  ok client-meta.md

  # Englische Beschriftungen.
  text="$(render english.md)"
  expect_compact english.md "${text}" "EXAMPLE LTD"
  expect english.md "${text}" "Example Ltd" "Kick-off" "Page 1 /" "NOTE" "English alert titles." \
    "Task" "Owner" "Due" "Status" "17 Oct" "Ben Probe" "October 17, 2026"
  reject english.md "${text}" "[!NOTE]" "– jcmx9"
  reject english.md "${text}" "Seite"
  ok english.md

  # Ohne title: kein Titel – "#" bleibt ein Kapitel; PDF-Titel = Dateiname.
  text="$(render h1-chapter.md)"
  expect h1-chapter.md "${text}" "Kapitel ohne Titel" "Abschnitt" "h1-chapter.pdf"
  pdfinfo "${out_dir}/h1-chapter.pdf" | grep -q '^Title: *h1-chapter$' ||
    die "h1-chapter.md: PDF-Titel ist nicht der Dateiname"
  ok h1-chapter.md

  # Hinweisboxen: GitHub- und deutsche Schlüsselwörter, deutsche Titel.
  text="$(render alerts.md)"
  expect alerts.md "${text}" "INFO" "TIPP" "WICHTIG" "HINWEIS" "ACHTUNG" "Ruhiges Orange." \
    "Deutsches Schlüsselwort mit Text in derselben Zeile." "Liste in der Box" \
    "Ein normales Zitat bleibt ein Zitat."
  reject alerts.md "${text}" "[!NOTE]" "[!HINWEIS]" "[!TIP]"
  ok alerts.md

  # Aufgabentabelle mit Wer/Bis; gemischte Liste bleibt Liste.
  text="$(render tasks.md)"
  expect tasks.md "${text}" "Aufgabe" "Wer" "Bis" "Status" "Sitemap-Entwurf erstellen" "jcmx9" \
    "Ben Probe" "15.10." "Anna Beispiel" "Offener Punkt ohne Zuständigkeit" \
    "Ein normaler Punkt" "Erledigte Aufgabe – bleibt Liste"
  reject tasks.md "${text}" "– jcmx9" ", bis 17.10." "[ ]" "[x]"
  ok tasks.md

  # Checkliste ohne Namen/Termine: nur Aufgabe + Status (lose Liste, kein Absturz).
  text="$(render checklist.md)"
  expect checklist.md "${text}" "Aufgabe" "Status" "Ohne Zuständigkeit bleibt es eine Checkliste" "Erledigt"
  reject checklist.md "${text}" "Wer" "Bis"
  ok checklist.md

  # Anführungszeichen wie getippt, Markierung, Datumszeilen, Seitenumbrüche;
  # Code bleibt unverändert.
  text="$(render text-features.md)"
  # shellcheck disable=SC1111,SC1112
  expect text-features.md "${text}" '„Deutsche Anführungszeichen“' '‚einfache‘' '»Guillemets«' \
    '"gerade"' "Text mit markiert" "==kein Mark im Code==" "==bleibt Code==" '\newpage' \
    "1. Echte Liste" "Seite drei."
  expect_line text-features.md "${text}" "18. Oktober 2026" "19. Okt. 2026" "1. Dez. 2026"
  # shellcheck disable=SC1111
  reject text-features.md "${text}" "==markiert==" "pagebreak" '“gerade”'
  pdfinfo "${out_dir}/text-features.pdf" | grep -q '^Pages: *3$' ||
    die "text-features.md: Seitenumbrüche fehlen (erwartet 3 Seiten)"
  ok text-features.md

  # Zeilenumbrüche: Standard weich, mit --hard-breaks / hard_breaks: true hart.
  text="$(render soft-breaks.md)"
  expect soft-breaks.md "${text}" "Zeile eins Zeile zwei"
  text="$(render soft-breaks.md --hard-breaks)"
  expect_line "soft-breaks.md --hard-breaks" "${text}" "Zeile eins" "Zeile zwei"
  reject "soft-breaks.md --hard-breaks" "${text}" "\\"
  ok "soft-breaks.md (+ --hard-breaks)"

  # Zettlr-Notiz ohne Leerzeilen, harte Umbrüche per Front Matter.
  text="$(render no-blank-lines.md)"
  expect no-blank-lines.md "${text}" "Agenda" "Mitschrift" "Das ist zu tun" "Markierung" "Abschluss"
  expect_line no-blank-lines.md "${text}" "Letzte Zeile." "Noch eine Zeile." "18. Oktober 2026" \
    "Text direkt danach mit Markierung."
  reject no-blank-lines.md "${text}" "# Mitschrift" "==Markierung==" "\\"
  ok no-blank-lines.md

  # Tabellen: Spaltenbreiten nach Inhalt, Zahlen rechtsbündig, Kopf wiederholt.
  text="$(render tables.md)"
  expect tables.md "${text}" "Donaudampfschifffahrtsgesellschaftskapitänsmütze" "1.250,00 €" "17.10.2026"
  if command -v pdftotext >/dev/null 2>&1; then
    local pdf="${out_dir}/tables.pdf" edges
    # Beträge unterschiedlicher Länge enden an derselben Kante (rechtsbündig).
    edges="$(for w in 520,00 1.250,00 9,50; do xmax "${pdf}" "${w}"; done |
      awk 'NR == 1 { a = $1 } { d = $1 - a; if (d < 0) d = -d; if (d > 0.5) bad = 1 } END { print bad + 0 }')"
    [[ "${edges}" == 0 ]] || die "tables.md: Beträge nicht rechtsbündig"
    # Kleine Tabelle bleibt in Inhaltsbreite (Satzspiegel endet bei ~538 pt).
    awk '{ exit !($1 < 400) }' <<<"$(xmax "${pdf}" Verantwortlich)" ||
      die "tables.md: kleine Tabelle auf volle Breite gezogen"
    # Lange Tabelle: Kopfzeile wiederholt sich auf Seite 2.
    expect "tables.md Seite 2" "$(pdftotext -f 2 -l 2 -layout "${pdf}" -)" "Position" "Betrag"
  fi
  ok tables.md

  # Bilder: Breite aus {width=…}, Remote-Bild übersprungen, Bildunterschrift.
  text="$(render images.md)"
  expect images.md "${text}" "Abbildung 1: Screenshot aus dem Termin" "Ende der Bilder."
  reject images.md "${text}" "{width" "Remote wird übersprungen"
  if command -v pdfimages >/dev/null 2>&1; then
    [[ "$(pdfimages -list "${out_dir}/images.pdf" | tail -n +3 | wc -l | tr -d ' ')" -ge 2 ]] ||
      die "images.md: Bilder nicht eingebettet"
  fi
  ok images.md

  # Absolute Pfade über Umgebungsvariablen ($VAR, ${VAR} fürs Logo); ein
  # fehlendes Bild hinterlässt einen Hinweis statt den Export abzubrechen.
  text="$(TEST_ASSETS="${fixtures}" render absolute-paths.md)"
  expect absolute-paths.md "${text}" "Abbildung 1: Absolut über Variable" \
    "[Bild fehlt: bilder/gibt-es-nicht.png]" "Text nach den Bildern."
  grep -q "Bild nicht gefunden: bilder/gibt-es-nicht.png" "${out_dir}/absolute-paths.md.err" ||
    die "absolute-paths.md: keine Warnung auf stderr"
  reject absolute-paths.md "${text}" "real·fast"   # Notiz-Logo statt Standard-Logo
  ok absolute-paths.md

  # Mermaid offline: Beschriftungen als Text im PDF, kein Quelltext.
  text="$(render mermaid.md)"
  expect mermaid.md "${text}" "Kick-off" "Konzept ok?" "Design" "Briefing" "Angebot" \
    "Text nach dem Diagramm."
  reject mermaid.md "${text}" "flowchart LR" "sequenceDiagram" "-->"
  ok mermaid.md

  # Frontmatter: Inline-Kommentare, Quotes, Listen, auto und leere Bool-Werte –
  # ohne eine einzige Warnung.
  text="$(render frontmatter-parsing.md)"
  expect frontmatter-parsing.md "${text}" "Titel mit Kommentar" "Ohne Anführungszeichen" \
    "Anna Beispiel, Ben Probe" "Inhalt."
  expect_compact frontmatter-parsing.md "${text}" "EINFACHE ANFÜHRUNGSZEICHEN"
  reject frontmatter-parsing.md "${text}" "Kommentar gehört" "# auch" '"'
  if grep -q "Warnung" "${out_dir}/frontmatter-parsing.md.err"; then
    die "frontmatter-parsing.md: unerwartete Warnung: $(cat "${out_dir}/frontmatter-parsing.md.err")"
  fi
  ok frontmatter-parsing.md

  # Vorlage header.md (alle Schlüssel mit Standardwerten) baut ohne Warnung.
  (cd "${root_dir}" && bash "${build}" header.md "${out_dir}/header.pdf" >/dev/null 2>"${out_dir}/header.err") ||
    die "header.md: Export fehlgeschlagen: $(cat "${out_dir}/header.err")"
  if grep -q "Warnung" "${out_dir}/header.err"; then
    die "header.md: unerwartete Warnung: $(cat "${out_dir}/header.err")"
  fi
  ok header.md
}

test_interface() {
  local err code text

  # Ausdrücklich angegebene Ausgabe: exakt dieser Pfad, kein ISO-Präfix.
  (cd "${fixtures}" && bash "${build}" client-meta.md "${out_dir}/exakt.pdf" >/dev/null 2>&1)
  [[ -s "${out_dir}/exakt.pdf" ]] || die "Ausgabe nicht exakt geschrieben"
  [[ ! -e "${out_dir}/2026-10-12_exakt.pdf" && ! -e "${fixtures}/2026-10-12_client-meta.pdf" ]] ||
    die "ISO-Präfix trotz ausdrücklicher Ausgabe"
  ok "Ausgabe exakt"

  # Ohne Ausgabe: neben der Quelle, deutsches Datum -> ISO-Präfix.
  cp "${fixtures}/client-meta.md" "${fixtures}/logo.png" "${out_dir}/"
  (cd "${out_dir}" && bash "${build}" client-meta.md >/dev/null 2>&1)
  [[ -s "${out_dir}/2026-10-12_client-meta.pdf" ]] || die "ISO-Präfix aus 12.10.2026 fehlt"
  ok "ISO-Präfix aus deutschem Datum"

  # Fehlende Quelle: Exit != 0, kurze Meldung auf stderr.
  code=0
  err="$(bash "${build}" "${out_dir}/gibt-es-nicht.md" "${out_dir}/x.pdf" 2>&1 >/dev/null)" || code=$?
  [[ "${code}" -ne 0 ]] || die "fehlende Quelle liefert Exit 0"
  grep -q "Quelle nicht gefunden" <<<"${err}" || die "fehlende Quelle: unklare Meldung: ${err}"
  ok "Exit-Code bei fehlender Quelle (${code})"

  # Unbekannte Option: Exit 2.
  code=0
  bash "${build}" --gibt-es-nicht >/dev/null 2>&1 || code=$?
  [[ "${code}" -eq 2 ]] || die "unbekannte Option liefert Exit ${code}"
  ok "Exit-Code bei unbekannter Option"

  # Eingebettete Quelle: Standard an (nur Dateiname, kein lokaler Pfad),
  # aus per --no-source oder embed_source: false.
  if command -v mutool >/dev/null 2>&1; then
    [[ "$(attachments "${out_dir}/edge-cases.pdf")" == "edge-cases.md" ]] ||
      die "eingebettete Quelle fehlt oder trägt einen Pfad: $(attachments "${out_dir}/edge-cases.pdf")"
    render edge-cases.md --no-source >/dev/null
    [[ -z "$(attachments "${out_dir}/edge-cases.pdf")" ]] || die "--no-source bettet trotzdem ein"
    render no-source.md >/dev/null
    [[ -z "$(attachments "${out_dir}/no-source.pdf")" ]] || die "embed_source: false bettet trotzdem ein"
    ok "Quelle einbetten / --no-source / embed_source: false"
  else
    printf 'skip Einbettung (mutool fehlt)\n'
  fi

  # Absolute Pfade mit Leerzeichen (so ruft der Zettlr-Bote auf), Aufruf aus
  # einem fremden Arbeitsverzeichnis: das PDF entsteht genau am Zielpfad.
  local in_dir="${out_dir}/Notiz Ordner" target_dir="${out_dir}/Aus gabe"
  mkdir -p "${in_dir}/bilder" "${target_dir}"
  cp "${fixtures}/edge-cases.md" "${in_dir}/meine notiz.md"
  cp "${fixtures}/bilder/screenshot.png" "${in_dir}/bilder/"
  (cd / && bash "${build}" --no-source --hard-breaks "${in_dir}/meine notiz.md" "${target_dir}/mein pdf.pdf" \
    >/dev/null 2>"${out_dir}/spaces.err") || die "Pfade mit Leerzeichen: Export fehlgeschlagen: $(cat "${out_dir}/spaces.err")"
  [[ -s "${target_dir}/mein pdf.pdf" ]] || die "Pfade mit Leerzeichen: PDF fehlt am Zielpfad"
  ok "absolute Pfade mit Leerzeichen"

  # Temporäre Kopie (Zettlr bei ungespeicherten Änderungen): Bilder gelten über
  # RFD_BASE_DIR relativ zum Originalordner; Name in Fußzeile, PDF-Titel und
  # Anhang bleibt der der Notiz (die Kopie trägt denselben Dateinamen).
  local tmp_copy="${out_dir}/tmpkopie"
  mkdir -p "${tmp_copy}"
  cp "${fixtures}/edge-cases.md" "${tmp_copy}/edge-cases.md"
  (cd "${fixtures}" && RFD_BASE_DIR="${fixtures}" bash "${build}" "${tmp_copy}/edge-cases.md" \
    "${out_dir}/basis.pdf" >/dev/null 2>"${out_dir}/basis.err") ||
    die "RFD_BASE_DIR: Export fehlgeschlagen: $(cat "${out_dir}/basis.err")"
  text="$(pdf_text "${out_dir}/basis.pdf")"
  reject "RFD_BASE_DIR" "${text}" "Bild fehlt"
  expect "RFD_BASE_DIR" "${text}" "basis.pdf"
  pdfinfo "${out_dir}/basis.pdf" | grep -q '^Title: *edge-cases$' || die "RFD_BASE_DIR: PDF-Titel ist nicht der Notizname"
  if command -v mutool >/dev/null 2>&1; then
    [[ "$(attachments "${out_dir}/basis.pdf")" == "edge-cases.md" ]] || die "RFD_BASE_DIR: Anhangsname falsch"
  fi
  # Gegenprobe: ohne RFD_BASE_DIR fehlt das Bild neben der Kopie.
  (cd "${fixtures}" && bash "${build}" "${tmp_copy}/edge-cases.md" "${out_dir}/ohne-basis.pdf" >/dev/null 2>&1)
  expect "ohne RFD_BASE_DIR" "$(pdf_text "${out_dir}/ohne-basis.pdf")" "Bild fehlt: bilder/screenshot.png"
  # Ungültiger RFD_BASE_DIR: Warnung, Rückfall auf den Ordner der Quelle.
  RFD_BASE_DIR="${out_dir}/gibt-es-nicht" bash "${build}" "${fixtures}/edge-cases.md" "${out_dir}/x.pdf" \
    >/dev/null 2>"${out_dir}/basis2.err" || die "ungültiger RFD_BASE_DIR bricht den Export ab"
  grep -q "RFD_BASE_DIR ist kein Ordner" "${out_dir}/basis2.err" || die "ungültiger RFD_BASE_DIR ohne Warnung"
  ok "RFD_BASE_DIR (temporäre Kopie) + Dateiname"

  # Minimaler PATH wie bei einer GUI-App (Zettlr, Finder): typst muss über
  # bin/rfd-tools.env bzw. bin/typst gefunden werden.
  if [[ -f "${root_dir}/bin/rfd-tools.env" || -x "${root_dir}/bin/typst" ]]; then
    (cd "${fixtures}" && env -i HOME="${HOME}" PATH=/usr/bin:/bin RFD_NO_OPEN=1 \
      bash "${build}" edge-cases.md "${out_dir}/minpath.pdf" >/dev/null 2>&1) ||
      die "Build mit minimalem PATH fehlgeschlagen"
    ok "minimaler PATH"
  else
    printf 'skip minimaler PATH (kein bin/rfd-tools.env – install.sh nicht gelaufen)\n'
  fi
}

test_fixtures
test_interface
printf 'Alle Tests bestanden.\n'
