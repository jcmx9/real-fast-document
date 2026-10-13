# real·fast·document

[Deutsch](README.md) · **English**

[![CI](https://github.com/jcmx9/real-fast-document/actions/workflows/ci.yml/badge.svg)](https://github.com/jcmx9/real-fast-document/actions/workflows/ci.yml)

> Turn a Markdown file into an archival, consistently styled **PDF/A-3b** —
> no word processor, no manual layout.

Markdown → **Typst** (packages **cmarker** + **mitex** + **mmdr**) → **PDF/A** with a fixed corporate
layout: A4 portrait, running header with chapter and logo, footer with filename, page count
and optional date. The Markdown source is embedded into the PDF. **No Pandoc required** — the
entire conversion runs in Typst.

## Prerequisites

- [typst](https://typst.app) ≥ 0.15 (PDF/A export + variable fonts — the `wght` axis provides
  the semibold heading weight; `build.sh` aborts below 0.15)
- [git](https://git-scm.com) for cloning

The Typst packages **cmarker** (Markdown → Typst), **mitex** (math) and **mmdr** (Mermaid diagrams) as well as the fonts are
placed into the project offline by the installer (`vendor/`, `fonts/`) — no registry access at
build time.

## Installation & update

The only prerequisite is **git**. **One command installs — the same command updates.**

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.ps1 | iex
```

On the first run the command clones the project into `~/.local/share/real-fast-document`
(Windows: `%LOCALAPPDATA%\real-fast-document`), installs typst, downloads fonts and Typst
packages and sets up the right-click entry and the terminal command `rf-document`. Every further
run updates the installation (`git pull --ff-only`, then the same setup; fonts and packages that
are already present are not downloaded again).

typst comes from the system package manager (Homebrew / apt / dnf / pacman / winget). If it is
missing there or older than 0.15 (common on Linux), the installer downloads the official typst
binary into `./bin` and uses it automatically.

### Manual (for development)

```bash
git clone https://github.com/jcmx9/real-fast-document.git
cd real-fast-document
bash scripts/install.sh      # Windows: ./scripts/install.ps1
```

## Uninstall

One command removes the right-click entry, the terminal command `rf-document` **and** the install
folder (program, fonts, packages, logo — back up a custom logo first). typst stays, it belongs to
the package manager.

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.sh | bash -s -- --uninstall
```

**Windows (PowerShell):**

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/jcmx9/real-fast-document/main/scripts/bootstrap.ps1))) -Uninstall
```

## Usage

### macOS / Linux

```bash
bash scripts/build.sh                 # example.md  -> example.pdf
bash scripts/build.sh document.md     # document.md -> document.pdf
bash scripts/build.sh in.md out.pdf   # exactly this output path
bash scripts/build.sh --no-source a.md # without embedded source
bash scripts/build.sh --hard-breaks a.md  # every line stays a line
bash scripts/build.sh --help          # options + keys
bash scripts/build.sh --version       # show versions
```

Without a second argument the output lands next to the source. If a `date` is set in the
frontmatter, the file automatically gets an ISO prefix (`2026-06-19_document.pdf`);
`isodate_praefix: false` disables that prefix (the date stays in the footer). An explicitly
given output path is written exactly as given, without a prefix.

**Calling from other programs** (e.g. as a Zettlr export target): the exit code is 0 only on
success; errors and warnings go briefly to stderr. `build.sh` finds Typst even with a minimal
`PATH` (GUI apps) because it loads the Typst folder recorded by the installer itself. Relative
paths (source, output) are relative to the calling directory, images and logo relative to the
note.

The global command understands the same options: `rf-document --help` or `rf-document --version`
(`-h` / `-V` as short forms). On Windows also as a PowerShell switch: `rf-document -Help` or
`rf-document -Version`.

| Option | Description |
|--------|-------------|
| `--hard-breaks` | Every line stays a line, as typed in the editor; same as `hard_breaks: true` |
| `--no-source` | Do **not** embed the Markdown source in the PDF (e.g. for client PDFs); same as `embed_source: false` |
| `--version`, `-V` | Print rf-document and Typst version, then exit |
| `--help`, `-h` | Print help (options, frontmatter keys, environment variables), then exit |

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

A YAML block at the start of the file controls individual documents. All keys are optional.
**[`header.md`](header.md)** is a template with every key, its default value and a comment
(comments in German) — copy and adapt it:

```yaml
---
title: "My Document"    # centered title block on top + title in the header from page 1
subtitle: "Workshop"    # subtitle below the title
client: "Example Ltd"   # client: small and letter-spaced above the title
author: "Ben Probe"     # author(s) below the title: "date · author"
date: 2026-06-19        # date (ISO or 19.06.2026): filename prefix + date bottom right
isodate_praefix: false  # disable the ISO filename prefix (default: on when date is set)
toc: true               # force (true) / suppress (false) the table of contents
h1_break: false         # force / suppress the chapter page break (before each # H1)
print_filename: false   # hide the filename bottom left (default: true)
lang: de                # document language (date format); default de
header: "Confidential"  # fixed header text from page 1 (overrides the running header)
watermark: "DRAFT"      # diagonal watermark beneath everything
logo: client-logo.png   # logo for this document only (relative to the note or absolute)
logo-height: 15mm       # maximum logo height (absolute lengths only; default 13mm, max 25mm)
embed_source: false     # do not embed the Markdown source (default: true)
hard_breaks: true       # every line stays a line (default: false)
---
```

| Key | Values | Effect |
|-----|--------|--------|
| `title` | text | **Document title**: centered title block on top, additionally in the header from page 1, and the PDF/A metadata title. Without `title` the metadata title stays the filename and there is no title block. |
| `subtitle` | text | Subtitle below the title. |
| `client` | text | Client/company, small and letter-spaced above the title. |
| `author` | text or `[A, B]` | Line below the title: "date · author" (only what is set). |
| `date` | ISO or `D.M.YYYY` | Set → output file gets the ISO prefix `YYYY-MM-DD_name.pdf`, the date appears bottom right, localized per `lang` (de "19. Juni 2026", en "June 19, 2026"), **and** it is set as the reproducible PDF metadata date (`CreateDate`). The footer then becomes 3-column (name · page centered · date). Without `date` the metadata date carries the **source file's modification time** (not the build moment); a set `SOURCE_DATE_EPOCH` wins. |
| `isodate_praefix` | `true` / `false` | Controls only the ISO prefix on the **filename**. Without it a set `date` prefixes automatically (backward-compatible); `false` disables the prefix without touching the date in the footer. No effect without `date`. |
| `toc` | `true` / `false` | Force / suppress the table of contents. Without it the structure automatism applies (see below). |
| `h1_break` | `true` / `false` | Force / suppress the chapter page break (before each `# H1`). Without it the same automatism applies, independently of `toc`. |
| `print_filename` | `true` / `false` | Show the bottom-left entry (filename or "client · title", see below). Default `true`. |
| `lang` | language code | Document language, date format and labels (Seite/Page, Inhalt/Contents, …): `de`, `en`, …. Default `de`. |
| `header` | text | Fixed header text from **page 1**; overrides the running header (and the title in the header). |
| `watermark` | text | Diagonal, letter-spaced watermark (bold, light gray) on every page, **beneath** all other elements. |
| `logo` | path | Logo **for this document only** (PNG/JPG/SVG), relative to the note or absolute; `~`, `$VAR`, `${VAR}` and `%VAR%` are expanded. Overrides the global logo. If the file is missing, the build warns and uses the global logo. |
| `logo-height` | length | Maximum logo height, absolute lengths only (`15mm`, `1.2cm`, `40pt`); anything else is ignored. The logo keeps its proportions and is at most 60 mm wide. |
| `hard_breaks` | `true` / `false` | Every line break in the source stays a line break (as typed in Zettlr/Obsidian). Default `false`: a single break becomes a space, as in CommonMark. |
| `embed_source` | `true` / `false` | Embed the Markdown source as an attachment. Default `true`; `false` (or `--no-source`) for PDFs that must not contain the note. |

