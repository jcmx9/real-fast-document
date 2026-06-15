# real·fast·document

Markdown → **Pandoc** (+ Lua-Filter) → **Typst** → **PDF/A** mit festem Corporate-Layout:
DIN A4 Hochformat, asymmetrische Ränder, laufender Kopf mit Logo, Fußzeile mit
Dateiname und Seitenzählung.

## Voraussetzungen

- [pandoc](https://pandoc.org) ≥ 3.x (Typst-Writer)
- [typst](https://typst.app) ≥ 0.15 (PDF/A-Export + Variable Fonts)

### Installation der Werkzeuge

**macOS / Linux (Homebrew):**

```bash
brew install pandoc typst
```

**Windows (winget):**

```powershell
winget install --id JohnMacFarlane.Pandoc -e
winget install --id Typst.Typst -e
```

> Hinweis: Unter Windows funktioniert die Pipeline über Git Bash / WSL
> (die Build-Skripte sind Bash). Alternativ die beiden Befehle aus
> `scripts/build.sh` direkt aufrufen.

## Schnellstart

```bash
# Fonts einmalig ins Projekt bündeln (Variable Source-Fonts)
bash scripts/fetch-fonts.sh

# Beispiel bauen
bash scripts/build.sh                 # -> example.pdf

# Eigene Datei
bash scripts/build.sh meine-datei.md  # -> meine-datei.pdf
bash scripts/build.sh in.md out.pdf   # explizite Ausgabe
```

### Windows („Senden an")

`install.ps1` richtet zwei Dinge ein. Die gesamte Logik bleibt im Installpfad;
im System landet nur eine Verknüpfung im „Senden an"-Ordner.

```powershell
# Im Projektordner (= Installpfad):
./scripts/install.ps1            # Fonts laden + "Senden an"-Verknüpfung
./scripts/install.ps1 -Fonts     # nur Fonts ins Projekt laden (./fonts)
./scripts/install.ps1 -SendTo    # nur die Verknüpfung anlegen
./scripts/install.ps1 -Uninstall # Verknüpfung entfernen
```

Danach im Explorer eine (oder mehrere) `.md` markieren → Rechtsklick →
**Senden an → „Nach PDF-A (real-fast-document)"**. Die PDF/A wird im selben
Verzeichnis wie die Quelle abgelegt. Der Konverter `scripts/convert.ps1`
verbleibt im Installpfad und wird über die Verknüpfung aufgerufen.

## Layout-Spezifikation

| Aspekt | Wert |
|--------|------|
| Format | DIN A4 Hochformat |
| Ränder | oben 40 mm · links 30 mm · rechts 20 mm · unten 30 mm |
| PDF-Standard | PDF/A-3b |
| **H1** | **Dokumenttitel** — genau einmal (mehrfaches H1 = Build-Fehler), eröffnet das Dokument |
| **H2** | **Kapitel** — aktuelles Kapitel läuft dynamisch im Kopf links mit |
| **TOC** | bedingt: ab `#H2 + #H3 > 5` → Inhaltsverzeichnis (über H2/H3) **und** jedes Kapitel beginnt auf neuer Seite |
| Kopf rechts | Logo (`logo.svg` → `.png` → `.jpg`), Höhe 25 mm, rechtsbündig — **optional** (ohne Logo bleibt die rechte Kopfseite leer) |
| Fuß links | Quell-Dateiname |
| Fuß rechts | `Seite x / y` |
| Trennlinien | unter dem Kopftext, über dem Fußtext |
| Anhang | Quell-Markdown als eingebettete Datei (PDF/A-3b) |
| Überschriften | Source Serif 4, Semibold, Farbe 80 % Schwarz (`luma(20%)`) |
| Fließtext | Source Sans 3 |
| Code | Source Code Pro |

### Dokumentstruktur

Die Überschriftenebenen haben feste Rollen:

- **H1 = Dokumenttitel.** Muss **genau einmal** vorkommen — bei mehreren H1
  bricht der Build mit klarer Meldung ab (`filters/meta-from-h1.lua`). Das H1
  liefert zugleich den PDF-Titel (PDF/A-Pflicht), wird **zentriert** gesetzt und
  erscheint **nicht** im Kopf und **nicht** im Inhaltsverzeichnis.
- **H2 = Kapitel.** Das jeweils aktive Kapitel läuft dynamisch im Seitenkopf
  links mit.
- **H3 und tiefer = Unterabschnitte.**

**Bedingtes Inhaltsverzeichnis (TOC):** Sind mehr als fünf H2- und
H3-Überschriften vorhanden (**`#H2 + #H3 > 5`**), schaltet das Template
automatisch in den *strukturierten* Modus:

- ein **Inhaltsverzeichnis** über H2/H3 (mit Seitenzahlen, klickbar) direkt
  nach dem Titel, und
- jedes **Kapitel (H2) beginnt auf einer neuen Seite**.

Bei fünf oder weniger bleibt das Dokument *kompakt*: kein TOC, Kapitel fließen
ohne Seitenumbruch. Der Schwellenwert ist eine einzige Stelle in
`template.typ`.

### Typografie (Schriftgrade)

| Element | Schrift | Grad |
|---------|---------|------|
| Fließtext | Source Sans 3 | 11 pt |
| Titel (H1) | Source Serif 4 semibold | 26 pt, zentriert |
| Kapitel (H2) | Source Serif 4 semibold | 16 pt |
| H3 / H4 / H5 / H6 | Source Serif 4 semibold | 13 / 11,5 / 11 / 10 pt |
| TOC-Titel „Inhalt" | Source Serif 4 semibold | 15 pt |
| TOC-Einträge | Source Sans 3 | 14 pt, Book (`wght` 450) |
| Kopf (Kapitel) | Source Serif 4 semibold | 11 pt |
| Code | Source Code Pro | 9,5 pt |
| Fußzeile | Source Sans 3 | 9 pt |

## Aufbau

```
template.typ              Pandoc-Typst-Template: gesamtes Seitenlayout
filters/meta-from-h1.lua  Dokumenttitel (PDF/A) aus H1, erzwingt genau ein H1
scripts/build.sh          Pipeline Markdown -> PDF/A (macOS/Linux)
scripts/fetch-fonts.sh    bündelt Variable Source-Fonts nach ./fonts
scripts/install.ps1       Windows-Setup: Fonts + "Senden an"-Verknüpfung
scripts/convert.ps1       Windows-Konverter (von "Senden an" aufgerufen)
fonts/                    gebündelte Schriften (Variable TTF)
logo.svg                  Kopf-Logo
example.md                kompaktes Beispiel (kein TOC, H2 inline)
long-example.md           strukturiertes Beispiel (Titel + TOC + Kapitelseiten)
showcase.md               Markdown-Schaukasten (alle Elemente, strukturiert)
```

## Anpassen

- **Logo / Dateiname** werden zur Compile-Zeit als Typst-`--input` übergeben
  (siehe `scripts/build.sh`); im Template über `sys.inputs` gelesen. Das Logo
  wird in der Reihenfolge `logo.svg` → `logo.png` → `logo.jpg` gewählt (erstes
  vorhandenes). Höhe im Template über `logo-height` (Standard 25 mm). Das Logo
  ist **optional**: fehlt es, baut die Pipeline mit einem Hinweis weiter und der
  Kopf bleibt rechts leer.
- **Ränder, Fonts, Farben** stehen gesammelt oben in `template.typ`
  (`#set page`, `#set text`, `head-color`).
- **Anderer PDF/A-Grad**: `standard` in `scripts/build.sh` ändern
  (`a-1b`, `a-2b`, `a-3b`). Das Einbetten der Quelle setzt `a-3b` voraus.
- **Quelle als Anhang**: Die Markdown-Datei wird via `pdf.attach` in das PDF
  eingebettet (`AFRelationship /Source`) und lässt sich z. B. mit
  `mutool extract datei.pdf` wieder herauslösen.

## Versionierung

[CalVer](https://calver.org/) im Format `YY.M.MICRO` — siehe `VERSION` und
[CHANGELOG.md](CHANGELOG.md).

## Lizenz

MIT — siehe [LICENSE](LICENSE). Die gebündelten Fonts unter `fonts/` stehen
unter der SIL Open Font License 1.1 (siehe [fonts/README.md](fonts/README.md)).
