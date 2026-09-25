from pathlib import Path
import json
import numpy as np
p=Path(__file__).resolve().parent
b=np.fromfile(p/'before-faces.bin',dtype='<f4').reshape(-1,3,3)
a=np.fromfile(p/'candidate-faces.bin',dtype='<f4').reshape(-1,3,3)
assert b.shape==a.shape
# Compare physical edge gradients, not shaded pixels.
vertices,indices=np.unique(b.reshape(-1,3),axis=0,return_index=True)
av=a.reshape(-1,3)[indices]
_,ids=np.unique(b.reshape(-1,3),axis=0,return_inverse=True);ids=ids.reshape(-1,3)
edges=np.concatenate([ids[:,[0,1]],ids[:,[1,2]],ids[:,[2,0]]]);edges.sort(axis=1);edges=np.unique(edges,axis=0)
gain=av[:,2]-vertices[:,2]
length=np.linalg.norm(vertices[edges[:,0],:2]-vertices[edges[:,1],:2],axis=1)
delta=np.abs(gain[edges[:,0]]-gain[edges[:,1]])
valid=(length>.02)&(vertices[edges[:,0],2]>.5)&(vertices[edges[:,1],2]>.5)
gradient=np.where(valid,delta/np.maximum(length,1e-9),0)
order=np.argsort(gradient)[::-1]
report={'edges':len(edges),'max_added_gradient':float(gradient.max()),'edges_over_2':int((gradient>2).sum()),'worst':[{'a':vertices[edges[i,0]].tolist(),'b':vertices[edges[i,1]].tolist(),'gain_a':float(gain[edges[i,0]]),'gain_b':float(gain[edges[i,1]]),'gradient':float(gradient[i])} for i in order[:24]]}
print(json.dumps(report,indent=2))
