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
// Tabellen über die volle Satzspiegelbreite; Kopf zentriert + fett, Inhalte
// linksbündig (auch Zahlen/Währungen), leichter Zebra-Hintergrund, senkrechte
// Trennlinien und eine Linie unter der Kopfzeile.
#show table: it => {
  // Guard gegen Rekursion: die umgebaute Tabelle setzt `fill` (eine Funktion),
  // die cmarker-Originaltabelle nicht -> nur die Originaltabelle umbauen.
  // (`it.columns` kommt von Typst als Array normalisiert – daher .len().)
  if it.fill != none {
    it
  } else {
    let n = if type(it.columns) == int { it.columns } else { it.columns.len() }
    table(
      columns: (1fr,) * n,
      align: (_, y) => if y == 0 { center } else { left },
      // Leichter Zeilen-Hintergrundwechsel (Zebra); zugleich der Guard-Marker
      // (fill ist eine Funktion != none).
      fill: (_, y) => if y > 0 and calc.even(y) { luma(96%) } else { none },
      // Nur senkrechte Trennlinien (innen) und eine Linie unter der Kopfzeile –
      // keine waagerechten Zeilenlinien.
      stroke: (x, y) => (
        left: if x > 0 { 0.4pt + luma(80%) } else { 0pt },
        top: if y == 1 { 0.7pt + luma(45%) } else { 0pt },
      ),
      ..it.children,
    )
  }
}
#show table.cell.where(y: 0): strong
#show figure.where(kind: table): set figure.caption(position: top)
#show figure.where(kind: image): set figure.caption(position: bottom)
// Bildunterschrift kleiner als Fließtext, mit etwas mehr Abstand unter der Abbildung.
#show figure.caption: set text(size: 10pt)
#show figure: it => block(below: 1.8em, it)

// ---------------------------------------------------------------------------
// Laufzeit-Eingaben (via `typst compile --input ...`)
// ---------------------------------------------------------------------------
#let doc-filename = sys.inputs.at("filename", default: "document.md")
// PDF/A-Metadatentitel (Frontmatter title: falls gesetzt, sonst .md-Basisname).
#let doc-title = sys.inputs.at("title", default: "Dokument")
// Sichtbarer Dokumenttitel aus dem Frontmatter (title:): Titelblock oben +
// Kopfzeile ab Seite 1. Leer = kein Titelblock (H1 ist trotzdem ein Kapitel).
#let title-text = sys.inputs.at("doctitle", default: "")
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
#let break-mode = sys.inputs.at("h1-break", default: "auto")
#let show-name  = sys.inputs.at("showname", default: "true") != "false"
// Kopfzeile (Vorrang von oben):
//   header: "Text"  -> fester Kopfzeilentext, ab Seite 1
//   sonst           -> Running Header mit dem aktiven H1-Kapitel; vor dem ersten
//                      Kapitel der Titel (title:), falls gesetzt
#let head-override = sys.inputs.at("header", default: "")
// Optionales Wasserzeichen (Frontmatter watermark:): diagonal, gespreizt, fett,
// auf unterster Ebene unter allen Elementen.
#let watermark-text = sys.inputs.at("watermark", default: "")

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

// Seitengeometrie (zentral, von Seite UND Header-Logik genutzt)
#let margin-top = 35mm
#let margin-bottom = 20mm
#let margin-left = 30mm
#let margin-right = 20mm

// Logo-Höhe: muss in den (jetzt schmaleren) oberen Rand passen. Bei 20 mm
// Top-Margin und 6 mm header-ascent bleibt der Kopf damit innerhalb des Randes.
#let logo-height = 13mm

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
  let chapter = text(font: body-font, weight: 450, size: 13pt, fill: head-color)[#current]
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

// Schrift/Farbe für alle Überschriften (Serif; Gewicht je Ebene: H1/„Inhalt"
// halbfett bzw. Book-Schnitt der variablen Schrift).
#let heading-text(size, weight, body) = text(
  font: heading-font, weight: weight, fill: heading-color, size: size, body,
)

// Strukturmodus-Steuerung: Frontmatter (toc/h1-break) übersteuert den
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
    // Kapitel: Umbruch davor (h1-break), Serif, feine Linie DICHT darunter.
    // par(spacing) im Block klein setzen – sonst liegt zwischen Text und Linie
    // der Default-Absatzabstand (1.1em) und die Linie sitzt zu tief.
    context { if want-break() { pagebreak(weak: true) } }
    block(width: 100%, above: 1.8em, below: 0.5em, {
      set par(spacing: 2pt)
      heading-text(18pt, 450, it)
      line(length: 100%, stroke: hairline-stroke)
    })
  } else if it.level == 2 {
    block(width: 100%, above: 1.4em, below: 0.4em, heading-text(15pt, 450, it))
  } else if it.level == 3 {
    block(width: 100%, above: 1.2em, below: 0.35em, heading-text(13pt, 450, it))
  } else {
    // H4+: nur fett, linksbündig.
    block(width: 100%, above: 1.0em, below: 0.3em, heading-text(12pt, "bold", it))
  }
}

// Inhaltsverzeichnis: nur H1 + H2, gleiche Zeilenabstände, Einträge in Sans und
// knapp über Fließtextgröße (Book, wght 450 – Default-Bold der H1 neutralisiert).
#let toc-entry(body) = block(above: 0.55em, below: 0pt, {
  show strong: s => s.body
  set text(font: body-font, weight: 450, size: 12pt)
  body
})
#show outline.entry.where(level: 1): it => toc-entry(it)
#show outline.entry.where(level: 2): it => toc-entry(it)

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

// Titelblock (aus title:) + optionales Inhaltsverzeichnis, VOR dem Markdown-Body.
// Der Titel ist KEIN Heading (steht daher nicht im TOC); H1 ist ein Kapitel.
#if title-text != "" {
  block(width: 100%, above: 0.2em, below: 1.0em,
    align(center, heading-text(21pt, "semibold", title-text)))
}
#context {
  if want-toc() {
    block(above: 2.0em, below: 1.0em, heading-text(16pt, "semibold", [Inhalt]))
    outline(title: none, depth: 2)
    pagebreak(weak: true)
  }
}

#cmarker.render(
  read(render-path),
  h1-level: 1,
  set-document-title: false,
  math: mitex,
  task-list-marker: rfd-task-marker,
  scope: (image: safe-image, divider: () => horizontalrule, terms: rfd-terms),
)
