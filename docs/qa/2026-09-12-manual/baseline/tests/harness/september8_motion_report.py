"""Plot recorded physics, visible-body and camera traces; build matched motion strips."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parents[2]/'docs/qa/2026-09-08-manual'
plot=Image.new('RGB',(1280,800),'#fafafa');draw=ImageDraw.Draw(plot)
colors=['#9097a5','#8162c9','#07866b']
for col,version in enumerate(['before','final']):
 rows=json.loads((root/f'05-motion-{version}.json').read_text())
 for row_idx,descent in enumerate([False,True]):
  t=next(r['trace'] for r in rows if r['id']=='volume.transition.04' and r['descent']==descent)
  left,top=70+col*640,55+row_idx*385
  draw.text((left,top-30),f'{version.title()} - {"Descent" if descent else "Ascent"}',fill='#202329')
  for y in range(4):
   py=top+280-y*80
   draw.line((left,py,left+520,py),fill='#dedee4');draw.text((left-35,py-5),f'{y} m',fill='#555555')
  for tick in [0,15,30,45,60]:
   px=left+tick/60*520
   draw.text((px-12,top+290),f'{tick/60:.2f}s',fill='#555555')
  for key,color,offset in [('body',colors[0],0),('visual_y',colors[1],0),('camera_y',colors[2],5)]:
   points=[(left+r['tick']/60*520,top+280-((r['xyz'][1] if key=='body' else r[key])-offset)*80) for r in t]
   draw.line(points,fill=color,width=3)
for i,label in enumerate(['Collision body','Visible character','Camera (minus 5 m)']):
 draw.line((200+i*300,780,225+i*300,780),fill=colors[i],width=3)
 draw.text((230+i*300,774),label,fill='#202329')
plot.save(root/'05-motion-height-traces.png')
for direction in ['up','down']:
 before=root/'05-motion-before';after=root/'05-motion-final'
 files=sorted(p.name for p in before.glob(f'motion_{direction}_*.png') if (after/p.name).exists())
 if not files:continue
 frames=[]
 for name in files:
  a,b=[Image.open(p/name).convert('RGB').resize((640,360)) for p in [before,after]]
  out=Image.new('RGB',(1280,390),'#202329');out.paste(a,(0,30));out.paste(b,(640,30))
  d=ImageDraw.Draw(out);d.text((12,8),'Before',fill='white');d.text((652,8),'After',fill='white')
  frames.append(out)
 frames[0].save(root/f'05-motion-{direction}.gif',save_all=True,append_images=frames[1:],duration=50,loop=0)
 selected=np.linspace(0,len(frames)-1,5,dtype=int)
 strip=Image.new('RGB',(1280,390*len(selected)))
 for i,j in enumerate(selected):strip.paste(frames[j],(0,i*390))
 strip.save(root/f'05-motion-{direction}-contact-sheet.png')
