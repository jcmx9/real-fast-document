# Markdown-Schaukasten

Dieses Dokument zeigt möglichst viele Markdown- und Pandoc-Elemente und dient
als visueller Regressionstest. Es ist **strukturiert** (mehr als fünf H2+H3),
daher mit Inhaltsverzeichnis und Kapiteln auf eigenen Seiten.

## Textebene

### Textauszeichnung

Normaler Text mit *kursiv*, **fett**, ***fett-kursiv***, ~~durchgestrichen~~,
`inline-code`, H~2~O (tiefgestellt) und E = mc^2^ (hochgestellt). Ein
erzwungener\
Zeilenumbruch steht über einen Backslash am Zeilenende.

Ein Link [zur Typst-Website](https://typst.app), ein automatischer Link
<https://pandoc.org> und ein Referenz-Link [zur Doku][doku].

[doku]: https://typst.app/docs "Typst-Dokumentation"

### Listen

Ungeordnet und verschachtelt:

- Erster Punkt
- Zweiter Punkt
  - Unterpunkt A
  - Unterpunkt B
    - Noch tiefer
- Dritter Punkt

Geordnet:

1. Schritt eins
2. Schritt zwei
   1. Teilschritt
   2. Teilschritt
3. Schritt drei

Aufgabenliste:

- [x] Template erstellt
- [x] PDF/A-Export
- [ ] Offener Punkt

### Definitionsliste

AST
:   Abstrakter Syntaxbaum — die Baumdarstellung des geparsten Markdown.

PDF/A
:   Archivierungs-Standard für PDF.
:   Mehrere Definitionen pro Begriff sind möglich.

### Zitate

> Ein einfaches Blockzitat.
>
> > Ein verschachteltes Zitat innerhalb des ersten.
>
> Zurück auf der ersten Ebene.

## Blöcke

### Code

Inline `print("hi")` und gehighlightete Blöcke:

```python
from pathlib import Path


def build(src: Path, out: Path) -> None:
    """Konvertiert Markdown nach PDF/A."""
    for line in src.read_text().splitlines():
        print(line.upper())
```

```bash
#!/usr/bin/env bash
set -euo pipefail
typst compile doc.typ doc.pdf --pdf-standard a-3b
```

```json
{ "format": "DIN A4", "standard": "PDF/A-3b", "engine": "Typst" }
```

### Tabellen

Pipe-Tabelle mit Ausrichtung:

| Links        |   Zentriert   |        Rechts |
|:-------------|:-------------:|--------------:|
| Format       |    DIN A4     |       210 mm  |
| Standard     |   PDF/A-3b    |          ISO  |
| Engine       |    Typst      |        0.15   |

Grid-Tabelle:

+---------------+---------------------------+
| Komponente    | Aufgabe                   |
+===============+===========================+
| Parser        | Markdown → AST            |
+---------------+---------------------------+
| Renderer      | Typst → PDF/A             |
+---------------+---------------------------+

### Mathematik

Inline-Mathe: $E = mc^2$ sowie $\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$.

Abgesetzte Formel:

$$\int_0^\infty e^{-x}\,dx = 1 \qquad \text{und} \qquad a^2 + b^2 = c^2$$

### Bild

![Das Projekt-Logo als eingebettete SVG-Grafik.](logo.svg){ width=60mm }

### Fußnoten

Hier steht ein Satz mit einer Fußnote.[^1] Und noch eine weitere.[^lang]

[^1]: Eine kurze Fußnote.

[^lang]: Eine längere Fußnote mit mehreren Sätzen. Fußnoten erscheinen am
    unteren Rand der Seite, oberhalb der Fußzeile.

## Überschriften und Trennlinien

### Ebene 3

#### Ebene 4

##### Ebene 5

###### Ebene 6

### Trennlinie

Über der Linie.

---

Unter der Linie.
