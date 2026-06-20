# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A document-rendering pipeline, **not** a Python project — the Python conventions in the
parent `~/GitHub/CLAUDE.md` (uv/ruff/mypy/pytest) do **not** apply here. What does apply
from that file: GitHub Flow branching, CalVer versioning, and Conventional Commits
(English, no AI co-author trailers). Author identity in this repo is `jcmx9`.

The pipeline turns a Markdown file into a corporate-styled **PDF/A-3b**:

```
Markdown → Pandoc (-t typst, custom template, Lua filter) → .typ → Typst → PDF/A-3b
```

## Commands

```bash
bash scripts/build.sh                 # build example.md → example.pdf (next to source)
bash scripts/build.sh SRC.md          # → SRC.pdf  (or DATE_SRC.pdf if frontmatter has date:)
bash scripts/build.sh SRC.md OUT.pdf  # explicit output
RFD_NO_OPEN=1 bash scripts/build.sh SRC.md   # suppress the auto-open (build.sh opens the PDF by default)
bash scripts/fetch-fonts.sh           # (re)download the bundled fonts into ./fonts (Source OTF + Noto fallbacks)
bash scripts/install.sh               # set up tools + fonts + right-click + rf-document CLI (idempotent)
bash scripts/install.sh --uninstall   # remove the right-click integration + rf-document
rf-document SRC.md                    # global CLI after install (wrapper → build.sh)
TYPST=/path/to/typst bash scripts/build.sh ...       # override the typst binary (e.g. to test a version)
# Lint ALL shell scripts (PowerShell has no runner here — review only):
shellcheck scripts/build.sh scripts/fetch-fonts.sh scripts/install.sh scripts/bootstrap.sh scripts/rfd-convert.sh
```

There is **no test suite**. Verification is **visual**: render pages to PNG and inspect them.
Render fixtures live in the root: `example.md` (default build target), `showcase.md` and
`long-example.md` (exercise the structured/TOC mode, `#H2 + #H3 > 5`), `faust.md` (a
large real-world document), and `example_special-characters.md` (exercises the emoji/symbol
glyph fallback). Use these to eyeball layout changes; their `*.pdf` are git-ignored.

```bash
pandoc SRC.md -f markdown -t typst -s --template template.typ \
  --lua-filter filters/meta-from-h1.lua --syntax-highlighting pygments -o _tmp.typ
typst compile _tmp.typ --font-path fonts --ignore-system-fonts \
  --input filename=OUT.pdf --input logo=logo.svg --input source=SRC.md \
  --input date= --input toc=auto --input "h2-break=auto" --input showname=true \
  --format png --ppi 120 preview-{p}.png
# then open / Read the preview-*.png, then clean up scratch files
# (`preview-*.png` is the git-ignored scratch name — other PNG names show up in `git status`)
```

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
- Fonts are **bundled variable OTFs (CFF2)** in `fonts/` (Source Serif 4 / Sans 3 / Code Pro,
  each Roman/Upright + Italic) and used via `--font-path fonts --ignore-system-fonts`
  (reproducible). They come from the **Adobe** upstream releases, fetched by `fetch-fonts.sh`
  (and `install.ps1`): `google/fonts` only ships these families as TTF — variable OTF exist
  only at Adobe. Typst's *embedded* math font still works under `--ignore-system-fonts`, so
  math renders without bundling a math font.
- **Glyph fallback for emoji/symbols** — `fonts/` also bundles two monochrome OFL fonts,
  `Noto Emoji` (variable TTF) and `Noto Sans Symbols 2`, fetched from `google/fonts` (TTF is
  fine — the OTF rule was Source-specific). `template.typ` appends them to every font list
  (`("SourceSans3VF", "Noto Emoji", "Noto Sans Symbols 2")` via `body-font`/`heading-font`/
  `code-font`), so Typst falls back **per glyph**: text stays fully Source, only characters
  Source lacks render from Noto. **Why this matters:** `--ignore-system-fonts` blocks any
  system fallback, and PDF/A-3b *aborts* on a missing glyph (`error: the text "🚀" could not
  be displayed`). Color emoji fonts are not PDF/A-embeddable, so the fallbacks are monochrome
  (which also matches the design). Coverage isn't 100 % — a glyph absent from all three (e.g.
  `⁃` U+2043) still hard-errors; `example_special-characters.md` doubles as a coverage probe.
