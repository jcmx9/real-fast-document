# real·fast·document

[Deutsch](README.md) · **English**

> Turn a Markdown file into an archival, consistently styled **PDF/A-3b** —
> no word processor, no manual layout.

Markdown → **Typst** (packages **cmarker** + **mitex**) → **PDF/A** with a fixed corporate
layout: A4 portrait, running header with chapter and logo, footer with filename, page count
and optional date. The Markdown source is embedded into the PDF. **No Pandoc required** — the
entire conversion runs in Typst.

## Prerequisites

- [typst](https://typst.app) ≥ 0.15 (PDF/A export + variable fonts — the `wght` axis provides
  the semibold heading weight; `build.sh` aborts below 0.15)
- [git](https://git-scm.com) for cloning

The Typst packages **cmarker** (Markdown → Typst) and **mitex** (math) as well as the fonts are
placed into the project offline by the installer (`vendor/`, `fonts/`) — no registry access at
build time.

## Installation

### Quick install (one command)

The only prerequisite is **git**. The bootstrap clones the project into
`~/.local/share/real-fast-document` (Windows: `%LOCALAPPDATA%\real-fast-document`), installs
typst, downloads fonts + Typst packages and sets up the right-click integration.

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.ps1 | iex
```

typst comes via the system package manager (Homebrew / apt / dnf / pacman / winget). If it is
missing there or older than 0.15 (common on Linux), the installer downloads the official typst
binary into `./bin` and uses it automatically.

### Manual

```bash
# 1. typst (Homebrew; on Linux alternatively apt/dnf/pacman)
brew install typst                             # Windows: winget install --id Typst.Typst -e

# 2. Clone the repository
git clone https://github.com/jcmx9/real-fast-document.git
cd real-fast-document

# 3. macOS / Linux: fonts + Typst packages + right-click integration
bash scripts/install.sh
#    (or assets only: bash scripts/fetch-fonts.sh && bash scripts/fetch-typst-packages.sh)

# 3. Windows: fonts + Typst packages + "Send to" shortcut
./scripts/install.ps1
```

`install.sh` / `install.ps1` are idempotent and can be controlled individually:

```bash
bash scripts/install.sh             # tool + fonts + packages + right-click integration
bash scripts/install.sh --uninstall # remove only the right-click integration
```

```powershell
./scripts/install.ps1             # tools + fonts + packages + "Send to" shortcut
./scripts/install.ps1 -Tools      # only typst via winget
./scripts/install.ps1 -Fonts      # only load fonts into the project (./fonts)
./scripts/install.ps1 -Packages   # only load Typst packages (./vendor)
./scripts/install.ps1 -SendTo     # only create the shortcut
./scripts/install.ps1 -Uninstall  # remove the shortcut
```

## Update

**Easiest way:** run the same bootstrap one-liner again — it detects the existing installation
and updates it (`git pull --ff-only` + installer).

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.ps1 | iex
```

Alternatively, manually in the install folder:

```bash
cd ~/.local/share/real-fast-document   # or the chosen install path
git pull --ff-only                     # fetch the latest version
bash scripts/install.sh                # refresh fonts/packages/integration if needed
```

On Windows, after `git pull --ff-only` re-run `./scripts/install.ps1` if needed.

## Usage

### macOS / Linux

```bash
bash scripts/build.sh                 # example.md  -> example.pdf
bash scripts/build.sh document.md     # document.md -> document.pdf
bash scripts/build.sh in.md out.pdf   # explicit output
```

Without a second argument the output lands next to the source. If a `date` is set in the
frontmatter, the file automatically gets an ISO prefix (`2026-06-19_document.pdf`).

After a successful build the PDF is opened automatically in the default viewer (terminal and
right-click, all three systems). For batch/cron runs this can be disabled with the environment
variable `RFD_NO_OPEN=1`.

### Without a terminal (right-click)

After setup, a right-click entry is available on all three systems; the PDF/A lands next to the
source each time:

- **Windows:** select `.md` → right-click → **Send to → "Nach PDF-A (real-fast-document)"**
- **macOS:** right-click `.md` → **Services / Quick Actions → "Nach PDF-A (real-fast-document)"**
- **Linux:** right-click `.md` → **Open with → "Nach PDF-A (real-fast-document)"**

## Frontmatter (optional)

A YAML block at the start of the file controls individual documents. All keys are optional:

```yaml
---
title: "My Document"    # centered title block on top + title in the header from page 1
date: 2026-06-19        # ISO date: filename prefix + date bottom right (per language)
toc: true               # force (true) / suppress (false) the table of contents
h1-break: false         # force / suppress the chapter page break (before each # H1)
print_filename: false   # hide the filename bottom left (default: true)
lang: de                # document language (date format); default de
header: "Confidential"  # fixed header text from page 1 (overrides the running header)
watermark: "DRAFT"      # diagonal watermark beneath everything
---
```

| Key | Values | Effect |
|-----|--------|--------|
| `title` | text | **Document title**: centered title block on top, additionally in the header from page 1, and the PDF/A metadata title. Without `title` the metadata title stays the filename and there is no title block. |
| `date` | ISO date | Set → output file gets the ISO prefix `YYYY-MM-DD_name.pdf` **and** the date appears bottom right, localized per `lang` (de "19. Juni 2026", en "June 19, 2026"). The footer then becomes 3-column (name · page centered · date). |
| `toc` | `true` / `false` | Force / suppress the table of contents. Without it the structure automatism applies (see below). |
| `h1-break` | `true` / `false` | Force / suppress the chapter page break (before each `# H1`). Without it the same automatism applies, independently of `toc`. |
| `print_filename` | `true` / `false` | Show the filename bottom left. Default `true`. |
| `lang` | language code | Document language and date format (`de`, `en`, …). Default `de`. |
| `header` | text | Fixed header text from **page 1**; overrides the running header (and the title in the header). |
| `watermark` | text | Diagonal, letter-spaced watermark (bold, light gray) on every page, **beneath** all other elements. |

**Header — precedence top to bottom:** (1) `header:` fixed text from page 1; else (2) the active
`# H1` chapter as a running header; before that, prior to the first chapter, (3) the **title**
(`title:`) if set. Always in sans.

**Structure automatism:** without an explicit setting, the heuristic `#H1 + #H2 > 5` decides.
With **more than five** chapter/subsection headings the document switches to *structured mode*:
a table of contents (H1 + H2 only) appears after the title **and** each chapter (`# H1`) starts on
a new page. With **five or fewer** it stays *compact* — no TOC, chapters run inline. `toc` and
`h1-break` toggle these two effects **individually and independently** (`true` forces, `false`
suppresses).

The boolean keys (`toc`, `h1-break`, `print_filename`) accept all YAML 1.1 spellings, regardless
of case: `true`/`false`, `yes`/`no`, `on`/`off` (as well as `"true"` in quotes). An unrecognized
value is ignored with a warning and the default applies.

## Markdown — quick start

Markdown covers almost everything day to day: `*italic*`, `**bold**`, `` `inline-code` ``,
bullet lists, numbered lists, task lists (`- [ ]`), tables, quotes, footnotes, definition lists
and `[links](https://typst.app)` work out of the box. Code blocks are set with syntax
highlighting, formulas (`$…$`, `$$…$$`) via LaTeX syntax.

**Images:** `![caption](path.svg)` is set as a numbered figure with a caption. Local images are
embedded; relative paths are **relative to the document**. **Remote images** (`http(s)://`,
protocol-relative `//host`, `data:`) cannot be loaded offline — Typst deliberately has no network
access — and are therefore dropped automatically; the build reports how many images were skipped.

The **document title** comes from the frontmatter (`title:`), not from the Markdown. `# H1` is the
top-level **chapter** (fine line, page break with `h1-break`, runs in the header); `## H2` and
`### H3` are subsections, and from `#### H4` on only bold and left-aligned.

```markdown
---
title: "Document title"
---

# First chapter

Body text with **emphasis** and a footnote.[^1]

## Subsection

- Item one
- Item two

[^1]: The footnote appears at the bottom of the page.
```

## Layout specification

| Aspect | Value |
|--------|-------|
| Format | A4 portrait |
| Margins | left 30 mm · top/bottom/right 20 mm each |
| PDF standard | PDF/A-3b, fonts embedded, source as attachment |
| **Title** | from `title:` — centered on top (serif) + in the header from page 1; not a heading, not in the TOC |
| **H1** | **Chapter** (serif, fine line right below); starts on a new page with `h1-break` and runs in the header |
| **H2 / H3** | subsections (serif, no line); from **H4** on only bold + left-aligned |
| Header | `header:` fixed text · else active H1 chapter · before the 1st chapter the title. Text in **sans** |
| **TOC** | conditional: from `#H1 + #H2 > 5` → table of contents (H1 + H2 only) + chapter per new page; overridable via `toc`/`h1-break` |
| Header right | logo (`logo.svg` → `.png` → `.jpg`), height 13 mm — **optional** |
| Footer | **sans**; without date: name left · page right. With date: name left · page centered · date right |
| Headings | **Source Serif 4**, `luma(8%)`, left-aligned, no bars; **only H1** carries a fine hairline right below, all others are set apart by size/spacing |
| Watermark | optional (`watermark:`): diagonal, letter-spaced, bold, light gray (single-channel gray → clean K in print), **beneath** everything |
| Body text | Source Sans 3, 12 pt, justified with hyphenation, `luma(13%)` |
| Tables | full width; header centered + bold with a line below; light row zebra, vertical separators, no horizontal row lines |
| Code | Source Code Pro, 10 pt, with syntax highlighting |
| Lists | unordered: small square at **all** levels; ordered: numbers; tasks (`- [ ]`): box ☐ open / ☒ done |
| Images | local: numbered figure with caption; remote (`http(s)`, `//host`, `data:`) removed automatically offline |
| Quotes | indented on both sides (narrower than the text block) + italic |
| Emoji/symbols | per-glyph fallback: Noto Emoji + Noto Sans Symbols 2 (monochrome, only for characters without a Source glyph) |

### Typography (font sizes)

| Element | Font | Size |
|---------|------|------|
| Body text | Source Sans 3 | 12 pt |
| Title (`title:`) | Source Serif 4 semibold | 21 pt, centered |
| Chapter (H1) | Source Serif 4 Book (`wght` 450) | 18 pt, fine line below |
| H2 / H3 | Source Serif 4 Book (`wght` 450) | 15 / 13 pt, no line |
| H4+ | Source Serif 4 bold | 12 pt, left-aligned |
| TOC title "Inhalt" | Source Serif 4 semibold | 16 pt |
| TOC entries (H1 + H2) | Source Sans 3 (`wght` 450) | 12 pt, uniform line spacing |
| Header (text) | Source Sans 3 (`wght` 450) | 13 pt |
| Caption | Source Sans 3 | 10 pt |
| Code | Source Code Pro | 10 pt |
| Footer | Source Sans 3 | 9 pt |

## Structure

```
template.typ                Typst template: page layout + calls cmarker on the source
scripts/build.sh            pipeline Markdown -> PDF/A (macOS/Linux), frontmatter + preprocessing
scripts/convert.ps1         Windows converter (called from "Send to")
scripts/fetch-fonts.sh      bundles the variable Source fonts into ./fonts
scripts/fetch-typst-packages.sh  vendors cmarker + mitex into ./vendor (offline)
scripts/bootstrap.sh        one-liner installer (macOS/Linux): clones + runs install.sh
scripts/bootstrap.ps1       one-liner installer (Windows): clones + runs install.ps1
scripts/install.sh          macOS/Linux setup: tool + fonts + packages + right-click
scripts/install.ps1         Windows setup: tool + fonts + packages + "Send to"
scripts/rfd-convert.sh      converter dispatcher of the right-click integration (macOS/Linux)
fonts/                      Source OTF (Serif 4 / Sans 3 / Code Pro) + Noto fallbacks (git-ignored)
vendor/                     vendored Typst packages cmarker + mitex (git-ignored)
logo.svg                    header logo (optional)
assets/pipeline.svg         local example figure for example.md
example.md                  full example/probe file (all elements, documented frontmatter)
```

## Customizing

- **Frontmatter** controls individual documents (date, TOC, break, filename, language) — see above.
- **Logo / filename / date / title** are passed as Typst `--input` at compile time
  (`scripts/build.sh`) and read in the template via `sys.inputs`. The logo is chosen in the order
  `logo.svg` → `logo.png` → `logo.jpg`; if missing, the pipeline continues with a note. Logo
  height in the template via `logo-height`.
- **Margins, fonts, colors, font sizes** are collected at the top of `template.typ`
  (`#set page`, `#set text`, `head-color`, `heading-text`).
- **Different PDF/A level**: change `standard` in `scripts/build.sh` (`a-1b`, `a-2b`, `a-3b`).
  Embedding the source requires `a-3b`.
- **Source as attachment**: the Markdown file is embedded into the PDF via `pdf.attach` and can be
  extracted again, e.g. with `mutool extract file.pdf`.
- **Package versions**: cmarker/mitex are pinned in `scripts/fetch-typst-packages.sh` and
  `scripts/install.ps1`; to update, bump the version there and re-vendor.

## Versioning

[CalVer](https://calver.org/) in the format `YY.M.MICRO` — see `VERSION` and
[CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE). The bundled fonts under `fonts/` are licensed under the SIL Open
Font License 1.1 (see [fonts/README.md](fonts/README.md)). The vendored packages under `vendor/`
carry their own licenses (cmarker: MIT, mitex: Apache-2.0).
