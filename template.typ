// Markdown -> Typst Template (PDF/A-tauglich)
// Layout: DIN A4 Hochformat, asymmetrische Ränder, dynamischer Kopf (aktuelles H2)
// + Logo, Fußzeile mit Dateiname & Seite x/y, Trennlinien.
//
// Diese Datei ist eine reine Typst-Datei (KEIN Pandoc-Template mehr): der Body
// wird am Ende selbst per cmarker aus der Markdown-Quelle erzeugt.

#import "vendor/cmarker/lib.typ" as cmarker
#import "vendor/mitex/lib.typ": mitex
#import "lib/markdown.typ": preprocess
#import "vendor/mmdr/lib.typ": mermaid-svg

// ---------------------------------------------------------------------------
// Helfer für von cmarker erzeugte Elemente
// ---------------------------------------------------------------------------
// Thematische Trennlinie (`---`): mittige Teillinie statt voller Breite.
#let horizontalrule = align(center, line(start: (25%, 0%), end: (75%, 0%)))


#set table(inset: 7pt, stroke: none)
// Gemeinsame Tabellen-Gestaltung (allgemeine Tabellen + Aufgabentabelle):
// leichtes Zebra ab der 1. Datenzeile, senkrechte Trennlinien innen, eine Linie
// unter der Kopfzeile. Die fill-Funktion ist zugleich der Rekursions-Guard der
// #show table-Regel (umgebaute Tabellen haben fill != none).
#let rfd-table-fill = (_, y) => if y > 0 and calc.even(y) { luma(96%) } else { none }
#let rfd-table-stroke = (x, y) => (
  left: if x > 0 { 0.4pt + luma(80%) } else { 0pt },
  top: if y == 1 { 0.7pt + luma(45%) } else { 0pt },
)
// Tabellen: kompakte Tabellenschrift – Source Sans 3 in 9 pt Medium mit leicht
// engerer Laufweite (Adobe liefert keinen Condensed-Schnitt; die variable
// Source Sans 3 hat nur die wght-Achse). Ziffern als Versalziffern gleicher
// Breite, Flattersatz (Blocksatz reißt in schmalen Zellen Lücken).
#let table-text = (size: 9pt, weight: 500, tracking: -0.02em, hyphenate: false,
  number-type: "lining", number-width: "tabular")
#let cell-inset = 7pt

// Allgemeine Tabellen (aus Markdown): Spaltenbreiten macht Typst selbst
// (auto-Spalten) – jede Spalte so breit wie ihr Inhalt; passt die Tabelle nicht,
// verteilt Typst den Platz und textreiche Spalten brechen um. Kleine Tabellen
// bleiben in Inhaltsbreite. (Ein eigenes Messverfahren war aufwendiger und
// sah kaum anders aus.)
// Ausrichtung: die der Markdown-Trennzeile (:--, --:, :-:); ohne Angabe werden
// reine Zahlen-/Betragsspalten rechtsbündig, alles andere linksbündig. Kopf
// zentriert + fett, leichtes Zebra, senkrechte Trennlinien, Linie unter dem Kopf.
// Klartext einer Zelle (für die Zahlenerkennung). .sum statt .join: join auf
// einem leeren Array liefert none (leere Zellen).
#let plain-text(c) = {
  if c.has("text") { c.text }
  else if c.has("children") { c.children.map(plain-text).sum(default: "") }
  else if c.has("body") { plain-text(c.body) }
  else if c == [ ] { " " }
  else { "" }
}
#let number-re = regex("^[+\-−]?\s*(?:[€$£]\s*)?[0-9][0-9.,'\u{2009}\u{00A0} ]*(?:\s*(?:%|€|\$|£|EUR|CHF|USD|Std\.?|h|Tage?|Stk\.?))?$")
#let is-number(c) = plain-text(c).trim().match(number-re) != none

#show table: it => {
  // Guard gegen Rekursion: umgebaute Tabellen (und die Aufgabentabelle) setzen
  // `fill` (eine Funktion), die cmarker-Originaltabelle nicht.
  if it.fill != none {
    it
  } else {
    let n = if type(it.columns) == int { it.columns } else { it.columns.len() }
    // Datenzellen spaltenweise (Kopfzeile aus table.header übersprungen) – nur
    // für die Zahlenerkennung; gerendert wird weiter ..it.children (der
    // table.header wiederholt sich so bei Seitenumbruch).
    let cell-body = c => if c.func() == table.cell { c.body } else { c }
    let rows = it.children.filter(c => c.func() != table.header).map(cell-body).chunks(n)
    let md-align = if type(it.align) == array { it.align } else { (auto,) * n }
    let aligns = range(n).map(i => {
      let a = md-align.at(i, default: auto)
      if a != auto { a }
      else {
        let cells = rows.map(r => r.at(i, default: [])).filter(c => plain-text(c).trim() != "")
        if cells.len() > 0 and cells.all(is-number) { right } else { left }
      }
    })
    block(above: 1.2em, below: 1.4em, breakable: true, {
      set text(..table-text)
      set par(justify: false)
      // Code in Zellen optisch gleich groß wie der 9-pt-Tabellentext.
      show raw: set text(size: 8.5pt)
      table(
        columns: (auto,) * n,
        inset: cell-inset,
        align: (x, y) => if y == 0 { center } else { aligns.at(x) },
        fill: rfd-table-fill,
        stroke: rfd-table-stroke,
        ..it.children,
      )
    })
  }
}
#show table.cell.where(y: 0): strong
#show figure.where(kind: table): set figure.caption(position: top)
#show figure.where(kind: image): set figure.caption(position: bottom)
// Bildunterschrift kleiner als Fließtext, mit etwas mehr Abstand unter der Abbildung.
#show figure.caption: set text(size: 10pt)
// breakable: false hält Abbildung UND Unterschrift zusammen auf einer Seite –
// passt beides nicht mehr aufs Blatt, wandert die ganze Figure auf die nächste
// Seite (die Unterschrift landet damit nie allein auf der Folgeseite).
#show figure: it => block(above: 1.4em, below: 1.6em, breakable: false, it)

