# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A document-rendering pipeline, **not** a Python project — the Python conventions in the
parent `~/GitHub/CLAUDE.md` (uv/ruff/mypy/pytest) do **not** apply here. What does apply
from that file: GitHub Flow branching, CalVer versioning, and Conventional Commits
(English, no AI co-author trailers). Author identity in this repo is `jcmx9`.

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
rf-document SRC.md                    # global CLI after install (wrapper → build.sh)
TYPST=/path/to/typst bash scripts/build.sh ...       # override the typst binary (e.g. to test a version)
# Lint ALL shell scripts (PowerShell has no runner here — review only):
shellcheck scripts/build.sh scripts/fetch-fonts.sh scripts/fetch-typst-packages.sh scripts/install.sh scripts/bootstrap.sh scripts/rfd-convert.sh
```

There is **no test suite**. Verification is **visual**: render pages to PNG and inspect them.
There is **one** render fixture in the root: `example.md` (the default build target). It is a
full showcase and doubles as the regression probe for every supported element — structured/TOC
mode (`#H2 + #H3 > 5`), task lists, tables, math, the emoji/symbol glyph fallback, a local
captioned figure, definition lists, **and** a remote image that the template must strip (see
below). Use it to eyeball layout changes; its `*.pdf` is git-ignored.

To render PNGs for inspection you must reproduce build.sh's preprocessing (strip frontmatter,
tighten task lists, deflists → `<dl>`) into a temp file, then compile `template.typ` directly:

