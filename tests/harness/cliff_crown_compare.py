from pathlib import Path
import json
from PIL import Image, ImageChops, ImageEnhance, ImageDraw
import numpy as np
root=Path('docs/qa/2026-09-26-p03-crown-colour')
for name in ['front','side','above']:
 a=Image.open(root/'00'/f'{name}.png').convert('RGB')
 b=Image.open(root/'final/04'/f'{name}.png').convert('RGB')
 diff=ImageChops.difference(a,b); diff.save(root/f'{name}-diff.png')
 amp=ImageEnhance.Brightness(diff).enhance(4)
 canvas=Image.new('RGB',(1600,948),'#171717');draw=ImageDraw.Draw(canvas)
 for title,x,y,im in [('BEFORE - reported cut-out appearance',0,0,a),('AFTER - water-pocket and rock-recess repair',800,0,b),('PIXEL DIFFERENCE x4',0,474,amp)]:
  draw.text((x+8,y+6),title,fill='white');canvas.paste(im.resize((800,450)),(x,y+24))
 canvas.save(root/f'{name}-comparison.jpg',quality=95)
 values=np.asarray(diff)
 (root/f'{name}-diff.json').write_text(json.dumps({'changed_pixels':int(np.any(values!=0,axis=2).sum()),'total_pixels':int(values.shape[0]*values.shape[1]),'mean_channel_difference':float(values.mean())},indent=2))
