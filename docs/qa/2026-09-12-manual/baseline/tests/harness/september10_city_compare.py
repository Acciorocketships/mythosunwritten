"""Matched real-render comparisons; never changes a source render."""
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]/'docs/qa/2026-09-10-manual/15-city-form'
OUT=ROOT/'comparisons'
OUT.mkdir(exist_ok=True)
rows=[]
for seed in range(1,5):
    for name in ['north-east','south-west','north-west','south-east','plan']:
        filename=f'seed-{seed:03d}-{name}.png'
        before=ROOT/'complete-before'/str(seed)/filename
        after=ROOT/'complete-after'/str(seed)/filename
        if not before.exists() or not after.exists():continue
        a=np.asarray(Image.open(before).convert('RGB')).astype(np.int16)
        b=np.asarray(Image.open(after).convert('RGB')).astype(np.int16)
        assert a.shape==b.shape
        delta=np.abs(a-b)
        diff=Image.fromarray(np.minimum(delta*3,255).astype(np.uint8))
        diff.save(OUT/f'{seed}-{name}-diff.png')
        crop=(450,230,1470,940) if name=='plan' else (450,300,1470,940)
        inputs=[Image.fromarray(a.astype(np.uint8)),Image.fromarray(b.astype(np.uint8)),diff]
        panels=[im.crop(crop).resize((765,int((crop[3]-crop[1])*0.75))) for im in inputs]
        canvas=Image.new('RGB',(2295,panels[0].height+32),'#eee8dc')
        draw=ImageDraw.Draw(canvas)
        for i,(im,label) in enumerate(zip(panels,['Before','After','Absolute RGB difference x3'])):
            canvas.paste(im,(i*765,32));draw.text((i*765+10,10),f'Seed {seed}, {name}: {label}',fill='black')
        canvas.save(OUT/f'{seed}-{name}-comparison.png')
        rows.append(dict(seed=seed,view=name,before=str(before),after=str(after),
            rgb_mae=float(delta.mean()),pixels_changed_gt8=int((delta.max(axis=2)>8).sum()),
            changed_percent=float((delta.max(axis=2)>8).mean()*100)))
(OUT/'pixel-metrics.json').write_text(json.dumps(rows,indent=2))
print(f'{len(rows)} complete matched pairs')
