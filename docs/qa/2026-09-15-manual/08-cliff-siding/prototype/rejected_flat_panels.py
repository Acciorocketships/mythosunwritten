"""Author larger fractured panels against the native 3 m / 4 m joining stock.

Only the collars consume the measured native source profile. The interior is
original irregular rock, with closed stones, restrained bevels and real joints.
"""
from pathlib import Path
import json
import numpy as np
import build_kit

ROOT=Path(__file__).resolve().parents[2]
STOCK=ROOT/'docs/qa/2026-09-15-manual/08-cliff-siding/prototype/native-stock.json'
OUT=ROOT/'assets/MythosCliffSiding'
WIDTHS=[3,6,12,24]
HEIGHTS=[4,8,12,16]


def clip(poly,n,d):
    out=[]
    for a,b in zip(poly,np.roll(poly,-1,axis=0)):
        da=np.dot(a,n)+d; db=np.dot(b,n)+d
        if da<=1e-9: out.append(a)
        if da*db < -1e-14: out.append(a+(b-a)*da/(da-db))
    return np.asarray(out)


def native_depth(points,triangles):
    result=np.full(len(points),.65)
    covered=np.zeros(len(points),bool)
    for triangle in triangles:
        xy=triangle[:,:2]
        matrix=np.stack([xy[1]-xy[0],xy[2]-xy[0]],axis=1)
        if abs(np.linalg.det(matrix))<1e-10: continue
        uv=(points-xy[0])@np.linalg.inv(matrix).T
        mask=(uv[:,0]>=-1e-6)&(uv[:,1]>=-1e-6)&(uv.sum(axis=1)<=1+1e-6)
        z=triangle[0,2]+uv[:,0]*(triangle[1,2]-triangle[0,2])+uv[:,1]*(triangle[2,2]-triangle[0,2])
        result[mask]=np.where(covered[mask],np.maximum(result[mask],z[mask]),z[mask]);covered|=mask
    assert covered.all(),points[~covered]
    return result


def panel(width,height,stock):
    rng=np.random.default_rng(812+width*31+height*73)
    lo=np.array([-width/2,-.3]);hi=np.array([width/2,height-.3])
    rectangle=np.array([lo,[hi[0],lo[1]],hi,[lo[0],hi[1]]])
    seeds=np.array([[x+rng.uniform(-1,1),y+rng.uniform(-1.2,1.2)]
        for y in np.arange(-3,height+4,4.8) for x in np.arange(-width/2-3,width/2+4,3.7)])
    metric=np.array([1,.62]); scaled=seeds*metric
    parts=[]
    for i,p in enumerate(scaled):
        poly=rectangle.copy()
        for j,q in enumerate(scaled):
            if i==j: continue
            poly=clip(poly,(q-p)*metric,(p@p-q@q)*.5)
            if len(poly)<3: break
        if len(poly)<3: continue
        # Keep exact intersections where collars cross native stock vertices.
        # Collinear samples do not alter the Voronoi footprint.
        ring=[]
        for a,b in zip(poly,np.roll(poly,-1,axis=0)):
            steps=max(1,int(np.ceil(np.linalg.norm(b-a)/.7)))
            for k in range(steps): ring.append(a+(b-a)*(k/steps))
        poly=np.array(ring);centre=poly.mean(axis=0)
        distance=np.linalg.norm(poly-centre,axis=1)
        boundary=np.minimum(poly-lo,hi-poly).min(axis=1)
        inset=np.minimum(.024,distance*.05)*np.clip(boundary/.10,0,1)
        edge=poly+(centre-poly)*(inset/np.maximum(distance,1e-6))[:,None]
        inner=edge+(centre-edge)*(np.minimum(.095,distance*.16)/np.maximum(distance,1e-6))[:,None]
        points=np.vstack([centre,inner,edge,edge])
        d=np.minimum(points-lo,hi-points).min(axis=1)
        # Native collars remain inside the existing grass/corner envelope;
        # their influence vanishes over 35 cm into the face.
        native_xy=points.copy()
        native_xy[:,0]=(native_xy[:,0]+1.5)%3-1.5
        native_xy[:,1]=(native_xy[:,1]+.3)%4-.3
        native_xy=np.clip(native_xy,[-1.5,-.3],[1.5,3.7])
        native=native_depth(native_xy,stock)
        collar=np.clip(d/.35,0,1);collar=collar*collar*(3-2*collar)
        slope=rng.uniform(-.035,.035,2)
        depth=np.clip(.77+rng.uniform(-.10,.1)+(points-centre)@slope,.4,.96)
        count=len(poly)
        depth[1+count:1+2*count]-=.09
        z=native*(1-collar)+depth*collar
        z[1+2*count:]=.20
        vertices=np.column_stack([points,z]); triangles=[]
        for k in range(count):
            j=(k+1)%count
            triangles += [[0,1+k,1+j], [1+k,1+count+k,1+count+j],
                          [1+k,1+count+j,1+j],
                          [1+count+k,1+2*count+k,1+2*count+j],
                          [1+count+k,1+2*count+j,1+count+j]]
        # Rear closure fans from a point on the rear plane.
        rear=len(vertices); vertices=np.vstack([vertices,[centre[0],centre[1],.20]])
        for k in range(count): triangles.append([rear,1+2*count+(k+1)%count,1+2*count+k])
        parts.append((vertices,np.array(triangles)))
    return parts


def main():
    OUT.mkdir(exist_ok=True);build_kit.OUT=OUT
    stock=np.asarray(json.loads(STOCK.read_text())['wall']['points']).reshape(-1,3,3)
    for width in WIDTHS:
        for height in HEIGHTS:
            parts=panel(width,height,stock)
            name=f'wall_{width}x{height}'
            build_kit.export_glb(name,parts)
            print(name,sum(len(t) for _,t in parts))

if __name__=='__main__':main()