// ---------------------------------------------------------------------------
// Laufzeit-Eingaben (via `typst compile --input ...`)
// ---------------------------------------------------------------------------
#let doc-filename = sys.inputs.at("filename", default: "document.md")
// Leerer Pfad = kein Logo (Kopf läuft dann ohne Logo durch). build.sh wählt:
// Frontmatter logo: (pro Notiz) vor dem globalen logo.svg/png/jpg.
#let logo-path = sys.inputs.at("logo", default: "")
// Markdown-Quelle (das Original; die Vorverarbeitung passiert in lib/markdown.typ).
#let source-path = sys.inputs.at("source", default: none)
// Verzeichnis der Original-Quelle: relative Bildpfade im Markdown werden dagegen
// aufgelöst (nicht gegen den Projekt-Root), damit Bilder neben Dokumenten überall
// gefunden werden.
#let doc-dir = sys.inputs.at("docdir", default: "")
// Einzubettende Original-Quelle (pdf.attach). Leer = nicht einbetten
// (embed_source: false / --no-source, z. B. für Kunden-PDFs).
#let attach-path = sys.inputs.at("attach", default: "")
// Frontmatter-gesteuert (von build.sh/convert.ps1 aus dem YAML-Block gereicht):
#let date-raw   = sys.inputs.at("date", default: "")       // ISO, T.M.JJJJ oder Freitext
#let client-text   = sys.inputs.at("client", default: "")
#let subtitle-text = sys.inputs.at("subtitle", default: "")
#let author-text   = sys.inputs.at("author", default: "")
#let toc-mode   = sys.inputs.at("toc", default: "auto")    // "true" | "false" | "auto"
#let break-mode = sys.inputs.at("h1_break", default: "auto")
#let show-name  = sys.inputs.at("showname", default: "true") != "false"
// Kopfzeile (Vorrang von oben):
//   header: "Text"  -> fester Kopfzeilentext, ab Seite 1
//   sonst           -> Running Header mit dem aktiven H1-Kapitel; vor dem ersten
//                      Kapitel der Titel (title:), falls gesetzt
#let head-override = sys.inputs.at("header", default: "")
// Optionales Wasserzeichen (Frontmatter watermark:): diagonal, gespreizt, fett,
// auf unterster Ebene unter allen Elementen.
#let watermark-text = sys.inputs.at("watermark", default: "")
// Maximale Logohöhe (Frontmatter logo-height:), nur absolute Längen.
#let logo-height-raw = sys.inputs.at("logo_height", default: "")

// Markdown vorverarbeiten (lib/markdown.typ).
// hard_breaks: true -> jede Zeile bleibt eine Zeile (Frontmatter oder --hard-breaks).
#let body-markdown = if source-path == none { "" } else {
  preprocess(read(source-path), hard-breaks: sys.inputs.at("hard_breaks", default: "false") == "true")
}
// Sichtbarer Dokumenttitel nur aus dem Frontmatter (title:): Titelblock oben +
// Kopfzeile ab Seite 1. Leer = kein Titel; ein "# …" ist immer ein Kapitel.
#let title-text = sys.inputs.at("doctitle", default: "")
// PDF/A-Metadatentitel (Pflicht): sichtbarer Titel, sonst .md-Basisname.
#let doc-title = if title-text != "" { title-text } else { sys.inputs.at("title", default: "Dokument") }

// Datum aus dem Frontmatter: ISO (2026-10-13) oder deutsch (13.10.2026).
// Defensiv: ungültige Werte -> none (datetime()/int() würden den Build sonst
// per Panic abbrechen).
#let parse-date(raw) = {
  let s = raw.trim()
  let (y, m, d) = if s.match(regex("^\d{4}-\d{1,2}-\d{1,2}$")) != none {
    s.split("-").map(int)
  } else if s.match(regex("^\d{1,2}\.\d{1,2}\.\d{4}$")) != none {
    s.split(".").map(int).rev()
  } else { return none }
  if m < 1 or m > 12 or d < 1 or d > 31 { return none }
  datetime(year: y, month: m, day: d)
}
#let date-parsed = parse-date(date-raw)

// PDF-/PDF-A-Metadaten: Titel ist für PDF/A Pflicht.
// Datum: standardmäßig würde Typst (date: auto) den *Build-Zeitpunkt* inkl.
// Uhrzeit in CreateDate/ModifyDate schreiben -> nicht reproduzierbar. Stattdessen
// ans Frontmatter date: pinnen (trägt das Dokumentdatum, byte-stabil bzgl. des
// Zeitstempels). Ohne gültiges date: bleibt es auto -- PDF/A-3b verlangt ZWINGEND
// ein Datum (date: none bricht den Export ab), aber build.sh setzt dann
// SOURCE_DATE_EPOCH aus der Quell-mtime, sodass auch auto stabil statt "jetzt" ist.
#set document(title: doc-title, date: if date-parsed == none { auto } else { date-parsed })

