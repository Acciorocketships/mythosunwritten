"""Pixel differences between matched renders.

pixdiff.py BEFORE_DIR AFTER_DIR OUT_DIR [threshold]
Writes OUT_DIR/<name>.png (after image dimmed, changed pixels red, bbox yellow)
and OUT_DIR/summary.json with changed fraction, mean absolute delta and bbox.
"""
import json, os, sys
from PIL import Image, ImageChops, ImageDraw

before_dir, after_dir, out_dir = sys.argv[1:4]
threshold = int(sys.argv[4]) if len(sys.argv) > 4 else 24
os.makedirs(out_dir, exist_ok=True)
summary = {}
for name in sorted(os.listdir(after_dir)):
    if not name.endswith('.png') or not os.path.exists(os.path.join(before_dir, name)):
        continue
    a = Image.open(os.path.join(before_dir, name)).convert('RGB')
    b = Image.open(os.path.join(after_dir, name)).convert('RGB')
    if a.size != b.size:
        b = b.resize(a.size)
    diff = ImageChops.difference(a, b).convert('L')
    mask = diff.point(lambda v: 255 if v > threshold else 0)
    changed = sum(1 for v in mask.getdata() if v)
    total = a.size[0] * a.size[1]
    hist = diff.histogram()
    mean = sum(i * c for i, c in enumerate(hist)) / total
    bbox = mask.getbbox()
    vis = Image.blend(b, Image.new('RGB', b.size, 'black'), 0.45)
    red = Image.new('RGB', b.size, (255, 40, 40))
    vis.paste(red, (0, 0), mask)
    if bbox:
        ImageDraw.Draw(vis).rectangle(bbox, outline=(255, 230, 0), width=3)
    vis.save(os.path.join(out_dir, name))
    summary[name] = {"changed_fraction": round(changed / total, 5), "mean_abs_delta": round(mean, 3), "bbox": bbox}
json.dump(summary, open(os.path.join(out_dir, 'summary.json'), 'w'), indent=2)
for k, v in summary.items():
    print(f"{k:28s} changed={v['changed_fraction']:.4f} mean={v['mean_abs_delta']:.2f} bbox={v['bbox']}")
