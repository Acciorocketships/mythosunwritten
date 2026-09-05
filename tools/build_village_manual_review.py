"""Unretouched, matched close-ups for the September 4 annotated village review.

Only crop the rendered evidence; never synthesize or paint scene pixels.
Difference panels are absolute RGB differences displayed with 3x gain.
"""
import argparse
import html
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


REGIONS = [
    ("terrain_handoff_wedge", "Floating ramp and open underside", (300, 250, 1000, 720)),
    ("orphan_stone_cell", "Orphan stone above the roof", (900, 0, 1510, 500)),
    ("diagonal_gap_facade_planes", "Vertical slot at the facade joint", (870, 0, 1100, 430)),
    ("diagonal_gap_facade_planes", "Protruding facade panels", (100, 80, 880, 650)),
    ("elevated_turf_supports", "Planted deck lip and thickness", (490, 430, 1670, 700)),
    ("elevated_turf_supports", "Disconnected hanging stone columns", (450, 560, 1280, 970)),
    ("planters_in_walkway", "Planters blocking the stair approach", (480, 320, 970, 620)),
    ("door_behind_railing", "Door blocked by a stair railing", (130, 390, 880, 920)),
    ("double_ground_sheet", "Two stacked town ground surfaces", (100, 130, 1140, 590)),
    ("facade_plane_jut", "Cream planes outside the corner", (790, 0, 1100, 360)),
    ("turf_lip_corner", "Stone piercing the straight grass lip", (475, 325, 1440, 810)),
    ("turf_lip_corner", "Grass corner and edge join", (830, 505, 1175, 825)),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--regions", type=Path, help="JSON list of [spot, title, crop]")
    parser.add_argument("--spot", help="Review only this capture pin")
    parser.add_argument("--before-frame", default="exact")
    parser.add_argument("--after-frame", default="exact")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    rows = []
    body = []
    regions = json.loads(args.regions.read_text()) if args.regions else REGIONS
    if args.spot:
        regions = [region for region in regions if region[0] == args.spot]
    for index, (spot, title, box) in enumerate(regions, 1):
        name = f"{index:02d}-{spot}"
        before = Image.open(args.before / f"{spot}_{args.before_frame}.png").convert("RGB").crop(box)
        after = Image.open(args.after / f"{spot}_{args.after_frame}.png").convert("RGB").crop(box)
        diff = ImageChops.difference(before, after)
        changed = sum(max(pixel) > 8 for pixel in diff.getdata()) / (diff.width * diff.height)
        for label, picture in [("before", before), ("after", after),
                               ("diff", diff.point(lambda value: min(255, value * 3)))]:
            picture.save(args.output / f"{name}-{label}.png")
        sheet = Image.new("RGB", (before.width * 3, before.height + 32), "#171d23")
        draw = ImageDraw.Draw(sheet)
        for column, label in enumerate(["before", "after", "diff"]):
            picture = Image.open(args.output / f"{name}-{label}.png")
            sheet.paste(picture, (column * before.width, 32))
            draw.text((column * before.width + 10, 10),
                      "ABS RGB DIFF (3x)" if label == "diff" else label.upper(), fill="white")
        sheet.save(args.output / f"{name}-comparison.png")
        rows.append({"id": spot, "issue": title, "crop_xyxy": box,
                     "before_frame": args.before_frame, "after_frame": args.after_frame,
                     "changed_fraction_over_8": changed})
        body.append(f'<section><h2>{index}. {html.escape(title)}</h2>'
                    f'<p>{html.escape(spot)} · changed pixels: {changed:.2%}</p>'
                    f'<a href="{name}-comparison.png"><img src="{name}-comparison.png"></a>'
                    f'<p><a href="{name}-before.png">Before at native size</a> · '
                    f'<a href="{name}-after.png">After at native size</a> · '
                    f'<a href="{name}-diff.png">Pixel diff at native size</a></p></section>')
    (args.output / "regions.json").write_text(json.dumps(rows, indent=2) + "\n")
    (args.output / "index.html").write_text('''<!doctype html><meta charset="utf-8">
<title>Village manual review — matched close-ups</title>
<style>body{font:16px system-ui;background:#f4f1eb;color:#252b2d;margin:32px auto;max-width:1500px;padding:0 24px}section{margin:40px 0}img{width:100%;height:auto}a{color:#1c527c}h2{font-size:21px}</style>
<h1>Village manual review: matched annotated details</h1>
<p>Unretouched crops of the matched before/after game captures. Each comparison reads left to right: before, after, absolute RGB difference (3× gain). The original screenshots contain rounded player/crosshair positions, not a complete camera transform; these reconstructed views share identical camera inputs with each other.</p>
<p>A changed pixel is evidence of change, not proof of correctness. See the written QA report for individual visual judgments and rejected iterations.</p>
''' + "\n".join(body))
    print(args.output / "index.html")


if __name__ == "__main__":
    main()
