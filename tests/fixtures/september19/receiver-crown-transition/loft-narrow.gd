extends RefCounted
const S=preload("res://scripts/terrain/field/CliffInnerSurface.gd")
const L=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
const CAPS=preload("res://scripts/terrain/field/CliffRockEndCaps.gd")
static func apply(forms:Array)->Dictionary:
 var incoming:Dictionary={};var outgoing:Dictionary={}
 for form:Dictionary in forms:
  if form.transform.origin.distance_to(Vector3(-445.5,28,-267))<.01:incoming=form
  if form.transform.origin.distance_to(Vector3(-445.5,32,-289.5))<.01:outgoing=form
 if incoming.is_empty() or outgoing.is_empty():return {"error":"missing actual source"}
 var x0:=8.0;var x1:=14.0
 var source_a:=S.section(incoming,Vector3(x0,0,0),12)
 var source_b:=S.section(outgoing,Vector3(-8.5,0,0),8)
 var tread_a:=L.nearest_row(L.columns(incoming),x0,5.0)
 var tread_b:=S.main_tread(outgoing,Vector3(-8.5,0,0),8)
 var a:=source_a.duplicate();var b:=source_b.duplicate()
 for i in b.size():b[i].y+=4.0
 b.append(Vector2(b[-1].x,a[-1].y))
 var bt:Array=[]
 for p:Vector2 in tread_b:bt.append(p+Vector2(0,4))
 var ad:=S.parameters(a,tread_a);var bd:=S.parameters(b,bt)
 if ad.is_empty() or bd.is_empty():return {"error":"missing actual treads"}
 var low_interval:=Vector2(INF,-INF)
 var low_tread:=L.nearest_row(L.columns(incoming),x0,2.5)
 for i in a.size():
  for p:Vector2 in low_tread:
   if a[i].distance_to(p)<.001:low_interval.x=minf(low_interval.x,ad[i]);low_interval.y=maxf(low_interval.y,ad[i])
 var samples:Array[float]=[]
 for list:PackedFloat32Array in [ad,bd]:
  for value:float in list:
   if value not in samples:samples.append(value)
 samples.sort()
 var front:Array=[];var back:Array=[]
 var steps:=36
 for i in steps+1:
  var t:=float(i)/steps;var blend:=smoothstep(0.0,1.0,t)
  var row:=PackedVector3Array();var rear:=PackedVector3Array()
  for s:float in samples:
   var pa:=S.at(a,ad,s);var pb:=S.at(b,bd,s)
   var p:=pa.lerp(pb,blend)
   row.append(Vector3(lerpf(x0,x1,t),p.y,p.x).snapped(Vector3.ONE*.0001))
   rear.append(Vector3(lerpf(x0,x1,t),p.y,-1.2).snapped(Vector3.ONE*.0001))
  front.append(row);back.append(rear)
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 for i in steps:
  for j in samples.size()-1:
   var turf:bool=(samples[j]>=.4-.00001 and samples[j+1]<=.6+.00001) or (samples[j]>=low_interval.x-.00001 and samples[j+1]<=low_interval.y+.00001)
   S.tri(faces,green,front[i][j],front[i+1][j],front[i][j+1],turf)
   S.tri(faces,green,front[i+1][j],front[i+1][j+1],front[i][j+1],turf)
   S.tri(faces,green,back[i][j],back[i][j+1],back[i+1][j],false)
   S.tri(faces,green,back[i+1][j],back[i][j+1],back[i+1][j+1],false)
  S.tri(faces,green,front[i][0],back[i][0],front[i+1][0],false)
  S.tri(faces,green,front[i+1][0],back[i][0],back[i+1][0],false)
  S.tri(faces,green,front[i][-1],front[i+1][-1],back[i][-1],false)
  S.tri(faces,green,front[i+1][-1],back[i+1][-1],back[i][-1],false)
 for j in samples.size()-1:
  S.tri(faces,green,front[0][j],front[0][j+1],back[0][j],false)
  S.tri(faces,green,back[0][j],front[0][j+1],back[0][j+1],false)
  S.tri(faces,green,front[-1][j],back[-1][j],front[-1][j+1],false)
  S.tri(faces,green,back[-1][j],back[-1][j+1],front[-1][j+1],false)
 _clip(incoming,x0,false)
 _clip(outgoing,-8.5,true)
 var result:Dictionary=incoming.duplicate(true)
 result.faces=faces;result.green=green;result.id="height_step_loft";result.erase("native_roots")
 _bounds(result);forms.append(result)
 return {"patch_triangles":faces.size()/3,"left_section":source_a.size(),"right_section":source_b.size()}
static func _clip(form:Dictionary,x:float,positive:bool)->void:
 for field:String in ["faces","green"]:
  var original:PackedVector3Array=form[field];var clipped:=PackedVector3Array()
  for i in range(0,original.size(),3):
   var polygon:Array[Vector3]=[]
   for e in 3:
    var a:=original[i+e];var b:=original[i+(e+1)%3]
    var inside:bool=a.x>=x-.00001 if positive else a.x<=x+.00001
    var next_inside:bool=b.x>=x-.00001 if positive else b.x<=x+.00001
    if inside:polygon.append(a)
    if inside!=next_inside:polygon.append(a.lerp(b,(x-a.x)/(b.x-a.x)).snapped(Vector3.ONE*.0001))
   for j in range(1,polygon.size()-1):
    if polygon[0]==polygon[j] or polygon[j]==polygon[j+1] or polygon[j+1]==polygon[0]:continue
    clipped.append_array(PackedVector3Array([polygon[0],polygon[j],polygon[j+1]]))
  form[field]=clipped
 # The joining patch shares this entire profile. Separate caps are intentionally
 # omitted in this art study; production would own the complete merged solid.
 _bounds(form)
static func _bounds(form:Dictionary)->void:
 var box:=AABB(form.faces[0],Vector3.ZERO)
 for p:Vector3 in form.faces:box=box.expand(p)
 form.bounds=form.transform*box;form.base=form.bounds.position.y;form.top=form.bounds.end.y
