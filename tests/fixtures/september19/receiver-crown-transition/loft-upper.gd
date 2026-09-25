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
 var a:=PackedVector2Array();var b:=source_b.duplicate()
 for i in source_a.size():
  var point:Vector2=source_a[i]
  if point.y>=4.0:a.append(point)
  else:
   if a[-1].y>4.0:a.append(a[-1].lerp(point,(4.0-a[-1].y)/(point.y-a[-1].y)))
   break
 for i in b.size():b[i].y+=4.0

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
 _clip(incoming,x0,false,4.0)
 _clip(outgoing,-8.5,true)
 var result:Dictionary=incoming.duplicate(true)
 result.faces=faces;result.green=green;result.id="height_step_loft";result.erase("native_roots")
 _bounds(result);forms.append(result)
 return {"patch_triangles":faces.size()/3,"left_section":source_a.size(),"right_section":source_b.size()}
static func _clip(form:Dictionary,x:float,positive:bool,min_y:float=-INF)->void:
 for field:String in ["faces","green"]:
  var original:PackedVector3Array=form[field];var clipped:=PackedVector3Array()
  for i in range(0,original.size(),3):
   var source:Array[Vector3]=[original[i],original[i+1],original[i+2]]
   var polygons:Array=[]
   if is_finite(min_y):
    if minf(source[0].y,minf(source[1].y,source[2].y))<min_y:
     polygons.append(_polygon(source,1,min_y,false))
    polygons.append(_polygon(_polygon(source,1,min_y,true),0,x,positive))
   else:polygons.append(_polygon(source,0,x,positive))
   for polygon:Array in polygons:
    for j in range(1,polygon.size()-1):
     if (polygon[j]-polygon[0]).cross(polygon[j+1]-polygon[0]).length_squared()<1e-14:continue
     clipped.append_array(PackedVector3Array([polygon[0],polygon[j],polygon[j+1]]))
  form[field]=clipped
 _bounds(form)
static func _polygon(source:Array[Vector3],axis:int,plane:float,positive:bool)->Array[Vector3]:
 var result:Array[Vector3]=[]
 for i in source.size():
  var a:=source[i];var b:=source[(i+1)%source.size()]
  var inside:bool=a[axis]>=plane if positive else a[axis]<=plane
  var next_inside:bool=b[axis]>=plane if positive else b[axis]<=plane
  if inside:result.append(a)
  if inside!=next_inside:result.append(a.lerp(b,(plane-a[axis])/(b[axis]-a[axis])).snapped(Vector3.ONE*.0001))
 return result
static func _bounds(form:Dictionary)->void:
 var box:=AABB(form.faces[0],Vector3.ZERO)
 for p:Vector3 in form.faces:box=box.expand(p)
 form.bounds=form.transform*box;form.base=form.bounds.position.y;form.top=form.bounds.end.y
