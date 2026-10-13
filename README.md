# real·fast·document

**Deutsch** · [English](README.en.md)

[![CI](https://github.com/jcmx9/real-fast-document/actions/workflows/ci.yml/badge.svg)](https://github.com/jcmx9/real-fast-document/actions/workflows/ci.yml)

> Aus einer Markdown-Datei ein archivfähiges, einheitlich gestaltetes **PDF/A-3b** —
> ohne Textverarbeitung, ohne manuelles Layout.

Markdown → **Typst** (Packages **cmarker** + **mitex** + **mmdr**) → **PDF/A** mit festem
Corporate-Layout: DIN A4 Hochformat, laufender Kopf mit Kapitel und Logo, Fußzeile mit
Dateiname, Seitenzählung und optionalem Datum. Die Markdown-Quelle wird ins PDF eingebettet.
**Kein Pandoc nötig** — die gesamte Konvertierung läuft in Typst.

## Voraussetzungen

- [typst](https://typst.app) ≥ 0.15 (PDF/A-Export + variable Fonts — die `wght`-Achse
  liefert den halbfetten Schnitt der Überschriften; `build.sh` bricht unter 0.15 ab)
- [git](https://git-scm.com) zum Klonen

Die Typst-Packages **cmarker** (Markdown → Typst), **mitex** (Formeln) und **mmdr** (Mermaid-Diagramme) sowie die Fonts
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

## Deinstallation

Die Integration (Rechtsklick-Eintrag, der globale Befehl `rf-document` und die
PATH-Hilfsdatei) entfernen:

**macOS / Linux:**

```bash
bash scripts/install.sh --uninstall
```

**Windows (PowerShell):**

```powershell
./scripts/install.ps1 -Uninstall
```

Der Installordner (Programm, Fonts, Packages, Logo) bleibt dabei erhalten. Um restlos
alles zu entfernen, ihn zusätzlich löschen:

```bash
rm -rf ~/.local/share/real-fast-document                           # macOS / Linux
```

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\real-fast-document"  # Windows
```

## Verwendung

### macOS / Linux

```bash
bash scripts/build.sh                 # example.md  -> example.pdf
bash scripts/build.sh dokument.md     # dokument.md -> dokument.pdf
bash scripts/build.sh in.md out.pdf   # exakt dieser Ausgabepfad
bash scripts/build.sh --no-source a.md # ohne eingebettete Quelle
bash scripts/build.sh --hard-breaks a.md  # Zeile bleibt Zeile
bash scripts/build.sh --help          # Optionen + Schlüssel
bash scripts/build.sh --version       # Versionen anzeigen
```

Ohne zweites Argument landet die Ausgabe neben der Quelle. Ist im Frontmatter ein `date`
gesetzt, bekommt die Datei automatisch einen ISO-Präfix (`2026-06-19_dokument.pdf`);
`isodate_praefix: false` schaltet dieses Präfix ab (das Datum bleibt in der Fußzeile). Ein
ausdrücklich angegebener Ausgabepfad wird exakt so geschrieben, ohne Präfix.

**Aufruf aus anderen Programmen** (z. B. als Zettlr-Exportziel): Der Exit-Code ist nur bei
Erfolg 0, Fehler und Warnungen gehen kurz auf stderr. `build.sh` findet Typst auch mit
minimalem `PATH` (GUI-Apps), weil es den vom Installer gemerkten Typst-Ordner selbst lädt.
Relative Pfade (Quelle, Ausgabe) gelten relativ zum Aufrufverzeichnis, Bilder und Logo relativ
zur Notiz.

Der globale Befehl versteht dieselben Optionen: `rf-document --help` bzw. `rf-document --version`
(`-h` / `-V` als Kurzform). Unter Windows zusätzlich als PowerShell-Switch: `rf-document -Help`
bzw. `rf-document -Version`.

| Option | Beschreibung |
|--------|--------------|
| `--hard-breaks` | Jede Zeile bleibt eine Zeile, wie im Editor getippt; wie `hard_breaks: true` |
| `--no-source` | Markdown-Quelle **nicht** ins PDF einbetten (z. B. für Kunden-PDFs); wie `embed_source: false` |
| `--version`, `-V` | rf-document- und Typst-Version ausgeben und beenden |
| `--help`, `-h` | Hilfe (Optionen, Frontmatter-Schlüssel, Umgebungsvariablen) ausgeben und beenden |

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
subtitle: "Workshop"    # Untertitel unter dem Titel
client: "Muster GmbH"   # Kunde: klein und gesperrt über dem Titel
author: "Ben Probe"     # Autor(en) unter dem Titel: "Datum · Autor"
date: 2026-06-19        # Datum (ISO oder 19.06.2026): Präfix am Dateinamen + Datum unten rechts
isodate_praefix: false  # ISO-Präfix am Dateinamen abschalten (Default: an, wenn date gesetzt)
toc: true               # Inhaltsverzeichnis erzwingen (true) / unterdrücken (false)
h1_break: false         # Kapitel-Seitenumbruch (vor jedem # H1) erzwingen / unterdrücken
print_filename: false   # Dateiname unten links ausblenden (Default: true)
lang: de                # Dokumentsprache (Datumsformat); Default de
header: "Vertraulich"   # fester Kopfzeilentext ab Seite 1 (übersteuert den Running Header)
watermark: "ENTWURF"    # diagonales Wasserzeichen unter allem
logo: logo-kunde.png    # Logo nur für dieses Dokument (relativ zur Notiz oder absolut)
logo-height: 15mm       # maximale Logohöhe (nur absolute Längen; Default 13mm, max. 25mm)
embed_source: false     # Markdown-Quelle nicht einbetten (Default: true)
hard_breaks: true       # jede Zeile bleibt eine Zeile (Default: false)
---
```

| Schlüssel | Werte | Wirkung |
|-----------|-------|---------|
| `title` | Text | **Dokumenttitel**: zentrierter Titelblock oben, zusätzlich in der Kopfzeile ab Seite 1, und PDF/A-Metadatentitel. Ohne `title` bleibt der Metadatentitel der Dateiname und es gibt keinen Titelblock. |
| `subtitle` | Text | Untertitel unter dem Titel. |
| `client` | Text | Kunde/Firma, klein und gesperrt über dem Titel. |
| `author` | Text oder `[A, B]` | Zeile unter dem Titel: „Datum · Autor“ (nur was gesetzt ist). |
| `date` | ISO oder `T.M.JJJJ` | Gesetzt → Ausgabedatei erhält den ISO-Präfix `JJJJ-MM-TT_name.pdf`, das Datum erscheint unten rechts, lokalisiert nach `lang` (de „19. Juni 2026", en „June 19, 2026"), **und** es wird als reproduzierbares PDF-Metadatendatum (`CreateDate`) gesetzt. Die Fußzeile wird dann 3-spaltig (Name · Seite mittig · Datum). Ohne `date` trägt das Metadatendatum die **Änderungszeit der Quelldatei** (nicht den Build-Zeitpunkt); ein gesetztes `SOURCE_DATE_EPOCH` gewinnt. |
| `isodate_praefix` | `true` / `false` | Steuert nur den ISO-Präfix am **Dateinamen**. Ohne Angabe präfixt ein gesetztes `date` automatisch (rückwärtskompatibel); `false` schaltet das Präfix ab, ohne das Datum in der Fußzeile zu berühren. Ohne `date` wirkungslos. |
| `toc` | `true` / `false` | Inhaltsverzeichnis erzwingen / unterdrücken. Ohne Angabe greift der Struktur-Automatismus (siehe unten). |
| `h1_break` | `true` / `false` | Kapitel-Seitenumbruch (vor jedem `# H1`) erzwingen / unterdrücken. Ohne Angabe greift derselbe Automatismus, unabhängig von `toc`. |
| `print_filename` | `true` / `false` | Angabe unten links anzeigen (Dateiname bzw. „Kunde · Titel“, siehe unten). Default `true`. |
| `lang` | Sprachcode | Dokumentsprache, Datumsformat und Beschriftungen (Seite/Page, Inhalt/Contents, …): `de`, `en`, …. Default `de`. |
| `header` | Text | Fester Kopfzeilentext ab **Seite 1**; übersteuert den Running Header (und den Titel im Kopf). |
| `watermark` | Text | Diagonales, gespreiztes Wasserzeichen (fett, hellgrau) auf jeder Seite, **unter** allen anderen Elementen. |
| `logo` | Pfad | Logo **nur für dieses Dokument** (PNG/JPG/SVG), relativ zur Notiz oder absolut; `~`, `$VAR`, `${VAR}` und `%VAR%` werden ersetzt. Überschreibt das globale Logo. Fehlt die Datei, warnt der Build und nimmt das globale Logo. |
| `logo-height` | Länge | Maximale Logohöhe, nur absolute Längen (`15mm`, `1.2cm`, `40pt`); anderes wird ignoriert. Das Logo bleibt proportional und höchstens 60 mm breit. |
| `hard_breaks` | `true` / `false` | Jeder Zeilenumbruch in der Quelle bleibt ein Zeilenumbruch (wie in Zettlr/Obsidian getippt). Default `false`: ein einzelner Umbruch wird zum Leerzeichen, wie in CommonMark. |
| `embed_source` | `true` / `false` | Markdown-Quelle als Anhang einbetten. Default `true`; `false` (oder `--no-source`) für PDFs, die die Notiz nicht enthalten sollen. |

Leere Werte (`subtitle: ""` oder nur `subtitle:`) werden ignoriert, nie ein Fehler.

**Fußzeile links:** der Dateiname — sobald `client` oder `subtitle` gesetzt ist, stattdessen
höchstens zwei Angaben aus Kunde, Titel und Untertitel in dieser Reihenfolge („Kunde · Titel“,
ohne Kunde „Titel · Untertitel“).

**Kopfzeile — Vorrang von oben:** (1) `header:` fester Text ab Seite 1; sonst (2) das jeweils
aktive `# H1`-Kapitel als Running Header; davor, vor dem ersten Kapitel, (3) der **Titel**
(`title:`), falls gesetzt. Text stets in Sans.

**Struktur-Automatismus:** Ohne explizite Angabe entscheidet die Heuristik `#H1 + #H2 > 5`.
Bei **mehr als fünf** Kapitel-/Unterüberschriften schaltet das Dokument in den *strukturierten
Modus*: ein Inhaltsverzeichnis (nur H1 + H2) erscheint nach dem Titel **und** jedes Kapitel
(`# H1`) beginnt auf einer neuen Seite. Bei **fünf oder weniger** bleibt es *kompakt* — kein
Verzeichnis, die Kapitel laufen im Fluss. `toc` und `h1_break` schalten diese beiden Effekte
**einzeln und unabhängig** (`true` erzwingt, `false` unterdrückt).

Die Boolean-Schlüssel (`isodate_praefix`, `toc`, `h1_break`, `print_filename`, `embed_source`, `hard_breaks`) akzeptieren alle
YAML-1.1-Schreibweisen, unabhängig von Groß-/Kleinschreibung: `true`/`false`, `yes`/`no`,
`on`/`off` (sowie `"true"` in Anführungszeichen). Ein nicht erkannter Wert wird mit einer
Warnung ignoriert und der Default greift.

## Markdown — Kurzeinstieg

Markdown deckt im Alltag fast alles ab: `*kursiv*`, `**fett**`, `` `inline-code` ``,
Aufzählungen, nummerierte Listen, Aufgabenlisten (`- [ ]`), Tabellen, Zitate, Fußnoten,
Definitionslisten und `[Links](https://typst.app)` funktionieren ohne Zusatzaufwand.
Codeblöcke werden mit Syntax-Hervorhebung gesetzt, Formeln (`$…$`, `$$…$$`) über LaTeX-Syntax.
Überschriften und Listen funktionieren auch ohne Leerzeile davor.

**Zusätzlich zu CommonMark:**

| Eingabe | Ergebnis |
|---------|----------|
| `==Text==` | Markierung (gelblicher Hintergrund) |
| `> [!NOTE]` … `[!CAUTION]`, `> [!INFO]`, `[!TIPP]`, `[!WICHTIG]`, `[!HINWEIS]`, `[!ACHTUNG]` | Hinweisbox (Info, Tipp, Wichtig, Hinweis, Achtung; englisch bei `lang: en`), bricht nicht über die Seite |
| Liste nur aus `- [ ] Aufgabe – Name, bis Datum` | Tabelle *Aufgabe · Wer · Bis · Status* (`bis`/`due`/`by`); überall leere Spalten entfallen |
| gemischte Liste mit `- [ ]` / `- [x]` | Kästchen statt Aufzählungspunkt, bündig mit den Punkten |
| `18. Oktober 2026` am Zeilenanfang | bleibt ein Datum, keine nummerierte Liste (Monatsnamen de/en, auch abgekürzt) |
| `<!-- pagebreak -->`, `\newpage` (eigene Zeile) | Seitenumbruch |
| `„…“`, `‚…‘`, `»…«`, `"…"` | Anführungszeichen bleiben exakt wie getippt (keine Automatik) |

Snippet-Vorlage für Aufgaben: `- [ ] ${1:Aufgabe} – ${2:Name}, bis ${3:Datum}$0`

**Bilder:** `![Untertitel](pfad.svg)` wird als nummerierte Abbildung mit Untertitel gesetzt,
`{width=50%}` (auch `8cm`, `80mm`, `300px`) dahinter setzt die Breite. Lokale Bilder werden
eingebettet; relative Pfade sind **relativ zum Dokument**, absolute gehen auch, und `~`, `$VAR`,
`${VAR}` sowie `%VAR%` werden ersetzt (`USER`↔`USERNAME`, `HOME`↔`USERPROFILE` als Rückfall).
Ein **fehlendes Bild bricht den Export nie ab**: Im PDF steht kursiv „[Bild fehlt: pfad]“, auf
stderr eine Warnung. Unter Windows sind nur Bilder auf dem Laufwerk der Installation erreichbar. **Remote-Bilder**
(`http(s)://`, protokoll-relativ `//host`, `data:`) lassen sich offline nicht laden — Typst hat
bewusst keinen Netzzugriff — und entfallen daher automatisch; der Build meldet, wie viele Bilder
übersprungen wurden.

**Diagramme:** Ein ` ```mermaid `-Codeblock wird offline gezeichnet (Typst-Package **mmdr**,
kein Netz), in ruhigen Farben und mit der variablen Source Sans 3. Fehlerhafte Syntax bricht
den Export nicht ab.

Der **Dokumenttitel** kommt aus dem Frontmatter (`title:`), nicht aus dem Markdown. `# H1` ist das
oberste **Kapitel** (feine Linie, Seitenumbruch bei `h1_break`, läuft im Seitenkopf mit); `## H2`
und `### H3` sind Unterabschnitte (`###` in Body-Größe, fein unterstrichen); `#### H4` und tiefer kursiv in Body-Größe.

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
| **Titel** | aus `title:` — zentriert oben (Serif) + in der Kopfzeile ab Seite 1; kein Heading, nicht im TOC. Darüber optional der Kunde (klein, gesperrt), darunter Untertitel und „Datum · Autor“ |
| **H1** | **Kapitel** (Serif, feine Linie dicht darunter); beginnt bei `h1_break` auf neuer Seite und läuft im Kopf mit |
| **H2 / H3** | Unterabschnitte (Serif, ohne Linie); **H3** fein unterstrichen, **H4** und tiefer kursiv, beide in Body-Größe |
| Kopf | `header:` fester Text · sonst aktives H1-Kapitel · vor dem 1. Kapitel der Titel. Text in **Sans** |
| **TOC** | bedingt: ab `#H1 + #H2 > 5` → Inhaltsverzeichnis (nur H1 + H2) + Kapitel je neue Seite; per `toc`/`h1_break` übersteuerbar |
| Kopf rechts | Logo (`logo:` pro Dokument, sonst `logo.svg` → `.png` → `.jpg`), proportional in 13 mm × 60 mm (`logo-height`) — **optional** |
| Fuß | **Sans**; ohne Datum: Name links · Seite rechts. Mit Datum: Name links · Seite mittig · Datum rechts. Name = Dateiname bzw. „Kunde · Titel“ |
| Überschriften | **Source Serif 4**, `luma(8%)`, linksbündig, ohne Balken; **nur H1** trägt eine feine Hairline dicht darunter, alle anderen grenzen sich über Größe/Abstand ab |
| Wasserzeichen | optional (`watermark:`): diagonal, gespreizt, fett, hellgrau (Einkanal-Grau → sauberes K im Druck), **unter** allem |
| Fließtext | Source Sans 3, 11 pt, `wght` 380, Mediävalziffern, Blocksatz mit Silbentrennung (Zeilenabstand 0.85em), `luma(13%)`; **fett** = 560 (`strong.delta` 180) |
| Tabellen | **Spaltenbreiten nach Inhalt** (wie HTML-Tabellen): passt alles, bleibt die Tabelle in Inhaltsbreite; sonst erhält jede Spalte mindestens ihr längstes Wort und textreiche Spalten den Rest. Zahlen-/Betragsspalten rechtsbündig, Ausrichtung aus der Trennzeile (`:--`, `--:`, `:-:`) hat Vorrang; Ziffern gleich breit (Versalziffern); Flattersatz; Kopf zentriert + fett mit Linie darunter; leichtes Zeilen-Zebra, senkrechte Trennlinien, keine waagerechten Zeilenlinien; **Kopfzeile wiederholt sich** bei Seitenumbruch |
| Code | Source Code Pro, 10 pt, mit Syntax-Hervorhebung |
| Aufzählungen | ungeordnet: kleines Quadrat auf **allen** Ebenen; geordnet: Nummern; Aufgaben (`- [ ]`): gezeichnetes Kästchen (erledigt: dunkel gefüllt mit weißem Häkchen), bündig mit den Punkten; reine Aufgabenlisten als Tabelle (Aufgabe 56 % · Wer 20 % · Bis 14 % · Status 10 %) |
| Hinweisboxen | Fläche aufgehellt, 2,5-pt-Balken links, Titel klein + gesperrt in Versalien; Farben: Info `#2f6aa8`, Tipp `#3b7d3a`, Wichtig `#7a4fb0`, Hinweis `#b05a1a`, Achtung `#b5452b` |
| Bilder | lokal: nummerierte Abbildung mit Untertitel, Breite per `{width=…}`; fehlend: „[Bild fehlt: pfad]“ statt Abbruch; remote (`http(s)`, `//host`, `data:`) offline automatisch entfernt |
| Diagramme | ` ```mermaid ` offline per mmdr, mittig, Flächen `#f4f2ee`, Rahmen `#b9b2a6`, Linien `#6b6b6b`, Text `#2b2b2b`, Notizen `#fbeab0`; Beschriftung Source Sans 3 (variabel, Medium) |
| Zitate | beidseitig eingerückt (schmaler als Satzspiegel) + kursiv |
| Emoji/Symbole | zeichenbasierter Fallback: Noto Emoji + Noto Sans Symbols 2 (monochrom, nur für Zeichen ohne Source-Glyph) |
| Umbruchschutz | Überschriften nie allein am Seitenfuß (sticky); Abbildung + Unterschrift bleiben zusammen; Schusterjungen/Hurenkinder/Runts vermieden (`costs`); **geschützte Leerzeichen** in deutschen Abkürzungen (z. B., d. h., u. a., …) und zwischen Zahl + Einheit/Prozent/Währung (12 pt, 5 %, 1.234,56 €) |

### Typografie (Schriftgrade)

| Element | Schrift | Grad |
|---------|---------|------|
| Fließtext | Source Sans 3 (`wght` 380), fett 560 | 11 pt, Zeilenabstand 0.85em |
| Titel (`title:`) | Source Serif 4 (`wght` 470) | 18 pt, zentriert |
| Kapitel (H1) | Source Serif 4 (`wght` 470) | 15 pt, feine Linie darunter |
| H2 | Source Serif 4 (`wght` 470) | 13 pt, ohne Linie |
| H3 | Source Serif 4 (`wght` 380) | 11 pt, fein unterstrichen |
| H4+ | Source Serif 4 (`wght` 380) kursiv | 11 pt |
| TOC-Titel „Inhalt" | Source Serif 4 (`wght` 470) | 15 pt |
| TOC-Einträge (H1 + H2) | Source Sans 3 (`wght` 380) | 12 pt, gleiche Zeilenabstände |
| Kopf (Text) | Source Sans 3 (`wght` 380) | 13 pt |
| Bildunterschrift | Source Sans 3 | 10 pt |
| Code | Source Code Pro | 10 pt |
| Fußzeile | Source Sans 3 | 9 pt |

## Aufbau

```
template.typ                Typst-Template: Seitenlayout + ruft cmarker auf der Quelle auf
lib/markdown.typ            Markdown-Vorverarbeitung in Typst (für alle Systeme gleich)
scripts/build.sh            Pipeline Markdown -> PDF/A (macOS/Linux): Frontmatter, Pfade, Aufruf
scripts/test-pdf.sh         End-to-End-Tests: baut tests/fixtures/*.md und prüft den PDF-Text
scripts/convert.ps1         Windows-Konverter (von "Senden an" aufgerufen)
scripts/fetch-fonts.sh      bündelt variable Source-Fonts nach ./fonts
scripts/fetch-typst-packages.sh  vendort cmarker + mitex + mmdr nach ./vendor (offline)
scripts/bootstrap.sh        Ein-Zeiler-Installer (macOS/Linux): klont + ruft install.sh
scripts/bootstrap.ps1       Ein-Zeiler-Installer (Windows): klont + ruft install.ps1
scripts/install.sh          macOS/Linux-Setup: Werkzeug + Fonts + Packages + Rechtsklick
scripts/install.ps1         Windows-Setup: Werkzeug + Fonts + Packages + "Senden an"
scripts/rfd-convert.sh      Konverter-Dispatcher der Rechtsklick-Integration (macOS/Linux)
fonts/                      variable Source-OTF (Serif 4 / Sans 3 / Code Pro) + Noto-Fallbacks
vendor/                     gevendorte Typst-Packages cmarker + mitex + mmdr (git-ignored)
logo.svg                    Kopf-Logo (optional)
assets/pipeline.svg         lokale Beispielabbildung für example.md
example.md                  volle Beispiel-/Falltest-Datei (alle Elemente, dokumentierter Frontmatter)
tests/fixtures/             Testnotizen (je Funktion eine, plus Grenzfälle)
```

**Tests:** `bash scripts/test-pdf.sh` baut alle Testnotizen und prüft den Text der PDFs sowie die
Schnittstelle (exakter Ausgabepfad, Exit-Codes, eingebettete Quelle, minimaler `PATH`). Benötigt
`pdftotext` (poppler) oder `mutool` (mupdf). Die CI führt die Tests bei jedem Push aus.

## Anpassen

- **Frontmatter** steuert einzelne Dokumente (Datum, TOC, Umbruch, Dateiname, Sprache) — siehe oben.
- **Dateiname / Datum / Titel** werden zur Compile-Zeit als Typst-`--input` übergeben
  (`scripts/build.sh`) und im Template über `sys.inputs` gelesen.
- **Logo austauschen:** Das globale Logo liegt **im Installordner** und gilt für **alle**
  Dokumente; ein einzelnes Dokument kann per `logo:` im Frontmatter ein eigenes setzen. Standardpfade nach der Schnellinstallation:
  - macOS / Linux: `~/.local/share/real-fast-document/logo.svg`
  - Windows: `%LOCALAPPDATA%\real-fast-document\logo.svg`

  Den Installpfad im Zweifel selbst ermitteln — der installierte Befehl verrät ihn:

  ```bash
  cat "$(command -v rf-document)"                                  # macOS / Linux
  ```

  ```powershell
  type "$env:LOCALAPPDATA\Microsoft\WindowsApps\rf-document.cmd"   # Windows
  ```

  Gewählt wird das **erste vorhandene** aus `logo.svg` → `logo.png` → `logo.jpg`; die
  bestehende Datei ersetzen (oder die anderen Formate entfernen). Fehlt ein Logo, baut die
  Pipeline mit Hinweis weiter. Maximale Höhe pro Dokument per `logo-height:`.
- **Ränder, Fonts, Farben, Schriftgrade** stehen gesammelt oben in `template.typ`
  (`#set page`, `#set text`, `head-color`, `heading-text`).
- **Anderer PDF/A-Grad**: `standard` in `scripts/build.sh` ändern (`a-1b`, `a-2b`, `a-3b`).
  Das Einbetten der Quelle setzt `a-3b` voraus.
- **Quelle als Anhang**: Die Markdown-Datei wird via `pdf.attach` ins PDF eingebettet (unter
  ihrem Dateinamen, ohne lokalen Pfad) und lässt sich z. B. mit `mutool extract datei.pdf`
  wieder herauslösen. Abschalten mit `--no-source` oder `embed_source: false`.
- **Package-Versionen**: cmarker/mitex/mmdr sind in `scripts/fetch-typst-packages.sh` und
  `scripts/install.ps1` gepinnt; zum Aktualisieren dort die Version anheben und neu vendoren.

## Versionierung

[CalVer](https://calver.org/) im Format `YY.M.MICRO` — siehe `VERSION` und
[CHANGELOG.md](CHANGELOG.md).

## Lizenz

MIT — siehe [LICENSE](LICENSE). Die gebündelten Fonts unter `fonts/` stehen unter der
SIL Open Font License 1.1 (siehe [fonts/README.md](fonts/README.md)). Die gevendorten Packages
unter `vendor/` tragen ihre eigenen Lizenzen (cmarker: MIT, mitex: Apache-2.0, mmdr: MIT).
