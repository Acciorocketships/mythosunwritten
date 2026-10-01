#!/usr/bin/env python3
"""Labelled side-by-side composites for the dual-grid terrain review.

usage: dual_grid_side_by_side.py OUT_DIR LABEL=DIR [LABEL=DIR ...]

Every PNG name present in the first DIR (searched recursively, first match
wins) becomes OUT_DIR/<name>.jpg: the panels side by side, each captioned with
its LABEL. Panels missing from a later DIR are drawn as a grey placeholder.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

PANEL_W = 960
CAPTION_H = 44


def index(directory: Path) -> dict:
    found = {}
    for path in sorted(directory.rglob("*.png")):
        found.setdefault(path.name, path)
    return found


def font(size: int):
    for name in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                 "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main() -> None:
    out = Path(sys.argv[1])
    columns = [arg.split("=", 1) for arg in sys.argv[2:]]
    indexes = [(label, index(Path(directory))) for label, directory in columns]
    out.mkdir(parents=True, exist_ok=True)
    caption_font = font(26)
    for name, first in indexes[0][1].items():
        panels = []
        for label, found in indexes:
            if name in found:
                image = Image.open(found[name]).convert("RGB")
                image = image.resize((PANEL_W, round(image.height * PANEL_W / image.width)))
            else:
                image = Image.new("RGB", (PANEL_W, round(PANEL_W * 9 / 16)), (90, 90, 90))
            panels.append((label, image))
        height = max(image.height for _, image in panels) + CAPTION_H
        sheet = Image.new("RGB", (PANEL_W * len(panels), height), (24, 24, 24))
        draw = ImageDraw.Draw(sheet)
        for i, (label, image) in enumerate(panels):
            sheet.paste(image, (i * PANEL_W, CAPTION_H))
            draw.text((i * PANEL_W + 14, 8), f"{label} — {Path(name).stem}", fill=(240, 240, 240), font=caption_font)
        sheet.save(out / (Path(name).stem + ".jpg"), quality=88)


if __name__ == "__main__":
    main()
