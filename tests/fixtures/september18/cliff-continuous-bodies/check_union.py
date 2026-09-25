"""Check physical study solids independently of Godot materials and lighting."""
from pathlib import Path
import json
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
P=Path(__file__).resolve().parent
results=[]
for name in ['union_faces.bin']+[f'world-union-{i:02d}-faces.bin' for i in [19,20,21]]:
 tri=np.fromfile(P/name,dtype='<f4').reshape(-1,3,3)
 v,flat=np.unique(tri.reshape(-1,3),axis=0,return_inverse=True);faces=flat.reshape(-1,3)
 edges=np.concatenate([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]]);edges.sort(axis=1)
 unique,counts=np.unique(edges,axis=0,return_counts=True)
 area=np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1)
 signed_volume=float(np.einsum('ij,ij->i',tri[:,0],np.cross(tri[:,1],tri[:,2])).sum()/6)
 graph=coo_matrix((np.ones(len(unique)),(unique[:,0],unique[:,1])),shape=(len(v),len(v)))
 components,_=connected_components(graph,directed=False)
 record=dict(mesh=name,triangles=len(tri),vertices=len(v),nonmanifold_edges=int(np.sum(counts!=2)),degenerate=int(np.sum(area<1e-10)),components=components,volume=-signed_volume,min=v.min(0).tolist(),max=v.max(0).tolist())
 results.append(record);print(json.dumps(record),flush=True)
 assert record['nonmanifold_edges']==0
 assert record['degenerate']==0
 assert components==1,'The rock and cliff must be one connected solid, not intersecting loose objects'
 assert signed_volume<0,'Godot clockwise exterior winding'
(P/'union-checks.json').write_text(json.dumps(results,indent=2)+'\n')
