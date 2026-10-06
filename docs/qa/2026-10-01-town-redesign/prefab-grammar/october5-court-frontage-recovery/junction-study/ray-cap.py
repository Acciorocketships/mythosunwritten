import json,numpy as np, math
E=np.array([-20.49615,41,9.969208]);T=np.array([-18,38,-10]);f=(T-E);f/=np.linalg.norm(f);r=np.cross(f,[0,1,0]);r/=np.linalg.norm(r);u=np.cross(r,f)
for x,y in [(774,286),(777,288),(775,293),(770,287)]:
 d=f+r*(2*x/1600-1)*math.tan(math.radians(65)/2)*1600/900+u*(1-2*y/900)*math.tan(math.radians(65)/2);d/=np.linalg.norm(d);e=(E+[2,0,2])/2
 hits=[]
 for p in json.load(open('/tmp/cap-ray.json')):
  for si,s in enumerate(p['surfaces']):
   v=np.array(s['vertices']);ids=np.array(s['indices'],dtype=int);
   if len(ids)==0:continue
   tris=v[ids.reshape(-1,3)];a=tris[:,0];ab=tris[:,1]-a;ac=tris[:,2]-a;h=np.cross(d,ac);det=np.einsum('ij,ij->i',ab,h);valid=np.abs(det)>1e-9;inv=np.divide(1,det,out=np.zeros_like(det),where=valid);q=e-a;U=inv*np.einsum('ij,ij->i',q,h);cross=np.cross(q,ab);V=inv*(cross@d);ts=inv*np.einsum('ij,ij->i',ac,cross);valid&=(U>=0)&(V>=0)&(U+V<=1)&(ts>0)
   if np.any(valid):
    t=min(ts[valid]);hits.append((t,p['role'],p['asset'],si,list(e+t*d)))
 print(x,y,sorted(hits)[:2])
