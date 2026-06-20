# real·fast·document

[Deutsch](README.md) · **English**

> Turn a Markdown file into an archivable, consistently styled **PDF/A-3b** —
> no word processor, no manual layout.

Markdown → **Pandoc** (+ Lua filter) → **Typst** → **PDF/A** with a fixed corporate layout:
DIN A4 portrait, running header with chapter and logo, footer with file name,
page count and optional date. The Markdown source is embedded into the PDF.

## Prerequisites

- [pandoc](https://pandoc.org) ≥ 3.x (Typst writer)
- [typst](https://typst.app) ≥ 0.15 (PDF/A export + variable fonts — the `wght` axis
  provides the semibold heading weight; `build.sh` aborts below 0.15)
- [git](https://git-scm.com) for cloning

## Installation

### Quick install (one command)

The only prerequisite is **git**. The bootstrap clones the project into
`~/.local/share/real-fast-document` (Windows: `%LOCALAPPDATA%\real-fast-document`),
installs pandoc and typst, downloads the fonts and sets up the right-click integration.

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.ps1 | iex
```

Tools come from the system package manager (Homebrew / apt / dnf / pacman / winget).
If typst is missing there or older than 0.15 (common on Linux), the installer downloads
the official typst binary into `./bin` and uses it automatically.

### Manual

```bash
# 1. Tools (Homebrew; on Linux use apt/dnf/pacman for pandoc)
brew install pandoc typst                      # Windows: winget install --id JohnMacFarlane.Pandoc -e; winget install --id Typst.Typst -e

# 2. Clone the repository
git clone https://github.com/jcmx9/real-fast-document.git
cd real-fast-document

# 3. macOS / Linux: fonts + right-click integration
bash scripts/install.sh
#    (or fonts only: bash scripts/fetch-fonts.sh)

# 3. Windows: fonts + "Send to" shortcut
./scripts/install.ps1
```

`install.sh` / `install.ps1` are idempotent and can be controlled individually:

```bash
bash scripts/install.sh             # tools + fonts + right-click integration
bash scripts/install.sh --uninstall # remove only the right-click integration
```

```powershell
./scripts/install.ps1            # tools + fonts + "Send to" shortcut
./scripts/install.ps1 -Tools     # pandoc/typst via winget only
./scripts/install.ps1 -Fonts     # download fonts into the project only (./fonts)
./scripts/install.ps1 -SendTo    # create the shortcut only
./scripts/install.ps1 -Uninstall # remove the shortcut
```

## Update

```bash
cd ~/.local/share/real-fast-document   # or your chosen install path
git pull                               # fetch the latest version
bash scripts/install.sh                # refresh fonts/integration if needed
```

On Windows, run `./scripts/install.ps1` again after `git pull` if needed.

## Usage

### macOS / Linux

```bash
bash scripts/build.sh                 # example.md  -> example.pdf
bash scripts/build.sh document.md     # document.md -> document.pdf
bash scripts/build.sh in.md out.pdf   # explicit output
```

Without a second argument the output lands next to the source. If the frontmatter sets a
`date`, the file automatically gets an ISO prefix (`2026-06-19_document.pdf`).

After a successful build the PDF opens automatically in the default viewer (terminal and
right-click, all three systems). For batch/cron runs this can be disabled with the
environment variable `RFD_NO_OPEN=1`.

### Without a terminal (right-click)

After setup a right-click entry is available on all three systems; the PDF/A lands next to
the source:

- **Windows:** select `.md` → right-click → **Send to → "Nach PDF-A (real-fast-document)"**
- **macOS:** right-click `.md` → **Services / Quick Actions → "Nach PDF-A (real-fast-document)"**
- **Linux:** right-click `.md` → **Open with → "Nach PDF-A (real-fast-document)"**

## Frontmatter (optional)

A YAML block at the start of the file controls individual documents. All keys are optional:

```yaml
---
date: 2026-06-19   # ISO date: prefix on the file name + date bottom-right (per language)
toc: true          # force (true) / suppress (false) the table of contents
h2-break: false    # force (true) / suppress (false) chapter page breaks
filename: false    # hide the file name at the bottom left (default: true)
---
```

| Key | Values | Effect |
|-----|--------|--------|
| `date` | ISO date | Set → output file gets the ISO prefix `YYYY-MM-DD_name.pdf` **and** the date appears bottom-right, localized by `lang` (de "19. Juni 2026", en "June 19, 2026"). The footer then becomes 3-column (name · page centered · date). |
| `toc` | `true` / `false` | Force / suppress the table of contents. Without it, the structure automatism applies (see below). |
| `h2-break` | `true` / `false` | Force / suppress chapter page breaks. Without it, the same automatism applies, independently of `toc`. |
| `filename` | `true` / `false` | Show the file name at the bottom left. Default `true`. |

**Structure automatism:** without an explicit value the heuristic `#H2 + #H3 > 5` decides.
With **more than five** chapter/subsection headings the document switches to *structured*
mode: a table of contents appears after the title **and** each chapter (`## H2`) starts on a
new page. At **five or fewer** it stays *compact* — no contents, chapters run inline. `toc`
and `h2-break` toggle these two effects **individually and independently** (`true` forces,
`false` suppresses), so e.g. a table of contents without chapter page breaks is possible.

The boolean keys (`toc`, `h2-break`, `filename`) accept all YAML 1.1 spellings, regardless of
case: `true`/`false`, `yes`/`no`, `on`/`off` (as well as `"true"` in quotes). An unrecognized
value is ignored with a warning and the default applies.

`lang` (standard Pandoc key) controls the document language and thus the date format.

## Markdown — quick start

Markdown covers almost everything day to day: `*italic*`, `**bold**`, `` `inline-code` ``,
bullet lists, numbered lists, task lists (`- [ ]`), tables, quotes, footnotes and
`[links](https://typst.app)` work without extra effort. Code blocks are set with syntax
highlighting.

**Images:** `![caption](path.svg)` is set as a numbered figure with a caption. Local images
are embedded. **Remote images** (`http(s)://`, protocol-relative `//host`, `data:`) cannot be
loaded offline — Typst deliberately has no network access — and are therefore dropped
automatically; the build reports how many images were skipped.

A single rule is mandatory: **exactly one `# H1` per document** — it is the title
(centered, pulled into the PDF metadata, not in the header/TOC). Chapters start at `## H2`
and run along the left of the page header; `### H3` and deeper are subsections.

```markdown
# Document title

## First chapter

Body text with **emphasis** and a footnote.[^1]

### Subsection

- Item one
- Item two

[^1]: The footnote appears at the bottom of the page.
```

## Layout specification

| Aspect | Value |
|--------|-------|
| Format | DIN A4 portrait |
| Margins | left 30 mm · top/bottom/right 20 mm each |
| PDF standard | PDF/A-3b, fonts embedded, source as attachment |
| **H1** | **Document title** — exactly once (multiple H1 = build error), centered, opens the document |
| **H2** | **Chapter** — the current chapter runs dynamically along the left of the header |
| **TOC** | conditional: from `#H2 + #H3 > 5` → table of contents + chapters on their own pages; overridable via frontmatter `toc`/`h2-break` |
| Header right | logo (`logo.svg` → `.png` → `.jpg`), height 13 mm — **optional** |
| Footer | without date: name left · page right. With date: name left · page centered · date right |
| Headings | Source Sans 3 (sans-serif), `luma(8%)`; H2 with a 1 pt frame + 3 pt accent bar on the left, H3+ only a 3 pt bar on the left (`luma(20%)`, 80 % gray) |
| Body | Source Sans 3, 12 pt, justified with hyphenation, `luma(13%)` |
| Code | Source Code Pro, 10 pt, with syntax highlighting |
| Lists | unordered: a small square at **all** levels; ordered: numbers; tasks (`- [ ]`): checkbox only |
| Images | local: numbered figure with caption; remote (`http(s)`, `//host`, `data:`) dropped automatically when offline |
| Quotes | indented on both sides (narrower than the text block) + italic |
| Emoji/symbols | glyph-level fallback: Noto Emoji + Noto Sans Symbols 2 (monochrome, only for characters without a Source glyph) |

### Typography (font sizes)

| Element | Font | Size |
|---------|------|------|
| Body | Source Sans 3 | 12 pt |
| Title (H1) | Source Sans 3 semibold | 28 pt, centered |
| Chapter (H2) | Source Sans 3 Book (`wght` 450) | 18 pt, 1 pt frame + 3 pt bar on the left |
| H3 / H4 / H5 / H6 | Source Sans 3 Book (`wght` 450) | 14.5 / 13 / 12 / 12 pt, 3 pt bar on the left |
| TOC title "Inhalt" | Source Sans 3 semibold | 16 pt |
| TOC entries | Source Sans 3 | 13 pt, Book (`wght` 450) |
| Header (chapter) | Source Sans 3 Book (`wght` 450) | 13 pt, plain text (no bar) |
| Code | Source Code Pro | 10 pt |
| Footer | Source Sans 3 | 9 pt |

## Structure

```
template.typ              Pandoc/Typst template: the entire page layout
filters/meta-from-h1.lua  document title (PDF/A) from exactly one H1, task lists, strips remote images
scripts/build.sh          pipeline Markdown -> PDF/A (macOS/Linux), frontmatter parser
scripts/fetch-fonts.sh    bundles the fonts into ./fonts
scripts/bootstrap.sh      one-line installer (macOS/Linux): clones + runs install.sh
scripts/bootstrap.ps1     one-line installer (Windows): clones + runs install.ps1
scripts/install.sh        macOS/Linux setup: tools + fonts + right-click integration
scripts/rfd-convert.sh    converter dispatcher of the right-click integration (macOS/Linux)
scripts/install.ps1       Windows setup: tools + fonts + "Send to" shortcut
scripts/convert.ps1       Windows converter (invoked by "Send to")
fonts/                    Source OTF (Serif 4 / Sans 3 / Code Pro) + Noto fallbacks (Emoji, Symbols 2)
logo.svg                  header logo (optional)
assets/pipeline.svg       local example figure for example.md
example.md                full example/probe file (all elements, documented frontmatter)
```

## Customizing

- **Frontmatter** controls individual documents (date, TOC, break, file name) — see above.
- **Logo / file name / date** are passed at compile time as Typst `--input`
  (`scripts/build.sh`) and read in the template via `sys.inputs`. The logo is chosen in the
  order `logo.svg` → `logo.png` → `logo.jpg`; if missing, the pipeline continues with a
  notice. Logo height via `logo-height` in the template.
- **Margins, fonts, colors, font sizes** are collected at the top of `template.typ`
  (`#set page`, `#set text`, `head-color`, `heading-text`).
- **Different PDF/A level**: change `standard` in `scripts/build.sh` (`a-1b`, `a-2b`, `a-3b`).
  Embedding the source requires `a-3b`.
- **Source as attachment**: the Markdown file is embedded into the PDF via `pdf.attach` and
  can be extracted again, e.g. with `mutool extract file.pdf`.

## Versioning

[CalVer](https://calver.org/) in the format `YY.M.MICRO` — see `VERSION` and
[CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE). The bundled fonts under `fonts/` are licensed under the
SIL Open Font License 1.1 (see [fonts/README.md](fonts/README.md)).
