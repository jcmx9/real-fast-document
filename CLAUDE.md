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
bash scripts/build.sh                 # build example.md → example.pdf
bash scripts/build.sh SRC.md          # → SRC.pdf
bash scripts/build.sh SRC.md OUT.pdf  # explicit output
bash scripts/fetch-fonts.sh           # (re)download the bundled variable fonts into ./fonts
shellcheck scripts/build.sh scripts/fetch-fonts.sh   # lint the shell scripts (PowerShell is untested here)
TYPST=/path/to/typst bash scripts/build.sh ...       # override the typst binary (e.g. to test a version)
```

There is **no test suite**. Verification is **visual**: render pages to PNG and inspect them.

```bash
pandoc SRC.md -f markdown -t typst -s --template template.typ \
  --lua-filter filters/meta-from-h1.lua --syntax-highlighting pygments -o _tmp.typ
typst compile _tmp.typ --font-path fonts --ignore-system-fonts \
  --input filename=OUT.pdf --input logo=logo.svg --input source=SRC.md \
  --format png --ppi 120 _page-{p}.png
# then open / Read the _page-*.png, then clean up scratch files
```

`mutool extract FILE.pdf` (mupdf) pulls the embedded Markdown back out; check PDF/A
conformance with `strings FILE.pdf | grep pdfaid` (Typst 0.15 compresses object streams,
so `grep '/Type /EmbeddedFile'` gives false negatives — use `mutool` to confirm attachments).

## Requirements & environment gotchas

- **Typst ≥ 0.15 is mandatory** — the project uses variable fonts (the `wght` axis gives the
  semibold heading weight). `build.sh` hard-errors below 0.15. Homebrew may still ship 0.14;
  on this machine a 0.15 binary lives at `~/.local/bin/typst` (earlier in `PATH` than brew).
- Fonts are **bundled variable TTFs** in `fonts/` and used via `--font-path fonts
  --ignore-system-fonts` (reproducible). Typst's *embedded* math font still works under
  `--ignore-system-fonts`, so math renders without bundling a math font.

## Architecture

- **`template.typ`** owns the entire layout (DIN A4, margins, header/footer, fonts, heading
  rules, TOC, footnotes). It is a *Pandoc* template: Pandoc fills `$body$` / `$if(...)$`,
  then Typst compiles it. Runtime values (`filename`, `logo`, `source`) are passed as
  `typst --input` and read via `sys.inputs`, **not** through Pandoc.
- **`filters/meta-from-h1.lua`** sets the PDF/A title from the H1 and **enforces exactly one
  H1** (errors otherwise) — H1 is the document title.
- **`scripts/build.sh`** (macOS/Linux) and **`scripts/convert.ps1`** (Windows, via an Explorer
  "Send to" shortcut installed by `scripts/install.ps1`) are the two entry points. They
  resolve the logo (`logo.svg → .png → .jpg`, optional), run pandoc then typst, and emit
  PDF/A-3b with the source Markdown embedded (`pdf.attach`). The Windows logic stays in the
  install path; only a shortcut is placed in the system.

### Heading / document model (encoded in template.typ)

- **H1 = document title** (exactly one, centered, excluded from header and TOC).
- **H2 = chapter** — the active H2 is threaded into the running header (left).
- **H3+** = subsections.
- **Conditional TOC**: when `#H2 + #H3 > 5` the document switches to "structured" mode —
  a table of contents over H2/H3 is rendered after the title and each chapter (H2) starts on
  a new page. At or below the threshold it stays compact (no TOC, chapters inline). The
  threshold is a single `query(heading).filter(...).len() > 5` in `template.typ`.

### Typst show-rule traps (cost real debugging here)

- Inside `#show heading: it => …`, **never realize `it` within a `context` block** — the
  recursion guard does not cross the context boundary and the rule matches its own output
  ("maximum show rule depth exceeded"). Keep `it` in the plain branch; put only
  introspection (`query`, conditional `pagebreak`/`outline`) inside small `context` blocks.
- `outline(title: [..])` renders its title as a *heading*, which re-triggers the heading
  show rule → recursion. Use `outline(title: none)` and render the "Inhalt" label as plain
  text.

## Release flow

GitHub Flow: `feature/*` → PR → squash-merge to `main`, then fast-forward `dev` to `main`.
CalVer `YY.M.MICRO` in `VERSION` + `CHANGELOG.md`; tag `vX` and create a GitHub release.

When scripting a merge+tag+release, **verify the merge landed in `main` before tagging**
(`gh pr merge` can return "not mergeable" right after a push while GitHub recomputes
mergeability; a `set -e`-less script will otherwise tag the wrong commit). Poll
`gh pr view N --json mergeable` until `MERGEABLE` first.

Generated artifacts (`*.pdf`, generated `*.typ`, `_*.png`) are git-ignored;
`template.typ` is the one tracked `.typ`. `.gitignore` globs `*.typ` are dangerous with
`rm` — clean scratch with `find . -maxdepth 1 -name '*.typ' ! -name 'template.typ' -delete`.
