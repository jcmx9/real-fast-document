# Schnellstart

Dieses Dokument demonstriert die Pipeline **Markdown → Pandoc → Typst → PDF/A**.
Der laufende Seitenkopf zeigt links das *aktuelle* H1, rechts das Logo; die
Fußzeile trägt links den Dateinamen und rechts die Seitenzählung.

## Worum es geht

Quelle ist reines Markdown. Ein kleiner Lua-Filter zieht das erste `#`-Element
als Dokumenttitel in die PDF-Metadaten (von PDF/A gefordert). Das Layout — Ränder,
Fonts, Kopf und Fuß — lebt vollständig im Typst-Template.

- DIN A4 Hochformat
- Ränder: oben 40 mm, links 30 mm, rechts 20 mm, unten 30 mm
- Überschriften in *Source Serif 4*, Fließtext in *Source Sans 3*
- Code in *Source Code Pro*

### Inline-Elemente

Inline-Code wie `pandoc --to typst` wird in der Monospace-Schrift gesetzt.
Links funktionieren ebenfalls: [Typst](https://typst.app).

> Ein Blockzitat zur Auflockerung. Typst setzt es mit hängendem Einzug,
> der Fließtext bleibt im Blocksatz.

## Codebeispiel

```python
from pathlib import Path


def build(src: Path, out: Path) -> None:
    """Konvertiert eine Markdown-Datei nach PDF/A."""
    print(f"{src} -> {out}")
```

## Tabelle

| Bereich | Wert        |
|---------|-------------|
| Format  | DIN A4      |
| Standard| PDF/A-3b    |
| Engine  | Typst 0.14  |

# Zweiter Abschnitt

Dieses zweite H1 zeigt, dass der Seitenkopf **dynamisch** mitläuft: Sobald der
Text diesen Abschnitt erreicht, wechselt die Kopfzeile auf „Zweiter Abschnitt".

## Mehr Text

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren,
no sea takimata sanctus est Lorem ipsum dolor sit amet.
