"""Matched native captures: raw and amplified RGB differences plus metrics."""
import argparse, json
from pathlib import Path
import numpy as np
from PIL import Image
p=argparse.ArgumentParser()
p.add_argument('before'); p.add_argument('after'); p.add_argument('output')
a=p.parse_args(); out=Path(a.output); out.parent.mkdir(parents=True, exist_ok=True)
x=np.asarray(Image.open(a.before).convert('RGB')).astype(np.int16)
y=np.asarray(Image.open(a.after).convert('RGB')).astype(np.int16)
assert x.shape==y.shape, (x.shape,y.shape)
d=np.abs(y-x); mask=d.max(2)>8
Image.fromarray(d.astype(np.uint8)).save(str(out)+'-raw.png')
Image.fromarray(np.minimum(d*4,255).astype(np.uint8)).save(str(out)+'-x4.png')
ys,xs=np.where(mask)
metrics={'before':a.before,'after':a.after,'size':[x.shape[1],x.shape[0]],'mean_absolute_channel_difference':float(d.mean()),'pixels_over_8':int(mask.sum()),'fraction_over_8':float(mask.mean()),'changed_bounds':None if not len(xs) else [int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())], 'note':'Pixel changes establish change, not correctness. Inspect matched images; animated grass and temporal rendering also change pixels.'}
Path(str(out)+'.json').write_text(json.dumps(metrics,indent=2)+'\n')
print(json.dumps(metrics))
