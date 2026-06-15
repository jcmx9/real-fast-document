# Systemdokumentation

## Einleitung

Dieses Dokument ist der **strukturierte** Demonstrationsfall: ein H1-Titel, fünf
Kapitel (H2) mit Unterabschnitten. Da `#H2 + #H3 > 5` ist, wird automatisch ein
**Inhaltsverzeichnis** eingeblendet und jedes Kapitel beginnt auf einer **neuen
Seite**. Der laufende Kopf zeigt das jeweils aktive Kapitel (H2).

### Aufbau des Dokuments

Fünf Kapitel mit unterschiedlich viel Inhalt, sodass der Kopf mehrfach umschlägt.

#### Hinweis zur Lesart

Achte oben links auf das Kapitel, in dem sich der Seitenanfang befindet.

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
vero eos et accusam et justo duo dolores et ea rebum.

## Architektur

Die Architektur folgt einer klaren Pipeline. Jede Stufe hat genau eine Aufgabe.

### Komponenten

Die drei zentralen Bausteine lassen sich unabhängig testen.

| Komponente  | Eingabe   | Ausgabe   |
|-------------|-----------|-----------|
| Parser      | Markdown  | AST       |
| Transformer | AST       | Typst     |
| Renderer    | Typst     | PDF/A     |

#### Parser

Der Parser liest reines Markdown und erzeugt einen abstrakten Syntaxbaum.

#### Transformer

Der Transformer bildet den AST auf Typst-Markup ab.

```python
def transform(ast: Node) -> str:
    """Bildet einen Markdown-AST auf Typst-Markup ab."""
    return "\n".join(render(n) for n in ast.walk())
```

### Entwurfsprinzipien

Kleine, klar umrissene Einheiten mit einer einzigen Verantwortung.

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.

## Datenfluss

Der Datenfluss ist streng gerichtet: Markdown hinein, PDF/A heraus.

### Von Markdown zu AST

Pandoc übernimmt das Parsen; der Lua-Filter setzt den Titel aus dem H1.

> Ein Zwischenformat, das man inspizieren kann, spart später Stunden.

### Von AST zu Typst

Das Template definiert die gesamte Geometrie.

#### Seitenzählung

Die Gesamtseitenzahl ermittelt Typst über den finalen Stand des Zählers.

### Von Typst zu PDF/A

Typst exportiert direkt nach PDF/A-3b inklusive eingebetteter Fonts.

## Fehlerbehandlung

Erwartete Fehler werden früh abgefangen und verständlich gemeldet.

### Eingabevalidierung

Existiert die Quelldatei nicht, bricht der Build mit klarer Meldung ab.

```bash
if [[ ! -f "${src}" ]]; then
  echo "Error: ${src} nicht gefunden" >&2
  exit 1
fi
```

### Fehlende Fonts

Fehlen die gebündelten Fonts, greift der Build auf Systemschriften zurück.

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.

## Anhang

Der Anhang sammelt ergänzende Tabellen und Verweise.

### Glossar

| Begriff | Bedeutung |
|---------|-----------|
| AST     | Abstrakter Syntaxbaum |
| PDF/A   | Archivierungs-Standard für PDF |

### Weiterführendes

- Typst-Dokumentation
- Pandoc User's Guide
- PDF/A-Spezifikation (ISO 19005)
