// Markdown -> Typst Template (PDF/A-tauglich)
// Layout: DIN A4 Hochformat, asymmetrische Ränder, dynamischer Kopf (aktuelles H2)
// + Logo, Fußzeile mit Dateiname & Seite x/y, Trennlinien.
//
// Diese Datei ist eine reine Typst-Datei (KEIN Pandoc-Template mehr): der Body
// wird am Ende selbst per cmarker aus der Markdown-Quelle erzeugt.

#import "vendor/cmarker/lib.typ" as cmarker
#import "vendor/mitex/lib.typ": mitex

// ---------------------------------------------------------------------------
// Helfer für von cmarker erzeugte Elemente
// ---------------------------------------------------------------------------
// Thematische Trennlinie (`---`): mittige Teillinie statt voller Breite.
#let horizontalrule = align(center, line(start: (25%, 0%), end: (75%, 0%)))

// Definitionslisten (aus cmarker <dl>): Begriff fett, Beschreibung eingerückt.
#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

#set table(inset: 7pt, stroke: none)
// Tabellen über die volle Satzspiegelbreite; Kopf zentriert + fett, alle Inhalte
// linksbündig (auch Zahlen/Währungen), Zeilen mit dezent wechselndem Hintergrund.
#show table: it => {
  // Guard gegen Rekursion: die umgebaute Tabelle hat ein fill (Funktion), die
  // cmarker-Originaltabelle nicht -> dann unverändert durchreichen.
  if it.fill != none {
    it
  } else {
    let n = if type(it.columns) == int { it.columns } else { it.columns.len() }
    table(
      columns: (1fr,) * n,
      align: (_, y) => if y == 0 { center } else { left },
      fill: (_, y) => if y > 0 and calc.even(y) { luma(95%) } else { none },
      ..it.children,
    )
  }
}
#show table.cell.where(y: 0): strong
#show figure.where(kind: table): set figure.caption(position: top)
#show figure.where(kind: image): set figure.caption(position: bottom)

// ---------------------------------------------------------------------------
// Laufzeit-Eingaben (via `typst compile --input ...`)
// ---------------------------------------------------------------------------
#let doc-filename = sys.inputs.at("filename", default: "document.md")
// PDF/A verlangt einen Dokumenttitel -> vom Build als .md-Basisname gereicht.
#let doc-title = sys.inputs.at("title", default: "Dokument")
// Leerer Pfad = kein Logo (Kopf läuft dann ohne Logo durch).
#let logo-path = sys.inputs.at("logo", default: "")
// Zu rendernde Quelle (ggf. vorverarbeitete Kopie).
#let render-path = sys.inputs.at("source", default: none)
// Verzeichnis der Original-Quelle: relative Bildpfade im Markdown werden dagegen
// aufgelöst (nicht gegen den Projekt-Root), damit Bilder neben Dokumenten überall
// gefunden werden.
#let doc-dir = sys.inputs.at("docdir", default: "")
// Einzubettende Original-Quelle (pdf.attach); getrennt von render-path, damit
// der Anhang die unveränderte .md mit korrektem Namen behält.
#let attach-path = sys.inputs.at("attach", default: none)
// Frontmatter-gesteuert (von build.sh/convert.ps1 aus dem YAML-Block gereicht):
#let date-iso   = sys.inputs.at("date", default: "")       // ISO-Wert oder leer
#let toc-mode   = sys.inputs.at("toc", default: "auto")    // "true" | "false" | "auto"
#let break-mode = sys.inputs.at("h2-break", default: "auto")
#let show-name  = sys.inputs.at("showname", default: "true") != "false"

// PDF-/PDF-A-Metadaten: Titel ist für PDF/A Pflicht.
#set document(title: doc-title)

