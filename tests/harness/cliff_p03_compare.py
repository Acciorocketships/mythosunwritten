"""Matched native images and pixel differences; camera changes are excluded."""
from pathlib import Path
import sys, json
from PIL import Image, ImageChops, ImageEnhance, ImageDraw
import numpy as np
root = Path(sys.argv[1])
final = sys.argv[2] if len(sys.argv) > 2 else '23'
out = root / 'diffs'
out.mkdir(exist_ok=True)
for name in ['p03','crest','wall-overview','grass-ledge','rock-face']:
    before = Image.open(root / '11' / (name + '.png')).convert('RGB')
    after = Image.open(root / final / (name + '.png')).convert('RGB')
    raw = ImageChops.difference(before, after)
    raw.save(out / (name + '-raw.png'))
    amplified = ImageEnhance.Brightness(raw).enhance(4)
    amplified.save(out / (name + '-x4.png'))
    a = np.asarray(raw)
    report = dict(changed_pixels=int(np.any(a != 0, axis=2).sum()), pixels=a.shape[0]*a.shape[1], mean_channel_difference=float(a.mean()))
    (out / (name + '.json')).write_text(json.dumps(report, indent=2))
    canvas = Image.new('RGB', (1600, 948), '#171717')
    draw = ImageDraw.Draw(canvas)
    for label,x,y,img in [('BEFORE - reported defects',0,0,before),('AFTER - P03 follow-up',800,0,after),('PIXEL DIFFERENCE x4',0,474,amplified)]:
        draw.text((x+8,y+6),label,fill='white')
        canvas.paste(img.resize((800,450)),(x,y+24))
    canvas.save(out / (name + '-review.jpg'), quality=95)
