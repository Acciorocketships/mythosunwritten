"""Offline compatibility experiment: fractured relief inside measured native stock.

Source triangles and seam coordinates are exported by export_cliff_stock.gd.
No source files or runtime terrain controls are modified by this authoring tool.
"""
from pathlib import Path
import json
import numpy as np
import build_kit

ROOT = Path(__file__).resolve().parents[2]
STOCK = ROOT/'docs/qa/2026-09-15-manual/08-cliff-siding/prototype/native-stock.json'
OUT = ROOT/'assets/MythosCliffSiding'


def clip(poly, normal, offset):
    result=[]
    for a,b in zip(poly,np.roll(poly,-1,axis=0)):
        da=np.dot(a[:3],normal)+offset; db=np.dot(b[:3],normal)+offset
        if da <= 1e-9: result.append(a)
        if (da < -1e-9 and db > 1e-9) or (da > 1e-9 and db < -1e-9):
            result.append(a+(b-a)*da/(da-db))
    return np.asarray(result)


def boundary_distance(p, name):
    d=min(p[1]+.3,3.7-p[1])
    if name=='wall': return max(0,min(d,p[0]+1.5,1.5-p[0]))
    if name=='outer_wall': return max(0,min(d,p[0]+1.5,p[2]+1.5))
    return max(0,min(d,1.5-p[0],1.5-p[2]))


def make(name, points):
    faces=np.asarray(points).reshape(-1,3,3)
    normals={}
    for tri in faces:
        n=np.cross(tri[2]-tri[0],tri[1]-tri[0]) # Godot front winding -> outward
        n/=np.linalg.norm(n)
        for p in tri:
            key=tuple(np.round(p,5)); normals[key]=normals.get(key,np.zeros(3))+n
    for key,n in normals.items(): normals[key]=n/max(np.linalg.norm(n),1e-8)
    rng=np.random.default_rng(615)
    # Tall, irregular joints; no horizontal rows of blocks.
    seeds=np.array([[x+rng.uniform(-.35,.35), y+rng.uniform(-.55,.55),z+rng.uniform(-.35,.35)]
                    for x in [-2,-.6,.8,2.2] for y in [-1,1.1,3.5,5.5] for z in [-2,-.6,.8,2.2]])
    metric=np.array([1,.5,1]); seeds_scaled=seeds*metric
    output=[]
    for tri in faces:
        attrs=np.array([np.r_[p,normals[tuple(np.round(p,5))]] for p in tri])
        for i,p in enumerate(seeds_scaled):
            poly=attrs.copy(); planes=[]
            for j,q in enumerate(seeds_scaled):
                if i==j: continue
                n=(q-p)*metric; off=(np.dot(p,p)-np.dot(q,q))*.5
                planes.append((n,off))
                if len(poly)<3: break
                poly=clip(poly,n,off)
            if len(poly)<3: continue
            centre=poly.mean(axis=0)
            # Refine each original clipped polygon so creases occur at actual
            # fracture boundaries, not only at the old mesh's sparse vertices.
            ring=[]
            for a,b in zip(poly,np.roll(poly,-1,axis=0)):
                steps=max(1,int(np.ceil(np.linalg.norm(a[:3]-b[:3])/.25)))
                for k in range(steps): ring.append(a+(b-a)*(k/steps))
            ring=np.asarray(ring)
            vertices=np.vstack([centre,ring,centre+(ring-centre)*.76])
            # Distance to the owning Voronoi halfspaces is independent of the
            # source triangulation, so neighbouring stock triangles still meet.
            for vertex in vertices:
                source=vertex[:3].copy()
                distances=[-(np.dot(source,n)+off)/np.linalg.norm(n) for n,off in planes]
                edge=max(0,min(distances))
                groove=.13*(1-np.clip(edge/.075,0,1))
                collar=np.clip(boundary_distance(source,name)/.16,0,1)
                vertex[:3]-=vertex[3:]*groove*collar
            count=len(ring); triangles=[]
            for k in range(count):
                j=(k+1)%count
                triangles += [[0,1+count+k,1+count+j],[1+k,1+j,1+count+k],[1+j,1+count+j,1+count+k]]
            verts=vertices[:,:3]; ts=np.asarray(triangles)
            areas=np.linalg.norm(np.cross(verts[ts[:,1]]-verts[ts[:,0]],verts[ts[:,2]]-verts[ts[:,0]]),axis=1)
            ts=ts[areas>1e-9]
            # Export glTF CCW rather than the Godot clockwise source triangles.
            if len(ts): output.append((verts,ts[:,::-1]))
    return output


def main():
    OUT.mkdir(exist_ok=True)
    build_kit.OUT=OUT
    stock=json.loads(STOCK.read_text())
    for name in ['wall','outer_wall','inner_wall']:
        parts=make(name,stock[name]['points'])
        build_kit.export_glb(name,parts)
        print(name,sum(len(t) for _,t in parts))

if __name__=='__main__': main()
