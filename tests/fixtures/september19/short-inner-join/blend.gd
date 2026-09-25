extends RefCounted
const STEP:=.20
const BIN:=.5
const TETS=[[0,1,3,7],[0,3,2,7],[0,2,6,7],[0,6,4,7],[0,4,5,7],[0,5,1,7]]
static func projected(form:Dictionary,pose:Transform3D)->Dictionary:
 var n:Vector3=Vector3(1,0,1).normalized() if form.replay_recipe.kind=="inner_corner" else pose.basis.inverse()*form.transform.basis.z
 var t:=Vector3(n.z,0,-n.x)
 var bins:Dictionary={}
 var limits:=Rect2();var first:=true
 var transform:Transform3D=pose.affine_inverse()*form.transform
 for i in range(0,form.faces.size(),3):
  var tri:Array=[];var box:=Rect2()
  for j in 3:
   var p:Vector3=transform*form.faces[i+j]
   var q:=Vector3(t.dot(p),p.y,n.dot(p));tri.append(q)
   if first:limits=Rect2(Vector2(q.x,q.y),Vector2.ZERO);first=false
   else:limits=limits.expand(Vector2(q.x,q.y))
   if j==0:box=Rect2(Vector2(q.x,q.y),Vector2.ZERO)
   else:box=box.expand(Vector2(q.x,q.y))
  var a:=Vector2(tri[1].x-tri[0].x,tri[1].y-tri[0].y)
  var b:=Vector2(tri[2].x-tri[0].x,tri[2].y-tri[0].y)
  var determinant:=a.cross(b)
  if absf(determinant)<.000001:continue
  var entry:Array=[tri[0],tri[1],tri[2],a,b,determinant]
  for x in range(floori(box.position.x/BIN),floori(box.end.x/BIN)+1):
   for y in range(floori(box.position.y/BIN),floori(box.end.y/BIN)+1):
    var key:=Vector2i(x,y)
    if not bins.has(key):bins[key]=[]
    bins[key].append(entry)
 return {"normal":n,"tangent":t,"bins":bins,"limits":limits}
static func field(source:Dictionary,p:Vector3)->float:
 var raw:=Vector2(source.tangent.dot(p),p.y)
 var limits:Rect2=source.limits
 var q:=raw.clamp(limits.position+Vector2.ONE*.0001,limits.end-Vector2.ONE*.0001)
 var depth:=-100.0
 for tri:Array in source.bins.get(Vector2i(floori(q.x/BIN),floori(q.y/BIN)),[]):
  var r:=q-Vector2(tri[0].x,tri[0].y)
  var a:float=r.cross(tri[4])/tri[5];var b:float=(tri[3] as Vector2).cross(r)/tri[5]
  if a<-.00001 or b<-.00001 or a+b>1.00001:continue
  depth=maxf(depth,tri[0].z+a*(tri[1].z-tri[0].z)+b*(tri[2].z-tri[0].z))
 return minf(depth-source.normal.dot(p),minf(minf(raw.x-limits.position.x,limits.end.x-raw.x),minf(raw.y-limits.position.y,limits.end.y-raw.y)))
static func density(sources:Array,p:Vector3)->float:
 var value:=-100.0
 for source:Dictionary in sources:
  var b:=field(source,p)
  var k:=.6
  var h:=maxf(0.0,k-absf(value-b))/k
  value=maxf(value,b)+h*h*k*.25
 return minf(value+.10,minf(minf(p.x+.6,8.4-p.x),minf(minf(p.z+.6,8.4-p.z),minf(p.y+.2,3.96-p.y))))
static func tri(out:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3,outward:Vector3)->void:
 a=a.snapped(Vector3.ONE*.00001);b=b.snapped(Vector3.ONE*.00001);c=c.snapped(Vector3.ONE*.00001)
 if (c-a).cross(b-a).length_squared()<1e-14:return
 if (c-a).cross(b-a).dot(outward)<0:var swap:=b;b=c;c=swap
 out.append(a);out.append(b);out.append(c)
