"""Check actual rendered glow around each projected production sprite."""
import json
import re
import sys
from pathlib import Path
import numpy as np
from PIL import Image
root = Path(sys.argv[1])
before = json.loads((root/'before/motion.json').read_text())
after = json.loads((root/'after/motion.json').read_text())
assert before['fixture_sha256'] == after['fixture_sha256']
assert before['count'] == after['count'] == 11
rows = []
for a,b in zip(before['rows'],after['rows']):
    assert (a['view'],a['seconds'],a['camera']) == (b['view'],b['seconds'],b['camera'])
    if b['view'] != 'second_orb':
        continue
    name = f"{b['view']}_{int(b['seconds']):02d}.png"
    left,right = [np.asarray(Image.open(root/v/name).convert('RGB')).astype(float) for v in ['before','after']]
    x,y = [float(v) for v in re.findall(r'-?\d+(?:\.\d+)?',b['projected_orb'])]
    yy,xx = np.mgrid[:right.shape[0],:right.shape[1]]
    region = (xx-x)**2+(yy-y)**2 < 25**2
    glow = region & (right.mean(axis=2)>225) & ((right-left).mean(axis=2)>70)
    count = int(glow.sum())
    assert count > 80, f'{name}: production sprite must add a visible luminous core'
    centroid = [float(xx[glow].mean()),float(yy[glow].mean())]
    error = float(np.hypot(centroid[0]-x,centroid[1]-y))
    assert error < 6, f'{name}: rendered glow must follow the moving parent'
    rows.append({'frame':name,'new_bright_core_pixels':count,'projected_center':[x,y],'rendered_center':centroid,'error_pixels':error})
assert len(rows)==4
(root/'pixel-verification.json').write_text(json.dumps({'all_cameras_identical':True,'rows':rows},indent=2)+'\n')
print(json.dumps(rows,indent=2))
