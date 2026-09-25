from pathlib import Path
import importlib.util,json
import numpy as np
from scipy.spatial import ConvexHull
ROOT=Path(__file__).resolve().parents[4];OUT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('p',ROOT/'tools/mountain_art/build_nature_terrace_profiles.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
directions=[]
for y in np.linspace(-1,1,9):
 for angle in np.linspace(0,2*np.pi,20,endpoint=False):directions.append([np.sqrt(max(0,1-y*y))*np.cos(angle),y,np.sqrt(max(0,1-y*y))*np.sin(angle)])
directions=np.array(directions);result=[]
for variant in [1,2,6]:
 vertices,_=m.read_obj(ROOT/f'assets/UltimateNaturePack/OBJ/Rock_{variant}.obj');vertices=np.unique(np.array(vertices),axis=0)
 vertices=.5+(vertices-.5)*.84
 feet=vertices[(vertices[:,2]>.5)&(vertices[:,1]<.85)].copy();feet[:,0]=.5+(feet[:,0]-.5)*1.15;feet[:,1]=.06;feet[:,2]+=.04
 vertices=np.concatenate([vertices,feet])
 cloud=(vertices[:,None,:]+directions[None,:,:]*.07).reshape(-1,3)
 hull=ConvexHull(cloud);faces=hull.simplices.copy()
 normals=np.cross(cloud[faces[:,1]]-cloud[faces[:,0]],cloud[faces[:,2]]-cloud[faces[:,0]])
 invert=np.einsum('ij,ij->i',normals,hull.equations[:,:3])<0
 faces[invert]=faces[invert,::-1]
 ids=np.unique(faces);remap=np.empty(len(cloud),int);remap[ids]=np.arange(len(ids))
 result.append({'vertices':cloud[ids].tolist(),'faces':remap[faces].tolist(),'green':(hull.equations[:,1]>.72).tolist(),'asset':f'Beveled_Rock_{variant}'})
 print(variant,len(ids),len(faces))
(OUT/'bevel-rocks.json').write_text(json.dumps(result,separators=(',',':')))
