---
name: nanobanana
description: Generate, edit, and restore images using Gemini CLI with the Nano Banana extension. Use when users request image generation, edits, icons, patterns, diagrams, or visual storytelling.
---

# Nano Banana images with Gemini CLI

## Overview

Use Gemini CLI plus the Nano Banana extension to generate and edit images via slash commands. Outputs are saved to `./nanobanana-output/` for review or delivery.

## Prerequisites

- Confirm Gemini CLI is installed: `gemini --version`
- Confirm the extension is installed: `gemini extensions install https://github.com/gemini-cli-extensions/nanobanana`
- Ensure an API key is set: `NANOBANANA_GEMINI_API_KEY`, `NANOBANANA_GOOGLE_API_KEY`, `GEMINI_API_KEY`, or `GOOGLE_API_KEY`
- Optional: set `NANOBANANA_MODEL=gemini-3-pro-image-preview` for Nano Banana Pro
- If MCP tools are blocked by policy, run with approvals: `gemini --approval-mode yolo -p "..."` or allow the MCP server with `--allowed-mcp-server-names nanobanana`

## Workflow

1. Identify the request type (generate, edit, restore, icon, pattern, story, diagram).
2. Ensure any input images are in the current directory or the extension search paths.
3. Start Gemini CLI in the working directory: `gemini` (or use `gemini --approval-mode yolo -p "..."` for one-shot runs)
4. Run the appropriate command:
   - `/generate "prompt" --count=3 --styles="watercolor,sketch"`
   - `/edit input.png "instruction" --preview`
   - `/restore old_photo.jpg "instruction"`
   - `/icon "prompt" --sizes="64,128,256"`
   - `/pattern "prompt" --type="seamless"`
   - `/story "prompt" --steps=4`
   - `/diagram "prompt" --type="architecture"`
   - `/nanobanana "freeform instruction"`
5. Collect outputs from `./nanobanana-output/` and share the file paths.

## Troubleshooting

- If `generate_image` is denied by policy, re-run with `--approval-mode yolo` or allow MCP server `nanobanana`.
- If you see `No valid API key found`, set `NANOBANANA_GEMINI_API_KEY` (or `NANOBANANA_GOOGLE_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_API_KEY`) and retry.

## Prompting Guidance

- Specify subject, style, medium, lighting, composition, color palette, and constraints.
- For consistent series, repeat style and include specific variation goals.
- Use `--count`, `--styles`, and `--variations` for systematic exploration.
- Use `--preview` only when interactive output is desired.

## Files and Tools

- Use `scripts/example.py` to list output images or fetch the newest output.
- Use `references/api_reference.md` for command options and file-handling details.
- Use `assets/example_asset.txt` as a prompt template.
