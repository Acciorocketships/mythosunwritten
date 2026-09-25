from pathlib import Path
import numpy as np,json
from scipy.spatial import ConvexHull
P=Path(__file__).resolve().parent
rng=np.random.default_rng(2697992464);result=[]
for i in range(9):
 pts=[]
 # Irregular rounded shoulders; a broad buried foot carries the upper mass.
 for j in range(9):
  t=j/8; y=t
  rx=np.sqrt(max(.04,1-((t-.35)/.72)**2))*.5
  for k in range(15):
   a=2*np.pi*(k+.2*np.sin(j*.8+i))/15
   wave=1+.07*np.sin(3*a+i)+.05*np.cos(5*a+j*.7+i)
   x=.5+rx*np.cos(a)*wave+.06*np.sin(t*3+i)*t
   z=.5+rx*np.sin(a)*wave
   pts.append([x,y,z])
 pts=np.array(pts);h=ConvexHull(pts);faces=h.simplices.copy()
 n=np.cross(pts[faces[:,1]]-pts[faces[:,0]],pts[faces[:,2]]-pts[faces[:,0]])
 flip=np.einsum('ij,ij->i',n,h.equations[:,:3])<0;faces[flip]=faces[flip,::-1]
 result.append(dict(vertices=pts.tolist(),faces=faces.tolist(),green=[False]*len(faces),asset=f'RootedShoulder{i}'))
(P/'cluster-rocks.json').write_text(json.dumps(result))
s=(P/'bevel-union.gd').read_text().replace('bevel-','cluster-').replace('for i in 3:','for i in 9:')
s=s.replace('[-6.5,-.5,5.5]','[-9.1,-6.4,-3.7,-1.6,1.4,3.3,5.6,8.1,10.2]').replace('[1.9,1.6,1.25]','[1.2,2.1,1.0,3.0,1.5,1.0,2.0,1.4,2.7]')
s=s.replace('[9.0,6.5,8.5]','[4.7,3.5,5.4,3.3,4.8,3.5,4.3,5.1,3.4]').replace('[4.7,3.9,3.3]','[3.6,5.0,3.2,6.5,4.2,3.1,5.0,3.9,6.0]').replace('[6.0,5.4,5.5]','[3.2,2.4,3.8,2.2,3.4,2.8,3.2,3.7,2.4]')
s=s.replace('[.2,-.3,.4][i]','sin(float(i)*2.7)*.5').replace('[.1,-.15,.06][i]','sin(float(i)*1.9)*.07').replace('depth*.35','depth*.16')
(P/'cluster-union.gd').write_text(s)
(P/'cluster-union-replay.gd').write_text((P/'bevel-union-replay.gd').read_text().replace('bevel-','cluster-'))
