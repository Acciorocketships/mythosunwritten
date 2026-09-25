import json,numpy as np,sys
from pathlib import Path
root=Path('/Users/ryko/story/docs/qa/2026-09-13-manual/11-roof-joins')
label=sys.argv[1] if len(sys.argv)>1 else 'offset'
data=json.loads((root/(label+'-native-triangles.json')).read_text())
meshes={k:np.array(v).reshape(-1,3,3) for k,v in data.items()}
# Vertical rays intersect actual triangles; independently compare the upper
# envelope of the two original native meshes against the cut junction.
def height(t,pts, owners=False):
 a,b,c=t[:,0],t[:,1],t[:,2]
 v0=b[:,[0,2]]-a[:,[0,2]];v1=c[:,[0,2]]-a[:,[0,2]]
 det=v0[:,0]*v1[:,1]-v0[:,1]*v1[:,0]
 valid=np.abs(det)>1e-10
 triangle_ids=np.flatnonzero(valid)
 a,b,c,v0,v1,det=[x[valid] for x in [a,b,c,v0,v1,det]]
 out=np.full(len(pts),-np.inf)
 owner=np.full(len(pts),-1,dtype=int)
 for start in range(0,len(pts),96):
  p=pts[start:start+96,None,:]-a[None,:,[0,2]]
  u=(p[:,:,0]*v1[None,:,1]-p[:,:,1]*v1[None,:,0])/det
  v=(v0[None,:,0]*p[:,:,1]-v0[None,:,1]*p[:,:,0])/det
  yes=(u>=-1e-7)&(v>=-1e-7)&(u+v<=1+1e-7)
  y=a[None,:,1]+u*(b-a)[None,:,1]+v*(c-a)[None,:,1]
  scores=np.where(yes,y,-np.inf)
  winners=scores.argmax(axis=1)
  out[start:start+96]=scores[np.arange(len(winners)),winners]
  owner[start:start+96]=triangle_ids[winners]
 return (out,owner) if owners else out
if label.startswith('catalog/'):
 vertices=np.concatenate([meshes['host'],meshes['branch']]).reshape(-1,3)
 low=vertices.min(axis=0);high=vertices.max(axis=0)
 x,z=np.meshgrid(np.arange(low[0]+.013,high[0],.04),np.arange(low[2]+.017,high[2],.04))
 pts=np.column_stack([x.ravel(),z.ravel()])
else:
 x,z=np.meshgrid(np.arange(-1.49,4.49,.04),np.arange(-2.99,2.99,.04))
 pts=np.column_stack([x.ravel(),z.ravel()]);pts=pts[((pts[:,0]<1.5)|(pts[:,1]>0))]
a=height(meshes['host'],pts);b=height(meshes['branch'],pts);expected=np.maximum(a,b);actual=height(meshes['joined'],pts)
valid=np.isfinite(expected);missing=valid&~np.isfinite(actual)
error=np.abs(actual[valid&~missing]-expected[valid&~missing])
compared=np.flatnonzero(valid&~missing)
wrong=compared[error>.0001]
report={'rays':len(pts),'source_hits':int(valid.sum()),'missing_hits':int(missing.sum()),'max_height_error':float(error.max()),'wrong_height_over_0_1mm':int((error>.0001).sum()),'missing_positions':pts[missing].tolist()[:20], 'wrong_samples':[{'xz':pts[i].tolist(),'expected':expected[i],'actual':actual[i]} for i in wrong[:20]]}
# An almost vertical authored shingle lip can amplify a single float32 ULP
# from equivalent transform orders into a large vertical-ray height delta.
# Credit that case only when BOTH winning triangles are the same complete
# native triangle within two coordinate ULPs (all vertices, with no retriangulation).
# Holes and changed/cut triangles receive no exemption.
reference=np.concatenate([meshes['host'],meshes['branch']])
_,expected_ids=height(reference,pts[wrong],True) if len(wrong) else ([],[])
_,actual_ids=height(meshes['joined'],pts[wrong],True) if len(wrong) else ([],[])
rounding=[]
for index,ei,ai in zip(wrong,expected_ids,actual_ids):
 native=reference[ei];candidate=meshes['joined'][ai]
 best=min((np.abs(candidate-np.roll(native,k,axis=0)).max(),k) for k in range(3))
 aligned=np.roll(native,best[1],axis=0)
 ulp=np.maximum(np.abs(np.spacing(aligned.astype(np.float32))).astype(float),np.abs(np.spacing(candidate.astype(np.float32))).astype(float))
 same=bool(np.all(np.abs(candidate-aligned)<=2*ulp))
 if same:
  rounding.append({'xz':pts[index].tolist(),'expected_triangle':int(ei),'actual_triangle':int(ai),'max_vertex_delta':float(best[0]),'vertical_height_delta':float(abs(expected[index]-actual[index]))})
report['unchanged_native_triangle_rounding']=rounding
report['unexplained_height_errors']=len(wrong)-len(rounding)
print(json.dumps(report,indent=2));(root/(label+'-coverage.json')).write_text(json.dumps(report,indent=2))
sys.exit(1 if report['missing_hits'] or report['unexplained_height_errors'] else 0)