// PDF/A-3b erlaubt eingebettete Dateien: Original-Markdown als Anhang beilegen.
#if attach-path != none {
  pdf.attach(
    attach-path,
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
#let rule-stroke = 0.5pt + luma(20%) // Trennlinien: 80 % Grau
#let accent = luma(20%)        // Akzent (Balken der Überschriften): 80 % Grau
// Hairlines unter den Überschriften: heller als der Balken, leicht aber sichtbar.
#let hairline-stroke = 0.6pt + luma(72%)
#let hairline-thin   = 0.4pt + luma(78%)

// Alles "Source", aber serifenlos: Überschriften nutzen denselben Sans wie der
// Fließtext (statt Source Serif 4). Code bleibt SourceCodeVF.
//
// Zeichenbasierter Fallback (Typst macht das pro Glyph automatisch): zuerst
// Source; nur Zeichen, die Source NICHT hat (Emoji, Symbole), fallen einzeln auf
// Noto Emoji, dann Noto Sans Symbols 2. Normaler Text bleibt damit voll Source.
// Beide Notos sind monochrom -> PDF/A-3b-tauglich und einbettbar.
#let fallback-fonts = ("Noto Emoji", "Noto Sans Symbols 2")
#let body-font = ("SourceSans3VF", ..fallback-fonts)
#let heading-font = ("SourceSans3VF", ..fallback-fonts)
#let code-font = ("SourceCodeVF", ..fallback-fonts)

// Seitengeometrie (zentral, von Seite UND Header-Logik genutzt)
#let margin-top = 35mm
#let margin-bottom = 20mm
#let margin-left = 30mm
#let margin-right = 20mm

// Logo-Höhe: muss in den (jetzt schmaleren) oberen Rand passen. Bei 20 mm
// Top-Margin und 6 mm header-ascent bleibt der Kopf damit innerhalb des Randes.
#let logo-height = 13mm

// ---------------------------------------------------------------------------
// Laufender Seitenkopf: aktuelles H2-Kapitel links, Logo rechts, Linie darunter
// (H1 ist der Dokumenttitel und erscheint NICHT im Kopf.)
// ---------------------------------------------------------------------------
#let doc-header = context {
  let this-page = here().page()
  let all = query(heading.where(level: 2))
  // Kapitel (H2), das OBEN auf dieser Seite aktiv ist:
  //   1) ein H2, das direkt am Seitenanfang beginnt (Seitenumbruch davor), sonst
  //   2) das zuletzt auf einer früheren Seite begonnene H2 (Fortsetzung), sonst
  //   3) nichts (Titel-/TOC-Seiten vor dem ersten Kapitel).
  let at-top = all.filter(h => (
    h.location().page() == this-page and h.location().position().y < margin-top + 8mm
  ))
  let prior = all.filter(h => h.location().page() < this-page)
  let current = if at-top.len() > 0 {
    at-top.first().body
  } else if prior.len() > 0 {
    prior.last().body
  } else { [] }
  // Kapitel im Kopf: serifenlos, +2pt (13pt), ohne grafisches Element.
  let chapter = text(font: heading-font, weight: 450, size: 13pt, fill: head-color)[#current]
  grid(
    columns: (1fr, auto),
    column-gutter: 6mm,
    align: (left + bottom, right + bottom),
    chapter,
    if logo-path != "" { image(logo-path, height: logo-height) } else { [] },
  )
  v(2pt)
  line(length: 100%, stroke: rule-stroke)
}

// ---------------------------------------------------------------------------
// Dokumentsprache (einmal zentral; auch für die Datumslokalisierung genutzt)
// ---------------------------------------------------------------------------
#let doc-lang = sys.inputs.at("lang", default: "de")

// Lokalisiertes Datum aus ISO-String. Typst lokalisiert Monatsnamen NICHT
// selbst ([month repr:long] ist nur Englisch), daher manuelle Tabelle.
// Defensiv: ungültige Eingaben -> none (sonst paniced datetime/int den Build).
#let months-de = (
  "Januar", "Februar", "März", "April", "Mai", "Juni",
  "Juli", "August", "September", "Oktober", "November", "Dezember",
)
#let fmt-date(iso, lang) = {
  let s = iso.trim()
  if s == "" { return none }
  if s.match(regex("^\d{1,4}-\d{1,2}-\d{1,2}$")) == none { return none }
  let p = s.split("-").map(int)
  let (y, m, d) = (p.at(0), p.at(1), p.at(2))
  if m < 1 or m > 12 or d < 1 or d > 31 { return none }
  let dt = datetime(year: y, month: m, day: d)
  if lang == "de" {
    [#dt.display("[day padding:none]"). #months-de.at(m - 1) #dt.display("[year]")]
  } else {
    dt.display("[month repr:long] [day padding:none], [year]")
  }
}

