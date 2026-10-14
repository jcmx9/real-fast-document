# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A document-rendering pipeline, **not** a Python project — the Python conventions in the
parent `~/GitHub/CLAUDE.md` (uv/ruff/mypy/pytest) do **not** apply here. What does apply
from that file: GitHub Flow branching, CalVer versioning, and Conventional Commits
(English, no AI co-author trailers). Author identity in this repo is `jcmx9`.

**Language split — bilingual by rule, not by accident.** Script *comments* and every *user-facing
CLI string* are **German**: `build.sh`'s `--help` text, its errors (`Error: Typst >= 0.15 nötig`),
the `N Remote-Bild(er) übersprungen` summary, the comments in `template.typ` and the `.ps1` files
(there transliterated to ASCII, see below). **English** are commits, PR titles, `CHANGELOG.md` and
this file. `README.md` is German, `README.en.md` its English parity twin. Match the file you are
editing — a new English error string in `build.sh` breaks the user-facing consistency.

The pipeline turns a Markdown file into a corporate-styled **PDF/A-3b**, entirely in Typst
(**no Pandoc**): `template.typ` is a plain Typst file that renders the body itself via the
**cmarker** package (with **mitex** for math).

```
Markdown → Typst (template.typ → cmarker.render, mitex) → PDF/A-3b
```

> **⚠️ Develop in the repo, never in the install path.** The development repo is
> `~/GitHub/real-fast-document` (keeps `main` + `dev`). `~/.local/share/real-fast-document`
> is a *separate* bootstrap **installation** (only `main`, plus `bin/`/`vendor/` install
> artifacts). All edits, branches, commits, and PRs happen in the `~/GitHub/` repo. Confirm
> before committing: `git -C <dir> remote -v` and the **presence of `bin/rfd-tools.env`** marks
> the install path — if you see it, you are in the wrong place. See *Release flow* for the full note.

## Where to look (wegweiser)

This file is long and dense; jump by task instead of reading top-to-bottom:

- **Changing layout / typography / headings / TOC / watermark** → *Architecture › Heading /
  document model* and the `#set`/`#show` rules in `template.typ`.
- **Touching a `#show` rule (tables, NBSP, raw/code guard)** → *Architecture › Typst show-rule
  traps* first — these cost real debugging and have non-obvious recursion pitfalls.
- **Build flags, frontmatter keys, preprocessing, remote-image skip** → *Architecture*
  (`build.sh`/`convert.ps1` sections) and *Commands*.
- **Install / bootstrap / right-click / `rf-document` CLI / GUI-PATH** → *Architecture ›
  Install / bootstrap*.
- **Verifying a change (PNG render, NBSP visible-marker trick)** → *Commands*.
- **Windows `.ps1` gotchas (ASCII-only, UTF-8 read, Typst path normalization)** →
  *Architecture › Install / bootstrap* and the `convert.ps1` notes.
- **Releasing (branch flow, CalVer, README parity)** → *Release flow*.

## Commands

```bash
bash scripts/build.sh                 # build example.md → example.pdf (next to source)
bash scripts/build.sh SRC.md          # → SRC.pdf  (or DATE_SRC.pdf if frontmatter has date:)
bash scripts/build.sh SRC.md OUT.pdf  # explicit output
bash scripts/build.sh --help          # usage, options, frontmatter keys, env vars (also -h)
bash scripts/build.sh --version       # rf-document version + Typst version (also -V)
RFD_NO_OPEN=1 bash scripts/build.sh SRC.md   # suppress the auto-open (build.sh opens the PDF by default)
bash scripts/fetch-fonts.sh           # download bundled fonts into ./fonts (idempotent: skips if all present; --force to re-fetch)
bash scripts/fetch-typst-packages.sh  # vendor cmarker + mitex into ./vendor (idempotent: skips if vendored at the pinned version; --force)
bash scripts/install.sh               # set up tool + fonts + packages + right-click + rf-document CLI (idempotent)
bash scripts/install.sh --uninstall   # remove the right-click integration + rf-document
bash scripts/bootstrap.sh --uninstall # FULL removal: integration + rf-document + install folder
                                      #   (README one-liner: curl … | bash -s -- --uninstall;
                                      #    Windows: & ([scriptblock]::Create((irm …))) -Uninstall)
rf-document SRC.md                    # global CLI after install (wrapper → build.sh)
TYPST=/path/to/typst bash scripts/build.sh ...       # override the typst binary (e.g. to test a version)
# Lint ALL shell scripts (PowerShell has no runner here — review only).
# This list is duplicated in ci.yml's "Lint shell scripts" step (same seven scripts, different order):
# a NEW script must be added to BOTH, otherwise it is never linted anywhere.
shellcheck scripts/build.sh scripts/fetch-fonts.sh scripts/fetch-typst-packages.sh scripts/install.sh scripts/bootstrap.sh scripts/rfd-convert.sh scripts/test-pdf.sh
bash scripts/test-pdf.sh              # end-to-end tests: build tests/fixtures/*.md, check PDF text + CLI interface
```

