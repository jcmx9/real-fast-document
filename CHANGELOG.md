# Changelog

All notable changes to this project are documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [CalVer](https://calver.org/) (`YY.M.MICRO`).

## [Unreleased]

### Changed
- Fresher, fully sans-serif look: headings now use Source Sans 3 instead of
  Source Serif 4 (body and code unchanged). H1 and the "Inhalt" label stay
  semibold; H2/H3+ use the Book weight (`wght` 450). H2 gets a thin 1 pt frame
  plus a 3 pt accent bar on the left, H3+ just the 3 pt left bar (both 80 % grey)
  — the same bar repeats before the chapter name in the running header, whose
  font size grows by 2 pt (11 → 13 pt).

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