// PDF/A-3b erlaubt eingebettete Dateien: Original-Markdown als Anhang beilegen.
// Name des Anhangs = reiner Dateiname: mit nur einem Pfad würde Typst den
// vollen lokalen Pfad (inkl. Benutzername) als Anhangsnamen ins PDF schreiben.
#if attach-path != "" {
  pdf.attach(
    "/" + attach-path.split("/").last(),
    read(attach-path, encoding: none),
    relationship: "source",
    mime-type: "text/markdown",
    description: "Markdown-Quelle dieses Dokuments",
  )
}

// ---------------------------------------------------------------------------
// Farben
// ---------------------------------------------------------------------------
#let heading-color = luma(8%)  // Überschriften: dunkel, kontrastreich
#let head-color = luma(20%)    // "Chrome" (Kopf/Fuß-Text): 80 % Grau
#let rule-stroke = 0.5pt + luma(20%) // Trennlinien (Kopf/Fuß): 80 % Grau
// Hairline dicht unter H2: leicht aber sichtbar.
#let hairline-stroke = 0.6pt + luma(60%)

// Fließtext in Sans (Source Sans 3), Überschriften in Serif (Source Serif 4),
// Code in Source Code Pro.
//
// Zeichenbasierter Fallback (Typst macht das pro Glyph automatisch): zuerst
// Source; nur Zeichen, die Source NICHT hat (Emoji, Symbole), fallen einzeln auf
// Noto Emoji, dann Noto Sans Symbols 2. Normaler Text bleibt damit voll Source.
// Beide Notos sind monochrom -> PDF/A-3b-tauglich und einbettbar.
#let fallback-fonts = ("Noto Emoji", "Noto Sans Symbols 2")
#let body-font = ("SourceSans3VF", ..fallback-fonts)
// Überschriften (inkl. „Inhalt" und Kapitel im Seitenkopf) in Serif; Fließtext
// und TOC-Einträge bleiben Sans.
#let heading-font = ("Source Serif 4", ..fallback-fonts)
#let code-font = ("SourceCodeVF", ..fallback-fonts)

// Strichstärken (wght-Achse der variablen Schriften). PDF-Viewer (Vorschau)
// zeichnen die variablen Source-Schriften kräftiger als Browser/Editor; leicht
// unter den Nennwerten wirkt das PDF wie der Editor: Text 380, Überschriften 470,
// Fett 560 (= Text + strong.delta 180).
#let weight-text = 380
#let weight-heading = 470

// Seitengeometrie (zentral, von Seite UND Header-Logik genutzt)
#let margin-top = 35mm
#let margin-bottom = 20mm
#let margin-left = 30mm
#let margin-right = 20mm

// Logo: proportional in einen Rahmen aus maximaler Höhe und Breite eingepasst.
// Standardhöhe 13 mm; logo-height: (nur absolute Längen wie 15mm, 1.2cm, 40pt,
// 0.8in) übersteuert, gedeckelt auf 25 mm, damit der Kopf im oberen Rand bleibt.
// Ungültige Werte (z. B. 50%) werden ignoriert.
#let logo-max-width = 60mm
#let logo-max-height = {
  let m = logo-height-raw.trim().match(regex("^(\d+(?:\.\d+)?)\s*(mm|cm|pt|in)$"))
  if m == none { 13mm } else {
    let v = float(m.captures.at(0))
    let unit = (mm: 1mm, cm: 1cm, pt: 1pt, "in": 1in).at(m.captures.at(1))
    calc.min(v * unit, 25mm)
  }
}
#let doc-logo = if logo-path == "" { [] } else {
  context {
    let natural = measure(image(logo-path))
    let scale = calc.min(logo-max-width / natural.width, logo-max-height / natural.height)
    image(logo-path, width: natural.width * scale, alt: "Logo")
  }
}

// ---------------------------------------------------------------------------
// Laufender Seitenkopf: Text links, Logo rechts, Linie darunter.
//   header: gesetzt  -> fester Text ab Seite 1 (Vorrang).
//   sonst            -> aktives H1-Kapitel; vor dem ersten Kapitel der Titel
//                       (title:), falls gesetzt, sonst leer.
// ---------------------------------------------------------------------------
#let doc-header = context {
  let this-page = here().page()
  let current = if head-override != "" {
    // Fester Kopfzeilentext: auf allen Seiten (ab Seite 1).
    head-override
  } else {
    // Running Header: H1, das OBEN auf dieser Seite aktiv ist:
    //   1) ein H1 direkt am Seitenanfang, sonst
    //   2) das zuletzt auf einer früheren Seite begonnene H1 (Fortsetzung), sonst
    //   3) der Titel (vor dem ersten Kapitel), sonst nichts.
    let all = query(heading.where(level: 1))
    let at-top = all.filter(h => (
      h.location().page() == this-page and h.location().position().y < margin-top + 8mm
    ))
    let prior = all.filter(h => h.location().page() < this-page)
    if at-top.len() > 0 { at-top.first().body }
    else if prior.len() > 0 { prior.last().body }
    else if title-text != "" { title-text }
    else { [] }
  }
  // Kopf-Text: Sans (nicht Serif wie die Überschriften), 13pt, ohne grafisches
  // Element. Kopf und Fuß bleiben bewusst serifenlos.
  let chapter = text(font: body-font, weight: weight-text, size: 13pt, fill: head-color,
    number-type: "lining")[#current]
  grid(
    columns: (1fr, auto),
    column-gutter: 6mm,
    align: (left + bottom, right + bottom),
    chapter,
    doc-logo,
  )
  v(2pt)
  line(length: 100%, stroke: rule-stroke)
}

