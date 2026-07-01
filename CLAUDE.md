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

## Commands

```bash
bash scripts/build.sh                 # build example.md → example.pdf (next to source)
bash scripts/build.sh SRC.md          # → SRC.pdf  (or DATE_SRC.pdf if frontmatter has date:)
bash scripts/build.sh SRC.md OUT.pdf  # explicit output
RFD_NO_OPEN=1 bash scripts/build.sh SRC.md   # suppress the auto-open (build.sh opens the PDF by default)
bash scripts/fetch-fonts.sh           # (re)download the bundled fonts into ./fonts (Source OTF + Noto fallbacks)
bash scripts/fetch-typst-packages.sh  # (re)vendor cmarker + mitex into ./vendor (offline build)
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
  --input filename=OUT.pdf --input title=SRC --input logo=logo.svg \
  --input date= --input toc=auto --input "h2-break=auto" --input showname=true --input lang=de \
  --format png --ppi 120 preview-{p}.png
# then open / Read the preview-*.png, then clean up scratch files
# (`preview-*.png` is the git-ignored scratch name — other PNG names show up in `git status`)
```

The simplest path is just `RFD_NO_OPEN=1 bash scripts/build.sh SRC.md` for the PDF, then render
that PDF's pages separately if you need PNGs.

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
  Runtime values (`filename`, `title`, `logo`, `source`, `attach`, `docdir`, plus the
  frontmatter-derived `date`, `toc`, `h2-break`, `showname`, `lang`) are passed as
  `typst --input` and read via `sys.inputs`.
  - The **cmarker call** uses `h1-level: 1` (H1 stays a level-1 heading → the existing heading
    show rule styles it as the centered title) and `set-document-title: false` (we set the PDF/A
    title ourselves from the `.md` basename via `--input title`, which is always present — no H1
    dependency, no "set rules inside container" error). `math: mitex`, `task-list-marker:` a
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
  `date:` (ISO) → ISO-prefixes the output file (`2026-06-19_name.pdf`) **and** shows a
  `lang`-localized date in the footer right; `toc:`/`h2-break:` true|false override the `> 5`
  automatism; `print_filename:` true|false toggles the footer-left name (→ `showname` input);
  `lang:` sets the document language / date format (default `de`). The footer is 2-col without a
  date (name | page) and 3-col with one (name | page centered | date). The three bool keys are
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
  would show literal backticks. The temp copy is rendered; the **original** `.md` is embedded
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
  - **Skip reporting:** the template marks each stripped remote image with an invisible
    `<rfd-remote-skip>` metadatum; after compiling, `build.sh`/`convert.ps1` run a **second
    `typst query`** pass (same inputs) to count them and print a `N Remote-Bild(er) übersprungen`
    summary. `rfd-convert.sh` greps that summary out of each build's output and folds the total
    into its system notification (so GUI right-click users notice). The summary line is the parse
    contract — don't reword it without updating the grep. (Cost: two Typst passes per build;
    negligible for small docs.)
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
  - **`Invoke-WebRequest -OutFile` treats its path as a wildcard pattern.** A font name with
    brackets (`NotoEmoji[wght].ttf`) is read as a char class and the download aborts with
    "resolved wildcard path does not specify a file". `install.ps1` escapes the target via
    `[Management.Automation.WildcardPattern]::Escape(...)`; don't pass an unescaped bracketed
    path to `-OutFile`. (bash `curl -o` is unaffected — it writes the literal name.)

### Heading / document model (encoded in template.typ)

- **H1 = document title** (centered, excluded from header and TOC). H1 is **not enforced** and
  no longer required — it is optional and not limited to one. The PDF/A metadata title is the
  `.md` basename (always present), independent of H1.
- **H2 = chapter** — the active H2 is threaded into the running header (left, plain text, no
  graphic element).
- **H3+** = subsections.
- **Visual language** (all sans-serif — `Source Sans 3`, *not* Source Serif): H1 and the
  "Inhalt" label are semibold; H2/H3+ use the Book weight (`wght` 450). Headings are
  left-aligned (ragged, `justify: false`); only H1 is centered. **H2 gets a 3 pt left accent bar
  plus a fine full-width hairline underneath; H3+ a thinner 2 pt bar plus a shorter/lighter
  hairline** (bars `luma(20%)`, hairlines lighter `luma(72%)`/`luma(78%)`). Fonts come from
  `body-font`/`heading-font`/`code-font` (Source + Noto fallbacks). Unordered lists use one small
  drawn square marker at **all** levels (`#set list(marker: …)`); ordered lists keep numbers;
  task items use a checkbox glyph (☐ open, ☒ done, via Noto fallback). Blockquotes are indented
  both sides + italic (`#show quote.where(block: true)`).
- **Conditional TOC**: by default, when `#H2 + #H3 > 5` the document switches to "structured"
  mode — a table of contents over H2/H3 is rendered after the title and each chapter (H2)
  starts on a new page. At or below the threshold it stays compact (no TOC, chapters inline).
  The `> 5` check lives in **one** helper (`auto-structured()`); `want-toc()` and `want-break()`
  wrap it and let the `toc`/`h2-break` frontmatter override each independently
  (`true`/`false`/`auto`). Edit the helpers, not scattered `> 5` literals. (These count real
  Typst `heading` elements — cmarker emits genuine headings, so `query` works unchanged.)

### Typst show-rule traps (cost real debugging here)

- Inside `#show heading: it => …`, **never realize `it` within a `context` block** — the
  recursion guard does not cross the context boundary and the rule matches its own output
  ("maximum show rule depth exceeded"). Keep `it` in the plain branch; put only
  introspection (`query`, conditional `pagebreak`/`outline`) inside small `context` blocks.
- `outline(title: [..])` renders its title as a *heading*, which re-triggers the heading
  show rule → recursion. Use `outline(title: none)` and render the "Inhalt" label as plain
  text.
- The **full-width table** show rule rebuilds the table (`columns: (1fr,)*n`) to stretch it,
  centered/bold header, left body, zebra `fill`. Emitting a `table` inside `#show table:`
  recurses → guard on a field the rebuild sets but cmarker never does: `if it.fill != none {
  it } else { …rebuild… }`. `it.columns` is an int from cmarker (`(1fr,)*n` needs that count).

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