// ---------------------------------------------------------------------------
// Fußzeile: Trennlinie darüber. Ohne Datum 2-spaltig (Name | Seite x/y),
// mit Datum 3-spaltig (Name | Seite x/y mittig | Datum). print_filename:false
// blendet den Namen aus.
// ---------------------------------------------------------------------------
#let doc-footer = context {
  let n = counter(page).at(here()).first()
  let total = counter(page).final().first()
  let date-disp = fmt-date(date-iso, doc-lang)
  let name = if show-name { doc-filename } else { [] }
  let page-num = [Seite #n / #total]
  line(length: 100%, stroke: rule-stroke)
  v(2pt)
  set text(font: body-font, size: 9pt, fill: head-color)
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
#set page(
  paper: "a4",
  margin: (top: margin-top, bottom: margin-bottom, left: margin-left, right: margin-right),
  header: doc-header,
  header-ascent: 6mm,
  footer: doc-footer,
  footer-descent: 6mm,
)

// ---------------------------------------------------------------------------
// Fließtext, Überschriften, Code
// ---------------------------------------------------------------------------
#set text(font: body-font, size: 12pt, lang: doc-lang, hyphenate: true, fill: luma(13%))
#set par(justify: true, leading: 0.8em, spacing: 1.1em)

// Ungeordnete Listen: auf ALLEN Ebenen derselbe Marker – ein kleines Quadrat
// (statt der ebenenabhängigen Standardzeichen •/‣/–). Als Typst-Form gezeichnet
// (font-unabhängig, exakte Größe/Farbe), leicht angehoben zur optischen Mitte.
// Gemischte Listen (normale Punkte + Tasks) löst cmarker nativ: Task-Items nutzen
// den task-list-marker unten, Nicht-Task-Items diesen Quadrat-Marker.
#let rfd-list-marker = box(baseline: -0.2em, square(size: 0.32em, fill: luma(20%)))
#set list(marker: rfd-list-marker)

// Blockzitate heben sich ab: schmaler als der Satzspiegel (beidseitig
// eingerückt) und kursiv.
#show quote.where(block: true): it => pad(left: 2em, right: 2em,
  block(spacing: 1.1em, text(style: "italic", it.body)))

// H1 (Dokumenttitel) erscheint nicht im Inhaltsverzeichnis.
#show heading.where(level: 1): set heading(outlined: false)

// Schrift/Farbe für alle Überschriften (serifenlos; Gewicht je Ebene:
// H1/„Inhalt" halbfett, H2/H3 im Book-Schnitt der variablen Schrift).
#let heading-text(size, weight, body) = text(
  font: heading-font, weight: weight, fill: heading-color, size: size, body,
)

// Strukturmodus-Steuerung: Frontmatter (toc/h2-break) übersteuert den
// Automatismus (#H2 + #H3) > 5. Drei Zustände je Schlüssel: true|false|auto.
// Die Helfer enthalten nur `query` (kein `it`) -> keine Rekursion der Show-Regel.
#let auto-structured() = query(heading).filter(h => h.level == 2 or h.level == 3).len() > 5
#let want-toc() = if toc-mode == "true" { true } else if toc-mode == "false" { false } else { auto-structured() }
#let want-break() = if break-mode == "true" { true } else if break-mode == "false" { false } else { auto-structured() }

