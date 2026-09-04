"""Compare unmodified, camera-matched render captures (before / after / abs diff)."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for before_path in sorted(args.before.glob("*.png")):
        after_path = args.after / before_path.name
        if not after_path.exists():
            continue
        before = Image.open(before_path).convert("RGB")
        after = Image.open(after_path).convert("RGB")
        assert before.size == after.size, "Matched captures must have the same size"
        diff = ImageChops.difference(before, after)
        # Threshold rejects tiny temporal antialiasing changes. The displayed
        # diff is the actual absolute RGB difference, with a labeled 3x gain.
        mask = diff.convert("L").point(lambda value: 255 if value > 12 else 0)
        changed = mask.histogram()[255] / (before.width * before.height)
        diff.save(args.output / f"{before_path.stem}-diff.png")
        panel_width = 720
        panel_height = round(before.height * panel_width / before.width)
        board = Image.new("RGB", (panel_width * 3, panel_height + 32), "#161a20")
        draw = ImageDraw.Draw(board)
        for index, (label, panel) in enumerate([
            ("BEFORE", before), ("AFTER", after),
            ("ABSOLUTE RGB DIFFERENCE (3x gain)", ImageEnhance.Brightness(diff).enhance(3)),
        ]):
            draw.text((index * panel_width + 10, 10), label, fill="white")
            board.paste(panel.resize((panel_width, panel_height)), (index * panel_width, 32))
        board.save(args.output / f"{before_path.stem}-comparison.png")
        results.append({"image": before_path.name, "changed_fraction": changed})
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