// ---------------------------------------------------------------------------
// Dokumentsprache (einmal zentral; auch für die Datumslokalisierung genutzt)
// ---------------------------------------------------------------------------
#let doc-lang = sys.inputs.at("lang", default: "de")

// Beschriftungen je Sprache (de, sonst en).
#let labels = (
  de: (page: "Seite", contents: "Inhalt", task: "Aufgabe", owner: "Wer", due: "Bis", status: "Status",
       note: "Info", tip: "Tipp", important: "Wichtig", warning: "Hinweis", caution: "Achtung",
       missing: "Bild fehlt", diagram: "Diagramm"),
  en: (page: "Page", contents: "Contents", task: "Task", owner: "Owner", due: "Due", status: "Status",
       note: "Note", tip: "Tip", important: "Important", warning: "Warning", caution: "Caution",
       missing: "Image missing", diagram: "Diagram"),
)
#let label-text(key) = labels.at(doc-lang.slice(0, calc.min(2, doc-lang.len())), default: labels.en).at(key)

// Lokalisiertes Datum. Typst lokalisiert Monatsnamen NICHT selbst
// ([month repr:long] ist nur Englisch), daher manuelle Tabelle. Ein nicht
// erkennbares Datum (z. B. "Herbst 2026") erscheint unverändert; leer -> none.
#let months-de = (
  "Januar", "Februar", "März", "April", "Mai", "Juni",
  "Juli", "August", "September", "Oktober", "November", "Dezember",
)
#let date-display = {
  let dt = date-parsed
  if dt == none {
    if date-raw.trim() == "" { none } else { date-raw.trim() }
  } else if doc-lang.starts-with("de") {
    [#dt.display("[day padding:none]"). #months-de.at(dt.month() - 1) #dt.display("[year]")]
  } else {
    dt.display("[month repr:long] [day padding:none], [year]")
  }
}

// ---------------------------------------------------------------------------
// Fußzeile: Trennlinie darüber. Ohne Datum 2-spaltig (Name | Seite x/y),
// mit Datum 3-spaltig (Name | Seite x/y mittig | Datum).
// Links steht der Dateiname – oder, sobald client: oder subtitle: gesetzt ist,
// höchstens zwei Angaben aus Kunde, Titel, Untertitel in dieser Reihenfolge
// ("Kunde · Titel", ohne Kunde "Titel · Untertitel"). print_filename:false
// blendet die linke Angabe aus.
// ---------------------------------------------------------------------------
#let footer-left = if client-text != "" or subtitle-text != "" {
  let parts = (client-text, title-text, subtitle-text).filter(p => p != "")
  parts.slice(0, calc.min(2, parts.len())).join(" · ")
} else { doc-filename }

#let doc-footer = context {
  let n = counter(page).at(here()).first()
  let total = counter(page).final().first()
  let date-disp = date-display
  let name = if show-name { footer-left } else { [] }
  let page-num = [#label-text("page") #n / #total]
  line(length: 100%, stroke: rule-stroke)
  v(2pt)
  set text(font: body-font, size: 9pt, fill: head-color, number-type: "lining")
  if date-disp == none {
    // 2-spaltig: Name links, Seitenzahl rechts (bzw. mittig, wenn kein Name).
    if show-name {
      grid(
        columns: (1fr, auto),
        align: (left + top, right + top),
        name, page-num,
      )
    } else {
      align(center, page-num)
    }
  } else {
    // 3-spaltig: Name links, Seitenzahl mittig, Datum rechts.
    grid(
      columns: (1fr, auto, 1fr),
      align: (left + top, center + top, right + top),
      name, page-num, align(right, date-disp),
    )
  }
}

