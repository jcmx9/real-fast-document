---
# Vorlage: alle Frontmatter-Schlüssel von rf-document mit ihren Standardwerten.
# Die eingetragenen Werte gelten auch, wenn ein Schlüssel fehlt – kopieren und
# nur ändern, was abweichen soll. Leere Werte ("" oder nichts hinter dem
# Doppelpunkt) werden ignoriert, nie ein Fehler. Ja/Nein-Schlüssel verstehen
# true/false, yes/no, on/off. Beschreibung aller Schlüssel: README, "Frontmatter".

# ---- Titelblock -------------------------------------------------------------
# Dokumenttitel: mittig oben, in der Kopfzeile ab Seite 1, PDF-Metadatentitel.
# Leer: kein Titelblock, Metadatentitel = Dateiname. "# …" im Text ist immer
# ein Kapitel, nie der Titel.
title: ""
# Untertitel unter dem Titel.
subtitle: ""
# Kunde/Firma: klein und gesperrt über dem Titel.
client: ""
# Autor(en): Zeile "Datum · Autor" unter dem Titel; mehrere: [Anna, Ben]
author: ""
# Datum: 2026-10-13 oder 13.10.2026. Erscheint unten rechts, setzt das
# PDF-Datum und stellt dem Dateinamen das ISO-Datum voran. Leer: kein Datum.
date: ""
# ISO-Datum vor dem Dateinamen (2026-10-13_name.pdf), wenn date gesetzt ist.
# Gilt nicht bei ausdrücklich angegebenem Ausgabepfad.
isodate_praefix: true

# ---- Sprache & Struktur -----------------------------------------------------
# Sprache: Datumsformat, Silbentrennung, Anführungszeichen ("x" -> de „x“,
# en “x”) und Beschriftungen (de: Seite/Inhalt/Aufgabe, Info/Tipp/…;
# en: Page/Contents/Task, Note/Tip/…). Standard: de.
lang: de
# Inhaltsverzeichnis: auto = ab mehr als fünf #/##-Überschriften; true/false erzwingt.
toc: auto
# Jedes Kapitel (#) auf neuer Seite: auto = wie toc; true/false erzwingt.
# Mit false läuft der Text auch direkt unter dem Inhaltsverzeichnis weiter.
h1_break: auto

# ---- Kopf, Fuß, Wasserzeichen -----------------------------------------------
# Fester Kopfzeilentext ab Seite 1 (sonst das aktuelle Kapitel bzw. der Titel).
header: ""
# Fußzeile links: Dateiname bzw. "Kunde · Titel" (wenn client oder subtitle
# gesetzt); false blendet die Angabe aus.
print_filename: true
# Diagonales Wasserzeichen auf jeder Seite, z. B. "ENTWURF".
watermark: ""

# ---- Logo -------------------------------------------------------------------
# Logo im Kopf (.svg, .png, .jpg, .jpeg); leer oder ohne Schlüssel: kein Logo.
# Relativ: gesucht im Ordner der Notiz, dann im Benutzerordner, dann im
# Installordner. Absolut geht auch; ~, $VAR, ${VAR} und %VAR% werden ersetzt.
# Nicht gefunden: Hinweis, ohne Logo.
logo: ""
# Maximale Logohöhe, nur absolute Längen (mm, cm, pt, in); Standard 13mm,
# höchstens 25mm. Das Logo bleibt proportional und höchstens 60 mm breit.
logo-height: 13mm

# ---- Ausgabe ----------------------------------------------------------------
# Markdown-Quelle als Anhang ins PDF einbetten; false für Kunden-PDFs
# (gleichwertig: rf-document --no-source).
embed_source: true
# Jeder Zeilenumbruch bleibt ein Zeilenumbruch, wie im Editor getippt
# (Standard, auch ohne Eintrag). false: CommonMark, ein einzelner Umbruch wird
# zum Leerzeichen, z. B. für umbrochenen Fließtext (rf-document --soft-breaks).
hard_breaks: true
---
