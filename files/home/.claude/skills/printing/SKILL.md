---
name: printing
description: Print files or selected pages, check printer status, or troubleshoot printing problems.
---

# Printing

## Defaults

- Use the system default printer
- Use A4, fit to printable area, and one copy
- Use black-and-white unless color is requested or meaningful.
- Preserve configured Draft quality
- Change persistent printer settings only with explicit permission.

## Normal workflow

- Preview generated or resized documents before printing, checking both paper dimensions and artwork size.
- Discover the default printer with `lpstat -d` once per session and inspect capabilities only for unfamiliar options.
- Submit once with `lp`, using `-o media=A4 -o fit-to-page -n 1` and `-o ColorModel=Gray` for monochrome.

## Known pitfalls

- Select A4 even when the source PDF is Letter, unless the document itself is some kind of form (e.g. IRS) which probably must be printed on Letter. Alert the user to load the correct paper in that case, I usually have A4 in the hopper.
- Enlarge artwork without ImageMagick’s shrink-only `>` flag, trimming excessive whitespace while preserving aspect ratio and printable margins.
- Use `pdftoppm` for PDF previews rather than ImageMagick’s Ghostscript-dependent PDF reader.
- Prefer available command-line tools over introducing dependencies.

## Troubleshooting

- Cancel only the relevant job and inspect cancellation errors rather than silently suppressing them.
- Distinguish queued, processing, and physically printed instead of treating queue acceptance as completion.
- Treat CUPS idle/enabled status as queue state, not proof that the printer is powered on or reachable.