// ---------------------------------------------------------------------------
// Seitengeometrie
// ---------------------------------------------------------------------------
// Wasserzeichen im Seitenhintergrund (liegt unter allem): diagonal (-45°),
// gespreizt (tracking), fett. Grau über `luma()`: Typst legt neutrale Grautöne
// im PDF/A als Einkanal-Graustufen ab (ICCBased /N 1, NICHT RGB) -> separiert
// auf CMYK-Maschinen sauber nach K, kein „Rich-Gray". luma(92%) ~ 8 % Schwarz.
// Echtes CMYK (cmyk(0,0,0,10%)) kann Typst 0.15 im PDF/A-Export (noch) nicht
// einbetten. Leer -> kein Hintergrund.
#let watermark-bg = if watermark-text != "" {
  align(center + horizon, rotate(-45deg,
    text(font: body-font, weight: "bold", size: 90pt, tracking: 0.18em,
      fill: luma(92%))[#watermark-text]))
} else { none }

#set page(
  paper: "a4",
  margin: (top: margin-top, bottom: margin-bottom, left: margin-left, right: margin-right),
  header: doc-header,
  header-ascent: 6mm,
  footer: doc-footer,
  footer-descent: 6mm,
  background: watermark-bg,
)

// ---------------------------------------------------------------------------
// Fließtext, Überschriften, Code
// ---------------------------------------------------------------------------
// costs: Schusterjungen (orphan – erste Absatzzeile allein am Seitenfuß) und
// Hurenkinder (widow – letzte Absatzzeile allein am Seitenkopf) werden über den
// Default hinaus verteuert, sodass Typst sie vermeidet (eine Zeile mitnimmt).
// runt = einzelnes kurzes Wort allein auf der letzten Absatzzeile (im Blocksatz
// unschön) – ebenfalls verteuert, damit Typst umbricht/trennt statt es stehen zu lassen.
// Mediävalziffern im Fließtext und in Überschriften (Tabellen: Versalziffern
// gleicher Breite, Code: neutral, Kopf/Fuß: Versalziffern).
#set text(font: body-font, size: 11pt, weight: weight-text, number-type: "old-style",
  lang: doc-lang, hyphenate: true, fill: luma(13%),
  costs: (orphan: 200%, widow: 200%, runt: 200%))
#set par(justify: true, leading: 0.85em, spacing: 1.1em)

// Geschützte Leerzeichen (NBSP): verhindern hässliche Zeilenumbrüche mitten in
// deutschen Abkürzungen, Einheiten, Prozent- und Währungsangaben.
// (a) Deutsche Abkürzungen – literale Ersetzung; das Ergebnis enthält NBSP (~)
//     statt eines normalen Leerzeichens, daher keine Rekursion der Show-Regel.
#show "z. B.": [z.~B.]
#show "u. a.": [u.~a.]
#show "d. h.": [d.~h.]
#show "u. Ä.": [u.~Ä.]
#show "o. Ä.": [o.~Ä.]
#show "u. U.": [u.~U.]
#show "z. T.": [z.~T.]
#show "i. d. R.": [i.~d.~R.]
#show "s. o.": [s.~o.]
#show "s. u.": [s.~u.]
// (b) Zahl + Einheit/Prozent/Währung – das trennende Leerzeichen wird geschützt.
//     Typsts Regex (Rust regex-Crate) kennt kein Lookaround -> den ganzen Treffer
//     matchen und das eine Leerzeichen durch NBSP ersetzen. Buchstaben-Einheiten
//     mit \b abgrenzen (kein Treffer in „5 Meter"); Symbol-Einheiten ohne \b.
#show regex("[0-9] (pt|px|mm|cm|km|kg|mg|MB|GB|KB|TB|ms|dpi|ppi|°C)\b"): it => it.text.replace(" ", "\u{00A0}")
#show regex("[0-9] (%|€|£|\\$)"): it => it.text.replace(" ", "\u{00A0}")

// Code/`raw` von den NBSP-Regeln oben ausnehmen. Sonst würde ein Space in einem
// Code-Beispiel (etwa `x = 5 % 2` oder `12 pt`) zu NBSP – im PDF unsichtbar, aber
// beim Copy-Paste bricht der eingefügte U+00A0 den Code (Shell/Python/JS). Typst
// hat keinen „nicht in raw"-Selektor; die NBSP-Regeln oben greifen auf JEDEN Text.
// Lösung: innerhalb von raw ein unsichtbares Atom (box()) zwischen die geschützte
// Zahl/Abkürzung und ihr Folgezeichen schieben. Der sichtbare Text (mit normalem
// Space) bleibt exakt erhalten, aber die äußeren Regex-/String-Regeln finden kein
// zusammenhängendes Muster mehr und feuern nicht. Zwei Anker decken alles ab:
//   (1) Zahl + Space  -> bricht Einheiten- UND Symbol-/Prozent-/Währungsregel,
//   (2) Buchstabe. + Space  -> bricht alle Abkürzungen (jeder geschützte Space
//       dort steht hinter „x."). Die box() wird jeweils HINTER den Space (vor das
//       Folgezeichen) gesetzt; Nachbarzeichen werden mit re-emittiert, damit die
//       äußere Regel den Treffer nicht doch über die Elementgrenze zusammenzieht.
#show raw: it => {
  show regex("[0-9] \S"): r => [#r.text.slice(0, 2)#box()#r.text.slice(2)]
  show regex("[A-Za-zÄÖÜäöü]\. \S"): r => [#r.text.slice(0, 3)#box()#r.text.slice(3)]
  it
}

// Ungeordnete Listen: auf ALLEN Ebenen derselbe Marker – ein kleines Quadrat
// (statt der ebenenabhängigen Standardzeichen •/‣/–). Als Typst-Form gezeichnet
// (font-unabhängig, exakte Größe/Farbe), leicht angehoben zur optischen Mitte.
// Gemischte Listen (normale Punkte + Tasks) löst cmarker nativ: Task-Items nutzen
// das Aufgaben-Kästchen (task-box), Nicht-Task-Items diesen Quadrat-Marker.
// Beide sitzen in einem Feld gleicher Breite (marker-slot) -> der Text aller
// Einträge beginnt bündig, das Quadrat steht mittig über dem Kästchen.
#let marker-slot = 0.72em
#let rfd-list-marker = box(width: marker-slot,
  align(center, box(baseline: -0.2em, square(size: 0.32em, fill: luma(20%)))))
