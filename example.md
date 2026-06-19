---
# Optionaler Frontmatter — alle Schlüssel optional. Auskommentiert dokumentiert,
# damit dieses Beispiel sein Standardverhalten behält.
# date: 2026-06-19   # ISO-Datum -> ISO-Präfix am Dateinamen + Datum in Fußzeile rechts
# toc: true          # Inhaltsverzeichnis erzwingen (true) / unterdrücken (false)
# h2-break: false    # Kapitel-Seitenumbruch erzwingen (true) / unterdrücken (false)
filename: true       # Dateiname unten links in der Fußzeile (Default true)
---

# Markdown zu PDF/A

Dieser Leitfaden zeigt, wie aus einer einzigen Markdown-Datei ein
archivfähiges, einheitlich gestaltetes PDF entsteht — ohne Textverarbeitung,
ohne manuelles Layout. Er ist selbst mit genau dieser Pipeline gesetzt und
dient daher zugleich als Vorlage für das Ergebnis.

Der Ablauf in einem Satz: **Markdown → Pandoc → Typst → PDF/A-3b**. Die Quelle
bleibt reiner Text, das Layout lebt vollständig im Template, und das fertige PDF
trägt seine eigene Markdown-Quelle als Anhang in sich.

## Überblick

Die Pipeline verfolgt drei Ziele: **reproduzierbare Gestaltung**, **langfristige
Archivierbarkeit** und **minimale Quelldateien**. Wer Inhalt schreibt, soll sich
nicht um Ränder, Schriften oder Kopfzeilen kümmern müssen.

### Trennung von Inhalt und Form

Inhalt steht im Markdown, Form im Typst-Template. Dieselbe Quelle ergibt — über
verschiedene Templates — unterschiedliche Erscheinungsbilder, ohne dass am Text
etwas geändert werden muss.

### Archivfähigkeit

Das Ergebnis ist **PDF/A-3b**: ein ISO-Standard für die Langzeitarchivierung.
Schriften werden eingebettet, Metadaten sauber gesetzt, und die ursprüngliche
Markdown-Datei liegt als Anhang bei — das Dokument bleibt also auch nach Jahren
verlustfrei in seine Quelle rückführbar.

## Schnellstart

Ein einziger Befehl genügt, um aus einer Markdown-Datei ein PDF zu erzeugen:

```bash
bash scripts/build.sh dokument.md
```

Ohne zweites Argument landet die Ausgabe neben der Quelle (`dokument.pdf`). Soll
der Zielname abweichen, wird er einfach angehängt:

```bash
bash scripts/build.sh dokument.md bericht-2026.pdf
```

> Voraussetzung ist **Typst ≥ 0.15**. Erst diese Version rendert die gebündelten
> variablen Schriften, aus deren `wght`-Achse der halbfette Schnitt der
> Überschriften stammt.

## Funktionsumfang

Die wichtigsten Eigenschaften des Standard-Templates auf einen Blick:

| Bereich        | Festlegung                                  |
|----------------|---------------------------------------------|
| Seitenformat   | DIN A4 Hochformat                           |
| Ränder         | oben 40 mm, links 30 mm, rechts 20 mm, unten 30 mm |
| Überschriften  | Source Serif 4, halbfett, 80 % Schwarz      |
| Fließtext      | Source Sans 3, 11 pt, Blocksatz             |
| Code           | Source Code Pro mit Syntax-Hervorhebung     |
| Standard       | PDF/A-3b, Schriften eingebettet             |

Daraus ergibt sich das Verhalten beim Setzen:

1. Das erste `# H1` wird zum **Dokumenttitel** und in die PDF-Metadaten gezogen.
2. Jedes `## H2` ist ein **Kapitel** und erscheint links im laufenden Kopf.
3. Ab mehr als fünf Abschnitten schaltet das Dokument automatisch in den
   **strukturierten Modus**: Inhaltsverzeichnis voran, jedes Kapitel auf neuer
   Seite — wie in genau diesem Dokument.

### Was sich automatisch ergibt

- laufende Kopfzeile mit aktivem Kapitel und optionalem Logo
- Fußzeile mit Dateiname und Seitenzählung
- Inhaltsverzeichnis, sobald sich der Umfang lohnt
- Fußnoten mit hängendem Einzug[^quelle]

## Hinweise für die Praxis

Markdown deckt im Alltag fast alles ab: *kursiv*, **fett**, `inline-code`,
Aufzählungen, Tabellen und [Links](https://typst.app) funktionieren ohne
Zusatzaufwand. Für die saubere Trennung gilt eine einfache Regel — **genau ein
H1 pro Dokument**; Kapitel beginnen bei H2.

Wer das fertige PDF prüfen möchte, kann die eingebettete Quelle jederzeit wieder
entnehmen und so Inhalt und Darstellung getrennt versionieren.

[^quelle]: Diese Fußnote erscheint am unteren Seitenrand, oberhalb der Fußzeile,
    und nutzt denselben Schriftschnitt wie der Fließtext.
