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
            # Straight interior Voronoi edges need no uniform subdivisions.
            # Only the native joining frame introduces measured breakpoints.
            steps=1
            ts=set(float(k)/steps for k in range(steps))
            # Exact native breakpoints along the joining frame, rather than
            # approximating a wavy socket with arbitrary uniform samples.
            for axis,period in [(0,3),(1,4)]:
                other=1-axis
                if abs(a[other]-b[other])>1e-7: continue
                if min(abs(a[other]-lo[other]),abs(a[other]-hi[other]))>1e-7: continue
                if abs(b[axis]-a[axis])<1e-9: continue
                source_values=np.unique(stock[:,:,axis])
                phase=width/2-1.5 if axis==0 else 0
                for repeat in range(-int(width/3)-1,int(height/4)+int(width/3)+2):
                    for value in source_values:
                        cut=value+repeat*period-phase
                        t=(cut-a[axis])/(b[axis]-a[axis])
                        if 1e-7<t<1-1e-7: ts.add(float(t))
            for t in sorted(ts):
                point=a+(b-a)*t
                # Native shared vertices differ by float roundoff in the
                # exported stock. Weld adjacent samples before constructing
                # all four rings, preserving each stone's closed topology.
                if not ring or np.linalg.norm(point-ring[-1])>1e-5: ring.append(point)
        if len(ring)>1 and np.linalg.norm(ring[0]-ring[-1])<1e-5: ring.pop()
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
        native_xy[:,0]=(native_xy[:,0]+width/2)%3-1.5
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


def terraced_panels(parts,width,height):
    # The whole rock mass widens downwards. Shoulders are sections of that
    # volume, never separate floating slabs. Native side/crown collars remain.
    cuts=[height*.31-.3,height*.63-.3]
    levels=sorted([c+d for c in cuts for d in [-.12,.12]])
    result=[]
    def section(poly,y,above):
        output=[]
        for a,b in zip(poly,np.roll(poly,-1,axis=0)):
            ina=a[1]>=y if above else a[1]<=y
            inb=b[1]>=y if above else b[1]<=y
            if ina: output.append(a)
            if ina!=inb:
                v=a+(b-a)*((y-a[1])/(b[1]-a[1]));v[1]=y;output.append(v)
        return np.array(output)
    for vertices,triangles in parts:
        newv=[];newt=[];lookup={}
        def index(v):
            key=tuple(np.round(v,8))
            if key not in lookup: lookup[key]=len(newv);newv.append(v)
            return lookup[key]
        for triangle in vertices[triangles]:
            bounds=[-np.inf]+[c for c in levels if triangle[:,1].min()<c<triangle[:,1].max()]+[np.inf]
            for low,high in zip(bounds,bounds[1:]):
                poly=triangle.copy()
                if np.isfinite(low): poly=section(poly,low,True)
                if np.isfinite(high): poly=section(poly,high,False)
                if len(poly)<3: continue
                ids=[index(v) for v in poly]
                for j in range(1,len(ids)-1):newt.append([ids[0],ids[j],ids[j+1]])
        v=np.array(newv);t=np.array(newt)
        x=v[:,0];y=v[:,1];z=v[:,2]
        side=np.clip((width/2-np.abs(x))/.8,0,1)
        side=side*side*(3-2*side)
        front=np.clip((z-.20)/.3,0,1)
        top=np.clip((height-.3-y)/.7,0,1)
        shoulder=np.zeros(len(y))
        for n,c in enumerate(cuts):
            shoulder+=np.clip((c+.12-y)/.24,0,1)*(0.65+0.22*np.sin(x*.45+n*2.1))
        # Broad ribs and rooted toe breakup add depth without repeated pyramids.
        rib=(.30+.18*np.sin(x*.55+height*.21))
        v[:,2]+=front*side*top*(rib+shoulder)*min(1,height/8)
        result.append((v,t))
    return result


def volumetric_panel(width,height):
    # Fracture actual three-dimensional rock masses with the same authoring
    # operation as the reviewed mountain kit. The high rear mass joins the
    # crown; lower ribs and shoulders stay rooted at the common foot.
    if width<6 or height<8: return []
    parts=[]
    specifications=[(0,1.00,1.00,-1.0),(width*-.27,.47,.79,.05),(width*.28,.44,.56,.28)]
    for i,(offset,w,h,z) in enumerate(specifications):
        seed=238+i*83+width*3+height*7
        raw=build_kit.column(seed,width*w,2.5,height*h,(offset,0,z))
        # At gameplay scale the continuous backing already supplies joints.
        # Keep broad closed ribs; hidden, separately bevelled interior stones
        # multiplied the streamed geometry without changing the silhouette.
        pieces=build_kit.terraced([raw],seed,height*h)
        parts+=pieces
    cloud=np.concatenate([v for v,_ in parts]);lo=cloud.min(axis=0);hi=cloud.max(axis=0)
    result=[]
    for vertices,triangles in parts:
        v=vertices.copy()
        v[:,0]=(v[:,0]-(lo[0]+hi[0])*.5)*width/(hi[0]-lo[0])
        v[:,1]=(v[:,1]-lo[1])*height/(hi[1]-lo[1])-.3
        v[:,2]=.23+(v[:,2]-lo[2])/(hi[2]-lo[2])*min(2.6,height*.26)
        # Recess all rock into the native crown and side socket envelopes.
        edge=np.clip((width*.5-np.abs(v[:,0]))/.55,0,1)
        top=np.clip((height-.3-v[:,1])/.7,0,1)
        v[:,2]=.22+(v[:,2]-.22)*edge*top
        areas=np.linalg.norm(np.cross(v[triangles[:,1]]-v[triangles[:,0]],v[triangles[:,2]]-v[triangles[:,0]]),axis=1)
        result.append((v,triangles[areas>1e-9]))
    return result


def main():
    OUT.mkdir(exist_ok=True);build_kit.OUT=OUT
    for width in WIDTHS:
        for height in HEIGHTS:
            parts=panel(width,height,np.asarray(json.loads(STOCK.read_text())["wall"]["points"]).reshape(-1,3,3))+volumetric_panel(width,height)
            name=f'wall_{width}x{height}'
            build_kit.export_glb(name,parts)
            print(name,sum(len(t) for _,t in parts),flush=True)

if __name__=='__main__':main()
