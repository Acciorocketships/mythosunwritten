"""Author original fractured limestone meshes; deterministic, no downloaded geometry.

glTF sources use metres, outward CCW triangles and independently closed solids.
All shape decisions live here; the game never regenerates these meshes at runtime.
"""
from pathlib import Path
import json
import math
import struct
import numpy as np
from scipy.spatial import ConvexHull, HalfspaceIntersection
from scipy.optimize import linprog

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/MythosMountains'


def column(seed, width, depth, height, offset=(0,0,0), lean=0):
    rng = np.random.default_rng(seed)
    # An asymmetric bevelled rectangle, rather than concentric square tiers.
    outline = np.array([[-.34,-.5],[.25,-.51],[.48,-.29],[.52,.17],
                        [.34,.47],[.05,.53],[-.30,.48],[-.49,.24],
                        [-.52,-.16]], dtype=float)
    outline += rng.uniform(-.06,.06,outline.shape)
    phases = rng.uniform(0,6.28,len(outline))
    levels = [0.0]
    y = 0.0
    while y < height-3:
        y += rng.uniform(4.3,8.7)
        if y < height-2:
            levels.extend([y, y+.20])
    levels.append(height)
    vertices = []
    for k,y in enumerate(levels):
        q=y/height
        for j,(x,z) in enumerate(outline):
            taper=1.02-.13*q + .09*math.sin(q*4.5+phases[j])
            fault = (.035 if k%2==1 else -.018) if k not in (0,len(levels)-1) else 0
            px=x*width*(taper+fault)+lean*q*q+math.sin(q*5+seed)*width*.035
            pz=z*depth*(taper+fault)+math.sin(q*3+seed)*depth*.065
            py=y
            if k==len(levels)-1: py += (.16+.15*math.sin(phases[j]))*min(width,depth)
            vertices.append([px+offset[0],py+offset[1],pz+offset[2]])
    n=len(outline); faces=[]
    # CCW around Y means this outline's side normal must be chosen explicitly.
    for k in range(len(levels)-1):
        for j in range(n):
            a=k*n+j;b=k*n+(j+1)%n;c=(k+1)*n+j;d=(k+1)*n+(j+1)%n
            faces.extend([[a,c,b],[b,c,d]])
    for j in range(1,n-1):
        faces.append([0,j,j+1])
        s=(len(levels)-1)*n
        faces.append([s,s+j+1,s+j])
    v=np.asarray(vertices);t=np.asarray(faces)
    a,b,c=v[t[:,0]],v[t[:,1]],v[t[:,2]]
    if np.einsum('ij,ij->i',a,np.cross(b,c)).sum()<0:t=t[:,::-1]
    return v,t


def raw_kit():
    return {
        'pillar_slender': [column(51,8,8,48,lean=3),column(14,3.7,5,32,(-3,0,1),lean=1)],
        'pillar_split': [column(32,9,10,44,(-3,0,0),lean=-1),column(76,6,7,36,(3,0,2),lean=2)],
        'pillar_crown': [column(22,11,11,38,lean=-2),column(47,6,8,27,(5,0,0),lean=-1),column(68,5,7,19,(-5,0,2))],
        'buttress_tall': [column(87,10,8,34),column(45,6,7,23,(-6,0,1)),column(74,5,6,15,(6,0,2))],
        'buttress_wide': [column(35,10,9,25,(-7,0,0)),column(63,9,11,32,(0,0,-1)),column(83,8,8,21,(7,0,2))],
        'shelf_long': [column(106,20,7,3)],
        'shelf_end': [column(107,8,6,3)],
        'shelf_corner': [column(109,9,10,4)],
    }


