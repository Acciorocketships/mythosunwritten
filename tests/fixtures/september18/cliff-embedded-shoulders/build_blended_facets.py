from pathlib import Path
p=Path(__file__).resolve().parent
s=(p/'finite-volume.gd').read_text()
s=s.replace('u/10.0','u/6.0').replace('height/7.5','height/5.5').replace('*.38','*.38').replace('<.38','<.18').replace('*10.0','*6.0').replace('*7.5','*5.5').replace('lerpf(2.4,5.7','lerpf(2.0,4.5').replace('lerpf(1.5,3.9','lerpf(1.6,3.6').replace('lerpf(.9,2.2','lerpf(.35,.95')
s=s.replace('var rounded:=sqrt(maxf(0.0,1.0-radius*radius))','var rounded:=minf(1.0+.25*nx-.18*ny,minf(1.18-.35*nx-.12*ny,1.08+.15*nx+.32*ny))')
s=s.replace('var contact:float=(1.0-radius)*minf(half_width,half_height)*1.2','var contact:float=smoothstep(1.0,.28,radius)')
s=s.replace('minf(reach*rounded,contact)*(1.0+.2*lower)','reach*maxf(0.0,rounded)*contact*(1.0+.2*lower)')
s=s.replace('value=maxf(value,lerpf(profile[row],profile[row+1],py-row))','value+=lerpf(profile[row],profile[row+1],py-row)')
s=s.replace('return value*.85*minf(1.0,descent*2.0)','return minf(value,1.45)*smoothstep(0.0,.55,descent)')
(p/'blended-facets.gd').write_text(s)
for suffix in ['-corner.gd','-dressing.gd','-tall.gd','-tall.tscn']:
 (p/('blended-facets'+suffix)).write_text((p/('finite-volume'+suffix)).read_text().replace('finite-volume','blended-facets'))
