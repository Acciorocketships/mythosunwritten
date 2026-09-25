extends RefCounted
## Study: sink an exposed end into an existing adjoining collinear rock body.
static func apply(forms:Array)->void:
 var originals:Array=forms.duplicate(true)
 var changed:=0
 for form:Dictionary in forms:
  var recipe:Dictionary=form.replay_recipe
  if recipe.kind!="wall" or not recipe.has("edge_heights"):continue
  var controls:Array=[]
  for sign_value:float in [-1.0,1.0]:
   if not bool(recipe.left_end if sign_value<0 else recipe.right_end):continue
   var shared:float=recipe.edge_heights.x if sign_value<0 else recipe.edge_heights.y
   if shared<=0:continue
   var end_x:float=sign_value*float(recipe.width)*.5
   for other:Dictionary in originals:
    if other.id==form.id or other.replay_recipe.kind!="wall":continue
    var local:Transform3D=form.transform.affine_inverse()*other.transform
    if local.basis.z.dot(Vector3.BACK)<.99 or absf(local.origin.z)>.01:continue
    var half_width:float=other.replay_recipe.width*.5
    var near_x:float=local.origin.x-sign_value*half_width
    var overlap:float=sign_value*(end_x-near_x)
    if overlap<-.001 or overlap>3.01 or sign_value*local.origin.x<=0:continue
    if local.origin.y>0 or local.origin.y+float(other.replay_recipe.height)<shared-.01:continue
    var segments:=profile(other,local.affine_inverse()*Vector3(end_x,0,0))
    if segments.is_empty():continue
    controls.append({"x":end_x,"profile":segments,"y_offset":local.origin.y,"overlap":overlap,"height":shared,"other":other,"local":local,"cache":{}})
  if controls.is_empty():continue
  var source_profiles:Dictionary={}
  var mapping:Dictionary={}
  for p:Vector3 in form.faces:
   if mapping.has(p):continue
   var q:=p
   var factor:=1.0
   if not source_profiles.has(p.x):source_profiles[p.x]=profile(form,Vector3(p.x,0,0))
   var source_depth:=depth_at(source_profiles[p.x],p.y)
   for control:Dictionary in controls:
    var weight:=1.0-smoothstep(0.0,2.75,absf(p.x-control.x))
    if weight<=0 or p.y>control.height or p.z<-.5:continue
    if not control.cache.has(p.x):
     var local:Transform3D=control.local
     var at:Vector3=local.affine_inverse()*Vector3(p.x,0,0)
     at.x=clampf(at.x,-float(control.other.replay_recipe.width)*.5,float(control.other.replay_recipe.width)*.5)
     control.cache[p.x]=profile(control.other,at)
    var depth:=depth_at(control.cache[p.x],p.y-control.y_offset)
    if not is_finite(depth):continue
    depth-=.04 if control.overlap>.01 else 0.0
    if not is_finite(source_depth) or source_depth<=-1.19:continue
    factor=minf(factor,lerpf(1.0,clampf((depth+1.2)/(source_depth+1.2),.03,1.0),weight))
   q.z=-1.2+(p.z+1.2)*factor if factor<1.0 else p.z
   mapping[p]=q
  for channel:String in ["faces","green"]:
   var values:PackedVector3Array=form[channel]
   for i in values.size():values[i]=mapping[values[i]]
   form[channel]=values
  _retriangulate_ends(form)
  var box:=AABB(form.faces[0],Vector3.ZERO)
  for p:Vector3 in form.faces:box=box.expand(p)
  form.bounds=form.transform*box;form.base=form.bounds.position.y;form.top=form.bounds.end.y
  changed+=1
 print("SHARED_END_PROFILES changed=",changed)
static func profile(form:Dictionary,at:Vector3)->Array:
 var segments:Array=[]
 for i in range(0,form.faces.size(),3):
  var points:Array[Vector2]=[]
  for e in 3:
   var a:Vector3=form.faces[i+e];var b:Vector3=form.faces[i+(e+1)%3]
   if absf(a.x-at.x)<.0001:
    var point:=Vector2(a.y,a.z)
    if point not in points:points.append(point)
   if (a.x-at.x)*(b.x-at.x)<0:
    var p:Vector3=a.lerp(b,(at.x-a.x)/(b.x-a.x));var point:=Vector2(p.y,p.z)
    if point not in points:points.append(point)
  if points.size()==2 and maxf(points[0].y,points[1].y)>=0 and maxf(points[0].x,points[1].x)>-1:segments.append(points)
 return segments
