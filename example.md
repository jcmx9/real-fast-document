---
date: 2026-06-19
toc: true
h2-break: true
filename: true
---

# Markdown zu PDF/A — Leitfaden

Dieses Dokument zeigt, wie aus einer einzigen Markdown-Datei ein archivfähiges,
einheitlich gestaltetes PDF entsteht — **ohne Textverarbeitung, ohne manuelles
Layout**. Es ist selbst mit genau dieser Pipeline gesetzt und dient damit
zugleich als Vorlage für das Ergebnis.[^pipeline]

[^pipeline]: Der Ablauf in einem Satz: Markdown → Pandoc → Typst → PDF/A-3b.
    Die Quelle bleibt reiner Text; das Layout lebt vollständig im Template.

## Überblick

Wer Inhalt schreibt, soll sich nicht um Ränder, Schriften oder Kopfzeilen
kümmern müssen. Die Pipeline verfolgt drei Ziele:

- **Reproduzierbare Gestaltung** — dieselbe Quelle ergibt immer dasselbe Layout.
- **Langzeitarchivierung** — das Ergebnis ist *PDF/A-3b*, ein ISO-Standard.
- **Minimale Quelldateien** — eine `.md`, sonst nichts.

Zusätzlich trägt jedes erzeugte PDF seine eigene Markdown-Quelle als Anhang in
sich und bleibt so jederzeit verlustfrei in Text rückführbar.

### Trennung von Inhalt und Form

Inhalt steht im Markdown, Form im Template. Dieselbe Quelle ergibt — über
verschiedene Templates — unterschiedliche Erscheinungsbilder, ohne dass am Text
etwas geändert werden muss.

## Schreiben in Markdown

Im Alltag deckt Markdown nahezu alles ab: *kursiv*, **fett**, `inline-code`
sowie [Verweise](https://typst.app) funktionieren ohne Zusatzaufwand.

### Listen

Verschachtelte und nummerierte Listen werden sauber gesetzt:

1. Quelle in Markdown schreiben.
2. Optional einen Frontmatter ergänzen:
   - `date` für ein Datum in der Fußzeile,
   - `toc` für das Inhaltsverzeichnis,
   - `h2-break` für den Kapitelumbruch.
3. Bauen lassen — fertig.

### Tabellen

Tabellen folgen der gewohnten Pipe-Syntax:

| Element       | Schrift         | Beispiel      |
| ------------- | --------------- | ------------- |
| Fließtext     | Source Sans 3   | dieser Absatz |
| Überschriften | Source Serif 4  | "Tabellen"    |
| Code          | Source Code Pro | `print("hi")` |

### Bilder

Bilder werden als *Abbildung* mit nummeriertem Untertitel gesetzt:

![Der Ablauf der Pipeline in vier Schritten — vom reinen Text bis zum Archiv-PDF.](assets/pipeline.svg)

### Definitionslisten

PDF/A-3b
: Archivformat mit erlaubten Dateianhängen — hier die Markdown-Quelle.

Variable Schrift
: Eine Schriftdatei, die über eine Achse (`wght`) beliebige Strichstärken liefert.

## Technisches

Codeblöcke erhalten Syntax-Hervorhebung. Ein kurzes Python-Beispiel:

```python
from pathlib import Path

def render(src: Path) -> Path:
    """Markdown -> PDF/A; gibt den Ausgabepfad zurück."""
    out = src.with_suffix(".pdf")
    print(f"{src} -> {out}")
    return out
```

Und der Aufruf der Pipeline selbst:

```bash
bash scripts/build.sh dokument.md      # -> dokument.pdf neben der Quelle
```

> **Hinweis:** Voraussetzung ist Typst ≥ 0.15. Erst diese Version rendert die
> gebündelten variablen Schriften, aus deren `wght`-Achse der halbfette Schnitt
> der Überschriften stammt.

## Mathematik

Auch Formeln werden ohne zusätzliche Schrift gesetzt — inline wie $E = mc^2$
oder abgesetzt:

$$
\int_{a}^{b} f(x)\,\mathrm{d}x = F(b) - F(a)
$$

## Struktur & Layout

Die Überschriftenebenen haben feste Rollen:

- **H1** ist der **Dokumenttitel** — genau einmal pro Dokument, zentriert, in den
  PDF-Metadaten und nicht im Inhaltsverzeichnis.
- **H2** ist ein **Kapitel** und läuft links im Seitenkopf mit.
- **H3** und tiefer sind Unterabschnitte.

Ab mehr als fünf H2-/H3-Überschriften schaltet das Dokument automatisch in den
strukturierten Modus (Inhaltsverzeichnis voran, jedes Kapitel auf neuer Seite) —
hier zusätzlich per Frontmatter erzwungen. Ist im Frontmatter ein `date` gesetzt,
erhält die Ausgabedatei einen ISO-Präfix (`2026-06-19_example.pdf`) und das Datum
erscheint rechts in der Fußzeile.

---

Damit ist der Rundgang abgeschlossen: ein einziger Befehl, ein archivfähiges PDF,
die Quelle inklusive.
