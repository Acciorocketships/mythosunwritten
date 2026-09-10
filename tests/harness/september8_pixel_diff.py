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
    '01_garden_trim': (.25,.38,.68,.66),
    '02_town_slope': (.42,.17,.80,.76),
    '03_door_edges': (.45,0,.92,.65),
    '04_wall_end': (.30,0,.49,.50),
    '05_path_notches': (.38,.52,.87,.94),
    '06_door_paths': (.25,.28,.92,.75),
    '07_wall_seams': (.48,0,.72,.57),
    '08_dead_end': (.36,.21,.84,.82),
    '09_facade_return': (.54,.05,.75,.66),
    '10_river_bank': (.02,.08,.98,.65),
    '11_floor_caps': (.14,.31,.72,.68),
    '12_floor_overlap': (.31,.44,.62,.80),
    '13_ground_slope': (.33,.30,.76,.88),
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