static func depth_at(segments:Array,y:float)->float:
 var depth:=-INF
 for segment:Array in segments:
  var a:Vector2=segment[0];var b:Vector2=segment[1]
  if y<minf(a.x,b.x)-.0001 or y>maxf(a.x,b.x)+.0001:continue
  if absf(a.x-b.x)<.0001:depth=maxf(depth,maxf(a.y,b.y))
  else:depth=maxf(depth,lerpf(a.y,b.y,(y-a.x)/(b.x-a.x)))
 return depth

static func _retriangulate_ends(source:Dictionary)->void:
 # Native polygon triangulation can leave zero-area ears along a straight end
 # boundary. Retriangulate only affected end caps, then restore every boundary
 # sample by splitting its containing triangle. Dropping ears alone opens seams.
 var faces:PackedVector3Array=source.faces
 var half:float=source.replay_recipe.width*.5
 for end:float in [-half,half]:
  var side:=PackedVector3Array();var rest:=PackedVector3Array()
  for i in range(0,faces.size(),3):
   var a:Vector3=faces[i];var b:Vector3=faces[i+1];var c:Vector3=faces[i+2]
   if a.x==end and b.x==end and c.x==end:side.append_array(PackedVector3Array([a,b,c]))
   else:rest.append_array(PackedVector3Array([a,b,c]))
  var edges:Dictionary={}
  for i in range(0,side.size(),3):
   for j in 3:
    var a:=Vector2(side[i+j].z,side[i+j].y)
    var b:=Vector2(side[i+(j+1)%3].z,side[i+(j+1)%3].y)
    var key:Array=[a,b] if a<b else [b,a]
    edges[key]=edges.get(key,0)+1
  var adjacency:Dictionary={}
  for edge:Array in edges:
   if edges[edge]!=1:continue
   for j in 2:
    if not adjacency.has(edge[j]):adjacency[edge[j]]=[]
    adjacency[edge[j]].append(edge[1-j])
  var outline:=PackedVector2Array();var point:Vector2=adjacency.keys()[0];var previous:=Vector2(INF,INF)
  for step in adjacency.size():
   outline.append(point)
   var next:Vector2=adjacency[point][0]
   if next==previous:next=adjacency[point][1]
   previous=point;point=next
  assert(point==outline[0],"End-cap boundary must be one closed loop")
  var clean:=PackedVector2Array()
  for i in outline.size():
   var a:Vector2=outline[posmod(i-1,outline.size())];var b:=outline[i];var c:=outline[(i+1)%outline.size()]
   if absf((b-a).cross(c-b))>.0000001:clean.append(b)
  var indices:=Geometry2D.triangulate_polygon(clean)
  assert(not indices.is_empty())
  var triangles:Array=[]
  for i in range(0,indices.size(),3):triangles.append([clean[indices[i]],clean[indices[i+1]],clean[indices[i+2]]])
  for i in clean.size():
   var start:=outline.find(clean[i]);var finish:=outline.find(clean[(i+1)%clean.size()])
   var chain:Array[Vector2]=[outline[start]]
   while start!=finish:
    start=(start+1)%outline.size();chain.append(outline[start])
   if chain.size()<=2:continue
   var found:=false
   for t in triangles.size():
    var tri:Array=triangles[t]
    for j in 3:
     var reverse:bool=tri[j]==chain[-1] and tri[(j+1)%3]==chain[0]
     if not reverse and not (tri[j]==chain[0] and tri[(j+1)%3]==chain[-1]):continue
     if reverse:chain.reverse()
     var opposite:Vector2=tri[(j+2)%3]
     triangles.remove_at(t)
     for n in chain.size()-1:triangles.append([chain[n],chain[n+1],opposite])
     found=true;break
    if found:break
   assert(found,"Every collinear boundary sample retains its physical edge")
  for tri:Array in triangles:
   var a:=Vector3(end,tri[0].y,tri[0].x);var b:=Vector3(end,tri[1].y,tri[1].x);var c:=Vector3(end,tri[2].y,tri[2].x)
   if (c-a).cross(b-a).x*end<0:var swap:=b;b=c;c=swap
   rest.append_array(PackedVector3Array([a,b,c]))
  faces=rest
 source.faces=faces
