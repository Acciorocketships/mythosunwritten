"""Split the actual solid along a continuous slope contour, with shared edges."""
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

def split_turf(vertices, triangles, threshold=.78):
    v=np.asarray(vertices,dtype=np.float64);t=np.asarray(triangles)
    normals=np.cross(v[t[:,2]]-v[t[:,0]],v[t[:,1]]-v[t[:,0]])
    sums=np.zeros_like(v)
    for j in range(3):np.add.at(sums,t[:,j],normals)
    sums/=np.maximum(np.linalg.norm(sums,axis=1)[:,None],1e-12)
    level=np.minimum.reduce([sums[:,1]-threshold,v[:,2]-.4,v[:,1]-.3])
    positions=list(v);edge_cuts={};out=[];grass=[]
    def cut(a,b):
        key=tuple(sorted((int(a),int(b))))
        if key not in edge_cuts:
            a,b=key;f=level[a]/(level[a]-level[b]);edge_cuts[key]=len(positions)
            positions.append(v[a]+f*(v[b]-v[a]))
        return edge_cuts[key]
    def polygon(tri,positive):
        result=[]
        for a,b in zip(tri,np.roll(tri,-1)):
            ina=level[a]>=0 if positive else level[a]<0
            inb=level[b]>=0 if positive else level[b]<0
            if ina:result.append(int(a))
            if ina!=inb:result.append(cut(a,b))
        return result
    for tri in t:
        signs=level[tri]>=0
        if np.all(signs):out.append(tri);grass.append(tri);continue
        if not np.any(signs):out.append(tri);continue
        for positive in [False,True]:
            poly=polygon(tri,positive)
            for i in range(1,len(poly)-1):
                piece=[poly[0],poly[i],poly[i+1]];out.append(piece)
                if positive:grass.append(piece)
    v=np.asarray(positions);out=np.asarray(out);grass=np.asarray(grass)
    # Reject isolated sub-leaf flecks while retaining continuous pointed ledges.
    graph=coo_matrix((np.ones(len(grass)*3),(grass.ravel(),np.roll(grass,-1,axis=1).ravel())),shape=(len(v),len(v)))
    _,labels=connected_components(graph,directed=False)
    areas=np.linalg.norm(np.cross(v[grass[:,1]]-v[grass[:,0]],v[grass[:,2]]-v[grass[:,0]]),axis=1)*.5
    totals=np.bincount(labels[grass[:,0]],weights=areas,minlength=len(v))
    grass=grass[totals[labels[grass[:,0]]]>.20]
    return v[out],v[grass]

def weld_solid(tri,green):
    # Every material surface shares the same sub-millimetre vertex collapse.
    n=len(tri)
    vertices,indices=np.unique(np.round(np.concatenate([tri,green]).reshape(-1,3),4).astype('<f4'),axis=0,return_inverse=True)
    indices=indices.reshape(-1,3);body=indices[:n];turf=indices[n:]
    def clean(ids):
        return ids[(ids[:,0]!=ids[:,1])&(ids[:,1]!=ids[:,2])&(ids[:,2]!=ids[:,0])]
    body=clean(body);turf=clean(turf)
    for iteration in range(12):
        p=vertices[body]
        bad=np.linalg.norm(np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]),axis=1)<1e-10
        if not np.any(bad):break
        parent=np.arange(len(vertices))
        for face in body[bad]:
            edges=[(int(face[j]),int(face[(j+1)%3])) for j in range(3)]
            a,b=min(edges,key=lambda e:np.linalg.norm(vertices[e[0]]-vertices[e[1]]))
            assert np.linalg.norm(vertices[a]-vertices[b])<.003,'Refuse to hide a substantive collapsed face'
            while parent[a]!=a:a=int(parent[a])
            while parent[b]!=b:b=int(parent[b])
            parent[max(a,b)]=min(a,b)
        while np.any(parent!=parent[parent]):parent=parent[parent]
        body=clean(parent[body]);turf=clean(parent[turf])
    else:raise AssertionError('Needle collapse did not converge')
    return vertices[body],vertices[turf]