**End-to-end tests:** `scripts/test-pdf.sh` builds every note in `tests/fixtures/` through `build.sh`
(from the fixture folder, like Zettlr: cwd = the note's folder) and checks the extracted PDF text
(`pdftotext`, else `mutool`) with `expect`/`expect_compact`/`reject` — `expect_compact` ignores
whitespace because letter-spaced text (`tracking`, e.g. the client line) extracts as `M U S T E R`.
It also checks the interface: exact explicit output (no ISO prefix), prefix from a German date,
exit codes (missing source, unknown option), embedded attachment name / `--no-source` /
`embed_source: false` (via `mutool show … trailer/Root/Names/EmbeddedFiles`), and a build under
`env -i PATH=/usr/bin:/bin` (skipped when no `bin/rfd-tools.env`/`bin/typst` exists, e.g. in CI).
**Every new feature gets a fixture + assertions here.** Layout is still checked **visually**
(render pages to PNG and inspect).
**CI gates builds**: `.github/workflows/ci.yml` (push/PR on `main`/`dev`) installs Typst
`0.15.0` on Linux, fetches fonts + vendors the packages, `shellcheck`s the scripts, runs
`scripts/test-pdf.sh` (installs `poppler-utils` + `mupdf-tools` for it), then builds
`example.md`, `README.md` **and** `README.en.md` and asserts each is PDF/A part 3. A clean CI run
already proves no compile error, no missing-glyph abort, and PDF/A-3b conformance — the README builds
also exercise the date-less `SOURCE_DATE_EPOCH` metadata path. CI can't catch *visual* regressions
(layout, spacing) — those still need the PNG eyeball loop below.
`example.md` (the default build target) is the **feature tour**: one chapter per feature, each in
its variants (title block/header/footer, typography table input→output, headings H1–H5, list
forms, four task-table variants, all ten callout keywords, tables, images with/without caption,
`{width=…}`, a **deliberately missing** image and a remote image, Mermaid, math, code,
definition lists, emoji/symbol fallback, page break). It forces `toc`/`h1_break`, so it also
exercises structured mode. Building it prints one expected warning (`Bild nicht gefunden:
bilder/fehlt.png`) and the remote-skip note. `README.md`/`README.en.md` are organized by feature
(overview → install → usage → frontmatter → Markdown per feature → layout → PDF/A → fonts →
customizing → development) and must keep identical structure; they have no frontmatter (GitHub
would render it), so they build with `lang: de` — write English quotes in `README.en.md` prose as
typed “…” or the typography step would set German „…“. Never write a bare `--` in README prose
(it becomes –); options always in backticks. Use it to eyeball layout changes; its `*.pdf` is
git-ignored.

To render PNGs directly, compile `template.typ` with the same inputs `build.sh` passes (the
Markdown preprocessing runs inside the template, so `source=` is the original `.md`; absolute
paths because of `--root /`):

```bash
typst compile template.typ --root / --font-path fonts --ignore-system-fonts \
  --input source=/ABS/SRC.md --input attach= --input docdir=/ABS/SRC_DIR \
  --input filename=OUT.pdf --input title=SRC --input doctitle= --input logo=logo.svg \
  --input date= --input toc=auto --input "h1_break=auto" --input showname=true --input lang=de \
  --input header= --input watermark= \
  --format png --ppi 120 preview-{p}.png
# then open / Read the preview-*.png, then clean up scratch files
# (`preview-*.png` is the git-ignored scratch name — other PNG names show up in `git status`)
```

The simplest path is just `RFD_NO_OPEN=1 bash scripts/build.sh SRC.md` for the PDF, then render
that PDF's pages separately if you need PNGs.

**Verifying a `template.typ` change (the standard loop):**
1. `RFD_NO_OPEN=1 bash scripts/build.sh example.md /tmp/ex.pdf` — `example.md` is the regression
   probe; a clean build (`✓ … PDF/A-3b`) already rules out compile errors and missing-glyph aborts.
2. Find the page that exercises what you touched and eyeball it:
   `mutool draw -F png -r 130 -o /tmp/p{page}.png /tmp/ex.pdf N`, then Read the PNG.
3. **For any change to the NBSP / text-substitution show rules, a text dump is useless** —
   `mutool`/`pdftotext` **normalize U+00A0 back to a plain space**, so an extracted-text diff can't
   tell you whether a rule fired. Use the **visible-marker trick**: temporarily swap the rule's
   `\u{00A0}`/`~` for a visible glyph (e.g. `¤`), render, and read where the marker lands — it must
   appear in body prose but **never** inside a code block (the `#show raw` guard, see below). Revert
   the marker before committing.

`mutool extract FILE.pdf` (mupdf) pulls the embedded Markdown back out; check PDF/A
conformance with `strings FILE.pdf | grep pdfaid` (Typst 0.15 compresses object streams,
so `grep '/Type /EmbeddedFile'` gives false negatives — use `mutool` to confirm attachments).

Locally this is macOS (no Linux/Windows runner); **CI runs the Linux build** (see `ci.yml` above),
but not the **installer** — the **Linux installer** can be validated for real in Docker (mount
read-only, copy inside, run `install.sh`): this is how the install path was verified, and it caught
real bugs. Locally Windows `.ps1` can only be reviewed (no `pwsh`; the `mcr.microsoft.com/powershell`
image crashes under qemu on arm64). **Since 26.10.7 CI has a `windows` job** (`windows-latest`,
`shell: powershell` = **Windows PowerShell 5.1**): it installs Typst from the release zip, runs
`install.ps1 -Fonts -Packages -Cli -Force` and `scripts/test-windows.ps1` (absolute in/out paths with
spaces from a foreign cwd, POSIX options through the `rf-document.cmd` shim, `RFD_BASE_DIR`, exit
codes, `--version`/`-Version`). Still **not** executed anywhere: `install.ps1 -Tools` (winget),
`-SendTo`, `-Uninstall`, and `bootstrap.ps1`. Work dirs in that test must sit on the repo's drive
(`D:` on the runner) — Typst only reads below `--root` = the install drive.

## Requirements & environment gotchas

- **Typst ≥ 0.15 is mandatory** — the project uses variable fonts (the `wght` axis gives the
  semibold heading weight). `build.sh` hard-errors below 0.15. Homebrew may still ship 0.14;
  on this machine a 0.15 binary lives at `~/.local/bin/typst` (earlier in `PATH` than brew).
- **cmarker + mitex are vendored, not fetched from the registry.** `fetch-typst-packages.sh`
  downloads the two package tarballs from `packages.typst.org` into `vendor/cmarker` and
  `vendor/mitex` (both self-contained: own `*.wasm`, only local imports). `template.typ`
  imports them by **relative path** (`#import "vendor/cmarker/lib.typ"`), so builds need no
  network. `vendor/` is git-ignored (like `fonts/`, `bin/`). Versions are pinned in
  `fetch-typst-packages.sh` **and** `install.ps1` — keep them in sync.
- Fonts are **bundled variable OTFs (CFF2)** in `fonts/` (Source Serif 4 / Sans 3 / Code Pro,
  each Roman/Upright + Italic) and used via `--font-path fonts --ignore-system-fonts`
  (reproducible). They come from the **Adobe** upstream releases, fetched by `fetch-fonts.sh`
  (and `install.ps1`): `google/fonts` only ships these families as TTF — variable OTF exist
  only at Adobe. Typst's *embedded* math font still works under `--ignore-system-fonts`, so
  math (via mitex) renders without bundling a math font.
- **Glyph fallback for emoji/symbols** — `fonts/` also bundles two monochrome OFL fonts,
  `Noto Emoji` (variable TTF) and `Noto Sans Symbols 2`, fetched from `google/fonts` (TTF is
  fine — the OTF rule was Source-specific). `template.typ` appends them to every font list
  (`("SourceSans3VF", "Noto Emoji", "Noto Sans Symbols 2")` via `body-font`/`heading-font`/
  `code-font`), so Typst falls back **per glyph**: text stays fully Source, only characters
  Source lacks render from Noto. **Why this matters:** `--ignore-system-fonts` blocks any
  system fallback, and PDF/A-3b *aborts* on a missing glyph (`error: the text "🚀" could not
  be displayed`). Color emoji fonts are not PDF/A-embeddable, so the fallbacks are monochrome
  (which also matches the design). Coverage isn't 100 % — a glyph absent from all three (e.g.
  `⁃` U+2043) still hard-errors; the "Sonderzeichen & Emoji" section of `example.md` doubles
  as a coverage probe.
