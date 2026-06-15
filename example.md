# Schnellstart

Dieses Dokument demonstriert die Pipeline **Markdown → Pandoc → Typst → PDF/A**
im **kompakten** Modus: ein H1-Titel, wenige Kapitel. Da `#H2 + #H3 ≤ 5` ist,
gibt es **kein Inhaltsverzeichnis** und die Kapitel (H2) fließen ohne
Seitenumbruch. Der laufende Kopf zeigt das aktive Kapitel (H2).

## Worum es geht

Quelle ist reines Markdown. Ein Lua-Filter zieht das H1 als Dokumenttitel in die
PDF-Metadaten (von PDF/A gefordert). Das Layout — Ränder, Fonts, Kopf und Fuß —
lebt vollständig im Typst-Template.

- DIN A4 Hochformat
- Ränder: oben 40 mm, links 30 mm, rechts 20 mm, unten 30 mm
- Überschriften in *Source Serif 4*, Fließtext in *Source Sans 3*

### Inline-Elemente

Inline-Code wie `pandoc --to typst` wird in der Monospace-Schrift gesetzt.
Links funktionieren ebenfalls: [Typst](https://typst.app).

## Codebeispiel

```python
from pathlib import Path


def build(src: Path, out: Path) -> None:
    """Konvertiert eine Markdown-Datei nach PDF/A."""
    print(f"{src} -> {out}")
```

## Tabelle

| Bereich  | Wert        |
|----------|-------------|
| Format   | DIN A4      |
| Standard | PDF/A-3b    |
| Engine   | Typst 0.15  |