Empty values (`subtitle: ""` or just `subtitle:`) are ignored, never an error.

**Footer left:** the filename — as soon as `client` or `subtitle` is set, instead at most two of
client, title and subtitle in this order ("client · title", without client "title · subtitle").

**Header — precedence top to bottom:** (1) `header:` fixed text from page 1; else (2) the active
`# H1` chapter as a running header; before that, prior to the first chapter, (3) the **title**
(`title:`) if set. Always in sans.

**Structure automatism:** without an explicit setting, the heuristic `#H1 + #H2 > 5` decides.
With **more than five** chapter/subsection headings the document switches to *structured mode*:
a table of contents (H1 + H2 only) appears after the title **and** each chapter (`# H1`) starts on
a new page. With **five or fewer** it stays *compact* — no TOC, chapters run inline. `toc` and
`h1_break` toggle these two effects **individually and independently** (`true` forces, `false`
suppresses).

The boolean keys (`isodate_praefix`, `toc`, `h1_break`, `print_filename`, `embed_source`, `hard_breaks`) accept all YAML 1.1 spellings, regardless
of case: `true`/`false`, `yes`/`no`, `on`/`off` (as well as `"true"` in quotes); `toc` and
`h1_break` also accept `auto` (= the automatism). An empty value is ignored silently, an
unrecognized one with a warning — in both cases the default applies. Comments (`# …`) may stand
on their own lines and after values.

