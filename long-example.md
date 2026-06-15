# Einleitung

Dieses Dokument demonstriert den **dynamischen Seitenkopf** über mehrere
Kapitel hinweg. Jedes `#`-Kapitel ist ein eigenes H1. Sobald der Textfluss ein
neues H1 erreicht, wechselt der Titel oben links — das Logo rechts bleibt
konstant, die Fußzeile zählt durch.

## Aufbau des Dokuments

Das Dokument gliedert sich in fünf Kapitel mit unterschiedlich viel Inhalt,
sodass die Kapitelwechsel auf verschiedene Seiten fallen und der Header
mehrfach umschlägt.

- Einleitung (dieses Kapitel)
- Architektur
- Datenfluss
- Fehlerbehandlung
- Anhang

### Hinweis zur Lesart

Achte beim Durchblättern auf die obere linke Ecke: Dort steht stets das Kapitel,
in dem sich der jeweilige Seitenanfang befindet. Beginnt ein neues Kapitel mitten
auf einer Seite, zeigt der Kopf bereits das neue Kapitel.

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren,
no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit
amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut
labore et dolore magna aliquyam erat, sed diam voluptua.

# Architektur

Die Architektur folgt einer klaren Pipeline. Jede Stufe hat genau eine Aufgabe
und kommuniziert über ein wohldefiniertes Format mit der nächsten.

## Komponenten

Die drei zentralen Bausteine sind Parser, Transformer und Renderer. Sie lassen
sich unabhängig voneinander testen und austauschen.

| Komponente  | Eingabe   | Ausgabe   |
|-------------|-----------|-----------|
| Parser      | Markdown  | AST       |
| Transformer | AST       | Typst     |
| Renderer    | Typst     | PDF/A     |

### Parser

Der Parser liest reines Markdown und erzeugt einen abstrakten Syntaxbaum.
Er kennt keine Layout-Details — diese Trennung hält die Stufen entkoppelt.

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
vero eos et accusam et justo duo dolores et ea rebum.

### Transformer

Der Transformer bildet den AST auf Typst-Markup ab und reichert ihn mit dem
Layout aus dem Template an. Hier entstehen Kopf, Fuß und Schriftregeln.

```python
def transform(ast: Node) -> str:
    """Bildet einen Markdown-AST auf Typst-Markup ab."""
    out: list[str] = []
    for node in ast.walk():
        out.append(render_node(node))
    return "\n".join(out)
```

## Entwurfsprinzipien

Kleine, klar umrissene Einheiten mit einer einzigen Verantwortung. Was man nicht
von außen verstehen kann, gehört gekapselt.

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren,
no sea takimata sanctus est Lorem ipsum dolor sit amet.

# Datenfluss

Der Datenfluss ist streng gerichtet: Markdown geht hinein, PDF/A kommt heraus.
Zwischenformate sind beobachtbar und damit gut zu debuggen.

## Von Markdown zu AST

Pandoc übernimmt das Parsen. Der Lua-Filter greift in dieser Phase ein und
setzt den Dokumenttitel aus dem ersten H1 — eine Anforderung von PDF/A.

> Ein Zwischenformat, das man inspizieren kann, spart später Stunden bei der
> Fehlersuche. Sichtbarkeit schlägt Cleverness.

## Von AST zu Typst

Das Template definiert die gesamte Geometrie. Variablen wie Dateiname und
Logo-Pfad werden zur Compile-Zeit injiziert, nicht hart kodiert.

- Ränder und Papierformat: `#set page`
- Schriften: `#set text` und `#show heading`
- Kopf/Fuß: Funktionen mit `context`

### Seitenzählung

Die Gesamtseitenzahl ermittelt Typst über den finalen Stand des Seitenzählers.
So steht in der Fußzeile zuverlässig `Seite x / y`.

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.

## Von Typst zu PDF/A

Typst exportiert direkt nach PDF/A-3b. Eingebettete Fonts und gesetzte
Metadaten erfüllen die Kernanforderungen des Archivstandards.

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren.

# Fehlerbehandlung

Erwartete Fehler werden früh abgefangen und verständlich gemeldet — keine
Stacktraces für Anwenderfehler.

## Eingabevalidierung

Existiert die Quelldatei nicht, bricht der Build mit klarer Meldung ab. Pfade
werden aufgelöst, um Path-Traversal auszuschließen.

```bash
if [[ ! -f "${src}" ]]; then
  echo "Error: ${src} nicht gefunden" >&2
  exit 1
fi
```

## Fehlende Fonts

Fehlen die gebündelten Fonts, greift der Build auf Systemschriften zurück statt
abzubrechen. Das hält die Pipeline robust.

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
vero eos et accusam et justo duo dolores et ea rebum.

# Anhang

Der Anhang sammelt ergänzende Tabellen und Verweise.

## Glossar

| Begriff | Bedeutung |
|---------|-----------|
| AST     | Abstrakter Syntaxbaum |
| PDF/A   | Archivierungs-Standard für PDF |
| XMP     | Metadatenformat im PDF |

## Weiterführendes

- Typst-Dokumentation
- Pandoc User's Guide
- PDF/A-Spezifikation (ISO 19005)

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren,
no sea takimata sanctus est Lorem ipsum dolor sit amet.
