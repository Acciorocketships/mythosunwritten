from pathlib import Path
import numpy as np,json
from scipy.spatial import HalfspaceIntersection,ConvexHull
P=Path(__file__).resolve().parent
rng=np.random.default_rng(2697992464)
directions=[]
for y in np.linspace(-1,1,7):
 for a in np.linspace(0,np.pi*2,16,endpoint=False):directions.append([np.sqrt(max(0,1-y*y))*np.cos(a),y,np.sqrt(max(0,1-y*y))*np.sin(a)])
directions=np.array(directions);result=[]
for i in range(3):
 planes=[]
 # Offset cutting planes form broad, irregular polygonal rock faces.
 for k in range(7):
  a=(k+rng.uniform(-.16,.16))*np.pi*2/7
  n=np.array([np.cos(a),rng.uniform(-.42,.28),np.sin(a)]);n/=np.linalg.norm(n)
  planes.append([*n,-rng.uniform(.38,.55)])
 for side in [-1,1]:
  for k in range(3):
   a=k*np.pi*2/3+rng.uniform(-.35,.35)
   n=np.array([np.cos(a)*.3,side,np.sin(a)*.3]);n/=np.linalg.norm(n)
   planes.append([*n,-rng.uniform(.40,.54)])
 v=HalfspaceIntersection(np.array(planes),np.zeros(3)).intersections
 foot=v[(v[:,1]<.15)&(v[:,2]>-.2)].copy();foot[:,1]=-.58;foot[:,0]*=1.08;foot[:,2]+=.06
 v=np.concatenate([v,foot])
 cloud=(v[:,None,:]+directions[None,:,:]*.045).reshape(-1,3)
 h=ConvexHull(cloud);f=h.simplices.copy();norm=np.cross(cloud[f[:,1]]-cloud[f[:,0]],cloud[f[:,2]]-cloud[f[:,0]])
 flip=np.einsum('ij,ij->i',norm,h.equations[:,:3])<0;f[flip]=f[flip,::-1]
 ids=np.unique(f);remap=np.empty(len(cloud),int);remap[ids]=np.arange(len(ids))
 result.append(dict(vertices=(cloud[ids]+.5).tolist(),faces=remap[f].tolist(),green=(h.equations[:,1]>.87).tolist(),asset=f'PolygonalShoulder{i}'))
(P/'polyhedral-rocks.json').write_text(json.dumps(result,separators=(',',':')))
old=P.parent/'cliff-embedded-shoulders'
s=(old/'bevel-union.gd').read_text().replace('cliff-embedded-shoulders','cliff-connected-relief').replace('bevel-','polyhedral-')
s=s.replace('[-6.5,-.5,5.5]','[-6.0,1.8,8.0]').replace('[1.9,1.6,1.25]','[1.4,2.2,.85]').replace('[9.0,6.5,8.5]','[8.0,9.0,5.5]').replace('[4.7,3.9,3.3]','[3.4,4.7,2.7]').replace('[6.0,5.4,5.5]','[4.6,5.1,3.4]').replace('depth*.35','depth*.24')
(P/'polyhedral-union.gd').write_text(s)
(P/'polyhedral-union-replay.gd').write_text((old/'bevel-union-replay.gd').read_text().replace('cliff-embedded-shoulders','cliff-connected-relief').replace('bevel-','polyhedral-'))
