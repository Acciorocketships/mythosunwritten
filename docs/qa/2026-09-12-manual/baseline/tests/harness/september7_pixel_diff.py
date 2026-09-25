"""Compare the harness's identical-camera render pairs, with review crops.

Run with a Python environment providing Pillow and NumPy. The source annotations,
editor toolbar, and rounded-camera reconstruction error are deliberately not
counted as changes caused by an implementation.
"""
from pathlib import Path
import argparse
import json
import numpy as np
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument('before', type=Path)
parser.add_argument('after', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
rois = {
    '01_upper_door_gap': (.31, .015, .49, .46),
    '02_gallery_gaps_flicker': (.23, .02, .64, .55),
    '03_parallel_paths': (.33, .13, .67, .53),
    '04_garden_wall': (.38, .51, .72, .88),
    '05_ground_gaps': (.02, .01, .76, .57),
    '06_town_slopes': (.27, .09, .78, .47),
}
metrics = {}
jobs = [(stem, stem + '_exact.png', roi) for stem, roi in rois.items()]
jobs.append(('02_gallery_floor', '02_gallery_gaps_flicker_exact.png', (.015, .44, .32, .67)))
for path in sorted(args.after.glob('*_orbit_*.png')):
    if (args.before / path.name).exists():
        roi = (.42, 0, .72, .65) if path.stem == '02_gallery_gaps_flicker_orbit_-90' else (0, 0, 1, 1)
        jobs.append((path.stem, path.name, roi))
for path in sorted(args.after.glob('volume.transition.*.png')):
    if (args.before / path.name).exists():
        jobs.append((path.stem, path.name, (.20, .05, .80, .95)))
for stem, filename, roi in jobs:
    left = Image.open(args.before / filename).convert('RGB')
    right = Image.open(args.after / filename).convert('RGB')
    assert left.size == right.size, (left.size, right.size)
    a, b = np.asarray(left).astype(np.int16), np.asarray(right).astype(np.int16)
    delta = np.abs(a - b)
    changed = delta.max(axis=2) > 20
    x0, y0, x1, y1 = [round(v * left.size[i % 2]) for i, v in enumerate(roi)]
    local_delta = delta[y0:y1, x0:x1]
    metrics[stem] = {
        'size': left.size, 'roi': [x0,y0,x1,y1],
        'changed_over_20_fraction': float(changed.mean()),
        'roi_changed_over_20_fraction': float(changed[y0:y1,x0:x1].mean()),
        'roi_mean_abs_rgb': float(local_delta.mean()),
        'roi_max_abs_rgb': int(local_delta.max()),
    }
    heat = np.zeros_like(a, dtype=np.uint8)
    heat[:,:,0] = np.clip(delta.max(axis=2) * 4, 0, 255)
    heat[:,:,1] = np.where(changed, 90, 0)
    heatmap = Image.fromarray(heat)
    heatmap.save(args.output / (stem + '_diff.png'))
    crops = [im.crop((x0,y0,x1,y1)) for im in (left,right,heatmap)]
    panel = Image.new('RGB', (crops[0].width * 3, crops[0].height + 28), '#202329')
    draw = ImageDraw.Draw(panel)
    for index, (label, im) in enumerate(zip(('Before','Candidate','Pixel difference ×4'), crops)):
        panel.paste(im, (index*im.width,28))
        draw.text((index*im.width+8,8), label, fill='white')
    panel.save(args.output / (stem + '_comparison.png'))
(args.output / 'metrics.json').write_text(json.dumps(metrics, indent=2)+'\n')
