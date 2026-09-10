---
name: printing
description: Print files or selected pages, check printer status, or troubleshoot printing problems.
---

# Printing

## Defaults

- Use the system default printer, currently Canon TS3500, rather than hardcoding a destination.
- Use A4, fit to printable area, and one copy unless requested otherwise.
- Use black-and-white for coloring pages and ordinary documents unless color is requested or meaningful.
- Preserve configured Draft quality instead of overriding it with Normal.
- Change persistent printer settings only with explicit permission.

## Normal workflow

- Identify the exact files or pages requested, keeping content discovery and handout design outside this skill.
- Print existing PDFs directly instead of unnecessarily converting or rebuilding them.
- Download with `curl --fail --location`, validate PDF format, and check page counts before submission.
- Preview generated or resized documents before printing, checking both paper dimensions and artwork size.
- Discover the default printer with `lpstat -d` once per session and inspect capabilities only for unfamiliar options.
- Submit once with `lp`, using `-o media=A4 -o fit-to-page -n 1` and `-o ColorModel=Gray` for monochrome on the Canon.
- Report “Sent to printer” with the job ID, checking status only when useful or requested.

## Known pitfalls

- Select A4 even when the source PDF is Letter.
- Enlarge artwork without ImageMagick’s shrink-only `>` flag, trimming excessive whitespace while preserving aspect ratio and printable margins.
- Use `pdftoppm` for PDF previews rather than ImageMagick’s Ghostscript-dependent PDF reader.
- Specify `/System/Library/Fonts/Supplemental/Arial.ttf` for ImageMagick contact sheets on this Mac.
- Prefer available command-line tools over introducing Python dependencies.
- Stop on conversion or validation failures before submitting any print job.

## Troubleshooting

- Cancel only the relevant job and inspect cancellation errors rather than silently suppressing them.
- Confirm with the user before reprinting when completion is uncertain to avoid duplicate copies.
- Distinguish queued, processing, and physically printed instead of treating queue acceptance as completion.
- Treat CUPS idle/enabled status as queue state, not proof that the printer is powered on or reachable.
- For E03, consult Canon’s TS3500 jam/open-cover instructions before recommending physical intervention.
- For smearing, check Draft and plain-paper settings first and distinguish local macOS/CUPS defaults from device settings.
