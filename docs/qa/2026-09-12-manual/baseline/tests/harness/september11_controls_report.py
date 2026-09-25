"""Summarize actual saved camera bases, not just a controller's yaw variable."""
from pathlib import Path
import json, math, re, sys
from PIL import Image, ImageDraw
import numpy as np
root=Path(sys.argv[1]); summary={}
def numbers(value):
 return [float(x) for x in re.findall(r'[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?',value)]
def heading(basis):
 v=numbers(basis);return math.atan2(v[6],v[8])
for file in root.glob('*-trajectory.json'):
 rows=json.loads(file.read_text()); spot=file.stem.removesuffix('-trajectory')
 for row in rows:
  samples=row['samples']
  if samples:
   begin=heading(row.get('initial_basis',samples[0]['basis']));end=heading(samples[-1]['basis'])
   row['measured_heading_change_degrees']=math.degrees(math.atan2(math.sin(end-begin),math.cos(end-begin)))
  row.pop('samples')
 summary[spot]=rows
outliers=[]
for f in sorted((root/'after').glob('*.png')):
 a=np.asarray(Image.open(f).convert('RGB'));b=np.asarray(Image.open(root/'before'/f.name).convert('RGB'))
 if (a.max(2)<3).mean()>.95 or (b.max(2)<3).mean()>.95:outliers.append(f.stem)
for spot in summary:
 out=Image.new('RGB',(1440,4*294),'#202329');draw=ImageDraw.Draw(out)
 for row,scenario in enumerate(['pin','tactical_strafe','close_mouse','close_strafe']):
  for col,folder in enumerate(['before','after','diff']):
   name=f'{spot}_{scenario}'+('_diff.png' if folder=='diff' else '.png')
   im=Image.open(root/folder/name);im.thumbnail((480,270));out.paste(im,(480*col,row*294+24));draw.text((480*col+6,row*294+5),scenario+' '+folder,fill='white')
 out.save(root/(spot+'_review.png'))
(root/'summary.json').write_text(json.dumps({'trajectories':summary,'invalid_black_pairs':outliers},indent=2)+'\n')
print(json.dumps({'invalid_black_pairs':outliers,'spots':len(summary)},indent=2))