- **Font-family names differ by family**: the variable OTF expose `Source Serif 4` but
  `SourceSans3VF` and `SourceCodeVF` (internal VF names, *not* "Source Sans 3" / "Source Code
  Pro"). `template.typ` must reference exactly those names. Verify what Typst sees with
  `typst fonts --font-path fonts --ignore-system-fonts`.

## Architecture

- **`template.typ`** owns the entire layout (DIN A4, margins, header/footer, fonts, heading
  rules, TOC, footnotes). It is a *Pandoc* template: Pandoc fills `$body$` / `$if(...)$`,
  then Typst compiles it. Runtime values (`filename`, `logo`, `source`, plus the
  frontmatter-derived `date`, `toc`, `h2-break`, `showname`) are passed as `typst --input`
  and read via `sys.inputs`, **not** through Pandoc. Frontmatter must go through `--input`
  (not Pandoc `$if$`) because Pandoc's `$if(x)$` cannot tell a YAML bool `false` from
  "unset" — that collapses the three states `toc`/`h2-break` need (`true`/`false`/`auto`).
- **Optional YAML frontmatter** (parsed by `build.sh`/`convert.ps1`, *not* read from Pandoc
  metadata): `date:` (ISO) → ISO-prefixes the output file (`2026-06-19_name.pdf`) **and**
  shows a `lang`-localized date in the footer right; `toc:`/`h2-break:` true|false override
  the `> 5` automatism; `filename:` true|false toggles the footer-left name. The footer is
  2-col without a date (name | page) and 3-col with one (name | page centered | date).
  The three bool keys are parsed **YAML-1.1-tolerant** (case-insensitive
  `true/false/yes/no/on/off`, quotes, inline comments via `yaml_bool`/`ConvertTo-YamlBool`);
  an unrecognized value warns and keeps the default instead of failing silently.
  Typst does not localize month names (`[month repr:long]` is English only) → a manual
  `months-de` array lives in `template.typ`; `fmt-date` validates the ISO string defensively
  because an invalid `datetime`/`int()` *panics* and aborts the whole build.
- **Pandoc-template `$` trap:** Pandoc processes the *entire* `template.typ` (it has no notion
  of Typst comments), so any literal `$` — even inside a `//` comment or a `regex("…$")` —
  must be written `$$`, or the Pandoc step fails. The date regex in `fmt-date` relies on this.
- **`filters/meta-from-h1.lua`** sets the PDF/A title from the H1 and **enforces exactly one
  H1** (errors otherwise) — H1 is the document title. It also handles **task lists**: Pandoc
  renders `- [ ]`/`- [x]` as a normal list whose items start with ☐/☒, which together with the
  template's square bullet would show two markers; the filter wraps a pure task list in
  `#[ #set list(marker: none) … ]` so only the checkbox remains. It also **strips remote
  images**: Typst has no network access, so a `image("https://…")` hard-errors (`network
  access is not supported`); the filter drops any `http(s)://` image (we build offline) and
  removes a link left empty by the removal (the common `[![alt](img)](url)` pattern). Local
  images are untouched.
- **`scripts/build.sh`** (macOS/Linux) and **`scripts/convert.ps1`** (Windows) are the
  conversion entry points. They resolve the logo (`logo.svg → .png → .jpg`, optional), run
  pandoc then typst, and emit PDF/A-3b with the source Markdown embedded (`pdf.attach`).
  `build.sh` writes the PDF **next to the source** (not the repo root, which it `cd`s into for
  template/fonts) unless an explicit second arg is given, and passes `typst --root /` with an
  **absolute** `source=` so the attach works for sources anywhere on disk (Typst sandboxes
  reads to its root and treats `/…` as root-relative). `convert.ps1` instead works in the
  source dir (intermediate `.typ` there, logo copied in, `source=` as leaf).
  - **Relative paths:** because `build.sh` `cd`s into the project root, it records `orig_pwd`
    **before** the `cd` and resolves a relative source/output argument against it (`resolve_from_pwd`).
    Without this, `rf-document foo.md` from any other directory failed with "file not found".
  - **Auto-open:** after a successful build both scripts open the PDF in the default viewer
    (`open`/`xdg-open`/`Start-Process`); set `RFD_NO_OPEN=1` to suppress (batch/cron).
- **Install / bootstrap** (separate from conversion):
  - `scripts/bootstrap.sh` / `scripts/bootstrap.ps1` are the curl|bash / irm|iex one-liners:
    require git, clone/pull into `~/.local/share/real-fast-document` (Windows
    `%LOCALAPPDATA%\real-fast-document`), then run the installer.
  - `scripts/install.sh` (macOS/Linux) ensures pandoc + typst (≥0.15) via the system package
    manager — **typst falls back to the official GitHub binary into `./bin`** when no PM
    package exists (Linux) — fetches fonts, and installs the right-click integration:
    a Finder **Quick Action** (`~/Library/Services/*.workflow`) on macOS, a `.desktop` +
    `xdg-mime` association on Linux. `--uninstall` removes only the integration. Idempotent.
  - `scripts/install.ps1` (Windows) auto-installs pandoc/typst via winget (`-Tools`), fetches
    fonts, and creates the "Send to" shortcut (`-SendTo`). The logic stays in the install
    path; only a shortcut lands in the system.
  - `scripts/rfd-convert.sh` is the dispatcher the macOS/Linux right-click calls: it loops
    `build.sh` over the files (output next to source) and posts a success/fail notification
    (osascript / notify-send).
  - **`rf-document`** is the global terminal command: `install.sh` writes a wrapper to
    `~/.local/bin/rf-document` (macOS/Linux), `install.ps1` a `rf-document.cmd` shim into
    `%LOCALAPPDATA%\Microsoft\WindowsApps` (on PATH by default). It just calls the converter.
  - **GUI-PATH gotcha:** Finder Quick Actions / `.desktop` launches do **not** inherit the
    shell `PATH`, so a `typst`/`pandoc` in `~/.local/bin` or `/opt/homebrew/bin` is invisible
    and the build fails with `command not found`. `install.sh` therefore records the real tool
    dirs (resolved while PATH is correct) in `bin/rfd-tools.env`; `rfd-convert.sh` and the
    `rf-document` wrapper source it and prepend `RFD_TOOL_PATH`. `bin/` is git-ignored.
  - **pandoc highlight flag differs by version:** newer pandoc uses `--syntax-highlighting`,
    older (e.g. Debian-stable 3.1.x) only `--highlight-style`. `build.sh`/`convert.ps1` detect
    which exists and pick accordingly — don't hardcode one.
  - `install.sh` shell notes: never hardcode `sudo` (use the `run_priv` helper — works as root
    or without sudo); avoid `trap … RETURN` referencing a local under `set -u` (it fires
    unbound — use explicit cleanup).

### Heading / document model (encoded in template.typ)

- **H1 = document title** (exactly one, centered, excluded from header and TOC).
- **H2 = chapter** — the active H2 is threaded into the running header (left, plain text, no
  graphic element).
- **H3+** = subsections.
- **Visual language** (all sans-serif now — `Source Sans 3`, *not* Source Serif): H1 and the
  "Inhalt" label are semibold; H2/H3+ use the Book weight (`wght` 450). Headings are
  left-aligned (ragged, `justify: false`); only H1 is centered. H2 gets a 1 pt frame + a 3 pt
  left accent bar, H3+ only the 3 pt bar (both `luma(20%)`). Fonts come from `body-font`/
  `heading-font`/`code-font` (Source + Noto fallbacks). Unordered lists use one small drawn
  square marker at **all** levels (`#set list(marker: …)`); ordered lists keep numbers.
  Blockquotes are indented both sides + italic (`#show quote.where(block: true)`).
- **Conditional TOC**: by default, when `#H2 + #H3 > 5` the document switches to "structured"
  mode — a table of contents over H2/H3 is rendered after the title and each chapter (H2)
  starts on a new page. At or below the threshold it stays compact (no TOC, chapters inline).
  The `> 5` check lives in **one** helper now (`auto-structured()`); `want-toc()` and
  `want-break()` wrap it and let the `toc`/`h2-break` frontmatter override each independently
  (`true`/`false`/`auto`). Edit the helpers, not scattered `> 5` literals.

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
  recurses → guard on a field the rebuild sets but Pandoc never does: `if it.fill != none {
  it } else { …rebuild… }`. `it.columns` is an int from Pandoc (`(1fr,)*n` needs that count).

## Release flow

GitHub Flow: `feature/*` → PR → squash-merge to `main`, then fast-forward `dev` to `main`.
CalVer `YY.M.MICRO` in `VERSION` + `CHANGELOG.md`; tag `vX` and create a GitHub release.

When scripting a merge+tag+release, **verify the merge landed in `main` before tagging**
(`gh pr merge` can return "not mergeable" right after a push while GitHub recomputes
mergeability; a `set -e`-less script will otherwise tag the wrong commit). Poll
`gh pr view N --json mergeable` until `MERGEABLE` first.

The README is dogfooded: `bash scripts/build.sh README.md README.pdf` renders it through
the pipeline, and that PDF is attached to GitHub releases as an asset (it is not committed).

Generated artifacts (`*.pdf`, generated `*.typ`, `preview-*.png`, and `bin/` — the
installer's bundled typst + `rfd-tools.env`) are git-ignored —
note only `preview-*.png` matches, so scratch PNGs under any other name pollute
`git status`. `build.sh` leaves the Pandoc intermediate as `<base>.typ` in the root
(e.g. `example.typ`), itself git-ignored by `*.typ`.
`template.typ` is the one tracked `.typ`. `.gitignore` globs `*.typ` are dangerous with
`rm` — clean scratch with `find . -maxdepth 1 -name '*.typ' ! -name 'template.typ' -delete`.

The user's **global** excludesfile (`~/.gitignore`) ignores `CLAUDE.md` (and possibly other
names) across all repos: silently-ignored new files never appear in `git status`, so
`git add` skips them without error. Use `git check-ignore -v <file>` to diagnose and
`git add -f <file>` to track an intentionally-ignored file (`CLAUDE.md` is already tracked
here, so further edits commit normally).