```bash
# (build.sh does this; for a manual PNG render, feed a preprocessed copy as source=)
typst compile template.typ --root / --font-path fonts --ignore-system-fonts \
  --input source=RENDER.md --input attach=SRC.md --input docdir=SRC_DIR \
  --input filename=OUT.pdf --input title=SRC --input doctitle= --input logo=logo.svg \
  --input date= --input toc=auto --input "h1-break=auto" --input showname=true --input lang=de \
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

There is no Linux/Windows runner here (this is macOS). The **Linux installer** can be
validated for real in Docker (mount read-only, copy inside, run `install.sh`): this is how
the install path was verified, and it caught real bugs. Windows `.ps1` can only be reviewed
(the `mcr.microsoft.com/powershell` image crashes under qemu on arm64).

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
  Pandoc template): after all `#set`/`#show` rules it calls `#cmarker.render(read(source), …)`.
  Runtime values (`filename`, `title` [metadata], `doctitle` [visible title], `logo`, `source`,
  `attach`, `docdir`, plus the frontmatter-derived `date`, `toc`, `h1-break`, `showname`, `lang`,
  `header`, `watermark`) are passed as `typst --input` and read via `sys.inputs`.
  - The **cmarker call** uses `h1-level: 1` (markdown `#` → Typst level-1 heading, styled as a
    *chapter*) and `set-document-title: false` (the PDF/A metadata title comes from `--input title`
    = the frontmatter `title:` or the `.md` basename). `math: mitex`, `task-list-marker:` a
    checkbox glyph (☐/☒ via Noto), and `scope:` overrides for `image` (`safe-image`), `divider` (the centered
    `horizontalrule`), and `terms` (`rfd-terms`, builds `terms.item` explicitly to silence a
    cmarker deprecation warning).
  - **`safe-image`** (in `template.typ`) replaces the old Lua image/link/para/figure dance:
    remote sources (`http(s)://`, protocol-relative `//host`, `data:`) render **nothing** but
    emit an invisible `metadata("rfd-remote-skip")<rfd-remote-skip>` marker for counting; a
    local image with alt text becomes a **numbered figure with caption**; relative paths are
    resolved against `docdir` (the document's directory) so images next to documents anywhere
    on disk are found.
- **Optional YAML frontmatter** (parsed by `build.sh`/`convert.ps1`, then passed via `--input`):
  `title:` → centered title block + running-header title (from page 1) + PDF/A metadata title;
  `date:` (ISO) → ISO-prefixes the output file (`2026-06-19_name.pdf`) **and** shows a
  `lang`-localized date in the footer right; `isodate_praefix:` true|false controls **only** the
  filename prefix (default: on when `date:` is set — `false` drops the prefix but keeps the footer
  date; a filename-only knob, never passed to `template.typ`); `toc:`/`h1-break:` true|false
  override the `> 5`
  automatism; `print_filename:` true|false toggles the footer-left name (→ `showname` input);
  `lang:` sets the document language / date format (default `de`); `header:` → fixed header text
  (from page 1, overrides the running header); `watermark:` → diagonal page-background watermark.
  The footer is 2-col without a date (name | page) and 3-col with one (name | page centered | date).
  The bool keys are
  parsed **YAML-1.1-tolerant** (case-insensitive `true/false/yes/no/on/off`, quotes, inline
  comments via `yaml_bool`/`ConvertTo-YamlBool`); an unrecognized value warns and keeps the
  default. Typst does not localize month names (`[month repr:long]` is English only) → a manual
  `months-de` array lives in `template.typ`; `fmt-date` validates the ISO string defensively
  because an invalid `datetime`/`int()` *panics* and aborts the whole build.
- **Build-time Markdown preprocessing** (`build.sh` awk / `convert.ps1` native, kept in sync):
  before Typst sees the source it produces a **temp render copy** that (1) strips the YAML
  frontmatter, (2) normalizes **loose task lists to tight** — cmarker 0.1.9 **crashes** (`wasm unreachable`; upstream #71, fixed, pending release) on task items separated by blank lines — and (3) converts Pandoc-style
  definition lists (`Term` / `: def`) to HTML `<dl>`. The `<dl>` uses **block form** (a blank
  line after `<dd>`) so inline markdown in a definition renders — inline `<dd>x `code` y</dd>`
  would show literal backticks. **Multi-line definitions** (a `: def` line plus indented Pandoc
  continuation lines) are folded into one `<dd>` — otherwise the continuation escapes the `<dd>`
  and renders as body text flush left instead of indented under the term. The temp copy is rendered; the **original** `.md` is embedded
  (`--input attach`) so the attachment keeps the real name and untouched content.
- **`scripts/build.sh`** (macOS/Linux) and **`scripts/convert.ps1`** (Windows) are the
  conversion entry points. They parse the frontmatter, preprocess to a temp file, resolve the
  logo (`logo.svg → .png → .jpg`, optional), and run `typst compile template.typ` directly
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
  - **`--help` / `--version`:** `build.sh` parses `-h`/`--help` and `-V`/`--version` in a small
    loop **before** the Typst-version check (so `--help` works without typst) and before the
    positional `[SOURCE] [OUTPUT]`; the surviving positionals are restored via
    `if ((${#positional[@]})) then set -- …`. `--version` prints `rf-document <VERSION>` + the
    typst version. `convert.ps1` mirrors it with PowerShell-native `[switch]$Version`/`$Help`
    **plus** a scan of the remaining args for the POSIX `--version`/`--help` forms. **Windows trap:**
    do **not** advertise `-V`/`-h` as PS switches — under `[CmdletBinding()]` the common `-Verbose`
    param makes `-V` an **ambiguous prefix** (binding error before any script code runs); only the
    full `-Version`/`-Help` switches and the double-dash `--version`/`--help` are safe there. Keep
    the flag list in sync across `build.sh`, `convert.ps1`, and **both** READMEs' options tables.
  - **Skip reporting:** the template marks each stripped remote image with an invisible
    `<rfd-remote-skip>` metadatum; after compiling, `build.sh`/`convert.ps1` run a **second
    `typst eval` pass** — `typst eval --in template.typ 'query(<rfd-remote-skip>).len()'` with the
    same inputs — to count them and print a `N Remote-Bild(er) übersprungen` summary. (`typst query`
    is **deprecated since Typst 0.15**; `eval` with `query(...).len()` returns the count directly.
    The Typst `query` *function* used inside `template.typ`'s show rules is unaffected — only the
    CLI subcommand is deprecated.) `rfd-convert.sh` greps that summary out of each build's output
    and folds the total into its system notification (so GUI right-click users notice). The summary
    line is the parse contract — don't reword it without updating the grep. (Cost: two Typst passes
    per build; negligible for small docs.)
- **Install / bootstrap** (separate from conversion):
  - `scripts/bootstrap.sh` / `scripts/bootstrap.ps1` are the curl|bash / irm|iex one-liners:
    require git, clone/pull into `~/.local/share/real-fast-document` (Windows
    `%LOCALAPPDATA%\real-fast-document`), then run the installer.
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
  - **`.ps1` files must stay pure ASCII.** They carry no BOM, so Windows PowerShell 5.1 reads
    them in the ANSI code page (CP1252) — a non-ASCII char (e.g. an en-dash `–`) misdecodes
    and can yield a stray typographic quote that PowerShell treats as a string delimiter,
    breaking the parse (`Send to` then silently produces no PDF). Comments transliterate
    (`ae`/`ue`/`oe`); keep all `.ps1` content ASCII (`grep -nP '[^\x00-\x7F]'`).
  - **Read the Markdown *source* as UTF-8 explicitly.** Windows PowerShell 5.1's `Get-Content`
    (no `-Encoding`) decodes in the ANSI code page (CP1252), so a UTF-8 `.md` with umlauts becomes
    mojibake (`ä` → `Ã¤`) that then flows into the render temp and the PDF. `convert.ps1` reads via
    `[IO.File]::ReadAllLines($Src, (New-Object Text.UTF8Encoding $false))` — auto-detects/strips a
    BOM and matches the BOM-less UTF-8 the temp is written with. (This is about *content* files, not
    the ASCII rule above, which is about the *script* files themselves.) The body flows through the
    render **file** (UTF-8, safe); only the frontmatter values go via `--input` argv, which Windows
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
  page break before it (`h1-break`), and the active H1 threaded into the running header.
- **H2 / H3** = subsections (serif, no line). **H4+** = bold, left-aligned only.
- **Visual language:** all headings **serif** (`Source Serif 4`), `luma(8%)`, left-aligned
  (`justify: false`), **no accent bars**; only **H1** carries a hairline (`luma(60%)`) right below.
  Every heading uses space-above > space-below so it binds to the following text — but the `below`
  is sized ~`above`/2 (H1 2.0/0.6, H2 1.5/0.7, H3 1.25/0.55, H4 1.05/0.45 em) so the body no longer
  hugs the heading. **All above/below em are 12pt-em** (resolved against the body size at block
  creation, *not* the heading size) — so the rhythm is level-independent; edit the four block()
  calls in the `#show heading` rule. Header **and** footer
  text are Sans (`Source Sans 3`). Fonts come from `body-font`/`heading-font`/`code-font`. Unordered
  lists use one small drawn square marker at **all** levels; ordered lists keep numbers; task items
  use a checkbox glyph (☐ open, ☒ done, via Noto). Blockquotes are indented both sides + italic.
- **Page-break hygiene (widows/orphans, sticky headings, unbreakable figures):**
  - **Headings never sit alone at a page foot.** Typst sets `sticky: true` on heading blocks *by
    default* — but our `#show heading` rule builds its **own** `block(...)`, which **drops** that
    default. So every heading block here must set `sticky: true` explicitly (all four levels do);
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
- **Conditional TOC / structured mode**: when `#H1 + #H2 > 5` (`auto-structured()`) the doc renders
  a TOC (**H1 + H2 only**, `outline(depth: 2)`) after the title and breaks each **H1** to a new
  page. `toc`/`h1-break` override each independently via `want-toc()`/`want-break()`. The title
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
- The **full-width table** show rule rebuilds the table to fill the text block **with columns
  sized proportionally to content** (not `(1fr,)*n`, which stretches every column equally): it
  flattens the cell bodies (unwrapping the `table.header` — see below), then inside a
  `layout(size => …)` **`measure`s each column's natural max width**, caps it at the text width
  (`size.width`) so one text-heavy column can't crush the narrow ones to zero, adds ~12pt of
  inset compensation (`measure` doesn't know the cell inset), and turns those widths into
  `fr` weights (`w / total * 1fr`). Result: the table still fills the width, but narrow columns
  stay narrow and wide content gets more room. Header centered/bold, body left, zebra `fill`.
  Emitting a `table` inside `#show table:` recurses → guard on a field the rebuild sets but
  cmarker never does: `if it.fill != none { it } else { …rebuild… }` (the guard is a **field
  check**, so it survives the `layout`/`context` boundary — unlike the built-in heading
  recursion guard). `it.columns` is an int from cmarker (needs that count `n`). The rebuild
  spreads `..it.children` **as-is** — cmarker already wraps the first row in a real
  `table.header` (with `repeat: true`), so the **header row repeats on page breaks automatically**;
  do **not** re-wrap the first cells in another `table.header` (Typst errors: *header within another
  header*). For measuring only, the header is unwrapped (`c.func() == table.header` → its
  `.children`) and each cell's `.body` is pulled out (`c.func() == table.cell ? c.body : c`).
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

The README is dogfooded: `bash scripts/build.sh README.md README.pdf` renders it through
the pipeline, and that PDF is attached to GitHub releases as an asset (it is not committed).
`README.md` and `README.en.md` must stay in parity (same structure, sections, version) — a
change to one must land in the other in the same PR; both build cleanly through the pipeline.
`assets/pipeline.svg` is the pipeline diagram both READMEs embed (the only tracked non-root
resource); it is *not* rendered by the build — plain repo documentation.

Generated artifacts (`*.pdf`, generated `*.typ`, `preview-*.png`, `bin/`, and `vendor/`) are
git-ignored — note only `preview-*.png` matches, so scratch PNGs under any other name pollute
`git status`. There is **no Pandoc intermediate `.typ` anymore**; `build.sh` writes a temp
**render `.md`** (via `mktemp`, cleaned up by an `EXIT` trap even on failure), and `convert.ps1`
a dot-prefixed temp `.md` in a `finally` block. `template.typ` is the one tracked `.typ`;
`.gitignore` globs `*.typ`. If scratch `.typ` ever appear, clean with
`find . -maxdepth 1 -name '*.typ' ! -name 'template.typ' -delete`.

The user's **global** excludesfile (`~/.gitignore`) ignores `CLAUDE.md` (and possibly other
names) across all repos: silently-ignored new files never appear in `git status`, so
`git add` skips them without error. Use `git check-ignore -v <file>` to diagnose and
`git add -f <file>` to track an intentionally-ignored file (`CLAUDE.md` is already tracked
here, so further edits commit normally).
