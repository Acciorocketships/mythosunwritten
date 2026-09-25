import json
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
r=Path(__file__).resolve().parents[2] / 'docs/qa/2026-09-10-manual/15-city-form'
out=r/'final-comparisons';out.mkdir(exist_ok=True)
rows=[]
pairs=[]
for s in range(1,5):
 for n in ['north-east','south-west','north-west','south-east','plan']:
  f=f'seed-{s:03d}-{n}.png';pairs.append((f'city-{s}-{n}',r/'complete-before'/str(s)/f,r/'complete-final'/f'standard-{s}'/f))
for theme in ['blue','orange']:
 for n in ['NE','SW','NW','SE','plan','close']:
  pairs.append((f'valley-{theme}-{n}',r/'roof-valley'/'before'/theme/(n+'.png'),r/'roof-valley'/'after'/theme/(n+'.png')))
for s in [1,3,4]:
 for n in ['NE','SW','plan','square']:
  pairs.append((f'hamlet-{s}-{n}',r/'hamlet-candidate3'/str(s)/(n+'.png'),r/'hamlet-candidate4'/str(s)/(n+'.png')))
for label,before,after in pairs:
 if not before.exists() or not after.exists(): print('MISSING',label);continue
 a=np.asarray(Image.open(before).convert('RGB')).astype(np.int16);b=np.asarray(Image.open(after).convert('RGB')).astype(np.int16)
 assert a.shape==b.shape
 d=np.abs(a-b);diff=Image.fromarray(np.minimum(d*3,255).astype('uint8'));diff.save(out/(label+'-diff.png'))
 ims=[Image.fromarray(a.astype('uint8')),Image.fromarray(b.astype('uint8')),diff]
 canvas=Image.new('RGB',(1920,385),'#eee8dc');draw=ImageDraw.Draw(canvas)
 for i,(im,title) in enumerate(zip(ims,['Before','After','Difference x3'])):
  canvas.paste(im.resize((640,360)),(i*640,25));draw.text((i*640+5,5),label+' '+title,fill='black')
 canvas.save(out/(label+'.png'))
 rows.append(dict(id=label,before=str(before),after=str(after),rgb_mae=float(d.mean()),changed_percent=float((d.max(2)>8).mean()*100)))
(out/'metrics.json').write_text(json.dumps(rows,indent=2))
for group in ['city','valley','hamlet']:
 chosen=[row for row in rows if row['id'].startswith(group)]
 for page in range(0,len(chosen),4):
  sheet=Image.new('RGB',(1920,385*min(4,len(chosen)-page)), '#eee8dc')
  for i,row in enumerate(chosen[page:page+4]):sheet.paste(Image.open(out/(row['id']+'.png')),(0,i*385))
  sheet.save(out/(f'{group}-sheet-{page//4}.jpg'))
print(len(rows),'matched pairs')
