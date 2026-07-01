# Changelog

All notable changes to this project are documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [CalVer](https://calver.org/) (`YY.M.MICRO`).

## [Unreleased]

## [26.7.0] - 2026-07-01

### Changed
- **Pipeline reworked: Pandoc is gone.** Markdown is now converted to Typst by the
  **cmarker** package (with **mitex** for math) directly inside Typst:
  `Markdown → Typst (template.typ → cmarker) → PDF/A-3b`. `template.typ` is now a plain
  Typst file (no longer a Pandoc template) that renders the body itself via
  `cmarker.render(read(source))`. Removes the Pandoc, pygments and Lua-filter dependencies;
  code syntax highlighting is now native to Typst. The intermediate `.typ` scratch file and
  its cleanup trap are gone.
- **Packages vendored for offline builds.** cmarker + mitex are fetched into `vendor/`
  (git-ignored) by `scripts/fetch-typst-packages.sh` and imported by relative path, so builds
  need no registry access — consistent with the bundled fonts.
- **Headings restyled.** The framed H2 box is replaced by a 3 pt left accent bar plus a fine
  full-width hairline; H3+ use a thinner 2 pt bar with a shorter hairline (lighter, better
  delineated).
- **Frontmatter key `filename` renamed to `print_filename`** (toggles the footer-left filename;
  same default `true`). New `lang` frontmatter key controls the document language/date format.
- Local image paths are now resolved **relative to the document** (via a `docdir` input), so
  images next to documents anywhere on disk are found.
- The PDF/A document title (required by PDF/A) is now the `.md` basename.

### Added
- `scripts/fetch-typst-packages.sh` and an `Install-TypstPackages` step in `install.ps1` /
  `-Packages` switch — vendor cmarker + mitex into `vendor/`.
- Build-time Markdown preprocessing (in `build.sh` / `convert.ps1`): Pandoc-style definition
  lists are converted to HTML `<dl>`, and loose task lists are normalized to tight (works around
  a cmarker 0.1.9 crash on blank-separated task items).

### Removed
- **The single-H1 requirement.** H1 is optional now and no longer enforced; a `# H1` is rendered
  as the centered title.
- `filters/meta-from-h1.lua` (its jobs are now handled by cmarker, the template's `safe-image`
  scope override, and build-time preprocessing). Pandoc and pygments are no longer dependencies.

## [26.6.18] - 2026-06-22

### Fixed
- Task lists **mixed** with normal bullets in a single list now render correctly. The Lua
  filter previously suppressed the list marker only when *every* item was a task (`- [ ]` /
  `- [x]`); a list with both normal items and tasks kept the square marker, so task items
  showed both the square **and** the checkbox. The filter now triggers on **any** task item
  in the list and re-adds the template marker (`#rfd-list-marker`, newly exported by
  `template.typ`) to the non-task items, so normal bullets keep their square while tasks show
  only the checkbox. The checkbox matcher is also prefix-based now (tolerates Pandoc emitting
  the box glyph and trailing text in one `Str`).

## [26.6.17] - 2026-06-22

### Fixed
- `convert.ps1` is now pure ASCII. A single en-dash (`–`, U+2013) in a `Write-Host`
  string broke the script under Windows PowerShell 5.1: BOM-less `.ps1` files are read
  in the ANSI code page (CP1252), where the en-dash's last UTF-8 byte (`0x93`) decodes
  to a typographic quote (`"`, U+201C) that PowerShell treats as a string delimiter —
  yielding an unterminated string and a parser error, so "Send to" produced no PDF.
  `.ps1` scripts must stay ASCII-only.

## [26.6.16] - 2026-06-21

### Fixed
- `build.sh` now removes the Pandoc intermediate `<base>.typ` (e.g. `example.typ`,
  `README.typ`) after every run via an `EXIT` trap — previously it was left behind in
  the project/install directory after each conversion. The trap fires on failures too
  and never touches the tracked `template.typ`. (`convert.ps1` already cleaned up via a
  `finally` block.)
- `install.ps1` now escapes wildcard characters in the font-download target path
  (`WildcardPattern::Escape`) before passing it to `Invoke-WebRequest -OutFile`. The
  brackets in `NotoEmoji[wght].ttf` were read as a wildcard pattern, so the Windows
  bootstrap aborted with "resolved wildcard path does not specify a file". macOS/Linux
  were unaffected (`curl -o` writes the literal name).

## [26.6.15] - 2026-06-20

### Docs
- CLAUDE.md: corrected the release-flow note — the repo keeps both `main` and `dev`
  (`dev` is fast-forwarded to `main` after merge); a previous edit had wrongly claimed
  there is no `dev` branch. Added a note distinguishing the `~/GitHub` development repo
  from the `~/.local/share` bootstrap installation.

## [26.6.14] - 2026-06-20

### Docs
- Both READMEs now explain the structure automatism in the frontmatter section: the
  `#H2 + #H3 > 5` heuristic switches between structured mode (TOC + chapter page
  breaks) and compact mode, and `toc`/`h2-break` override the two effects
  individually (the `h2-break` default was previously left unexplained).
- CLAUDE.md: documented the skipped-remote-image reporting (build.sh/convert.ps1
  summary line + rfd-convert.sh notification), corrected the release flow (no `dev`
  branch), and noted the README parity rule.

## [26.6.13] - 2026-06-20

### Docs
- Both READMEs now document the image handling shipped in 26.6.12: local captioned
  figures and the automatic stripping of remote images (`http(s)://`, `//host`,
  `data:`) when building offline, plus the skip count the build reports. Added task
  lists to the Markdown quick-start, an Images row to the layout spec, and refreshed
  the `meta-from-h1.lua` description (also fixing a de/en parity gap where only the
  English README mentioned task lists).

## [26.6.12] - 2026-06-20

### Added
- Build scripts report how many remote images were skipped: `build.sh` and
  `convert.ps1` print a hint, and the right-click dispatcher (`rfd-convert.sh`)
  includes the count in its system notification.

### Changed
- Consolidated the render fixtures into a single full `example.md` — structured/TOC
  mode, task lists, tables, math, the emoji/symbol fallback, a local captioned
  figure, and a remote image that gets stripped. Removed `showcase.md`,
  `long-example.md`, `faust.md` and `example_special-characters.md`.

### Fixed
- Remote-image stripping no longer leaves artefacts: an empty paragraph, an empty
  link, or a lone `![caption](url)` whose caption would survive as a ghost figure
  are now removed too. Stripping also covers protocol-relative (`//host/…`) and
  `data:` image sources, not just `http(s)://`.

## [26.6.11] - 2026-06-20

### Fixed
- Remote images (`http(s)://` sources) no longer abort the build. Typst has no
  network access, so an `image("https://…")` hard-errors (`network access is not
  supported`); the Lua filter now strips remote images (we build offline) and
  drops a link left empty by the removal (the common `[![alt](img)](url)`
  pattern). Local images are untouched.

## [26.6.10] - 2026-06-20

### Added
- English README parity: `README.en.md` mirrors `README.md` (cross-linked at the
  top of each).

### Docs
- README updated for the latest layout: square list bullets, task-list checkbox
  handling, italic indented quotes, plain running-header chapter (no accent bar),
  Noto emoji/symbol fallback, and the `example_special-characters.md` fixture.

## [26.6.9] - 2026-06-20

### Changed
- Blockquotes are now visually distinct: indented on both sides (narrower than
  the text block) and italic.
- The running header shows the current chapter as plain text — the small accent
  bar before it was removed (heading accent bars are unchanged).

### Fixed
- Task lists (`- [ ]` / `- [x]`) no longer show the square list bullet **and** the
  checkbox; the Lua filter renders pure task lists without a list marker, leaving
  only the checkbox.

### Docs
- `CLAUDE.md` updated for the 26.6.6–26.6.9 features (sans-serif layout, accent
  bars, square bullets, heading alignment, auto-open, relative-path resolution,
  YAML-1.1 booleans, Noto emoji/symbol fallback, task-list handling, quotes).

## [26.6.8] - 2026-06-20

### Changed
- Unordered lists now use a single small square marker (drawn, `luma(20%)`) at
  **all** nesting levels, instead of the level-dependent defaults (•/‣/–).
  Ordered lists keep their numbering.

### Added
- `example_special-characters.md` — a fixture/falltest exercising the emoji and
  symbol fallback (emoji, arrows, marks, math symbols, currency, geometry).

## [26.6.7] - 2026-06-20

### Added
- Bundled monochrome fallback fonts **Noto Emoji** and **Noto Sans Symbols 2**
  (OFL, in `fonts/`, fetched by `fetch-fonts.sh` / `install.ps1`). Typst falls
  back per glyph: text stays fully Source, and only characters Source lacks
  (emoji, symbols) render from Noto. This fixes the `PDF/A-3b error: the text …
  could not be displayed with font "SourceSans3VF"` abort on documents with
  emoji/symbols (e.g. Obsidian notes), without dropping `--ignore-system-fonts`.

## [26.6.6] - 2026-06-20

### Added
- The generated PDF now opens automatically in the default viewer after a
  successful build (terminal and right-click, all three platforms). Set
  `RFD_NO_OPEN=1` to disable it for batch/cron runs.

### Changed
- Fresher, fully sans-serif look: headings now use Source Sans 3 instead of
  Source Serif 4 (body and code unchanged). H1 and the "Inhalt" label stay
  semibold; H2/H3+ use the Book weight (`wght` 450). H2 gets a thin 1 pt frame
  plus a 3 pt accent bar on the left, H3+ just the 3 pt left bar (both 80 % grey)
  — the same bar repeats before the chapter name in the running header, whose
  font size grows by 2 pt (11 → 13 pt). Headings are left-aligned (ragged, never
  justified); only the H1 title is centered.

### Fixed
- `build.sh` resolved a relative source/output path against the project root
  (which it `cd`s into for template/fonts) instead of the caller's directory, so
  `rf-document foo.md` from any other folder failed with "file not found". Paths
  are now resolved against the invocation directory before the `cd`.
- Frontmatter booleans (`toc`, `h2-break`, `filename`) only accepted exact
  lowercase `true`/`false` and fell back to the default *silently* for anything
  else. They now parse the full YAML-1.1 boolean set case-insensitively
  (`true`/`false`/`yes`/`no`/`on`/`off`, quoted values, inline comments) in both
  `build.sh` and `convert.ps1`, and warn on an unrecognized value instead of
  ignoring it silently.

## [26.6.5] - 2026-06-19

### Added
- Cross-platform install/setup: one-line bootstrap (`bootstrap.sh` via curl|bash,
  `bootstrap.ps1` via irm|iex) clones into `~/.local/share/real-fast-document`
  (Windows `%LOCALAPPDATA%`) and runs the installer. `install.sh` (macOS/Linux)
  installs pandoc/typst via the system package manager — with an official typst
  binary fallback into `./bin` when no package exists — fetches fonts, and sets
  up a right-click action (Finder Quick Action / `.desktop` + xdg-mime).
  `install.ps1` gains `-Tools` (pandoc/typst via winget). `rfd-convert.sh` is the
  macOS/Linux right-click dispatcher (output next to source, desktop notification).
- Optional YAML frontmatter (parsed by `build.sh`/`convert.ps1`): `date:` (ISO)
  ISO-prefixes the output file (`2026-06-19_name.pdf`) and shows a `lang`-localized
  date in the footer right; `toc:` and `h2-break:` (true|false) override the
  `#H2 + #H3 > 5` automatism independently; `filename:` (true|false) toggles the
  footer-left name. Footer is 2-column without a date, 3-column with one
  (name · page centered · date).
- `faust.md` — Goethe's *Faust I* as a large structured-mode example (158-page
  PDF/A; verse via Pandoc line blocks, scenes as H2). Public domain, sourced
  from Project Gutenberg (eBook #2229).

### Changed
- `build.sh` now writes the PDF **next to the source file** (not the repo root)
  unless an explicit output path is given, matching the Windows converter.
- Typography/layout overhaul: body 12 pt with looser leading and hyphenation,
  softer body gray (`luma(13%)`), rescaled heading modular scale, margins now
  left 30 mm / top·bottom·right 20 mm, header logo height 13 mm (fits the
  narrower top margin).

### Changed
- Bundled fonts switched from variable **TTF** (Google Fonts) to variable
  **OTF/CFF2** (Adobe upstream releases): Source Serif 4 (4.005R), Source Sans 3
  (3.052R), Source Code Pro (1.026vf), each Roman/Upright + Italic.
  `fetch-fonts.sh` / `install.ps1` now download the Adobe release zips and
  extract the variable OTF. `template.typ` references the OTF family names
  (`SourceSans3VF`, `SourceCodeVF`; Serif stays `Source Serif 4`).

## [26.6.4] - 2026-06-15

### Changed
- `CLAUDE.md`: document the global `~/.gitignore` trap (silently-ignored files,
  `git check-ignore -v` / `git add -f`) and the dogfooded README (rendered
  through the pipeline and attached to releases).

## [26.6.3] - 2026-06-15

### Added
- `CLAUDE.md` — architecture, commands and Typst pitfalls for contributors and
  Claude Code; referenced from the README structure list.

## [26.6.2] - 2026-06-15

### Changed
- The logo is now **optional**: if no `logo.svg`/`.png`/`.jpg` is found, the
  build continues with a notice instead of aborting, and the header is rendered
  without a logo (right side empty). Affects `build.sh`, `convert.ps1` and
  `template.typ`.

## [26.6.1] - 2026-06-15

### Changed
- Heading model: **H1 = document title** (enforced to occur exactly once via the
  Lua filter), **H2 = chapter** shown in the running header (previously H1),
  H3+ = subsections.
- Conditional **table of contents**: when `#H2 + #H3 > 5`, the template renders a
  TOC (over H2/H3) and starts each chapter (H2) on a new page; below the
  threshold it stays compact (no TOC, chapters inline).
- Title centered with extra spacing; TOC rendered lighter — entries at 14 pt in
  book weight (`wght` 450) instead of bold; differentiated H4–H6 sizes.

## [26.6.0] - 2026-06-15

### Added
- Markdown → Pandoc → Typst → PDF/A-3b build pipeline (`scripts/build.sh`).
- Typst layout template (`template.typ`): DIN A4 portrait, margins
  top 40 mm / left 30 mm / right 20 mm / bottom 30 mm.
- Dynamic running header showing the H1 chapter active at the top of the page,
  with the logo (25 mm high) right-aligned to the right margin. The logo file is
  resolved as `logo.svg` → `logo.png` → `logo.jpg` (first match).
- Footer with source filename (left) and `Seite x / y` (right);
  separator rules below the header text and above the footer text.
- Footnotes rendered with a hanging indent (marker hangs, wrapped lines indent).
- Fonts: bundled **variable** Source fonts (requires Typst >= 0.15) — headings
  in Source Serif 4 (semibold via the `wght` axis, 80 % black), body in
  Source Sans 3, code in Source Code Pro. `build.sh` enforces the Typst version.
- Lua filter (`filters/meta-from-h1.lua`) deriving the PDF/A document title
  from the first H1.
- Source Markdown embedded as an attachment (`pdf.attach`,
  `AFRelationship /Source`), made possible by PDF/A-3b.
- Font bundling script (`scripts/fetch-fonts.sh`) collecting the variable
  Source fonts into `./fonts`.
- Windows setup (`scripts/install.ps1`): downloads the variable Source fonts into
  the project and registers an Explorer "Send to" shortcut that converts a `.md`
  to PDF/A next to the source. Conversion logic stays in the install path
  (`scripts/convert.ps1`); only the shortcut is placed in the system.
- Example documents `example.md`, `long-example.md` (multi-chapter header demo)
  and `showcase.md` (full Markdown/Pandoc feature kitchen sink).