## Markdown — quick start

Markdown covers almost everything day to day: `*italic*`, `**bold**`, `` `inline-code` ``,
bullet lists, numbered lists, task lists (`- [ ]`), tables, quotes, footnotes, definition lists
and `[links](https://typst.app)` work out of the box. Code blocks are set with syntax
highlighting, formulas (`$…$`, `$$…$$`) via LaTeX syntax. Headings and lists also work without a
blank line before them.

**In addition to CommonMark:**

| Input | Result |
|-------|--------|
| `==text==` | Highlight (yellowish background) |
| `> [!NOTE]` … `[!CAUTION]`, `> [!INFO]`, `[!TIPP]`, `[!WICHTIG]`, `[!HINWEIS]`, `[!ACHTUNG]` | Callout box (Info, Tipp, Wichtig, Hinweis, Achtung; English with `lang: en`), never split across pages |
| list of only `- [ ] Task – Name, due date` | Table *Task · Owner · Due · Status* (`bis`/`due`/`by`); columns empty everywhere are dropped |
| mixed list with `- [ ]` / `- [x]` | Box instead of the bullet, aligned with the bullets |
| `18. Oktober 2026` at line start | stays a date, not a numbered list (month names de/en, also abbreviated) |
| `<!-- pagebreak -->`, `\newpage` (own line) | Page break |
| `„…“`, `‚…‘`, `»…«`, `"…"` | Quotes stay exactly as typed (no automatic replacement) |

Snippet template for tasks: `- [ ] ${1:Task} – ${2:Name}, due ${3:Date}$0`

**Images:** `![caption](path.svg)` is set as a numbered figure with a caption; a trailing
`{width=50%}` (also `8cm`, `80mm`, `300px`) sets the width. Local images are embedded; relative
paths are **relative to the document**, absolute ones work too, and `~`, `$VAR`, `${VAR}` and
`%VAR%` are expanded (`USER`↔`USERNAME`, `HOME`↔`USERPROFILE` as fallback). A **missing image
never aborts the export**: the PDF shows "[Image missing: path]" in italics (German: "Bild
fehlt"), stderr a warning. On Windows only images on the install drive are reachable. **Remote images** (`http(s)://`,
protocol-relative `//host`, `data:`) cannot be loaded offline — Typst deliberately has no network
access — and are therefore dropped automatically; the build reports how many images were skipped.

