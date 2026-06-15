// Pandoc -> Typst Template (PDF/A-tauglich)
// Layout: DIN A4 Hochformat, asymmetrische Ränder, dynamischer Kopf (aktuelles H1)
// + Logo, Fußzeile mit Dateiname & Seite x/y, Trennlinien.

// ---------------------------------------------------------------------------
// Von Pandoc generierter Body benötigte Helfer (aus dem Default-Template)
// ---------------------------------------------------------------------------
#let horizontalrule = line(start: (25%, 0%), end: (75%, 0%))

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

#set table(inset: 6pt, stroke: none)
#show figure.where(kind: table): set figure.caption(position: top)
#show figure.where(kind: image): set figure.caption(position: bottom)

$if(highlighting-definitions)$
$highlighting-definitions$
$endif$

// ---------------------------------------------------------------------------
// Laufzeit-Eingaben (via `typst compile --input ...`)
// ---------------------------------------------------------------------------
#let doc-filename = sys.inputs.at("filename", default: "document.md")
#let logo-path = sys.inputs.at("logo", default: "logo.svg")
#let source-path = sys.inputs.at("source", default: none)

// PDF/A-3b erlaubt eingebettete Dateien: Markdown-Quelle als Anhang beilegen.
#if source-path != none {
  pdf.attach(
    source-path,
    relationship: "source",
    mime-type: "text/markdown",
    description: "Markdown-Quelle dieses Dokuments",
  )
}

// ---------------------------------------------------------------------------
// Farben
// ---------------------------------------------------------------------------
#let head-color = luma(20%) // 80 % Schwarz
#let rule-stroke = 0.5pt + luma(55%)

// Seitengeometrie (zentral, von Seite UND Header-Logik genutzt)
#let margin-top = 40mm
#let margin-bottom = 30mm
#let margin-left = 30mm
#let margin-right = 20mm

// Logo-Höhe (28->25 mm: Kopfzeile ist unten verankert, dadurch rückt die
// Logo-Oberkante zugleich ~3 mm weiter vom oberen Seitenrand weg).
#let logo-height = 25mm

// ---------------------------------------------------------------------------
// PDF-/PDF-A-Metadaten (Titel ist für PDF/A Pflicht; via Lua-Filter aus erstem H1)
// ---------------------------------------------------------------------------
$if(title)$
#set document(title: [$title$]$if(author)$, author: ($for(author)$"$author$"$sep$, $endfor$)$endif$)
$endif$

// ---------------------------------------------------------------------------
// Laufender Seitenkopf: aktuelles H1 links, Logo rechts, Trennlinie darunter
// ---------------------------------------------------------------------------
#let doc-header = context {
  let this-page = here().page()
  let all = query(heading.where(level: 1))
  // Kapitel, das OBEN auf dieser Seite aktiv ist:
  //   1) ein H1, das direkt am Seitenanfang beginnt (Seitenumbruch davor), sonst
  //   2) das zuletzt auf einer früheren Seite begonnene H1 (Fortsetzung), sonst
  //   3) das allererste H1 des Dokuments.
  let at-top = all.filter(h => (
    h.location().page() == this-page and h.location().position().y < margin-top + 8mm
  ))
  let prior = all.filter(h => h.location().page() < this-page)
  let current = if at-top.len() > 0 {
    at-top.first().body
  } else if prior.len() > 0 {
    prior.last().body
  } else if all.len() > 0 {
    all.first().body
  } else { [] }
  grid(
    columns: (1fr, auto),
    column-gutter: 6mm,
    align: (left + bottom, right + bottom),
    text(font: "Source Serif 4", weight: "semibold", size: 11pt, fill: head-color)[#current],
    image(logo-path, height: logo-height),
  )
  v(2pt)
  line(length: 100%, stroke: rule-stroke)
}

// ---------------------------------------------------------------------------
// Fußzeile: Trennlinie darüber, links Dateiname, rechts "Seite x/y"
// ---------------------------------------------------------------------------
#let doc-footer = context {
  let n = counter(page).at(here()).first()
  let total = counter(page).final().first()
  line(length: 100%, stroke: rule-stroke)
  v(2pt)
  set text(font: "Source Sans 3", size: 9pt, fill: head-color)
  grid(
    columns: (1fr, auto),
    align: (left + top, right + top),
    doc-filename,
    [Seite #n / #total],
  )
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
#set text(font: "Source Sans 3", size: 11pt, lang: "$if(lang)$$lang$$else$de$endif$")
#set par(justify: true, leading: 0.65em)

#show heading: set text(font: "Source Serif 4", weight: "semibold", fill: head-color)
#show heading.where(level: 1): set text(size: 20pt)
#show heading.where(level: 2): set text(size: 16pt)
#show heading.where(level: 3): set text(size: 13pt)
#show heading: it => block(above: 1.2em, below: 0.6em, it)

#show raw: set text(font: "Source Code Pro", size: 9.5pt)
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

$body$