#set list(marker: rfd-list-marker, body-indent: 0.4em)

// Aufgaben-Kästchen (Liste und Aufgabentabelle): offen = leerer Rahmen,
// erledigt = dunkel gefüllt mit weißem Häkchen. Gezeichnet statt ☐/☒-Glyphen.
#let task-box(done) = box(
  width: marker-slot, height: marker-slot, baseline: 0.1em, radius: 1.5pt,
  stroke: 0.7pt + luma(35%),
  fill: if done { luma(20%) } else { none },
  if done { align(center + horizon, text(fill: white, size: 0.62em, weight: 700)[✓]) },
)

// Markierung (==Text== -> <mark>): gelblicher Hintergrund.
#set highlight(fill: rgb("#fbeab0"))

// Blockzitate heben sich ab: schmaler als der Satzspiegel (beidseitig
// eingerückt) und kursiv.
#show quote.where(block: true): it => pad(left: 2em, right: 2em,
  block(spacing: 1.1em, text(style: "italic", it.body)))

// Schrift/Farbe für alle Überschriften (Serif; Gewicht je Ebene: H1/„Inhalt"
// halbfett bzw. Book-Schnitt der variablen Schrift).
// Fett: Typst ADDIERT strong.delta zur aktuellen Stärke (Standard +300 -> 680,
// fast schwarz). Nie zusätzlich eine Stärke in `show strong` setzen.
#set strong(delta: 180)

#let heading-text(size, weight, body) = text(
  font: heading-font, weight: weight, fill: heading-color, size: size, body,
)

// Strukturmodus-Steuerung: Frontmatter (toc/h1_break) übersteuert den
// Automatismus (#H1 + #H2) > 5. Drei Zustände je Schlüssel: true|false|auto.
// Die Helfer enthalten nur `query` (kein `it`) -> keine Rekursion der Show-Regel.
#let auto-structured() = query(heading).filter(h => h.level == 1 or h.level == 2).len() > 5
#let want-toc() = if toc-mode == "true" { true } else if toc-mode == "false" { false } else { auto-structured() }
#let want-break() = if break-mode == "true" { true } else if break-mode == "false" { false } else { auto-structured() }

// H1 = Kapitel (Linie + Umbruch), H2/H3 = Unterabschnitte, H4+ nur fett.
// Alle Überschriften linksbündig und mit Abstand-oben > Abstand-unten (binden an
// den folgenden Text). Der Titel ist KEIN Heading mehr (kommt aus title:).
#show heading: it => {
  set par(justify: false)
  if it.level == 1 {
    // Kapitel: Umbruch davor (h1_break), Serif, feine Linie DICHT darunter.
    // par(spacing) im Block klein setzen – sonst liegt zwischen Text und Linie
    // der Default-Absatzabstand (1.1em) und die Linie sitzt zu tief.
    context { if want-break() { pagebreak(weak: true) } }
    // sticky: true bindet die Überschrift an den Folgeinhalt -> nie allein am
    // Seitenfuß. Alle Ebenen: Abstand-oben > Abstand-unten (bindet nach unten),
    // aber below groß genug, dass der Text nicht klebt (~above/2).
    block(width: 100%, above: 2.0em, below: 0.6em, sticky: true, {
      set par(spacing: 2pt)
      heading-text(15pt, weight-heading, it)
      line(length: 100%, stroke: hairline-stroke)
    })
  } else if it.level == 2 {
    block(width: 100%, above: 1.5em, below: 0.7em, sticky: true, heading-text(13pt, weight-heading, it))
  } else if it.level == 3 {
    // H3: Body-Größe (11pt), schlank; eine feine Unterstreichung setzt sie ab.
    block(width: 100%, above: 1.25em, below: 0.55em, sticky: true,
      underline(stroke: 0.5pt + heading-color, offset: 2pt, heading-text(11pt, weight-text, it)))
  } else {
    // H4 und tiefer: Body-Größe, kursiv.
    block(width: 100%, above: 1.25em, below: 0.55em, sticky: true,
      text(style: "italic", heading-text(11pt, weight-text, it)))
  }
}

// Inhaltsverzeichnis: nur H1 + H2, gleiche Zeilenabstände, Einträge in Sans und
// knapp über Fließtextgröße (Book, wght 450 – Default-Bold der H1 neutralisiert).
#let toc-entry(body) = block(above: 0.55em, below: 0pt, {
  show strong: s => s.body
  set text(font: body-font, weight: weight-text, size: 12pt)
  body
})
#show outline.entry.where(level: 1): it => toc-entry(it)
#show outline.entry.where(level: 2): it => toc-entry(it)

#show raw: set text(font: code-font, size: 10pt, number-type: auto, number-width: auto)
#show raw.where(block: true): it => block(
  fill: luma(245),
  inset: 8pt,
  radius: 3pt,
  width: 100%,
  it,
)