**Diagrams:** a ` ```mermaid ` code block is drawn offline (Typst package **mmdr**, no
network), in calm colors and with the variable Source Sans 3. Broken syntax does not abort the
export.

The **document title** comes from the frontmatter (`title:`), not from the Markdown. `# H1` is the
top-level **chapter** (fine line, page break with `h1_break`, runs in the header); `## H2` and
`### H3` are subsections (`###` at body size, finely underlined); `#### H4` and deeper italic at body size.

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
| **Title** | from `title:` — centered on top (serif) + in the header from page 1; not a heading, not in the TOC. Optionally the client above (small, letter-spaced), subtitle and "date · author" below |
| **H1** | **Chapter** (serif, fine line right below); starts on a new page with `h1_break` and runs in the header |
| **H2 / H3** | subsections (serif, no line); **H3** finely underlined, **H4** and deeper italic, both at body size |
| Header | `header:` fixed text · else active H1 chapter · before the 1st chapter the title. Text in **sans** |
| **TOC** | conditional: from `#H1 + #H2 > 5` → table of contents (H1 + H2 only) + chapter per new page; overridable via `toc`/`h1_break` |
| Header right | logo (`logo:` per document, else `logo.svg` → `.png` → `.jpg`), fitted proportionally into 13 mm × 60 mm (`logo-height`) — **optional** |
| Footer | **sans**; without date: name left · page right. With date: name left · page centered · date right. Name = filename or "client · title" |
| Headings | **Source Serif 4**, `luma(8%)`, left-aligned, no bars; **only H1** carries a fine hairline right below, all others are set apart by size/spacing |
| Watermark | optional (`watermark:`): diagonal, letter-spaced, bold, light gray (single-channel gray → clean K in print), **beneath** everything |
| Body text | Source Sans 3, 11 pt, `wght` 380, old-style figures, justified with hyphenation (line spacing 0.85em), `luma(13%)`; **bold** = 560 (`strong.delta` 180) |
| Tables | **column widths by content** (like HTML tables): if everything fits, the table keeps its content width; otherwise every column gets at least its longest word and text-heavy columns get the rest. Number/amount columns right-aligned, alignment from the separator row (`:--`, `--:`, `:-:`) wins; equal-width lining figures; ragged right; header centered + bold with a line below; light row zebra, vertical separators, no horizontal row lines; **header row repeats** across page breaks |
| Code | Source Code Pro, 10 pt, with syntax highlighting |
| Lists | unordered: small square at **all** levels; ordered: numbers; tasks (`- [ ]`): drawn box (done: filled dark with a white check mark), aligned with the bullets; task-only lists as a table (Task 56 % · Owner 20 % · Due 14 % · Status 10 %) |
| Callouts | light fill, 2.5 pt bar on the left, small letter-spaced uppercase title; colors: Info `#2f6aa8`, Tip `#3b7d3a`, Important `#7a4fb0`, Warning `#b05a1a`, Caution `#b5452b` |
| Images | local: numbered figure with caption, width via `{width=…}`; missing: "[Image missing: path]" instead of an abort; remote (`http(s)`, `//host`, `data:`) removed automatically offline |
| Diagrams | ` ```mermaid ` offline via mmdr, centered, fills `#f4f2ee`, borders `#b9b2a6`, lines `#6b6b6b`, text `#2b2b2b`, notes `#fbeab0`; labels in Source Sans 3 (variable, Medium) |
| Quotes | indented on both sides (narrower than the text block) + italic |
| Emoji/symbols | per-glyph fallback: Noto Emoji + Noto Sans Symbols 2 (monochrome, only for characters without a Source glyph) |
| Break protection | headings never alone at a page foot (sticky); figure + caption stay together; orphans/widows/runts avoided (`costs`); **non-breaking spaces** in German abbreviations (z. B., d. h., u. a., …) and between number + unit/percent/currency (12 pt, 5 %, 1.234,56 €) |

### Typography (font sizes)

| Element | Font | Size |
|---------|------|------|
| Body text | Source Sans 3 (`wght` 380), bold 560 | 11 pt, line spacing 0.85em |
| Title (`title:`) | Source Serif 4 (`wght` 470) | 18 pt, centered |
| Chapter (H1) | Source Serif 4 (`wght` 470) | 15 pt, fine line below |
| H2 | Source Serif 4 (`wght` 470) | 13 pt, no line |
| H3 | Source Serif 4 (`wght` 380) | 11 pt, finely underlined |
| H4+ | Source Serif 4 (`wght` 380) italic | 11 pt |
| TOC title "Inhalt" | Source Serif 4 (`wght` 470) | 15 pt |
| TOC entries (H1 + H2) | Source Sans 3 (`wght` 380) | 12 pt, uniform line spacing |
| Header (text) | Source Sans 3 (`wght` 380) | 13 pt |
| Caption | Source Sans 3 | 10 pt |
| Code | Source Code Pro | 10 pt |
| Footer | Source Sans 3 | 9 pt |

