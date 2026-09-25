"""Offline geometry study: merge authored rock volumes into the actual cliff.
The scalar field represents solids, not a texture or shader displacement.
"""
from pathlib import Path
import importlib.util, json, hashlib, sys
import os
import numpy as np
from scipy.ndimage import distance_transform_edt, gaussian_filter
from scipy.spatial import ConvexHull
from skimage.measure import marching_cubes
ROOT=Path(__file__).resolve().parents[4]; OUT=Path(__file__).resolve().parent
INDEX=int(os.environ.get('STORY_BAKE_INDEX','20'))
META=next(m for m in json.loads((OUT/'world-sources.json').read_text()) if m['index']==INDEX)
WIDTH=META['width'];HEIGHT=round(META['height']);STEP=.12
faces=np.fromfile(ROOT/META['path'].removeprefix('res://'),dtype='<f4').reshape(-1,3,3)
xs=np.arange(-WIDTH/2-.6,WIDTH/2+.6+STEP/2,STEP);ys=np.arange(-1,HEIGHT+1+STEP/2,STEP);zs=np.arange(-2,float(faces[:,:,2].max())+5,STEP)
depth=np.full((len(xs),len(ys)),-1.2,dtype=np.float32)
# Rasterize the actual front triangles; overlapping front points own max depth.
for tri in faces:
 a,b,c=tri
 denom=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
 if abs(denom)<1e-9:continue
 lo=np.maximum(0,np.ceil((tri[:,:2].min(0)-[xs[0],ys[0]])/STEP).astype(int))
 hi=np.minimum(np.array(depth.shape)-1,np.floor((tri[:,:2].max(0)-[xs[0],ys[0]])/STEP).astype(int))
 if np.any(lo>hi):continue
 x=xs[lo[0]:hi[0]+1,None];y=ys[None,lo[1]:hi[1]+1]
 wa=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/denom
 wb=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/denom
 wc=1-wa-wb
 d=wa*a[2]+wb*b[2]+wc*c[2]
 target=depth[lo[0]:hi[0]+1,lo[1]:hi[1]+1]
 np.maximum(target,np.where((wa>=-1e-5)&(wb>=-1e-5)&(wc>=-1e-5),d,-1.2),out=target)
gx,gy=np.gradient(depth,STEP)
scale=np.minimum(2.5,np.sqrt(1+gx*gx+gy*gy))
field=(zs[None,None,:]-depth[:,:,None])/scale[:,:,None]
field=field.astype(np.float32)
spec=importlib.util.spec_from_file_location('profiles',ROOT/'tools/mountain_art/build_nature_terrace_profiles.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
assets=[]
for variant in [3,4,5,6]:
 vertices,_=mod.read_obj(ROOT/f'assets/UltimateNaturePack/OBJ/Rock_{variant}.obj')
 assets.append(np.array(vertices)-.5)
rng=np.random.default_rng(2697992464+INDEX*71);placements=[]
original_field=field.copy()
for i in range(max(3,int(WIDTH*HEIGHT/26))):
 cx=rng.uniform(-WIDTH/2+2,WIDTH/2-2);cy=rng.uniform(1,HEIGHT-2)
 if i<max(1,int(WIDTH/10)):cy=rng.uniform(.6,1.4)
 w=rng.uniform(3.5,6.5);h=rng.uniform(2.5,4.6);d=rng.uniform(2.6,4.4)
 cy=min(cy,HEIGHT-h*.6-1.2)
 yaw=rng.uniform(-np.pi,np.pi);tilt=rng.uniform(-.4,.4)
 r1=np.array([[np.cos(yaw),0,np.sin(yaw)],[0,1,0],[-np.sin(yaw),0,np.cos(yaw)]])
 r2=np.array([[np.cos(tilt),-np.sin(tilt),0],[np.sin(tilt),np.cos(tilt),0],[0,0,1]])
 index=int(rng.integers(4));points=assets[index]@r1.T@r2.T
 points*=np.array([w,h,d])
 cz=float(depth[int(round((cx-xs[0])/STEP)),int(round((cy-ys[0])/STEP))])-.55
 points+=np.array([cx,cy,cz])
 if points[:,1].max()>HEIGHT-1.0:continue
 # A wide rooted foot carries each low boulder into the real base.
 foot=points.copy()
 foot[:,1]=-.5 if cy<3 else cy-h*1.15
 foot[:,0]=cx+(foot[:,0]-cx)*1.22
 foot[:,2]+=.25
 points=np.concatenate([points,foot])
 hull=ConvexHull(points)
 # Work in the local volume, including the complete smoothing collar.
 radius=.8
 lo=np.maximum(0,np.floor((points.min(0)-radius-np.array([xs[0],ys[0],zs[0]]))/STEP).astype(int))
 hi=np.minimum(np.array(field.shape)-1,np.ceil((points.max(0)+radius-np.array([xs[0],ys[0],zs[0]]))/STEP).astype(int))
 sl=tuple(slice(a,b+1) for a,b in zip(lo,hi));x,y,z=np.meshgrid(xs[sl[0]],ys[sl[1]],zs[sl[2]],indexing='ij')
 sdf=np.full(x.shape,-np.inf,dtype=np.float32)
 for nx,ny,nz,c in hull.equations:np.maximum(sdf,nx*x+ny*y+nz*z+c,out=sdf)
 old=field[sl];blend=np.maximum(radius-np.abs(old-sdf),0)/radius
 field[sl]=np.minimum(old,sdf)-blend*blend*radius*.25
 placements.append(dict(center=[cx,cy,cz],size=[w,h,d],variant=index,radius=radius))
# Preserve the exact exterior domain and buried floor after all unions.
x,y,z=np.meshgrid(xs,ys,zs,indexing='ij')
edge=np.clip((WIDTH/2-np.abs(x)) / 1.2,0,1);edge=edge*edge*(3-2*edge)
field=original_field*(1-edge)+field*edge
field=np.maximum(field,np.maximum.reduce([np.abs(x)-WIDTH/2,-.4-y,y-HEIGHT,-1.2-z]))
field=gaussian_filter(field,.35)
verts,indices,normals,_=marching_cubes(field,0,spacing=(STEP,STEP,STEP),allow_degenerate=False)
verts+=np.array([xs[0],ys[0],zs[0]])
tri=verts[indices];volume=np.einsum('ij,ij->i',tri[:,0],np.cross(tri[:,1],tri[:,2])).sum()/6
if volume>0:indices=indices[:,::-1]
from split_turf import split_turf, weld_solid
tri,green=weld_solid(*split_turf(verts,indices))
tri.astype('<f4').tofile(OUT/f'world-union-{INDEX:02d}-faces.bin');green.astype('<f4').tofile(OUT/f'world-union-{INDEX:02d}-green.bin')
(OUT/f'world-union-{INDEX:02d}-manifest.json').write_text(json.dumps(dict(step=STEP,triangles=len(tri),green=len(green),rocks=placements,source_hash=hashlib.sha256((ROOT/META['path'].removeprefix('res://')).read_bytes()).hexdigest()),indent=2))
print('UNION',len(tri),'triangles',len(green),'turf',len(placements),'rocks',flush=True)
