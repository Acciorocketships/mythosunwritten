from pathlib import Path
import json, sys
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance
root=Path(sys.argv[1]); final=sys.argv[2] if len(sys.argv)>2 else '07'
out=root/'diffs';out.mkdir(exist_ok=True)
for name in ['p03','crest','wall-overview','ledges-above']:
    a=Image.open(root/'00'/f'{name}.png').convert('RGB')
    b=Image.open(root/final/f'{name}.png').convert('RGB')
    d=ImageChops.difference(a,b);d.save(out/f'{name}-raw.png')
    amplified=ImageEnhance.Brightness(d).enhance(4);amplified.save(out/f'{name}-x4.png')
    values=np.asarray(d)
    (out/f'{name}.json').write_text(json.dumps(dict(changed_pixels=int(np.any(values!=0,axis=2).sum()),pixels=values.shape[0]*values.shape[1],mean_channel_difference=float(values.mean())),indent=2))
    canvas=Image.new('RGB',(1600,948),'#171717');draw=ImageDraw.Draw(canvas)
    for text,x,y,img in [('BEFORE - owner marked remaining issues',0,0,a),('AFTER - constrained bank repair',800,0,b),('PIXEL DIFFERENCE x4',0,474,amplified)]:
        draw.text((x+8,y+6),text,fill='white');canvas.paste(img.resize((800,450)),(x,y+24))
    canvas.save(out/f'{name}-review.jpg',quality=95)
