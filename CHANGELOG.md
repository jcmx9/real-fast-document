# Changelog

All notable changes to this project are documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [CalVer](https://calver.org/) (`YY.M.MICRO`).

## [Unreleased]

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