def fractured(seed, original, joint_spacing=5.5, joint_scale=.985, bevel_width=.18):
    """Irregular volumetric joints, with rounded bevel planes along exposed edges."""
    rng=np.random.default_rng(seed)
    v,_=original
    hull=ConvexHull(v)
    lo,hi=v.min(axis=0),v.max(axis=0)
    extent=hi-lo
    # Staggered 3D fracture seeds; tall cells give a strong vertical grain.
    seeds=[]
    for y in np.arange(lo[1]+2,hi[1],joint_spacing):
        for x in [-.28,.16]:
            for z in [-.25,.23]:
                seeds.append([lo[0]+extent[0]*(.5+x+rng.uniform(-.1,.1)),
                              np.clip(y+rng.uniform(-4.0,4.0),lo[1]+.5,hi[1]-.5),lo[2]+extent[2]*(.5+z+rng.uniform(-.1,.1))])
    if len(seeds)<4:return [original]
    seeds=np.array(seeds)
    pieces=[]
    outer=hull.equations
    for p in seeds:
        planes=list(outer.copy())
        for q in seeds:
            if np.array_equal(p,q):continue
            n=q-p
            planes.append(np.r_[n,(np.dot(p,p)-np.dot(q,q))*.5])
        planes=np.array(planes)
        planes/=np.linalg.norm(planes[:,:3],axis=1)[:,None]
        # Chebyshev centre proves that a clipped cell has a real interior.
        sol=linprog([0,0,0,-1],A_ub=np.c_[planes[:,:3],np.ones(len(planes))],b_ub=-planes[:,3],bounds=[(None,None)]*3+[(0,None)],method='highs')
        if not sol.success or sol.x[3]<.08:continue
        center=sol.x[:3]
        pts=HalfspaceIntersection(planes,center).intersections
        cell=ConvexHull(pts)
        # Make fine closed joints; neighbouring fracture faces remain near each other.
        pts=center+(pts-center)*joint_scale
        cell=ConvexHull(pts)
        equations=cell.equations
        # Deduplicate coplanar triangles before adding edge bevels.
        unique=np.unique(np.round(equations,7),axis=0)
        bevel=list(unique)
        for a in range(len(unique)):
            for b in range(a+1,len(unique)):
                na,nb=unique[a,:3],unique[b,:3]
                dot=np.dot(na,nb)
                if dot>.96 or dot<-.85:continue
                on_a=abs(pts@na+unique[a,3])<1e-5
                on_b=abs(pts@nb+unique[b,3])<1e-5
                if np.count_nonzero(on_a&on_b)<2:continue
                n=na+nb;length=np.linalg.norm(n)
                eq=(unique[a]+unique[b])/length
                eq[3]+=min(bevel_width,sol.x[3]*.15)
                bevel.append(eq)
        bevel=np.array(bevel)
        pts=np.unique(np.round(HalfspaceIntersection(bevel,center).intersections,2),axis=0)
        final=ConvexHull(pts)
        triangles=final.simplices.copy()
        for i,t in enumerate(triangles):
            if np.dot(np.cross(pts[t[1]]-pts[t[0]],pts[t[2]]-pts[t[0]]),final.equations[i,:3])<0:triangles[i]=t[::-1]
        # One continuous deformation across all cells preserves matching fracture seams.
        q=(pts[:,1]-lo[1])/extent[1]
        radial=1+.027*np.sin(q*7+seed*.17)+.008*np.sin(q*15+seed)
        centre_xz=(lo+hi)[[0,2]]*.5
        pts[:,[0,2]]=centre_xz+(pts[:,[0,2]]-centre_xz)*radial[:,None]
        pts[:,0]+=.015*extent[0]*np.sin(q*5+seed)
        pieces.append((pts,triangles))
    return pieces


def terraced(parts, seed, height):
    """Carve shared, uneven shoulders into the already fractured volume.

    A convex hull cannot retain terraces. Split the *closed surface* at every
    shoulder first, then apply one common height/azimuth profile to all stones.
    Shared fracture edges receive the same transform, including the new cuts.
    Lower sections always extend farther than the section they carry.
    """
    rng = np.random.default_rng(seed)
    heights = height * (np.array([.26, .49, .73]) + rng.uniform(-.035, .035, 3))
    weights = rng.uniform(.23, .29, 3)
    phases = rng.uniform(0, 2*math.pi, 3)
    cuts = sorted([y+delta for y in heights for delta in [-.16, .16]])
    cloud = np.concatenate([v for v, _ in parts])
    centre = (cloud.min(axis=0) + cloud.max(axis=0))[[0, 2]] * .5

    def clip(poly, y, above):
        result = []
        for a, b in zip(poly, np.roll(poly, -1, axis=0)):
            inside_a = a[1] >= y if above else a[1] <= y
            inside_b = b[1] >= y if above else b[1] <= y
            if inside_a: result.append(a)
            if inside_a != inside_b:
                p = a + (b-a)*((y-a[1])/(b[1]-a[1]))
                p[1] = y
                result.append(p)
        return np.asarray(result)

    result = []
    for v, triangles in parts:
        vertices, faces, lookup = [], [], {}
        def index(p):
            key = tuple(np.round(p, 8))
            if key not in lookup:
                lookup[key] = len(vertices)
                vertices.append(p)
            return lookup[key]
        for triangle in v[triangles]:
            intervals = [-math.inf] + [y for y in cuts if triangle[:, 1].min() < y < triangle[:, 1].max()] + [math.inf]
            for lo, hi in zip(intervals, intervals[1:]):
                poly = triangle.copy()
                if math.isfinite(lo): poly = clip(poly, lo, True)
                if math.isfinite(hi) and len(poly): poly = clip(poly, hi, False)
                if len(poly) < 3: continue
                ids = [index(p) for p in poly]
                for j in range(1, len(ids)-1):
                    face = [ids[0], ids[j], ids[j+1]]
                    if len(set(face)) == 3: faces.append(face)
        vertices = np.array(vertices)
        angle = np.arctan2(vertices[:, 2]-centre[1], vertices[:, 0]-centre[0])
        factor = np.ones(len(vertices))
        for y, amount, phase in zip(heights, weights, phases):
            # Broad unequal shoulders, not concentric square stacks. The exposed
            # upward faces receive moss from their real geometric normals.
            lower = 1-np.clip((vertices[:, 1]-(y-.16))/.32, 0, 1)
            factor += lower*amount*(1+.30*np.sin(angle*2+phase))
        vertices[:, [0, 2]] = centre + (vertices[:, [0, 2]]-centre)*factor[:, None]
        # Open the narrow stone joints only AFTER shaping the ledges. Stretching
        # pre-opened horizontal gaps through a shallow ledge makes giant notches.
        stone_centre = vertices.mean(axis=0)
        vertices = stone_centre + (vertices-stone_centre)*.985
        faces = np.array(faces)
        # A shoulder plane can graze an existing bevel vertex. Collapse only
        # sub-centimetre edges of the resulting slivers, including both incident
        # triangles, so the closed stone never gains an open/degenerate face.
        while True:
            p = vertices[faces]
            tiny = np.linalg.norm(np.cross(p[:, 1]-p[:, 0], p[:, 2]-p[:, 0]), axis=1) <= 1e-5
            if not tiny.any(): break
            face = faces[np.flatnonzero(tiny)[0]]
            edges = [(int(face[j]), int(face[(j+1)%3])) for j in range(3)]
            a, b = min(edges, key=lambda e: np.linalg.norm(vertices[e[0]]-vertices[e[1]]))
            assert np.linalg.norm(vertices[a]-vertices[b]) < .01, 'A large sliver needs a new triangulation'
            faces[faces == b] = a
            faces = faces[(faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) & (faces[:, 2] != faces[:, 0])]
        result.append((vertices, faces))
    return result


