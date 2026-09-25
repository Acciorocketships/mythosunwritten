extends RefCounted
## Isolated art study: implicit union of the actual three source formations.
## Box clipping and voxel approximation are not production construction.
const CLIP=preload("res://tests/fixtures/september19/receiver-crown-transition/transition.gd")
const STEP:=.16
const TABLE_STEP:=.125
const TETS=[[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
const CUBE=[Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]
const EDGES=[[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]]
static func apply(forms:Array)->Dictionary:
 var selected:Array=[]
 for form:Dictionary in forms:
  for origin:Vector3 in [Vector3(-445.5,28,-267),Vector3(-445.5,32,-289.5),Vector3(-439.5,28,-277.5)]:
   if form.transform.origin.distance_to(origin)<.01:selected.append(form)
 if selected.size()!=3:return {"error":"requires three actual parents"}
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-445.5,28,-277.5))
 var fields:Array=[]
 for form:Dictionary in selected:fields.append(_field(form,pose))
 var low:=Vector3(-1.44,-.32,-7.04);var dims:=Vector3i(88,80,96)
 var high:=low+Vector3(dims)*STEP
 var nx:=dims.x+1;var ny:=dims.y+1;var nz:=dims.z+1
 var values:=PackedFloat32Array();values.resize(nx*ny*nz)
 var smoothness:=.55
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--union-smooth="):smoothness=float(arg.trim_prefix("--union-smooth="))
 for z in nz:
  for y in ny:
   for x in nx:
    var p:=low+Vector3(x,y,z)*STEP
    var value:=-100.0
    for f:Dictionary in fields:
     var d:=_density(p,f)
     var h:float=maxf(smoothness-absf(d-value),0.0)/smoothness
     value=maxf(value,d)+h*h*smoothness*.25
    values[x+nx*(y+ny*z)]=value
 print("UNION_FIELD samples=",values.size())
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 for z in dims.z:
  for y in dims.y:
   for x in dims.x:
    var ds:Array[float]=[];var ps:Array[Vector3]=[]
    var minimum:=INF;var maximum:=-INF
    for offset:Vector3i in CUBE:
     var q:=Vector3i(x,y,z)+offset
     var d:=values[q.x+nx*(q.y+ny*q.z)]
     ds.append(d);ps.append(low+Vector3(q)*STEP);minimum=minf(minimum,d);maximum=maxf(maximum,d)
    if minimum>=0 or maximum<0:continue
    for tet:Array in TETS:_tet(ps,ds,tet,faces,green)
 for form:Dictionary in selected:_outside_box(form,pose,low,high)
 var patch:Dictionary={"faces":faces,"green":green,"transform":pose,"anchor":pose.origin,"id":"three_way_union_study","replay_recipe":{"kind":"wall","width":14.08,"height":12.0,"seed":2697992464},"kind":"rock","asset":&"cliff.native_crag","native_crag":true}
 CLIP._bounds(patch);forms.append(patch)
 return {"sources":selected.size(),"samples":values.size(),"triangles":faces.size()/3,"green_triangles":green.size()/3,"smoothness":smoothness}
static func _field(form:Dictionary,pose:Transform3D)->Dictionary:
 var columns:Dictionary={}
 for p:Vector3 in form.faces:
  if p.z<=-1.1999:continue
  if not columns.has(p.x):columns[p.x]={}
  columns[p.x][Vector2(p.y,p.z)]=true
 var xs:Array=columns.keys();xs.sort()
 var profiles:Array=[]
 for x:float in xs:
  var row:Array=columns[x].keys();row.sort_custom(func(a:Vector2,b:Vector2)->bool:return a.x<b.x or (a.x==b.x and a.y<b.y))
  profiles.append(row)
 var height:float=form.replay_recipe.height
 var floor_y:=INF
 for p:Vector3 in form.faces:floor_y=minf(floor_y,p.y)
 var rows:=ceili((height-floor_y)/TABLE_STEP)+1
 var depths:=PackedFloat32Array();depths.resize(xs.size()*rows)
 for ix in xs.size():
  for iy in rows:
   var y:=minf(height,floor_y+iy*TABLE_STEP)
   depths[ix+xs.size()*iy]=_profile(profiles[ix],y)
 return {"inverse":form.transform.affine_inverse()*pose,"xs":xs,"nx":xs.size(),"rows":rows,"floor":floor_y,"height":height,"depth":depths}
