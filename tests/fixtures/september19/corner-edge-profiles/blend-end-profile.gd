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
    controls.append({"x":end_x,"profile":segments,"y_offset":local.origin.y,"overlap":overlap,"height":shared})
  if controls.is_empty():continue
  var mapping:Dictionary={}
  for p:Vector3 in form.faces:
   if mapping.has(p):continue
   var q:=p
   for control:Dictionary in controls:
    var weight:=1.0-smoothstep(0.0,2.75,absf(p.x-control.x))
    if weight<=0 or p.y>control.height or p.z<-.5:continue
    var depth:=depth_at(control.profile,p.y-control.y_offset)
    if not is_finite(depth):continue
    depth-=.04 if control.overlap>.01 else 0.0
    q.z-=maxf(0.0,q.z-depth)*weight
   mapping[p]=q
  for channel:String in ["faces","green"]:
   var values:PackedVector3Array=form[channel]
   for i in values.size():values[i]=mapping[values[i]]
   form[channel]=values
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