## Structure

```
template.typ                Typst template: page layout + calls cmarker on the source
lib/markdown.typ            Markdown preprocessing in Typst (identical on all systems)
scripts/build.sh            pipeline Markdown -> PDF/A (macOS/Linux): frontmatter, paths, invocation
scripts/test-pdf.sh         end-to-end tests: builds tests/fixtures/*.md and checks the PDF text
scripts/convert.ps1         Windows converter (called from "Send to")
scripts/fetch-fonts.sh      bundles the variable Source fonts into ./fonts
scripts/fetch-typst-packages.sh  vendors cmarker + mitex + mmdr into ./vendor (offline)
scripts/bootstrap.sh        one-liner installer (macOS/Linux): clones + runs install.sh
scripts/bootstrap.ps1       one-liner installer (Windows): clones + runs install.ps1
scripts/install.sh          macOS/Linux setup: tool + fonts + packages + right-click
scripts/install.ps1         Windows setup: tool + fonts + packages + "Send to"
scripts/rfd-convert.sh      converter dispatcher of the right-click integration (macOS/Linux)
fonts/                      variable Source OTF (Serif 4 / Sans 3 / Code Pro) + Noto fallbacks
vendor/                     vendored Typst packages cmarker + mitex + mmdr (git-ignored)
logo.svg                    header logo (optional)
assets/pipeline.svg         local example figure for example.md
example.md                  full example/probe file (all elements, documented frontmatter)
header.md                   frontmatter template: every key with its default value and a comment
tests/fixtures/             test notes (one per feature, plus edge cases)
```

**Tests:** `bash scripts/test-pdf.sh` builds all test notes and checks the PDFs' text and the
interface (exact output path, exit codes, embedded source, minimal `PATH`). Requires `pdftotext`
(poppler) or `mutool` (mupdf). CI runs the tests on every push.

## Customizing

- **Frontmatter** controls individual documents (date, TOC, break, filename, language) — see above.
- **Filename / date / title** are passed as Typst `--input` at compile time
  (`scripts/build.sh`) and read in the template via `sys.inputs`.
- **Swapping the logo:** the global logo lives **in the install folder** and applies to **all**
  documents; a single document can set its own via `logo:` in the frontmatter. Default paths after the quick install:
  - macOS / Linux: `~/.local/share/real-fast-document/logo.svg`
  - Windows: `%LOCALAPPDATA%\real-fast-document\logo.svg`

  If unsure of the install path, the installed command reveals it:

  ```bash
  cat "$(command -v rf-document)"                                  # macOS / Linux
  ```

  ```powershell
  type "$env:LOCALAPPDATA\Microsoft\WindowsApps\rf-document.cmd"   # Windows
  ```

  The **first existing** of `logo.svg` → `logo.png` → `logo.jpg` is chosen; replace the
  existing file (or remove the other formats). If no logo is present, the pipeline continues
  with a note. Maximum height per document via `logo-height:`.
- **Margins, fonts, colors, font sizes** are collected at the top of `template.typ`
  (`#set page`, `#set text`, `head-color`, `heading-text`).
- **Different PDF/A level**: change `standard` in `scripts/build.sh` (`a-1b`, `a-2b`, `a-3b`).
  Embedding the source requires `a-3b`.
- **Source as attachment**: the Markdown file is embedded into the PDF via `pdf.attach` (under its
  file name, without a local path) and can be extracted again, e.g. with `mutool extract file.pdf`.
  Disable with `--no-source` or `embed_source: false`.
- **Package versions**: cmarker/mitex/mmdr are pinned in `scripts/fetch-typst-packages.sh` and
  `scripts/install.ps1`; to update, bump the version there and re-vendor.

## Versioning

[CalVer](https://calver.org/) in the format `YY.M.MICRO` — see `VERSION` and
[CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE). The bundled fonts under `fonts/` are licensed under the SIL Open
Font License 1.1 (see [fonts/README.md](fonts/README.md)). The vendored packages under `vendor/`
carry their own licenses (cmarker: MIT, mitex: Apache-2.0, mmdr: MIT).
