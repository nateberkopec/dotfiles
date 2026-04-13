# Nano Banana Gemini CLI Extension Reference

## Installation

- Install: `gemini extensions install https://github.com/gemini-cli-extensions/nanobanana`
- Extension path: `~/.gemini/extensions/nanobanana`
- Restart Gemini CLI after installation.
- If MCP tools are blocked, run with `--approval-mode yolo` or `--allowed-mcp-server-names nanobanana`.

## Authentication Environment Variables

Set one of the following:

- `NANOBANANA_GEMINI_API_KEY` (preferred for Gemini API)
- `NANOBANANA_GOOGLE_API_KEY` (preferred for Vertex API)
- `GEMINI_API_KEY` (fallback)
- `GOOGLE_API_KEY` (fallback)

## Model Selection

- Default: `gemini-2.5-flash-image`
- Nano Banana Pro: set `NANOBANANA_MODEL=gemini-3-pro-image-preview`

## Commands

### One-shot usage example

`gemini --approval-mode yolo -p "/generate \"a coiled emerald green snake on a mossy rock\" --count=1"`

### `/generate` (text-to-image)

Options:
- `--count=N` (1-8)
- `--styles="style1,style2"`
- `--variations="var1,var2"`
- `--format=grid|separate`
- `--seed=123`
- `--preview`

### `/edit` (edit existing image)

- `/edit input.png "instruction" --preview`

### `/restore` (restore existing image)

- `/restore input.jpg "instruction" --preview`

### `/icon`

Options:
- `--sizes="16,32,64,128"`
- `--type="app-icon|favicon|ui-element"`
- `--style="flat|skeuomorphic|minimal|modern"`
- `--format="png|jpeg"`
- `--background="transparent|white|black|color"`
- `--corners="rounded|sharp"`

### `/pattern`

Options:
- `--size="256x256"`
- `--type="seamless|texture|wallpaper"`
- `--style="geometric|organic|abstract|floral|tech"`
- `--density="sparse|medium|dense"`
- `--colors="mono|duotone|colorful"`
- `--repeat="tile|mirror"`

### `/story`

Options:
- `--steps=N`
- `--type="story|process|tutorial|timeline"`
- `--style="consistent|evolving"`
- `--layout="separate|grid|comic"`
- `--transition="smooth|dramatic|fade"`
- `--format="storyboard|individual"`

### `/diagram`

Options:
- `--type="flowchart|architecture|network|database|wireframe|mindmap|sequence"`
- `--style="professional|clean|hand-drawn|technical"`
- `--layout="horizontal|vertical|hierarchical|circular"`
- `--complexity="simple|detailed|comprehensive"`
- `--colors="mono|accent|categorical"`
- `--annotations="minimal|detailed"`

### `/nanobanana`

- `/nanobanana "freeform instruction"`

## File Handling

- Input search paths: current directory, `./images/`, `./input/`, `./nanobanana-output/`, `~/Downloads/`, `~/Desktop/`
- Output directory: `./nanobanana-output/`