// Mermaid-Diagramme (```mermaid) offline über das gebündelte Typst-Paket mmdr
// (WASM, kein Netz). Farben aus der ruhigen Palette (Flächen, Rahmen, Linien,
// Text, Notizen). Schrift: NUR die variable Source Sans 3 von Adobe. Typst
// wählt im SVG die benannten Schnitte der variablen Schrift – font-weight 400
// fällt dabei auf den Standardschnitt ExtraLight (200) zurück und wird
// hauchdünn; 500 (Medium) trifft einen echten Schnitt und bleibt gut lesbar.
// Darum setzt die Regel font-weight="500" in das SVG. mmdr bricht bei
// fehlerhafter Syntax nicht ab (zeichnet, was es versteht).
#let mermaid-theme = (
  font_family: "SourceSans3VF",
  primary_color: "#f4f2ee",
  primary_text_color: "#2b2b2b",
  primary_border_color: "#b9b2a6",
  secondary_color: "#fbeab0",
  tertiary_color: "#fdfcfa",
  line_color: "#6b6b6b",
  text_color: "#2b2b2b",
  edge_label_background: "#ffffff",
  cluster_background: "#fdfcfa",
  cluster_border: "#e4e1dc",
  background: "#ffffff",
  sequence_actor_fill: "#f4f2ee",
  sequence_actor_border: "#b9b2a6",
  sequence_actor_line: "#b9b2a6",
  sequence_note_fill: "#fbeab0",
  sequence_note_border: "#e0c66a",
)
#show raw.where(lang: "mermaid", block: true): it => block(
  width: 100%, above: 1.4em, below: 1.4em, breakable: false,
  {
    let svg = mermaid-svg(it.text, base-theme: "modern", theme: mermaid-theme)
      .replace("font-family=", "font-weight=\"500\" font-family=")
    align(center, image(bytes(svg), format: "svg", alt: label-text("diagram"),
      width: auto))
  },
)

// Fußnoten mit hängendem Einzug: Markierung in fester Spalte, Body als eigener
// Block daneben -> alle Body-Zeilen fluchten unter dem Textanfang.
#show footnote.entry: it => {
  let loc = it.note.location()
  let num = numbering(it.note.numbering, ..counter(footnote).at(loc))
  block(inset: (left: 1em), grid(
    columns: (1.5em, 1fr),
    align: (left + top, left + top),
    super(num),
    it.note.body,
  ))
}

// ---------------------------------------------------------------------------
// Body: Markdown -> Typst via cmarker
// ---------------------------------------------------------------------------
// Bilder. Typst hat keinen Netzzugriff und kann nicht prüfen, ob eine Datei
// existiert (ein fehlendes Bild bricht den Build ab). Daher zwei Durchläufe:
//   1. probe=true: Bilder werden NICHT geladen, jede Quelle wird nur als
//      Metadatum <rfd-image> notiert. build.sh/convert.ps1 lesen sie per
//      `typst eval` aus, ersetzen ~/$VAR/${VAR}/%VAR%, lösen relative Pfade gegen
//      die Notiz auf und prüfen, ob die Datei existiert.
//   2. images=<json>: Zuordnung Quelle -> absoluter Pfad ("" = fehlt). Ein
//      fehlendes Bild erscheint kursiv als „[Bild fehlt: pfad]", nie als Abbruch.
// Remote-Quellen (http(s), //host, data:) werden nicht gerendert, aber als
// <rfd-remote-skip> gezählt. Lokale Bilder mit Alt-Text werden zur nummerierten
// Abbildung mit Untertitel; die Breite kommt aus {width=…} (siehe lib/markdown.typ).
#let probe-mode = sys.inputs.at("probe", default: "false") == "true"
#let image-map = {
  let f = sys.inputs.at("images", default: "")
  if f == "" { none } else { json(f) }
}
#let is-remote(s) = type(s) == str and (
  s.starts-with("http://") or s.starts-with("https://")
    or s.starts-with("//") or s.starts-with("data:"))
