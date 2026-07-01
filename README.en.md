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
date: 2026-06-19        # ISO date: filename prefix + date bottom right (per language)
toc: true               # force (true) / suppress (false) the table of contents
h2-break: false         # force (true) / suppress (false) the chapter page break
print_filename: false   # hide the filename bottom left (default: true)
lang: de                # document language (date format); default de
---
```

| Key | Values | Effect |
|-----|--------|--------|
| `date` | ISO date | Set → output file gets the ISO prefix `YYYY-MM-DD_name.pdf` **and** the date appears bottom right, localized per `lang` (de "19. Juni 2026", en "June 19, 2026"). The footer then becomes 3-column (name · page centered · date). |
| `toc` | `true` / `false` | Force / suppress the table of contents. Without it the structure automatism applies (see below). |
| `h2-break` | `true` / `false` | Force / suppress the chapter page break. Without it the same automatism applies, independently of `toc`. |
| `print_filename` | `true` / `false` | Show the filename bottom left. Default `true`. |
| `lang` | language code | Document language and date format (`de`, `en`, …). Default `de`. |

**Structure automatism:** without an explicit setting, the heuristic `#H2 + #H3 > 5` decides.
With **more than five** chapter/subsection headings the document switches to *structured mode*:
a table of contents appears after the title **and** each chapter (`## H2`) starts on a new page.
With **five or fewer** it stays *compact* — no TOC, chapters run inline. `toc` and `h2-break`
toggle these two effects **individually and independently** (`true` forces, `false` suppresses),
so e.g. a table of contents without a chapter page break is possible.

The boolean keys (`toc`, `h2-break`, `print_filename`) accept all YAML 1.1 spellings, regardless
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

A `# H1` is set as the centered **document title** (not in the header/TOC). It is optional and not
limited to one; the PDF/A metadata title is the filename. Chapters start at `## H2` and run along
the left of the page header; `### H3` and below are subsections.

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
| Format | A4 portrait |
| Margins | left 30 mm · top/bottom/right 20 mm each |
| PDF standard | PDF/A-3b, fonts embedded, source as attachment |
| **H1** | **Document title** — centered, opens the document (optional, not in header/TOC) |
| **H2** | **Chapter** — the current chapter runs dynamically in the header left |
| **TOC** | conditional: from `#H2 + #H3 > 5` → table of contents + chapter per new page; overridable via frontmatter `toc`/`h2-break` |
| Header right | logo (`logo.svg` → `.png` → `.jpg`), height 13 mm — **optional** |
| Footer | without date: name left · page right. With date: name left · page centered · date right |
| Headings | Source Sans 3 (sans-serif), `luma(8%)`; H2 with a 3 pt accent bar on the left + a fine full-width hairline, H3+ with a thinner 2 pt bar + shorter hairline (`luma(20%)`, 80 % gray) |
| Body text | Source Sans 3, 12 pt, justified with hyphenation, `luma(13%)` |
| Code | Source Code Pro, 10 pt, with syntax highlighting |
| Lists | unordered: small square at **all** levels; ordered: numbers; tasks (`- [ ]`): box (empty/filled) |
| Images | local: numbered figure with caption; remote (`http(s)`, `//host`, `data:`) removed automatically offline |
| Quotes | indented on both sides (narrower than the text block) + italic |
| Emoji/symbols | per-glyph fallback: Noto Emoji + Noto Sans Symbols 2 (monochrome, only for characters without a Source glyph) |

### Typography (font sizes)

| Element | Font | Size |
|---------|------|------|
| Body text | Source Sans 3 | 12 pt |
| Title (H1) | Source Sans 3 semibold | 28 pt, centered |
| Chapter (H2) | Source Sans 3 Book (`wght` 450) | 18 pt, 3 pt bar + hairline |
| H3 / H4 / H5 / H6 | Source Sans 3 Book (`wght` 450) | 14.5 / 13 / 12 / 12 pt, 2 pt bar + hairline |
| TOC title "Inhalt" | Source Sans 3 semibold | 16 pt |
| TOC entries | Source Sans 3 | 13 pt, Book (`wght` 450) |
| Header (chapter) | Source Sans 3 Book (`wght` 450) | 13 pt, plain text (no bar) |
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