static func _profile(points:Array,y:float)->float:
 var value:=-1.2
 for i in range(1,points.size()):
  var a:Vector2=points[i-1];var b:Vector2=points[i]
  if y<a.x-.00001 or y>b.x+.00001:continue
  if absf(a.x-b.x)<.00001:value=maxf(value,maxf(a.y,b.y))
  else:value=maxf(value,lerpf(a.y,b.y,(y-a.x)/(b.x-a.x)))
 return value
static func _density(p:Vector3,f:Dictionary)->float:
 var q:Vector3=f.inverse*p
 var x:float=clampf((q.x-f.xs[0])/.25,0,f.nx-1.000001)
 var y:float=clampf((q.y-f.floor)/TABLE_STEP,0,f.rows-1.000001)
 var ix:=floori(x);var iy:=floori(y);var tx:=x-ix;var ty:=y-iy
 var a:float=f.depth[ix+f.nx*iy];var b:float=f.depth[ix+1+f.nx*iy]
 var c:float=f.depth[ix+f.nx*(iy+1)];var d:float=f.depth[ix+1+f.nx*(iy+1)]
 var depth:=lerpf(lerpf(a,b,tx),lerpf(c,d,tx),ty)
 var dx:=lerpf(b-a,d-c,ty)/.25;var dy:=lerpf(c-a,d-b,tx)/TABLE_STEP
 var value:float=(depth-q.z)/sqrt(1+dx*dx+dy*dy)
 value=minf(value,minf(q.x-f.xs[0],f.xs[-1]-q.x))
 value=minf(value,minf(q.y-f.floor,f.height-q.y))
 return minf(value,q.z+1.2)
static func _tet(ps:Array[Vector3],ds:Array[float],tet:Array,faces:PackedVector3Array,green:PackedVector3Array)->void:
 var points:Array[Vector3]=[];var inside:=Vector3.ZERO;var outside:=Vector3.ZERO;var ni:=0;var no:=0
 for i:int in tet:
  if ds[i]>=0:inside+=ps[i];ni+=1
  else:outside+=ps[i];no+=1
 if ni==0 or no==0:return
 for edge:Array in EDGES:
  var a:int=tet[edge[0]];var b:int=tet[edge[1]]
  if (ds[a]>=0)==(ds[b]>=0):continue
  var p:Vector3=ps[a].lerp(ps[b],ds[a]/(ds[a]-ds[b])).snapped(Vector3.ONE*.00001)
  if p not in points:points.append(p)
 if points.size()<3:return
 var normal:Vector3=(outside/no-inside/ni).normalized()
 var center:=Vector3.ZERO
 for p:Vector3 in points:center+=p
 center/=points.size()
 var u:Vector3=(points[0]-center).normalized();var v:=normal.cross(u).normalized()
 points.sort_custom(func(a:Vector3,b:Vector3)->bool:return atan2((a-center).dot(v),(a-center).dot(u))<atan2((b-center).dot(v),(b-center).dot(u)))
 for i in range(1,points.size()-1):
  var a:=points[0];var b:=points[i];var c:=points[i+1]
  var n:Vector3=(c-a).cross(b-a)
  if n.length_squared()<1e-15:continue
  if n.dot(normal)<0:var swap:=b;b=c;c=swap;n=-n
  faces.append_array(PackedVector3Array([a,b,c]))
  if n.normalized().y>.75 and center.y>.05 and center.y<11.5:green.append_array(PackedVector3Array([a,b,c]))
static func _outside_box(form:Dictionary,pose:Transform3D,low:Vector3,high:Vector3)->void:
 var transform:Transform3D=pose.affine_inverse()*form.transform
 var inverse:=transform.affine_inverse()
 for field:String in ["faces","green"]:
  var source:PackedVector3Array=form[field];var result:=PackedVector3Array()
  for i in range(0,source.size(),3):
   var inside:Array[Vector3]=[transform*source[i],transform*source[i+1],transform*source[i+2]]
   var pieces:Array=[]
   for axis in 3:
    for positive:bool in [true,false]:
     var plane:float=low[axis] if positive else high[axis]
     pieces.append(CLIP._polygon(inside,axis,plane,not positive))
     inside=CLIP._polygon(inside,axis,plane,positive)
   for poly:Array in pieces:
    for j in range(1,poly.size()-1):
     if (poly[j]-poly[0]).cross(poly[j+1]-poly[0]).length_squared()<1e-14:continue
     result.append_array(PackedVector3Array([inverse*poly[0],inverse*poly[j],inverse*poly[j+1]]))
  form[field]=result
 CLIP._bounds(form)