// Ohne Zuordnung (z. B. direkter typst-Aufruf): relative Pfade gegen das
// Dokumentverzeichnis auflösen; absolute (führendes "/") unverändert.
#let resolve-path(p) = if doc-dir == "" or p.starts-with("/") { p } else { doc-dir + "/" + p }
#let safe-image(source, alt: none, ..args) = {
  if type(source) != str {
    image(source, alt: alt, ..args)
  } else if is-remote(source) {
    [#metadata("rfd-remote-skip")<rfd-remote-skip>]
  } else if probe-mode {
    [#metadata(source)<rfd-image>]
  } else {
    let path = if image-map == none { resolve-path(source) } else { image-map.at(source, default: "") }
    if path == "" {
      emph[\[#label-text("missing"): #source\]]
    } else if alt != none and alt != "" {
      figure(image(path, alt: alt, ..args), caption: alt)
    } else {
      image(path, alt: alt, ..args)
    }
  }
}

// Task-Listen-Marker (gemischte Listen): das gezeichnete Kästchen ersetzt den
// Aufzählungspunkt.
#let rfd-task-marker(checked) = task-box(checked)

// Hinweisboxen (> [!NOTE] … bzw. > [!HINWEIS] …, aus lib/markdown.typ als
// <rfd-alert kind="…">). Farben WCAG-AA auf Weiß; warning bewusst ruhiges
// Orange statt Warnrot. Fläche stark aufgehellt, links ein 2,5-pt-Balken, Titel
// klein, gesperrt, in Versalien. breakable: false -> der Titel steht nie allein
// am Seitenfuß.
#let alert-colors = (
  note: rgb("#2f6aa8"),
  tip: rgb("#3b7d3a"),
  important: rgb("#7a4fb0"),
  warning: rgb("#b05a1a"),
  caution: rgb("#b5452b"),
)
#let rfd-alert(attrs, body) = {
  let kind = attrs.at("kind", default: "note")
  let color = alert-colors.at(kind, default: alert-colors.note)
  block(
    width: 100%, breakable: false,
    fill: color.lighten(93%),
    stroke: (left: 2.5pt + color),
    radius: (right: 3pt),
    inset: (left: 12pt, right: 10pt, y: 8pt),
    above: 1.2em, below: 1.2em,
    {
      set par(spacing: 0.7em)
      block(below: 0.6em, text(size: 0.8em, weight: weight-text + 180, tracking: 0.06em, fill: color,
        upper(label-text(kind))))
      body
    },
  )
}

// Aufgabentabelle (reine Aufgabenliste, aus lib/markdown.typ als <rfd-tasks>
// mit <rfd-task done owner due>). Jede <rfd-task> liefert ein Metadatum; die
// Tabelle sammelt sie ein. Gestaltet wie alle Tabellen: Typsts auto-Spalten
// (so breit wie der Inhalt), Tabellenschrift table-text, Kopf zentriert, Status
// zentriert. Eine überall leere Spalte (Wer/Bis) entfällt.
#let rfd-task(attrs, body) = metadata((
  done: attrs.at("done", default: "false") == "true",
  owner: attrs.at("owner", default: ""),
  due: attrs.at("due", default: ""),
  body: body,
))
#let rfd-tasks(attrs, body) = {
  let children = if body.func() == metadata { (body,) } else if body.has("children") { body.children } else { () }
  let tasks = children.filter(c => c.func() == metadata).map(c => c.value)
  let cols = ("task",)
  if tasks.any(t => t.owner != "") { cols.push("owner") }
  if tasks.any(t => t.due != "") { cols.push("due") }
  cols.push("status")
  let status-x = cols.len() - 1
  let cell(t, key) = if key == "task" { t.body } else if key == "status" { task-box(t.done) } else { t.at(key) }
  set par(justify: false)
  set text(..table-text)
  show raw: set text(size: 8.5pt)
  block(above: 1.2em, below: 1.4em, breakable: true, table(
    columns: (auto,) * cols.len(),
    align: (x, y) => if y == 0 or x == status-x { center + horizon } else { left + horizon },
    fill: rfd-table-fill,
    stroke: rfd-table-stroke,
    table.header(..cols.map(label-text)),
    ..tasks.map(t => cols.map(c => {
      set par(spacing: 0pt)
      cell(t, c)
    })).flatten(),
  ))
}

// `terms`-Override für Definitionslisten (aus cmarker <dl>): Begriff fett auf
// eigener Zeile, Beschreibung darunter eingerückt; ein Paar bricht nicht über
// die Seite. Direkt als Blöcke gebaut – eine `#show terms.item`-Regel greift in
// Typst 0.15 nicht (Begriff und Beschreibung liefen sonst in einer Zeile).
#let rfd-terms(..pairs) = for p in pairs.pos() {
  block(breakable: false, above: 0.9em, below: 0.9em, {
    strong(p.at(0))
    block(inset: (left: 1.5em), above: 0.45em, p.at(1))
  })
}

// Titelblock + optionales Inhaltsverzeichnis, VOR dem Markdown-Body. Der Titel
// ist KEIN Heading (steht daher nicht im TOC); H1 ist ein Kapitel.
// Aufbau (mittig, jeweils nur was gesetzt ist): Kunde klein und gesperrt über
// dem Titel, Titel, Untertitel, darunter "Datum · Autor".
#let meta-line = (date-display, if author-text != "" { author-text }).filter(p => p != none)
#if (client-text, title-text, subtitle-text, author-text).any(p => p != "") {
  block(width: 100%, above: 0.2em, below: 1.0em, align(center, {
    set par(justify: false)
    if client-text != "" {
      block(below: 0.6em, text(font: body-font, size: 9pt, tracking: 0.12em, fill: head-color,
        upper(client-text)))
    }
    if title-text != "" {
      block(below: 0.5em, heading-text(18pt, weight-heading, title-text))
    }
    if subtitle-text != "" {
      block(below: 0.6em, text(font: heading-font, size: 13pt, fill: head-color, subtitle-text))
    }
    // Datum/Autor-Zeile nur, wenn ein Autor gesetzt ist – das Datum allein
    // steht wie bisher rechts in der Fußzeile.
    if author-text != "" {
      text(font: body-font, size: 10pt, fill: head-color, meta-line.join(" · "))
    }
  }))
}
#context {
  if want-toc() {
    block(above: 2.0em, below: 1.0em, heading-text(15pt, weight-heading, label-text("contents")))
    outline(title: none, depth: 2)
    pagebreak(weak: true)
  }
}

#cmarker.render(
  body-markdown,
  h1-level: 1,
  set-document-title: false,
  math: mitex,
  // Keine Smart-Quote-Automatik: getippte Anführungszeichen („ “ ‚ ‘ » «) und
  // gerade " ' bleiben exakt wie getippt (die Automatik setzte sonst englische
  // “…” auch in deutschen Text). Ebenso bleiben -- und ... wie getippt.
  smart-punctuation: false,
  task-list-marker: rfd-task-marker,
  html: (rfd-alert: rfd-alert, rfd-tasks: rfd-tasks, rfd-task: rfd-task),
  scope: (image: safe-image, divider: () => horizontalrule, terms: rfd-terms),
)
