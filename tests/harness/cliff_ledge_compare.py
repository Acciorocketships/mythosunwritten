from pathlib import Path
from PIL import Image, ImageDraw, ImageChops, ImageEnhance, ImageFont
import numpy as np
import json
FONT = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 18)
ROOT = Path(__file__).resolve().parents[2] / 'docs/qa/2026-09-26-rock-ledge-restoration'

def compare(before, after, output, title, before_label="BEFORE - flattened rock", after_label="AFTER - restored rock geometry"):
    a, b = Image.open(before).convert('RGB'), Image.open(after).convert('RGB')
    assert a.size == b.size
    diff = ImageChops.difference(a,b)
    ar = np.asarray(a).astype(np.int16); br = np.asarray(b).astype(np.int16)
    changed = np.max(np.abs(ar-br),axis=2)>3
    canvas = Image.new('RGB',(1600,954),(22,22,22)); draw=ImageDraw.Draw(canvas)
    for im, xy, label in [(a,(0,24),before_label),(b,(800,24),after_label),(ImageEnhance.Brightness(diff).enhance(4),(0,501),'PIXEL DIFFERENCE x4')]:
        canvas.paste(im.resize((800,450),Image.Resampling.LANCZOS),xy)
        draw.text((xy[0]+10,xy[1]-18),label,fill='white',font=FONT)
    draw.multiline_text((825,540), title+'\n\nMatched camera and render size.\nDifference is amplified x4.\n\nGeometry and ledges are verified\nseparately from colour/shading.',fill='white',spacing=8,font=FONT)
    canvas.save(output,quality=94)
    return {'changed_pixels_over_3':int(changed.sum()),'total_pixels':int(changed.size),'fraction_changed':float(changed.mean())}

stats={}
for view in ['front','side']:
    stats['neutral_'+view]=compare(ROOT/f'study-neutral-before-{view}.png', ROOT/f'study-neutral-leaning-{view}.png',ROOT/f'neutral-{view}-comparison.jpg','Neutral material: actual surface relief')
for view in ['front','side','above']:
    after=ROOT/'native/03'/f'{view}.png'
    if after.exists():stats[view]=compare(ROOT/'before'/f'{view}.png',after,ROOT/f'{view}-comparison.jpg','Production terrain, grass and collision')
(ROOT/'pixel-differences.json').write_text(json.dumps(stats,indent=2))

for view in ['front','side']:
    stats['leaning_neutral_'+view]=compare(ROOT/f'study-neutral-selected-{view}.png', ROOT/f'study-neutral-leaning-{view}.png',ROOT/f'leaning-neutral-{view}-comparison.jpg','Neutral material: face inclination', 'BEFORE - upright faces','AFTER - faces lean with the slope')
for view in ['front','side','above']:
    after=ROOT/'native/03'/f'{view}.png'
    if after.exists():stats['leaning_'+view]=compare(ROOT/'upright'/f'{view}.png',after,ROOT/f'leaning-{view}-comparison.jpg','Production terrain: inclined rock faces', 'BEFORE - upright faces','AFTER - faces lean with the slope')
(ROOT/'pixel-differences.json').write_text(json.dumps(stats,indent=2))