def kit():
    result={}
    for i,(name,parts) in enumerate(raw_kit().items()):
        result[name]=[]
        for j,part in enumerate(parts):
            stones = (fractured(900+i*20+j,part,7.8,1.0,.06)
                      if not name.startswith('shelf') else fractured(900+i*20+j,part))
            if not name.startswith('shelf'):
                stones = terraced(stones, 1200+i*20+j, part[0][:, 1].max())
            result[name].extend(stones)
    return result


def export_glb(name, parts):
    binary=bytearray();views=[];accessors=[];prims=[]
    def accessor(array, kind):
        array=np.asarray(array,dtype='<f4')
        while len(binary)%4:binary.append(0)
        offset=len(binary);binary.extend(array.tobytes())
        views.append({'buffer':0,'byteOffset':offset,'byteLength':array.nbytes})
        accessors.append({'bufferView':len(views)-1,'componentType':5126,'count':len(array),'type':kind,
                          'min':array.min(axis=0).tolist(),'max':array.max(axis=0).tolist()})
        return len(accessors)-1
    for vertices, triangles in parts:
        points=vertices[triangles]
        normal=np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0])
        normal/=np.linalg.norm(normal,axis=1)[:,None]
        pos=points.reshape(-1,3);norm=np.repeat(normal,3,axis=0)
        # Broad source colour variation; the study's moss shader adds world-space detail.
        shade=.90+.055*np.sin(pos[:,0]*.6+pos[:,1]*.11+pos[:,2]*.25)
        colors=np.column_stack([shade,shade,shade,np.ones(len(pos))])
        prims.append({'attributes':{'POSITION':accessor(pos,'VEC3'),'NORMAL':accessor(norm,'VEC3'),
                                    'TEXCOORD_0':accessor(pos[:,[0,1]]*.1,'VEC2'),'COLOR_0':accessor(colors,'VEC4')},'material':0})
    doc={'asset':{'version':'2.0','generator':'Mythos original mountain authoring tool'},
         'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0,'name':name}],
         'meshes':[{'primitives':prims}], 'materials':[{'name':'Limestone','pbrMetallicRoughness':{
             'baseColorFactor':[.51,.54,.48,1],'roughnessFactor':.92,'metallicFactor':0}}],
         'buffers':[{'byteLength':len(binary)}],'bufferViews':views,'accessors':accessors}
    data=json.dumps(doc,separators=(',',':')).encode()
    data+=b' '*((-len(data))%4)
    binary+=b'\0'*((-len(binary))%4)
    glb=struct.pack('<III',0x46546c67,2,12+8+len(data)+8+len(binary))
    glb+=struct.pack('<II',len(data),0x4e4f534a)+data+struct.pack('<II',len(binary),0x004e4942)+binary
    (OUT/f'{name}.glb').write_bytes(glb)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    entries=[]
    for name,parts in kit().items():
        export_glb(name,parts)
        entries.append({'id':'mythos.mountain.'+name,'source':'res://assets/MythosMountains/'+name+'.glb',
                        'collision_profile':'native_trimesh','merge_pieces':True,
                        'material_override':'res://terrain/environment/materials/mythos_mountains/limestone.tres','tags':['rock','cliff'],'supports_instance_color':False})
    (ROOT/'tools/environment_bake/manifests/mythos_mountains.json').write_text(json.dumps({
        'pack':'mythos_mountains','license':'Original project assets; authored from mathematical profiles','assets':entries},indent=2)+'\n')
    print('Wrote',len(entries),'original GLB sources')


if __name__ == '__main__':main()
