#!/usr/bin/env python3
"""
List Nano Banana output images.

Examples:
  scripts/example.py
  scripts/example.py --latest
  scripts/example.py --dir ./nanobanana-output
"""

from __future__ import annotations

import argparse
from pathlib import Path

IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}


def find_images(output_dir: Path) -> list[Path]:
    images = [
        path
        for path in output_dir.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES
    ]
    return sorted(images, key=lambda path: path.stat().st_mtime, reverse=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="List Nano Banana output images")
    parser.add_argument(
        "--latest",
        action="store_true",
        help="Print only the newest image path",
    )
    parser.add_argument(
        "--dir",
        default="nanobanana-output",
        help="Directory containing generated images",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_dir = Path(args.dir).expanduser().resolve()

    if not output_dir.exists():
        print(f"No directory found: {output_dir}")
        return 1

    images = find_images(output_dir)
    if not images:
        print(f"No images found in {output_dir}")
        return 1

    if args.latest:
        print(images[0])
        return 0

    for image in images:
        print(image)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