- **Font-family names differ by family**: the variable OTF expose `Source Serif 4` but
  `SourceSans3VF` and `SourceCodeVF` (internal VF names, *not* "Source Sans 3" / "Source Code
  Pro"). `template.typ` must reference exactly those names. Verify what Typst sees with
  `typst fonts --font-path fonts --ignore-system-fonts`.

## Architecture

- **`template.typ`** owns the entire layout (DIN A4, margins, header/footer, fonts, heading
  rules, TOC, footnotes) **and** renders the body. It is a **plain Typst file** now (not a
  Pandoc template): it reads the original `.md` (`source`), runs it through `preprocess()` from
  **`lib/markdown.typ`**, and after all `#set`/`#show` rules calls `#cmarker.render(prepared.markdown, …)`.
  Runtime values (`filename`, `title` [fallback metadata title = basename], `doctitle` [frontmatter
  `title:`], `logo` [already resolved: per-note or global], `logo_height`, `source`, `attach` [empty =
  don't embed], `docdir`, plus the frontmatter-derived `date`, `subtitle`, `client`, `author`, `toc`,
  `h1_break`, `showname`, `lang`, `header`, `watermark`) are passed as `typst --input` and read via
  `sys.inputs`. The visible title comes **only** from `doctitle` (frontmatter `title:`); a `# …`
  is **always a chapter**, never promoted to the title (the user explicitly rejected Zettlr's
  "leading `# Title` becomes the title" legacy rule). The PDF/A metadata title is `title:`, else the
  basename.
  - **Metadata:** `#set document(title, date, author, description, keywords)` — author list from
    `author:` (split on commas; empty without `author:`), description/Subject = `title:` (empty
    without it — the user wants the title there, not the subtitle), keywords = client + `"real-fast-document "` (repo name, user request) +
    `read("VERSION")`. Typst hard-codes Creator/CreatorTool ("Typst 0.15.0") with no setting; the
    user chose keywords over post-processing the PDF (exiftool/qpdf would risk PDF/A sync).
  - **Attachment name:** `pdf.attach` gets `"/" + basename` **plus the bytes** (`read(…, encoding:
    none)`). With only a path, Typst names the attachment after the root-relative path
    (`Users/<name>/…/note.md` — leaks the local path into client PDFs); a leading `/` makes the name
    root-relative = just the file name (the file need not exist there since the data is given).
  - The **cmarker call** uses `h1-level: 1` (markdown `#` → Typst level-1 heading, styled as a
    *chapter*) and `set-document-title: false` (the PDF/A metadata title comes from `--input title`
    = the frontmatter `title:` or the `.md` basename). `math: mitex`, `task-list-marker:` the drawn
    `task-box` (same `marker-slot` width as the bullet square, so mixed lists align), and `scope:` overrides for `image` (`safe-image`), `divider` (the centered
    `horizontalrule`), and `terms` (`rfd-terms`: builds each term/description pair as plain blocks —
    term bold on its own line, description indented below, unbreakable. A `#show terms.item` rule
    does **not** fire in Typst 0.15, which is why the old approach silently ran term and description
    on one line).
  - **`safe-image`** (in `template.typ`) replaces the old Lua image/link/para/figure dance:
    remote sources (`http(s)://`, protocol-relative `//host`, `data:`) render **nothing** but
    emit an invisible `metadata("rfd-remote-skip")<rfd-remote-skip>` marker for counting; a
    local image with alt text becomes a **numbered figure with caption**; relative paths are
    resolved against `docdir` (the document's directory) so images next to documents anywhere
    on disk are found.
- **Optional YAML frontmatter** (parsed by `build.sh`/`convert.ps1`, then passed via `--input`;
  **empty values are ignored, never an error**):
  `title:` → centered title block + running-header title (from page 1) + PDF/A metadata title;
  `subtitle:`/`client:`/`author:` → title block (client small + letter-spaced above, subtitle and a
  "date · author" line below — that line only appears when `author:` is set; `author: [A, B]` inline
  lists are flattened by `yaml_str`/`ConvertTo-YamlStr`); as soon as `client:` or `subtitle:` is set
  the **footer-left** shows at most two of client/title/subtitle ("Kunde · Titel") instead of the
  filename; `logo:` → per-note logo (expanded by `expand_path`/`Expand-NotePath`: `~`, `${VAR}`,
  `$VAR`, `%VAR%` with USER↔USERNAME / HOME↔USERPROFILE fallback, `%XX` decoding — **no `eval`**;
  relative to the note; missing → warning + global logo); `logo-height:` → absolute lengths only,
  parsed in the template (`logo-max-height`, default **20 mm**, capped at 25 mm), the logo is fitted proportionally into
  height × 60 mm via `measure`; `embed_source:` / CLI `--no-source` → `attach=` empty;
  `date:` (ISO **or** German `T.M.JJJJ`, parsed by `parse-date` in the template and `iso_date`/
  `ConvertTo-IsoDate` in the shells; anything else is shown verbatim and gets no prefix) → ISO-prefixes the output file (`2026-06-19_name.pdf`), shows a
  `lang`-localized date in the footer right, **and** pins the PDF metadata date (`CreateDate`/
  `ModifyDate`) via `#set document(date: <datetime>)` — see *Reproducible metadata date* below;
  `isodate_praefix:` true|false controls **only** the
  filename prefix (default: on when `date:` is set — `false` drops the prefix but keeps the footer
  date; a filename-only knob, never passed to `template.typ`); `toc:`/`h1_break:` true|false
  override the `> 5`
  automatism; `print_filename:` true|false toggles the footer-left name (→ `showname` input);
  `lang:` sets the document language / date format / labels (`labels` dict: Seite/Page,
  Inhalt/Contents; default `de`); `header:` → fixed header text
  (from page 1, overrides the running header); `watermark:` → diagonal page-background watermark.
  The footer is 2-col without a date (name | page) and 3-col with one (name | page centered | date).
  The columns keep an 8 mm `column-gutter`; the left entry is cut to one line by `fit-line`
  (binary search over grapheme clusters with `measure`, ends in "…", trailing separators dropped) —
  the user explicitly wants truncation, **not** wrapping.
  The bool keys are
  parsed **YAML-1.1-tolerant** via `fm_bool`/`Get-FmBool` (case-insensitive `true/false/yes/no/
  on/off`, quotes; `toc`/`h1_break` also `auto`): an **empty value is ignored silently**, an
  unrecognized one warns — both keep the default. String values go through `yaml_str`/
  `ConvertTo-YamlStr`: inside quotes the value ends at the closing quote, otherwise an inline
  `# comment` is cut off (before 26.10.6 a comment leaked into e.g. the title). `header.md` in
  the root is the user-facing template with every key + default + comment; `test-pdf.sh` builds
  it and fails on any `Warnung` — **a new frontmatter key must be added to `header.md` too.** Typst does not localize month names (`[month repr:long]` is English only) → a manual
  `months-de` array lives in `template.typ`; `parse-date` validates the string defensively
  because an invalid `datetime`/`int()` *panics* and aborts the whole build.
- **Reproducible metadata date.** By default Typst (`document.date: auto`) writes the *build moment*
  (date **and** wall-clock time) into the PDF `CreateDate`/`ModifyDate` — so the same source produced
  a different PDF every run. `template.typ` computes `doc-date`: the frontmatter `date:` parsed to a
  `datetime` (`parse-date`) when valid, else `auto`. `#set document(date:
  doc-date)` pins the metadata to the document date. **`date: none` is not an option** — PDF/A-3b
  *requires* a creation date and Typst aborts (`hint: set the date of the document`). For the
  date-less case, `build.sh`/`convert.ps1` export **`SOURCE_DATE_EPOCH`** (from the **source file's
  mtime**, unless the caller already set it) — Typst honours it for `auto`, so even date-less builds
  carry the source's last-modified time, not "now". **Known limit:** full byte-reproducibility still
  fails because Typst 0.15 emits a **random Document/Instance ID (UUID)** per build (base64 in the XMP
  and trailer `/ID`); the timestamp is fixed, the doc ID is not, and Typst 0.15 exposes no knob for
  it. Verify with `exiftool -CreateDate FILE.pdf` (not a text dump).
- **Markdown preprocessing lives in Typst** (`lib/markdown.typ`, imported by the template) — **not**
  in `build.sh`/`convert.ps1` anymore. Rationale: one implementation for all platforms; the
  Windows path (never executed) can't drift. The shells only parse the frontmatter and handle
  paths. `preprocess(src)` works line-wise and skips fenced code (`code-mask`):
  (1) strips the YAML frontmatter (CRLF-tolerant), then in this order: **`pagebreaks`**
  (`<!-- pagebreak -->`/`\newpage`/`\pagebreak`/`\clearpage` alone on a line →
  `<!--raw-typst #pagebreak(weak: true) -->`, cmarker evaluates raw-typst comments),
  **`alerts`** (`> [!KIND]` blockquote → `<rfd-alert kind="…">` block-form HTML; `alert-kinds`
  maps GitHub + German keywords), **`task-tables`** (a list made *only* of `- [ ]`/`- [x]` items,
  no continuation/nested lines → `<rfd-tasks>` with one `<rfd-task done owner due>` per item;
  owner/due from the **last** ` – `/` — `/` - ` and `, bis|due|by …`; mixed lists are copied
  through untouched, including continuation lines), **`date-lines`** (a run of `N. Month …` lines
  where *every* line starts with a month name → `N\.` escaped + `\` hard break between them),
  then (2) converts Pandoc-style definition lists (`Term` / `: def`) to HTML `<dl>` in **block form** (a
  blank line after `<dd>`, so inline markdown renders; inline `<dd>x `code` y</dd>` would show
  literal backticks) and folds indented continuation lines into the `<dd>`. Loose task lists need no
  workaround anymore — cmarker **0.1.10** fixed the `wasm unreachable` crash. Then **`keep-line-breaks`**
  (only with `hard_breaks`: appends `\` to a line when the next line *continues the same
  paragraph* — never before a block start (`block-start-re`: list item, heading, `>`, table,
  fence, `$$`, HTML, setext underline, footnote/deflist), never after a heading/table/HTML line,
  and never inside code or `$$` math (`skip-mask`); a `\` before a new block would print a literal
  backslash) and **`marks`** (`==x==` → `<mark>x</mark>` → cmarker `highlight`, skipping inline
  code by splitting on backticks). The custom tags are rendered by the `html:` callbacks of
  `cmarker.render`: `rfd-alert` builds the box; `rfd-task` returns a `metadata` value and
  `rfd-tasks` collects them from its body (`body.children.filter(c => c.func() == metadata)`) into
  a table with Typst `auto` columns and `table-text` (like every table) that reuses `rfd-table-fill`/`rfd-table-stroke` (the `fill` function is also
  the guard that keeps the general `#show table` rebuild away). cmarker runs with
  **`smart-punctuation: false`** (its automatic replacement put English “…” into German text) — the
  typography is done in `lib/markdown.typ` instead (**`smart-typography`**, runs right after
  `pagebreaks`): `---`→—, `--`→–, `...`→…, straight `"`/`'` → `lang`-dependent quotes (de „…“ ‚…‘,
  otherwise “…” ‘…’; opening vs closing decided by the preceding char, `opener-re`), apostrophe ’
  between letters. Typed typographic quotes are left alone. Skipped: code fences, `$$` math
  (`skip-mask`), inline code (split on backticks), inline `$…$` (split on `$` when the count is
  even), lines starting with `<`, lines containing an HTML tag/comment (attributes like `class="x"`
  must stay straight), rule/separator lines (`rule-line-re`). The user wants `--`/`...` converted
  ("das ist doch gut") and quotes by language; default `lang` stays **de**. The **original** `.md`
  is both rendered (after preprocessing in memory) and embedded (`--input attach`). New Markdown
  transforms go into `lib/markdown.typ` (git-tracked via `!lib/*.typ` in `.gitignore`).
- **`scripts/build.sh`** (macOS/Linux) and **`scripts/convert.ps1`** (Windows) are the
  conversion entry points. They parse the frontmatter, resolve the logo (frontmatter `logo:`, else
  `logo.svg → .png → .jpg`, optional), and run `typst compile template.typ` directly
  (no intermediate `.typ`, no Pandoc), emitting PDF/A-3b with the source Markdown embedded.
  `build.sh` writes the PDF **next to the source** (not the repo root, which it `cd`s into for
  template/fonts/vendor) unless an explicit second arg is given, and passes `typst --root /`
  with **absolute** `source=`/`attach=`/`docdir=` so reads work for sources anywhere on disk
  (Typst sandboxes reads to its root). `convert.ps1` mirrors this with `--root` = the install
  drive root (same-drive assumption for source), passing absolute paths — no logo copy needed.
  - **Relative paths:** because `build.sh` `cd`s into the project root, it records `orig_pwd`
    **before** the `cd` and resolves a relative source/output argument against it (`resolve_from_pwd`).
    Without this, `rf-document foo.md` from any other directory failed with "file not found".
  - **Auto-open:** after a successful build both scripts open the PDF in the default viewer
    (`open`/`xdg-open`/`Start-Process`); set `RFD_NO_OPEN=1` to suppress (batch/cron).
  - **Called by other programs (Zettlr messenger):** `rf-document IN.md OUT.pdf` writes exactly
    `OUT.pdf`; exit 0 only on success; errors short + German on stderr (missing source → `Error:
    Quelle nicht gefunden`, missing typst → `Error: typst nicht gefunden`). `build.sh` itself sources
    `bin/rfd-tools.env` and prefers `bin/typst`, so it works under a **minimal `PATH`** (GUI apps),
    not only through the `rf-document` wrapper. `convert.ps1` accepts `SOURCE.md OUTPUT.pdf` (exactly
    two args, second `.pdf`) and only waits for Enter on errors in the interactive "Send to" case.
  - **`--help` / `--version`:** `build.sh` parses `-h`/`--help` and `-V`/`--version` in a small
    loop **before** the Typst-version check (so `--help` works without typst) and before the
    positional `[SOURCE] [OUTPUT]`; the surviving positionals are restored via
    `if ((${#positional[@]})) then set -- …`. `--version` prints `rf-document <VERSION>` + the
    typst version. `convert.ps1` has **no `param()` block** and parses `$args` itself (`--version`/
    `-V`/`-Version`, `--help`/`-h`/`-Help`, `--no-source`, `--hard-breaks`; unknown `-x` → exit 2).
    **Windows trap:** with PowerShell parameter binding (`[CmdletBinding()]` + `param`) POSIX options
    such as `--no-source` coming through the `rf-document.cmd` shim (`powershell -File … %*`) are
    taken as unknown parameter names — the Zettlr messenger passes exactly those. **Path trap:** turn
    CLI paths absolute with `[IO.Path]::Combine(cwd, p)` (`ConvertTo-FullPath`), never `Join-Path`:
    `Join-Path` appends an absolute second path (`C:\Notizen\C:\…\x.pdf` → "Das angegebene
    Pfadformat wird nicht unterstützt"), `Combine` keeps it. **Temp trap:** files Typst must read (the
    image-mapping JSON) go into the install folder, not `%TEMP%` — Typst only reads on the `--root`
    drive. **`RFD_BASE_DIR`** (both converters): base folder for relative image/logo paths and the
    `docdir` input (Zettlr's temporary copy of an unsaved note); invalid → warning + source folder. Keep
    the flag list in sync across `build.sh`, `convert.ps1`, and **both** READMEs' options tables.
  - **Image probe pass (replaces the old remote-count pass):** Typst can neither read env vars
    nor test file existence (a missing image *aborts* the build). So both converters first run
    `typst eval --in template.typ <expr> --input probe=true`: in probe mode `safe-image` loads
    nothing and emits `metadata(source)<rfd-image>` (remote sources still emit
    `<rfd-remote-skip>`). `build.sh` uses a JSON *string* (`"N\npath\npath…"`, decoded by the awk
    `json_string_lines`); `convert.ps1` uses a quote-free expression returning a JSON *array*
    (`(str(…len()),) + query(<rfd-image>).map(m => m.value).dedup()`) because **Windows PowerShell
    5.1 mangles `"` inside arguments to native programs**. The shells expand each path
    (`expand_path`/`Expand-NotePath`), resolve it against the note, test it, write a JSON mapping
    `source → absolute path` (`""` = missing, plus a stderr warning) to a temp file and pass it as
    `--input images=…`; the template then renders `[Bild fehlt: …]` for `""`. Without `images`
    (direct typst call) `safe-image` falls back to `resolve-path`. The first probe value is the
    remote count → `N Remote-Bild(er) übersprungen` summary, which `rfd-convert.sh` greps — that
    line is the parse contract, don't reword it. Still two Typst passes per build. (`typst query`
    is deprecated since 0.15; the in-template `query` function is fine.)
  - **Image width:** `lib/markdown.typ`'s `image-attrs` turns `![alt](src){width=…}` into
    `<img src alt width>`; cmarker's built-in `img` handler parses only integer `%` or bare
    numbers (= pt) with `int()`, so `dim-attr` converts `cm`/`mm`/`in`/`px` to integer pt first.
  - **Mermaid:** `#show raw.where(lang: "mermaid", block: true)` renders via vendored **mmdr**
    (`vendor/mmdr`, pinned in `fetch-typst-packages.sh` + `install.ps1`) with `mermaid-theme`.
    **Font trap:** SVG text is drawn with *named instances* of the variable font; `font-weight`
    400 resolves to the default instance **ExtraLight (200)**, so the rule injects
    `font-weight="500"` (Medium) into the SVG. The user wants **only the variable Adobe Source
    fonts** — do not add a static `SourceSans3-Regular.otf` (tried and removed). mmdr does not
    abort on invalid syntax.
    Size: the image is fitted with `layout` + `measure` to the text width and `mermaid-max-height`
    (12 cm), and mmdr gets `mermaid-layout` (node_spacing 25, rank_spacing 35) — mmdr's default
    spacing made a 6-node TD flowchart 17 cm tall; tighter than 25/35 lets labelled edges collide
    with boxes. Gantt and stateDiagram render well; `pie` looked washed out (not used).
- **Install / bootstrap** (separate from conversion):
  - `scripts/bootstrap.sh` / `scripts/bootstrap.ps1` are the curl|bash / irm|iex one-liners:
    require git, clone/pull into `~/.local/share/real-fast-document` (Windows
    `%LOCALAPPDATA%\real-fast-document`), then run the installer. The **same** one-liner installs and
    updates. With `--uninstall` / `-Uninstall` they run `install.sh --uninstall` / `install.ps1
    -Uninstall` and then delete the install folder — **only** if it is a git clone whose `origin`
    contains `real-fast-document` (guard against a stray `RFD_HOME`). Test the cycle in a
    throwaway `HOME` (`HOME=/tmp/x XDG_DATA_HOME= XDG_BIN_HOME= bash scripts/bootstrap.sh`, then
    `… --uninstall`) — `install.sh` writes the Quick Action / `rf-document` under `$HOME`, so a run
    with the real `HOME` would overwrite the user's own integration.
  - `scripts/install.sh` (macOS/Linux) ensures typst (≥0.15) via the system package manager —
    **typst falls back to the official GitHub binary into `./bin`** when no PM package exists
    (Linux) — fetches fonts **and** vendors the Typst packages, then installs the right-click
    integration: a Finder **Quick Action** (`~/Library/Services/*.workflow`) on macOS, a
    `.desktop` + `xdg-mime` association on Linux. `--uninstall` removes only the integration.
    Idempotent. **No pandoc** (it is not a dependency anymore).
  - **Font/package fetching is idempotent** — re-running the installer (the normal *update* path
    via `bootstrap`) does **not** re-download when things are already there. `fetch-fonts.sh` skips
    if all target files exist; `fetch-typst-packages.sh` skips per package if `vendor/<name>/typst.toml`
    already carries the **pinned version** (so a version bump auto-refreshes, no flag needed).
    Override with `--force` (bash) / `-Force` (`install.ps1`) or `RFD_FORCE_FONTS`/`RFD_FORCE_PACKAGES=1`.
    `install.ps1`'s `Install-Fonts`/`Install-TypstPackages` mirror this (using `Test-Path -LiteralPath`
    so the brackets in `NotoEmoji[wght].ttf` aren't read as a wildcard).
  - `scripts/install.ps1` (Windows) auto-installs typst via winget (`-Tools`), fetches fonts
    (`-Fonts`), vendors the packages (`-Packages`), and creates the "Send to" shortcut
    (`-SendTo`). The logic stays in the install path; only a shortcut lands in the system.
  - `scripts/rfd-convert.sh` is the dispatcher the macOS/Linux right-click calls: it loops
    `build.sh` over the files (output next to source) and posts a success/fail notification
    (osascript / notify-send), including the aggregated count of skipped remote images.
  - **`rf-document`** is the global terminal command: `install.sh` writes a wrapper to
    `~/.local/bin/rf-document` (macOS/Linux), `install.ps1` a `rf-document.cmd` shim into
    `%LOCALAPPDATA%\Microsoft\WindowsApps` (on PATH by default). It just calls the converter.
  - **GUI-PATH gotcha:** Finder Quick Actions / `.desktop` launches do **not** inherit the
    shell `PATH`, so a `typst` in `~/.local/bin` or `/opt/homebrew/bin` is invisible and the
    build fails with `command not found`. `install.sh` therefore records the real typst dir
    (resolved while PATH is correct) in `bin/rfd-tools.env`; `rfd-convert.sh` and the
    `rf-document` wrapper source it and prepend `RFD_TOOL_PATH`. `bin/` is git-ignored.
  - `install.sh` shell notes: never hardcode `sudo` (use the `run_priv` helper — works as root
    or without sudo); avoid `trap … RETURN` referencing a local under `set -u` (it fires
    unbound — use explicit cleanup).
  - **Line endings are enforced per file type by `.gitattributes` — and `.ps1` differs.** `*.sh`,
    `*.typ`, `*.md` and `*.svg` are `eol=lf`, but **`*.ps1` is `text eol=crlf`**: the PowerShell
    scripts are CRLF in the working tree and LF in the repo (Windows PowerShell 5.1 wants CRLF).
    Do **not** "normalize" the CRLF you see in `convert.ps1`/`install.ps1` — that is the intended
    checkout form. Font/PDF/image types are marked `binary`.
  - **`.ps1` files must stay pure ASCII.** They carry no BOM, so Windows PowerShell 5.1 reads
    them in the ANSI code page (CP1252) — a non-ASCII char (e.g. an en-dash `–`) misdecodes
    and can yield a stray typographic quote that PowerShell treats as a string delimiter,
    breaking the parse (`Send to` then silently produces no PDF). Comments transliterate
    (`ae`/`ue`/`oe`); keep all `.ps1` content ASCII (`grep -nP '[^\x00-\x7F]'`).
  - **Read the Markdown *source* as UTF-8 explicitly.** Windows PowerShell 5.1's `Get-Content`
    (no `-Encoding`) decodes in the ANSI code page (CP1252), so a UTF-8 `.md` with umlauts becomes
    mojibake (`ä` → `Ã¤`) in the frontmatter values. `convert.ps1` reads via
    `[IO.File]::ReadAllLines($Src, (New-Object Text.UTF8Encoding $false))` — auto-detects/strips a
    BOM. (This is about *content* files, not the ASCII rule above, which is about the *script* files
    themselves.) The body is read by Typst itself (`read()` = UTF-8, safe); only the frontmatter
    values go via `--input` argv, which Windows
    passes as UTF-16 (unaffected). `build.sh` reads UTF-8 natively.
  - **`Invoke-WebRequest -OutFile` treats its path as a wildcard pattern.** A font name with
    brackets (`NotoEmoji[wght].ttf`) is read as a char class and the download aborts with
    "resolved wildcard path does not specify a file". `install.ps1` escapes the target via
    `[Management.Automation.WildcardPattern]::Escape(...)`; don't pass an unescaped bracketed
    path to `-OutFile`. (bash `curl -o` is unaffected — it writes the literal name.)
  - **Typst `--input` paths that the template resolves internally must be root-relative, not
    absolute Windows paths.** Typst resolves `read`/`image`/`pdf.attach`/`docdir` paths through
    its **virtual filesystem relative to `--root`**, which enforces two rules a Windows absolute
    path breaks: no backslashes (`error: path must not contain a backslash`) **and** no drive
    letter (`error: path contains invalid component "C:"`). So `convert.ps1`'s `ConvertTo-TypstPath`
    turns `C:\Users\x` into `/Users/x` (`-replace '\\','/'` then strip the leading `[A-Za-z]:`)
    for the four path-valued inputs — `source` (`read`), `attach` (`pdf.attach`), `docdir`
    (relative-image resolution), `logo` (`image`). This mirrors `build.sh`, which passes `--root /`
    plus `/`-absolute POSIX paths (root-relative already). Because `--root` = the drive root
    (`$Root`), this assumes **source and install live on the same drive** (documented; a single
    `--root` cannot span two drives). The **CLI filesystem args** (`$Template`, output, `--root`,
    `--font-path`) go through the OS fs layer, accept backslashes/drive letters, and are left
    untouched. `build.sh` is unaffected; non-path inputs (title, date, lang, …) need no transform.

### Heading / document model (encoded in template.typ)

- **Title** comes from the **`title:` frontmatter**, NOT from `# H1`: a centered title block
  emitted before the body, plus the title in the running header from page 1, plus the PDF/A
  metadata title. Optional — without it there's no title block and the metadata title is the `.md`
  basename.
- **H1 = chapter** — the top content heading: serif, a fine full-width hairline right below it, a
  page break before it (`h1_break`), and the active H1 threaded into the running header.
- **H2 / H3** = subsections (serif, no line). **H3** is body size (10pt) at `weight-text`, finely
  underlined; **H4 and deeper** are body size, italic.
- **Weights/figures (Zettlr-matched, 26.10.4):** `weight-text` 380 (body, H3+, header, TOC entries),
  `weight-heading` 470 (title, H1, H2, "Inhalt"); bold = 380 + **`set strong(delta: 180)`** = 560.
  **Never set a weight in `show strong`** — Typst *adds* `strong.delta` to the current weight. PDF
  viewers draw the variable Source fonts heavier than browsers/editors, hence the slightly-below-
  nominal values. Sizes (26.10.10): title 16, H1 14, H2 12, H3+ 10 pt (= body); header 11, TOC title 14 / entries 11, code + captions 9, tables + footer 9 pt. Margins left 35 / right 30 / top 35 / bottom 20 mm (145 mm text block, ~95 characters per line). Table cell inset `(x: 5pt, y: 7pt)` — 7 pt horizontal made a 13-column table overflow at 145 mm (checked in `test-pdf.sh`). Figures: body `number-type:
  "old-style"`; tables `lining` + `tabular`; header/footer `lining`; `raw` neutral (`auto`).
- **Visual language:** all headings **serif** (`Source Serif 4`), `luma(8%)`, left-aligned
  (`justify: false`), **no accent bars**; only **H1** carries a hairline (`luma(60%)`) right below.
  Every heading uses space-above > space-below so it binds to the following text — but the `below`
  is sized ~`above`/2 (H1 2.0/0.6, H2 1.5/0.7, H3+ 1.25/0.55 em) so the body no longer
  hugs the heading. **All above/below em are body-size-em (10pt)** (resolved against the body size at
  block creation, *not* the heading size) — so the rhythm is level-independent; edit the four block()
  calls in the `#show heading` rule (H1, H2, H3, H4+). Sizes: H1 14pt, H2 12pt, H3+ 10pt (= body); body
  text is 10pt with `leading: 0.85em`. Header **and** footer
  text are Sans (`Source Sans 3`). Fonts come from `body-font`/`heading-font`/`code-font`. Unordered
  lists use one small drawn square marker at **all** levels; ordered lists keep numbers; task items
  use the drawn `task-box` (outline open, dark fill + white ✓ done); task-only lists become a table. Blockquotes are indented both sides + italic.
- **Page-break hygiene (widows/orphans, sticky headings, unbreakable figures):**
  - **Headings never sit alone at a page foot.** Typst sets `sticky: true` on heading blocks *by
    default* — but our `#show heading` rule builds its **own** `block(...)`, which **drops** that
    default. So every heading block here must set `sticky: true` explicitly (all four branches —
    H1, H2, H3, H4+ — do);
    omitting it silently re-introduces orphaned headings. Verified via A/B (same doc, `sticky` on
    vs off): off strands the heading at the page foot, on pushes it to the next page.
  - **Figure + caption stay together** — the `#show figure` rule sets `breakable: false`, so an
    image and its (bottom) caption never split across a page; if both don't fit, the whole figure
    moves to the next page. (Don't set `breakable: true` unless a figure must span pages.)
  - **Widows/orphans** are discouraged via `#set text(costs: (orphan: 200%, widow: 200%))` —
    Schusterjunge = lone first line at a page foot, Hurenkind = lone last line at a page head;
    2× the default cost makes Typst pull an extra line rather than leave one stranded.
- **Running header** (`doc-header`): `header:` fixed text wins; else the active **H1** chapter;
  before the first chapter the `title:` (if set), else empty.
- **Page break after the TOC follows `h1_break`** (`if want-break() { pagebreak(weak: true) }`):
  with `h1_break: false` the body continues directly below the TOC (user decision). The outline sits
  in `block(below: 2.0em, …)` because the entries have `below: 0pt` — without it a following
  paragraph overlapped the last entry (`toc-no-break.md` checks it via bbox).
- **Conditional TOC / structured mode**: when `#H1 + #H2 > 5` (`auto-structured()`) the doc renders
  a TOC (**H1 + H2 only**, `outline(depth: 2)`) after the title and breaks each **H1** to a new
  page. `toc`/`h1_break` override each independently via `want-toc()`/`want-break()`. The title
  block + TOC are a **preamble emitted BEFORE `cmarker.render`** (no longer inside the heading show
  rule). Edit the helpers, not scattered `> 5` literals.
- **Watermark** (`watermark:` frontmatter): a diagonal (-45°), letter-spaced, bold, light-gray page
  **background** (under all content) via `#set page(background: …)`. Gray via `luma(92%)` =
  single-channel grayscale (ICCBased /N 1) → separates to clean **K** in print; **Typst 0.15 can't
  emit CMYK in PDF/A** (`cmyk()` hard-errors in that export mode), so luma is the print-clean route.

### Typst show-rule traps (cost real debugging here)

- Inside `#show heading: it => …`, **never realize `it` within a `context` block** — the
  recursion guard does not cross the context boundary and the rule matches its own output
  ("maximum show rule depth exceeded"). Keep `it` in the plain branch; put only
  introspection (`query`, conditional `pagebreak`/`outline`) inside small `context` blocks.
- `outline(title: [..])` renders its title as a *heading*, which re-triggers the heading
  show rule → recursion. Use `outline(title: none)` and render the "Inhalt" label as plain
  text.
- The **table** show rule rebuilds every cmarker table with **Typst's own `auto` columns**
  (`columns: (auto,) * n`) — each column as wide as its content, Typst shares the space and wraps
  text-heavy columns when the table doesn't fit; small tables keep their content width. **History:**
  26.10.2–26.10.7 used a hand-made HTML-auto-layout (measure min = widest word via a styled word
  split, max = natural width, distribute the rest); side by side with plain `auto` it looked almost
  identical, so the user judged it over-engineered ("übersteuert") — **don't reintroduce custom
  width measuring.** Table type is `table-text`: Source Sans 3 **9 pt, weight 500, tracking
  −0.02em**, lining tabular figures, ragged right; code in cells 8.5 pt (`show raw: set text(...)`
  inside the table block — the global raw size is 10 pt). Adobe has **no condensed** Source Sans (the
  VF only has a `wght` axis); the user chose tracking instead of another font. The task table uses the
  same `table-text`. **Alignment:** `it.align` is an array from cmarker (`auto` where the separator
  row has no `:`); `auto` columns whose non-empty cells all match `number-re` (`plain-text` of the
  cell) become `right`, others `left`; header row always centered/bold. `plain-text` must use
  `.sum(default: "")`, not `.join("")` — `join` on an empty array returns `none` and empty cells then
  crash `.trim()`. Zebra/stroke come from `rfd-table-fill`/`rfd-table-stroke` (shared with the task
  table).
  Emitting a `table` inside `#show table:` recurses → guard on a field the rebuild sets but
  cmarker never does: `if it.fill != none { it } else { …rebuild… }` (the guard is a **field
  check**, so it survives the `layout`/`context` boundary — unlike the built-in heading
  recursion guard). `it.columns` is an int from cmarker (needs that count `n`). The rebuild
  spreads `..it.children` **as-is** — cmarker already wraps the first row in a real
  `table.header` (with `repeat: true`), so the **header row repeats on page breaks automatically**;
  do **not** re-wrap the first cells in another `table.header` (Typst errors: *header within another
  header*). For measuring only, the header is unwrapped (`c.func() == table.header` → its
  `.children`) and each cell's `.body` is pulled out (`c.func() == table.cell ? c.body : c`).
  `scripts/test-pdf.sh` checks the result geometrically via `pdftotext -bbox` (`xmax`): amounts of
  different length end at the same x (right-aligned), a small table ends well before the margin,
  and page 2 of a long table repeats the header.
  The rebuilt table is wrapped in a `block(above/below, breakable: true)` for symmetric
  spacing while still letting long tables break across pages (with the repeating header).
- **Non-breaking spaces** — `template.typ` inserts NBSP so common pairs don't break across a line:
  German abbreviations via literal `#show "z. B.": [z.~B.]` rules (the replacement contains `~`/NBSP,
  not a plain space, so it can't re-match → no recursion), and number + unit/percent/currency via
  two `#show regex(...): it => it.text.replace(" ", "\u{00A0}")` rules (Typst's regex crate has **no
  lookaround**, so match the whole pair and swap its one space). Letter units carry a trailing `\b`
  so `5 Meter` isn't touched; symbol units (`%`/`€`/`£`/`$`) omit `\b`. Verify a change with the
  visible-marker trick: swap `\u{00A0}`/`~` for `X`, render, and check where `X` lands (an NBSP is
  invisible, and `mutool`/text-extractors normalize it back to a space, so a raw text dump won't
  show it). `#show regex(...)` needs a **colon** (`: it => …`), not `=>`.
  - **Code/`raw` is excluded from all of the above.** The NBSP rules match **every** text run,
    including inside `raw`/code — so without a guard a code sample (`x = 5 % 2`, `12 pt`) renders a
    space that is really a U+00A0, and copy-pasting it out of the PDF breaks the code. Typst has **no
    "not in raw" selector**, so a `#show raw: it => { … it }` wrapper re-runs two inner regex rules
    that shove an invisible `box()` atom **between the protected number/abbreviation and its next
    char**: `[0-9] \S` (covers unit **and** symbol/percent/currency) and `[A-Za-zÄÖÜäöü]\. \S`
    (covers every abbreviation — each protected space there sits behind `x.`). The visible text (with
    a **normal** space) is unchanged; the outer regex/string rules just no longer find a contiguous
    match, so they don't fire. Non-obvious traps found the hard way: (a) the box must sit **inside**
    the match with the neighbouring chars **re-emitted** (`slice…#box()#slice`) — a trailing box, an
    identity return, or a different-selector rule all let the outer rule re-match across the element
    boundary; (b) it must be a **regex** neutralizer, not `#show " "` (a content-literal space gets
    trimmed). Verify with the visible-marker trick on a **highlighted** code block (swap NBSP→`¤`):
    `¤` must appear in body prose but **never** inside a code block.

## Release flow

GitHub Flow: `feature/*` (or `fix/*`/`docs/*`) → PR → squash-merge to `main`, then
fast-forward `dev` to `main` (the repo keeps both `main` and `dev`). CalVer
`YY.M.MICRO` in `VERSION` + `CHANGELOG.md`; tag `vX` and create a GitHub release. The version
bump + CHANGELOG entry ride in the feature PR; a docs-only change can merge without a bump
(cut a separate `release: X` PR if you do want to ship it as a versioned release).

**Note on this repo vs. the install path:** the development repo lives under `~/GitHub/`
and keeps `main` + `dev`; `~/.local/share/real-fast-document` is a *separate* bootstrap
**installation** (only `main`, the `bin/`/`vendor/` install artifacts). Develop in the repo, not
in the install. Verify with `git -C <dir> remote -v` / the presence of `bin/rfd-tools.env` before
committing.

When scripting a merge+tag+release, **verify the merge landed in `main` before tagging**
(`gh pr merge` can return "not mergeable" right after a push while GitHub recomputes
mergeability; a `set -e`-less script will otherwise tag the wrong commit). Poll
`gh pr view N --json mergeable` until `MERGEABLE` first.

Full release once the feature PR (with the `VERSION` bump + CHANGELOG entry) is open — copy-paste
sequence (`V` = the CalVer in `VERSION`, `N` = PR number):

```bash
until [ "$(gh pr view N --json mergeable -q .mergeable)" = MERGEABLE ]; do sleep 3; done
gh pr merge N --squash --delete-branch
git checkout main && git pull origin main --ff-only          # tag the squash commit
git tag -a "v${V}" -m "Release ${V}" && git push origin "v${V}"
git checkout dev && git merge --ff-only main && git push origin dev && git checkout main
RFD_NO_OPEN=1 bash scripts/build.sh README.md /tmp/README.pdf # dogfood release asset
gh release create "v${V}" /tmp/README.pdf#README.pdf --title "v${V}" --notes "…CHANGELOG excerpt…"
```

The README is dogfooded: `bash scripts/build.sh README.md README.pdf` renders it through
the pipeline, and that PDF is attached to GitHub releases as an asset (it is not committed).
The English README builds identically (`bash scripts/build.sh README.en.md README.en.pdf`) and can
ride along as a parallel asset for parity; both `README.pdf` and `README.en.pdf` are `*.pdf`
git-ignored local artifacts (never committed), so a stray `README.en.pdf` in the root is expected.
`README.md` and `README.en.md` must stay in parity (same structure, sections, version) — a
change to one must land in the other in the same PR; both build cleanly through the pipeline.
`assets/pipeline.svg` is the pipeline diagram both READMEs embed (the only tracked non-root
resource); it is *not* rendered by the build — plain repo documentation.

Generated artifacts (`*.pdf`, generated `*.typ`, `preview-*.png`, `bin/`, and `vendor/`) are
git-ignored — note only `preview-*.png` matches, so scratch PNGs under any other name pollute
`git status`. There is **no intermediate file anymore** (no Pandoc `.typ`, no render temp `.md` —
the template preprocesses in memory). `template.typ` and `lib/*.typ` are the tracked `.typ` files;
`.gitignore` globs `*.typ` and re-includes both. If scratch `.typ` ever appear in the root, clean with
`find . -maxdepth 1 -name '*.typ' ! -name 'template.typ' -delete`.

The user's **global** excludesfile (`~/.gitignore`) ignores `CLAUDE.md` (and possibly other
names) across all repos: silently-ignored new files never appear in `git status`, so
`git add` skips them without error. Use `git check-ignore -v <file>` to diagnose and
`git add -f <file>` to track an intentionally-ignored file (`CLAUDE.md` is already tracked
here, so further edits commit normally).
