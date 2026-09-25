"""Compare matched production renders; annotations and UI chrome are excluded."""
from pathlib import Path
import argparse
import json
import numpy as np
from PIL import Image, ImageDraw

p = argparse.ArgumentParser()
p.add_argument('before', type=Path)
p.add_argument('after', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--exclude', nargs='*', default=[])
p.add_argument('--roi', nargs=4, type=float)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
regions = {
    '15_water_cliffs': (0, .02, 1, .48),
    '16_water_sheet': (.30, 0, 1, .29),
    '18_water_dry_strip': (.03, .04, .65, .67),
    '19_water_fold': (.15, .10, .78, .66),
    '10_overhang': (.30, 0, .65, .38),
    '01_rail': (.10, .08, .80, .95),
    '12_rail_texture': (.43, .24, .84, .79),
    '06_stone_gap': (.35, 0, .50, .46),
    '13_plaster_gap': (.14, 0, .68, .52),
    '04_ceiling': (.26, 0, .81, .36),
    '08_hanging_stone': (.13, .02, .84, .55),
    '09_stone_course': (.10, 0, .48, .56),
    '14_roof': (.32, .0, .97, .44),
}

metrics = {}
for after in sorted(a.after.glob('*.png')):
    if after.stem in a.exclude:
        continue
    before = a.before / after.name
    if not before.exists():
        continue
    left, right = (Image.open(f).convert('RGB') for f in (before, after))
    assert left.size == right.size
    roi = a.roi or next((v for k,v in regions.items() if after.stem.startswith(k)), (0,0,1,1))
    box = tuple(round(v*left.size[i%2]) for i,v in enumerate(roi))
    delta = np.abs(np.asarray(left).astype(np.int16)-np.asarray(right).astype(np.int16))
    amplitude = delta.max(axis=2)
    x0,y0,x1,y1 = box
    local = delta[y0:y1,x0:x1]
    metrics[after.stem] = {'roi':box, 'mean_abs_rgb':float(delta.mean()),
        'roi_mean_abs_rgb':float(local.mean()),
        'roi_changed_over_20_fraction':float((local.max(axis=2)>20).mean())}
    heat = np.zeros((*amplitude.shape,3),dtype=np.uint8)
    heat[:,:,0] = np.minimum(255,amplitude*4)
    heat[:,:,1] = np.where(amplitude>20,90,0)
    diff = Image.fromarray(heat)
    diff.save(a.output/(after.stem+'_diff.png'))
    crops = [im.crop(box) for im in (left,right,diff)]
    panel = Image.new('RGB',(crops[0].width*3,crops[0].height+28),'#202329')
    draw = ImageDraw.Draw(panel)
    for i,(label,crop) in enumerate(zip(('Before','After','Difference x4'),crops)):
        panel.paste(crop,(i*crop.width,28))
        draw.text((i*crop.width+8,8),label,fill='white')
    panel.save(a.output/(after.stem+'_comparison.png'))
(a.output/'metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
print(json.dumps(metrics,indent=2))
