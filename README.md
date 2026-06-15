# real·fast·document

Markdown → **Pandoc** (+ Lua-Filter) → **Typst** → **PDF/A** mit festem Corporate-Layout:
DIN A4 Hochformat, asymmetrische Ränder, laufender Kopf mit Logo, Fußzeile mit
Dateiname und Seitenzählung.

## Voraussetzungen

- [pandoc](https://pandoc.org) ≥ 3.x (Typst-Writer)
- [typst](https://typst.app) ≥ 0.14 (PDF/A-Export)

## Schnellstart

```bash
# Fonts einmalig ins Projekt bündeln (statische Source-OTFs)
bash scripts/fetch-fonts.sh

# Beispiel bauen
bash scripts/build.sh                 # -> example.pdf

# Eigene Datei
bash scripts/build.sh meine-datei.md  # -> meine-datei.pdf
bash scripts/build.sh in.md out.pdf   # explizite Ausgabe
```

## Layout-Spezifikation

| Aspekt | Wert |
|--------|------|
| Format | DIN A4 Hochformat |
| Ränder | oben 40 mm · links 30 mm · rechts 20 mm · unten 30 mm |
| PDF-Standard | PDF/A-3b |
| Kopf links | aktuelles H1 (dynamischer Running Header) |
| Kopf rechts | Logo (`logo.svg` → `.png` → `.jpg`), Höhe 25 mm, am rechten Rand ausgerichtet |
| Fuß links | Quell-Dateiname |
| Fuß rechts | `Seite x / y` |
| Trennlinien | unter dem Kopftext, über dem Fußtext |
| Anhang | Quell-Markdown als eingebettete Datei (PDF/A-3b) |
| Überschriften | Source Serif 4, Semibold, Farbe 80 % Schwarz (`luma(20%)`) |
| Fließtext | Source Sans 3 |
| Code | Source Code Pro |

## Aufbau

```
template.typ              Pandoc-Typst-Template: gesamtes Seitenlayout
filters/meta-from-h1.lua  setzt Dokumenttitel (PDF/A) aus erstem H1
scripts/build.sh          Pipeline Markdown -> PDF/A
scripts/fetch-fonts.sh    bündelt statische Source-Fonts nach ./fonts
fonts/                    gebündelte Schriften (statische OTF)
logo.svg                  Kopf-Logo
example.md                Beispieldokument
```

## Anpassen

- **Logo / Dateiname** werden zur Compile-Zeit als Typst-`--input` übergeben
  (siehe `scripts/build.sh`); im Template über `sys.inputs` gelesen. Das Logo
  wird in der Reihenfolge `logo.svg` → `logo.png` → `logo.jpg` gewählt (erstes
  vorhandenes). Höhe im Template über `logo-height` (Standard 25 mm).
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