static func cross_edge(a:Vector3,b:Vector3,da:float,db:float)->Vector3:return a.lerp(b,da/(da-db))
static func tetra(out:PackedVector3Array,points:Array,values:Array)->void:
 var inside:Array=[];var outside:Array=[];var a_mean:=Vector3.ZERO;var b_mean:=Vector3.ZERO
 for i in 4:
  if values[i]>0:inside.append(i);a_mean+=points[i]
  else:outside.append(i);b_mean+=points[i]
 if inside.is_empty() or outside.is_empty():return
 var outward:Vector3=b_mean/outside.size()-a_mean/inside.size()
 if inside.size()==1 or inside.size()==3:
  var one:int=inside[0] if inside.size()==1 else outside[0]
  var others:Array=outside if inside.size()==1 else inside
  var p:Array=[]
  for i:int in others:p.append(cross_edge(points[one],points[i],values[one],values[i]))
  tri(out,p[0],p[1],p[2],outward)
 else:
  var p:Array=[]
  for pair:Array in [[inside[0],outside[0]],[inside[0],outside[1]],[inside[1],outside[1]],[inside[1],outside[0]]]:
   p.append(cross_edge(points[pair[0]],points[pair[1]],values[pair[0]],values[pair[1]]))
  tri(out,p[0],p[1],p[2],outward);tri(out,p[0],p[2],p[3],outward)
static func apply(forms:Array)->void:
 var corner:=Vector3(-421.5,28,-349.5)
 var original:Dictionary={}
 for f:Dictionary in forms:
  if f.replay_recipe.kind=="inner_corner" and f.anchor.distance_to(corner)<.01:original=f
 if original.is_empty():return
 var pose:Transform3D=original.transform
 var sources:Array=[]
 for f:Dictionary in forms:
  if f.replay_recipe.kind not in ["wall","inner_corner"]:continue
  if f.anchor.distance_to(corner)>24 or f.top<corner.y or f.base>corner.y+4:continue
  var n:Vector3=pose.basis.inverse()*f.transform.basis.z
  if f!=original and n.dot(Vector3.BACK)<.99 and n.dot(Vector3.RIGHT)<.99:continue
  sources.append(projected(f,pose))
 var start:=Vector3(-.8,-.4,-.8);var nx:=48;var ny:=24;var nz:=48
 var samples:=PackedFloat32Array();samples.resize(nx*ny*nz)
 for z in nz:
  for y in ny:
   for x in nx:samples[x+nx*(y+ny*z)]=density(sources,start+Vector3(x,y,z)*STEP)
 var faces:=PackedVector3Array()
 for z in nz-1:
  for y in ny-1:
   for x in nx-1:
    var points:Array=[];var values:Array=[]
    for iz in 2:
     for iy in 2:
      for ix in 2:
       points.append(start+Vector3(x+ix,y+iy,z+iz)*STEP)
       values.append(samples[x+ix+nx*(y+iy+ny*(z+iz))])
    for tet:Array in TETS:tetra(faces,[points[tet[0]],points[tet[1]],points[tet[2]],points[tet[3]]],[values[tet[0]],values[tet[1]],values[tet[2]],values[tet[3]]])
 var green:=PackedVector3Array();var bounds:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:bounds=bounds.expand(p)
 for i in range(0,faces.size(),3):
  var n:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
  var center:Vector3=(faces[i]+faces[i+1]+faces[i+2])/3
  if n.y>.8 and center.y>.4 and center.y<3.8 and center.x>.6 and center.z>.6:
   green.append(faces[i]);green.append(faces[i+1]);green.append(faces[i+2])
 var new_form:=original.duplicate()
 new_form.native_roots={}
 for p:Vector3 in faces:new_form.native_roots[p]=[Vector3.UP,1.0]
 new_form.faces=faces;new_form.green=PackedVector3Array();new_form.bounds=pose*bounds;new_form.top=(pose*bounds).end.y;new_form.base=(pose*bounds).position.y
 forms[forms.find(original)]=new_form
 print("BLEND_STUDY triangles=",faces.size()/3," sources=",sources.size())
