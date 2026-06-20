# Gebündelte Fonts

**Variable OTF (CFF2)** der Source-Familien (je Roman/Upright + Italic), von
`scripts/fetch-fonts.sh` bzw. `scripts/install.ps1` aus den Adobe-Upstream-
Releases geladen.

| Familie          | Familienname (Typst) | Release | Quelle |
|------------------|----------------------|---------|--------|
| Source Serif 4   | `Source Serif 4`     | 4.005R  | https://github.com/adobe-fonts/source-serif |
| Source Sans 3    | `SourceSans3VF`      | 3.052R  | https://github.com/adobe-fonts/source-sans |
| Source Code Pro  | `SourceCodeVF`       | 1.026vf | https://github.com/adobe-fonts/source-code-pro |

**Zeichenbasierte Fallbacks** (monochrom, TTF) von `github.com/google/fonts` —
greifen pro Glyph nur für Zeichen, die Source nicht hat (Emoji, Symbole). Beide
sind PDF/A-3b-tauglich (Outline-Glyphen, kein Farbformat).

| Familie             | Familienname (Typst)   | Abdeckung |
|---------------------|------------------------|-----------|
| Noto Emoji          | `Noto Emoji`           | Emoji/Piktogramme (variabel, `wght`) |
| Noto Sans Symbols 2 | `Noto Sans Symbols 2`  | Dingbats, Pfeile, weitere Symbole |

> **Hinweis zur Quelle:** Google Fonts (`github.com/google/fonts`) verteilt die
> Source-Familien ausschließlich als TTF; variable **OTF** gibt es nur bei Adobe.
> Die Noto-Fallbacks kommen direkt als TTF von Google Fonts (Format dort egal —
> Typst bettet TTF ebenso PDF/A-konform ein).

> **Familiennamen:** Die variablen OTF von Sans/Code melden interne VF-Namen
> (`SourceSans3VF`, `SourceCodeVF`) — `template.typ` referenziert exakt diese.

**Lizenz:** SIL Open Font License 1.1 (OFL) — siehe
<https://openfontlicense.org>. Die Fonts dürfen frei gebündelt und
weitergegeben werden; sie unterliegen der OFL, nicht der MIT-Lizenz des
Projekts.

> Voraussetzung: **Typst ≥ 0.15** (Variable-Font-Unterstützung). Der
> Semibold-Schnitt der Überschriften kommt über die `wght`-Achse.
