# real·fast·document

**Deutsch** · [English](README.en.md)

> Aus einer Markdown-Datei ein archivfähiges, einheitlich gestaltetes **PDF/A-3b** —
> ohne Textverarbeitung, ohne manuelles Layout.

Markdown → **Typst** (Packages **cmarker** + **mitex**) → **PDF/A** mit festem
Corporate-Layout: DIN A4 Hochformat, laufender Kopf mit Kapitel und Logo, Fußzeile mit
Dateiname, Seitenzählung und optionalem Datum. Die Markdown-Quelle wird ins PDF eingebettet.
**Kein Pandoc nötig** — die gesamte Konvertierung läuft in Typst.

## Voraussetzungen

- [typst](https://typst.app) ≥ 0.15 (PDF/A-Export + variable Fonts — die `wght`-Achse
  liefert den halbfetten Schnitt der Überschriften; `build.sh` bricht unter 0.15 ab)
- [git](https://git-scm.com) zum Klonen

Die Typst-Packages **cmarker** (Markdown → Typst) und **mitex** (Formeln) sowie die Fonts
werden vom Installer offline ins Projekt gelegt (`vendor/`, `fonts/`) — kein Registry-Zugriff
zur Build-Zeit.

## Installation

### Schnellinstallation (ein Befehl)

Einzige Vorbedingung ist **git**. Der Bootstrap klont das Projekt nach
`~/.local/share/real-fast-document` (Windows: `%LOCALAPPDATA%\real-fast-document`),
installiert typst, lädt Fonts + Typst-Packages und richtet die Rechtsklick-Integration ein.

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.ps1 | iex
```

typst kommt über den System-Paketmanager (Homebrew / apt / dnf / pacman / winget). Fehlt es
dort oder ist es älter als 0.15 (häufig unter Linux), lädt der Installer das offizielle
typst-Binary nach `./bin` und nutzt es automatisch.

### Manuell

```bash
# 1. typst (Homebrew; unter Linux alternativ apt/dnf/pacman)
brew install typst                             # Windows: winget install --id Typst.Typst -e

# 2. Repository klonen
git clone https://github.com/jcmx9/real-fast-document.git
cd real-fast-document

# 3. macOS / Linux: Fonts + Typst-Packages + Rechtsklick-Integration
bash scripts/install.sh
#    (oder nur Assets: bash scripts/fetch-fonts.sh && bash scripts/fetch-typst-packages.sh)

# 3. Windows: Fonts + Typst-Packages + "Senden an"-Verknüpfung
./scripts/install.ps1
```

`install.sh` / `install.ps1` sind idempotent und lassen sich einzeln steuern:

```bash
bash scripts/install.sh             # Werkzeug + Fonts + Packages + Rechtsklick-Integration
bash scripts/install.sh --uninstall # nur die Rechtsklick-Integration entfernen
```

```powershell
./scripts/install.ps1             # Tools + Fonts + Packages + "Senden an"-Verknüpfung
./scripts/install.ps1 -Tools      # nur typst via winget
./scripts/install.ps1 -Fonts      # nur Fonts ins Projekt laden (./fonts)
./scripts/install.ps1 -Packages   # nur Typst-Packages laden (./vendor)
./scripts/install.ps1 -SendTo     # nur die Verknüpfung anlegen
./scripts/install.ps1 -Uninstall  # Verknüpfung entfernen
```

## Update

**Einfachster Weg:** denselben Bootstrap-Einzeiler erneut ausführen — er erkennt die
vorhandene Installation und aktualisiert sie (`git pull --ff-only` + Installer).

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.ps1 | iex
```

Alternativ manuell im Installordner:

```bash
cd ~/.local/share/real-fast-document   # bzw. der gewählte Installpfad
git pull --ff-only                     # neueste Version holen
bash scripts/install.sh                # Fonts/Packages/Integration bei Bedarf aktualisieren
```

Unter Windows nach `git pull --ff-only` bei Bedarf `./scripts/install.ps1` erneut ausführen.

## Verwendung

### macOS / Linux

```bash
bash scripts/build.sh                 # example.md  -> example.pdf
bash scripts/build.sh dokument.md     # dokument.md -> dokument.pdf
bash scripts/build.sh in.md out.pdf   # explizite Ausgabe
```

Ohne zweites Argument landet die Ausgabe neben der Quelle. Ist im Frontmatter ein `date`
gesetzt, bekommt die Datei automatisch einen ISO-Präfix (`2026-06-19_dokument.pdf`).

Die erzeugte PDF wird nach erfolgreichem Build automatisch im Standardprogramm geöffnet
(Terminal und Rechtsklick, alle drei Systeme). Für Batch-/Cron-Läufe lässt sich das mit
der Umgebungsvariable `RFD_NO_OPEN=1` abschalten.

### Ohne Terminal (Rechtsklick)

Nach der Einrichtung steht auf allen drei Systemen ein Rechtsklick-Eintrag bereit; die
PDF/A landet jeweils neben der Quelle:

- **Windows:** `.md` markieren → Rechtsklick → **Senden an → „Nach PDF-A (real-fast-document)"**
- **macOS:** `.md` rechtsklicken → **Dienste / Quick Actions → „Nach PDF-A (real-fast-document)"**
- **Linux:** `.md` rechtsklicken → **Öffnen mit → „Nach PDF-A (real-fast-document)"**

## Frontmatter (optional)

Ein YAML-Block am Dateianfang steuert einzelne Dokumente. Alle Schlüssel sind optional:

```yaml
---
title: "Mein Dokument"  # Titelblock oben + Titel in der Kopfzeile ab Seite 1
date: 2026-06-19        # ISO-Datum: Präfix am Dateinamen + Datum unten rechts (nach Sprache)
toc: true               # Inhaltsverzeichnis erzwingen (true) / unterdrücken (false)
h1-break: false         # Kapitel-Seitenumbruch (vor jedem # H1) erzwingen / unterdrücken
print_filename: false   # Dateiname unten links ausblenden (Default: true)
lang: de                # Dokumentsprache (Datumsformat); Default de
header: "Vertraulich"   # fester Kopfzeilentext ab Seite 1 (übersteuert den Running Header)
watermark: "ENTWURF"    # diagonales Wasserzeichen unter allem
---
```

| Schlüssel | Werte | Wirkung |
|-----------|-------|---------|
| `title` | Text | **Dokumenttitel**: zentrierter Titelblock oben, zusätzlich in der Kopfzeile ab Seite 1, und PDF/A-Metadatentitel. Ohne `title` bleibt der Metadatentitel der Dateiname und es gibt keinen Titelblock. |
| `date` | ISO-Datum | Gesetzt → Ausgabedatei erhält den ISO-Präfix `JJJJ-MM-TT_name.pdf` **und** das Datum erscheint unten rechts, lokalisiert nach `lang` (de „19. Juni 2026", en „June 19, 2026"). Die Fußzeile wird dann 3-spaltig (Name · Seite mittig · Datum). |
| `toc` | `true` / `false` | Inhaltsverzeichnis erzwingen / unterdrücken. Ohne Angabe greift der Struktur-Automatismus (siehe unten). |
| `h1-break` | `true` / `false` | Kapitel-Seitenumbruch (vor jedem `# H1`) erzwingen / unterdrücken. Ohne Angabe greift derselbe Automatismus, unabhängig von `toc`. |
| `print_filename` | `true` / `false` | Dateiname unten links anzeigen. Default `true`. |
| `lang` | Sprachcode | Dokumentsprache und Datumsformat (`de`, `en`, …). Default `de`. |
| `header` | Text | Fester Kopfzeilentext ab **Seite 1**; übersteuert den Running Header (und den Titel im Kopf). |
| `watermark` | Text | Diagonales, gespreiztes Wasserzeichen (fett, hellgrau) auf jeder Seite, **unter** allen anderen Elementen. |

**Kopfzeile — Vorrang von oben:** (1) `header:` fester Text ab Seite 1; sonst (2) das jeweils
aktive `# H1`-Kapitel als Running Header; davor, vor dem ersten Kapitel, (3) der **Titel**
(`title:`), falls gesetzt. Text stets in Sans.

**Struktur-Automatismus:** Ohne explizite Angabe entscheidet die Heuristik `#H1 + #H2 > 5`.
Bei **mehr als fünf** Kapitel-/Unterüberschriften schaltet das Dokument in den *strukturierten
Modus*: ein Inhaltsverzeichnis (nur H1 + H2) erscheint nach dem Titel **und** jedes Kapitel
(`# H1`) beginnt auf einer neuen Seite. Bei **fünf oder weniger** bleibt es *kompakt* — kein
Verzeichnis, die Kapitel laufen im Fluss. `toc` und `h1-break` schalten diese beiden Effekte
**einzeln und unabhängig** (`true` erzwingt, `false` unterdrückt).

Die Boolean-Schlüssel (`toc`, `h1-break`, `print_filename`) akzeptieren alle
YAML-1.1-Schreibweisen, unabhängig von Groß-/Kleinschreibung: `true`/`false`, `yes`/`no`,
`on`/`off` (sowie `"true"` in Anführungszeichen). Ein nicht erkannter Wert wird mit einer
Warnung ignoriert und der Default greift.

## Markdown — Kurzeinstieg

Markdown deckt im Alltag fast alles ab: `*kursiv*`, `**fett**`, `` `inline-code` ``,
Aufzählungen, nummerierte Listen, Aufgabenlisten (`- [ ]`), Tabellen, Zitate, Fußnoten,
Definitionslisten und `[Links](https://typst.app)` funktionieren ohne Zusatzaufwand.
Codeblöcke werden mit Syntax-Hervorhebung gesetzt, Formeln (`$…$`, `$$…$$`) über LaTeX-Syntax.

**Bilder:** `![Untertitel](pfad.svg)` wird als nummerierte Abbildung mit Untertitel gesetzt.
Lokale Bilder werden eingebettet; relative Pfade sind **relativ zum Dokument**. **Remote-Bilder**
(`http(s)://`, protokoll-relativ `//host`, `data:`) lassen sich offline nicht laden — Typst hat
bewusst keinen Netzzugriff — und entfallen daher automatisch; der Build meldet, wie viele Bilder
übersprungen wurden.

Der **Dokumenttitel** kommt aus dem Frontmatter (`title:`), nicht aus dem Markdown. `# H1` ist das
oberste **Kapitel** (feine Linie, Seitenumbruch bei `h1-break`, läuft im Seitenkopf mit); `## H2`
und `### H3` sind Unterabschnitte, ab `#### H4` nur noch fett und linksbündig.

```markdown
---
title: "Dokumenttitel"
---

# Erstes Kapitel

Fließtext mit **Auszeichnung** und einer Fußnote.[^1]

## Unterabschnitt

- Punkt eins
- Punkt zwei

[^1]: Die Fußnote erscheint am unteren Seitenrand.
```

## Layout-Spezifikation

| Aspekt | Wert |
|--------|------|
| Format | DIN A4 Hochformat |
| Ränder | links 30 mm · oben/unten/rechts je 20 mm |
| PDF-Standard | PDF/A-3b, Schriften eingebettet, Quelle als Anhang |
| **Titel** | aus `title:` — zentriert oben (Serif) + in der Kopfzeile ab Seite 1; kein Heading, nicht im TOC |
| **H1** | **Kapitel** (Serif, feine Linie dicht darunter); beginnt bei `h1-break` auf neuer Seite und läuft im Kopf mit |
| **H2 / H3** | Unterabschnitte (Serif, ohne Linie); ab **H4** nur noch fett + linksbündig |
| Kopf | `header:` fester Text · sonst aktives H1-Kapitel · vor dem 1. Kapitel der Titel. Text in **Sans** |
| **TOC** | bedingt: ab `#H1 + #H2 > 5` → Inhaltsverzeichnis (nur H1 + H2) + Kapitel je neue Seite; per `toc`/`h1-break` übersteuerbar |
| Kopf rechts | Logo (`logo.svg` → `.png` → `.jpg`), Höhe 13 mm — **optional** |
| Fuß | **Sans**; ohne Datum: Name links · Seite rechts. Mit Datum: Name links · Seite mittig · Datum rechts |
| Überschriften | **Source Serif 4**, `luma(8%)`, linksbündig, ohne Balken; **nur H1** trägt eine feine Hairline dicht darunter, alle anderen grenzen sich über Größe/Abstand ab |
| Wasserzeichen | optional (`watermark:`): diagonal, gespreizt, fett, hellgrau (Einkanal-Grau → sauberes K im Druck), **unter** allem |
| Fließtext | Source Sans 3, 12 pt, Blocksatz mit Silbentrennung, `luma(13%)` |
| Tabellen | volle Breite; Kopf zentriert + fett mit Linie darunter; leichtes Zeilen-Zebra, senkrechte Trennlinien, keine waagerechten Zeilenlinien |
| Code | Source Code Pro, 10 pt, mit Syntax-Hervorhebung |
| Aufzählungen | ungeordnet: kleines Quadrat auf **allen** Ebenen; geordnet: Nummern; Aufgaben (`- [ ]`): Kästchen ☐ offen / ☒ erledigt |
| Bilder | lokal: nummerierte Abbildung mit Untertitel; remote (`http(s)`, `//host`, `data:`) offline automatisch entfernt |
| Zitate | beidseitig eingerückt (schmaler als Satzspiegel) + kursiv |
| Emoji/Symbole | zeichenbasierter Fallback: Noto Emoji + Noto Sans Symbols 2 (monochrom, nur für Zeichen ohne Source-Glyph) |

### Typografie (Schriftgrade)

| Element | Schrift | Grad |
|---------|---------|------|
| Fließtext | Source Sans 3 | 12 pt |
| Titel (`title:`) | Source Serif 4 halbfett | 21 pt, zentriert |
| Kapitel (H1) | Source Serif 4 Book (`wght` 450) | 18 pt, feine Linie darunter |
| H2 / H3 | Source Serif 4 Book (`wght` 450) | 15 / 13 pt, ohne Linie |
| H4+ | Source Serif 4 fett | 12 pt, linksbündig |
| TOC-Titel „Inhalt" | Source Serif 4 halbfett | 16 pt |
| TOC-Einträge (H1 + H2) | Source Sans 3 (`wght` 450) | 12 pt, gleiche Zeilenabstände |
| Kopf (Text) | Source Sans 3 (`wght` 450) | 13 pt |
| Bildunterschrift | Source Sans 3 | 10 pt |
| Code | Source Code Pro | 10 pt |
| Fußzeile | Source Sans 3 | 9 pt |

## Aufbau

```
template.typ                Typst-Template: Seitenlayout + ruft cmarker auf der Quelle auf
scripts/build.sh            Pipeline Markdown -> PDF/A (macOS/Linux), Frontmatter + Preprocessing
scripts/convert.ps1         Windows-Konverter (von "Senden an" aufgerufen)
scripts/fetch-fonts.sh      bündelt variable Source-Fonts nach ./fonts
scripts/fetch-typst-packages.sh  vendort cmarker + mitex nach ./vendor (offline)
scripts/bootstrap.sh        Ein-Zeiler-Installer (macOS/Linux): klont + ruft install.sh
scripts/bootstrap.ps1       Ein-Zeiler-Installer (Windows): klont + ruft install.ps1
scripts/install.sh          macOS/Linux-Setup: Werkzeug + Fonts + Packages + Rechtsklick
scripts/install.ps1         Windows-Setup: Werkzeug + Fonts + Packages + "Senden an"
scripts/rfd-convert.sh      Konverter-Dispatcher der Rechtsklick-Integration (macOS/Linux)
fonts/                      Source-OTF (Serif 4 / Sans 3 / Code Pro) + Noto-Fallbacks (git-ignored)
vendor/                     gevendorte Typst-Packages cmarker + mitex (git-ignored)
logo.svg                    Kopf-Logo (optional)
assets/pipeline.svg         lokale Beispielabbildung für example.md
example.md                  volle Beispiel-/Falltest-Datei (alle Elemente, dokumentierter Frontmatter)
```

## Anpassen

- **Frontmatter** steuert einzelne Dokumente (Datum, TOC, Umbruch, Dateiname, Sprache) — siehe oben.
- **Logo / Dateiname / Datum / Titel** werden zur Compile-Zeit als Typst-`--input` übergeben
  (`scripts/build.sh`) und im Template über `sys.inputs` gelesen. Das Logo wird in der
  Reihenfolge `logo.svg` → `logo.png` → `logo.jpg` gewählt; fehlt es, baut die Pipeline mit
  Hinweis weiter. Logo-Höhe im Template über `logo-height`.
- **Ränder, Fonts, Farben, Schriftgrade** stehen gesammelt oben in `template.typ`
  (`#set page`, `#set text`, `head-color`, `heading-text`).
- **Anderer PDF/A-Grad**: `standard` in `scripts/build.sh` ändern (`a-1b`, `a-2b`, `a-3b`).
  Das Einbetten der Quelle setzt `a-3b` voraus.
- **Quelle als Anhang**: Die Markdown-Datei wird via `pdf.attach` ins PDF eingebettet und
  lässt sich z. B. mit `mutool extract datei.pdf` wieder herauslösen.
- **Package-Versionen**: cmarker/mitex sind in `scripts/fetch-typst-packages.sh` und
  `scripts/install.ps1` gepinnt; zum Aktualisieren dort die Version anheben und neu vendoren.

## Versionierung

[CalVer](https://calver.org/) im Format `YY.M.MICRO` — siehe `VERSION` und
[CHANGELOG.md](CHANGELOG.md).

## Lizenz

MIT — siehe [LICENSE](LICENSE). Die gebündelten Fonts unter `fonts/` stehen unter der
SIL Open Font License 1.1 (siehe [fonts/README.md](fonts/README.md)). Die gevendorten Packages
unter `vendor/` tragen ihre eigenen Lizenzen (cmarker: MIT, mitex: Apache-2.0).