// H1 = Titel (+ bedingtes TOC), H2 = Kapitel, H3-H6 abgestuft.
// Wichtig: `it` darf NICHT in einem context realisiert werden (sonst greift
// Typsts Rekursionsschutz nicht). Daher nur Zählung/TOC/Umbruch im context.
#show heading: it => {
  // Überschriften nie im Blocksatz: H1 wird explizit zentriert, alle anderen
  // bleiben linksbündig (auch über mehrere Zeilen, ohne Streckung).
  set par(justify: false)
  if it.level == 1 {
    // Titel zentriert, halbfett, mit Luft nach unten.
    block(width: 100%, above: 0.2em, below: 1.0em,
      align(center, heading-text(28pt, "semibold", it.body)))
    context {
      if want-toc() {
        // "Inhalt" als Text (kein Heading -> sonst Rekursion der Show-Regel),
        // mit deutlich Abstand nach oben und unten.
        block(above: 2.0em, below: 1.0em, heading-text(16pt, "semibold", [Inhalt]))
        outline(title: none, depth: 3)
        pagebreak(weak: true)
      }
    }
  } else if it.level == 2 {
    // Kapitel: Book-Schnitt, 3pt-Akzentbalken links + feine Hairline über die
    // volle Breite darunter (leicht, aber klar abgegrenzt – kein Rahmenkasten).
    context { if want-break() { pagebreak(weak: true) } }
    block(width: 100%, above: 1.5em, below: 0.6em, {
      block(inset: (left: 8pt, top: 2pt, bottom: 3pt), stroke: (left: 3pt + accent),
        heading-text(18pt, 450, it))
      v(3pt)
      line(length: 100%, stroke: hairline-stroke)
    })
  } else {
    // H3+: dünnerer 2pt-Balken links + kürzere, leichtere Hairline.
    let size = (14.5pt, 13pt, 12pt, 12pt).at(it.level - 3)
    block(width: 100%, above: 1.3em, below: 0.5em, {
      block(inset: (left: 8pt, top: 1pt, bottom: 2pt), stroke: (left: 2pt + accent),
        heading-text(size, 450, it))
      v(2pt)
      line(length: 45%, stroke: hairline-thin)
    })
  }
}

// Inhaltsverzeichnis lichter: mehr Luft zwischen den Einträgen und Inhalt
// höchstens in "Book" (wght 450, nicht fett) – das Default-Bold der obersten
// Ebene wird neutralisiert.
#let toc-entry(spacing, body) = block(above: spacing, below: 0pt, {
  show strong: s => s.body
  set text(weight: 450, size: 13pt) // TOC-Schriftgrad
  body
})
#show outline.entry.where(level: 2): it => toc-entry(1.0em, it)
#show outline.entry.where(level: 3): it => toc-entry(0.5em, it)

#show raw: set text(font: code-font, size: 10pt)
#show raw.where(block: true): it => block(
  fill: luma(245),
  inset: 8pt,
  radius: 3pt,
  width: 100%,
  it,
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
// Nicht-ladbare Bilder (Typst hat keinen Netzzugriff) werden entfernt: bei
// http(s)-, protokoll-relativen (`//host/…`) und data:-Quellen wird nichts
// gerendert, aber ein unsichtbares Metadatum als Zähl-Marker hinterlegt
// (build.sh zählt es per `typst query <rfd-remote-skip>`). Lokale Bilder mit
// Alt-Text werden zur nummerierten Abbildung mit Untertitel.
#let is-remote(s) = type(s) == str and (
  s.starts-with("http://") or s.starts-with("https://")
    or s.starts-with("//") or s.starts-with("data:"))
// Relative Pfade gegen das Dokumentverzeichnis auflösen; absolute (führendes "/")
// und leeres doc-dir unverändert lassen.
#let resolve-path(p) = if doc-dir == "" or p.starts-with("/") { p } else { doc-dir + "/" + p }
#let safe-image(source, alt: none, ..args) = {
  if is-remote(source) {
    [#metadata("rfd-remote-skip")<rfd-remote-skip>]
  } else if alt != none and alt != "" {
    figure(image(resolve-path(source), alt: alt, ..args), caption: alt)
  } else {
    image(resolve-path(source), alt: alt, ..args)
  }
}

// Task-Listen-Marker als Checkbox aus dem Zeichensatz (Noto-Fallback, monochrom
// und PDF/A-tauglich): leeres Kästchen ☐ = offen, angekreuztes ☒ = erledigt.
// Bewusst ein Kreuz (kein gefülltes Klötzchen), damit „erledigt" erkennbar ist.
#let rfd-task-marker(checked) = {
  box(text(fill: luma(20%), if checked [☒] else [☐]))
  h(0.3em)
}

// `terms`-Override: cmarker reicht die <dl>-Paare als Arrays an `terms` – das
// löst eine Deprecation-Warnung aus. Hier explizit zu `terms.item` bauen
// (stiller Build; das Aussehen macht die #show terms.item-Regel oben).
#let rfd-terms(..pairs) = terms(..pairs.pos().map(p => terms.item(p.at(0), p.at(1))))

#cmarker.render(
  read(render-path),
  h1-level: 1,
  set-document-title: false,
  math: mitex,
  task-list-marker: rfd-task-marker,
  scope: (image: safe-image, divider: () => horizontalrule, terms: rfd-terms),
)
