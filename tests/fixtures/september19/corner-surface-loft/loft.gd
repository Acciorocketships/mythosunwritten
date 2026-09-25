extends RefCounted
const LEDGES=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
## Art-only surface continuation between two measured straight-wall sections.
static func apply(forms:Array)->bool:
 var anchor:=Vector3(-421.5,28,-349.5)
 var corner:Dictionary={};var incoming:Dictionary={};var outgoing:Dictionary={}
 for form:Dictionary in forms:
  if form.replay_recipe.kind=="inner_corner" and form.anchor.distance_to(anchor)<.01:corner=form
  if form.replay_recipe.kind!="wall":continue
  if form.transform.origin.distance_to(Vector3(-421.5,28,-334.5))<.01:incoming=form
  if form.transform.origin.distance_to(Vector3(-414,28,-349.5))<.01:outgoing=form
 if corner.is_empty() or incoming.is_empty() or outgoing.is_empty():return false
 var left_z:=6.75
 var a:=section(incoming,incoming.transform.affine_inverse()*(anchor+Vector3(0,0,left_z)),4.0)
 if a.size()<3:return false
 var furthest:=-INF
 for p:Vector2 in a:furthest=maxf(furthest,p.x)
 var right_x:=ceilf((furthest+1.0)*4.0)/4.0
 if right_x>13.0:
  push_error("Source section cannot turn inside the measured outgoing run");return false
 var b:=section(outgoing,outgoing.transform.affine_inverse()*(anchor+Vector3(right_x,0,0)),4.0)
 if b.size()<3:return false
 var outgoing_max:=-INF
 for p:Vector2 in b:outgoing_max=maxf(outgoing_max,p.x)
 if outgoing_max>left_z-.25:
  push_error("Measured outgoing surface exceeds incoming section's reach");return false
 var ad:=parameters(a,main_tread(incoming,incoming.transform.affine_inverse()*(anchor+Vector3(0,0,left_z))))
 var bd:=parameters(b,main_tread(outgoing,outgoing.transform.affine_inverse()*(anchor+Vector3(right_x,0,0))))
 var samples:Array[float]=[]
 for values:PackedFloat32Array in [ad,bd]:
  for value:float in values:
   if value not in samples:samples.append(value)
 samples.sort()
 var front:Array=[];var back:Array=[]
 var steps:=64
 for i in steps+1:
  var t:=float(i)/steps
  var row:=PackedVector3Array();var rear:=PackedVector3Array()
  for s:float in samples:
   var pa:=at(a,ad,s);var pb:=at(b,bd,s)
   var start:=Vector2(pa.x,left_z);var finish:=Vector2(right_x,pb.x)
   var crossing:=Vector2(pa.x,pb.x)
   var c1:Vector2=start.lerp(crossing,.72);var c2:Vector2=finish.lerp(crossing,.72)
   var xz:=start*pow(1-t,3)+c1*(3*t*pow(1-t,2))+c2*(3*t*t*(1-t))+finish*pow(t,3)
   var y:=lerpf(pa.y,pb.y,t)
   var crown:Vector2=Vector2(-.5,left_z).lerp(Vector2(-.5,-.5),t*2) if t<=.5 else Vector2(-.5,-.5).lerp(Vector2(right_x,-.5),(t-.5)*2)
   var end_weight:=smoothstep(0.0,.25,t)*smoothstep(0.0,.25,1.0-t)
   xz=xz.lerp(crown,end_weight*(1.0-smoothstep(0.0,.35,s)))
   row.append(Vector3(xz.x,y,xz.y).snapped(Vector3.ONE*.0001))
   var rear_xz:Vector2=Vector2(-1.2,left_z).lerp(Vector2(-1.2,-1.2),t*2) if t<=.5 else Vector2(-1.2,-1.2).lerp(Vector2(right_x,-1.2),(t-.5)*2)
   rear.append(Vector3(rear_xz.x,y,rear_xz.y).snapped(Vector3.ONE*.0001))
  front.append(row);back.append(rear)
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 for i in steps:
  for j in samples.size()-1:
   var tread:bool=samples[j]>=.4-.00001 and samples[j+1]<=.6+.00001
   tri(faces,green,front[i][j],front[i+1][j],front[i][j+1],tread)
   tri(faces,green,front[i+1][j],front[i+1][j+1],front[i][j+1],tread)
   tri(faces,green,back[i][j],back[i][j+1],back[i+1][j],false)
   tri(faces,green,back[i+1][j],back[i][j+1],back[i+1][j+1],false)
  tri(faces,green,front[i][0],back[i][0],front[i+1][0],false)
  tri(faces,green,front[i+1][0],back[i][0],back[i+1][0],false)
  tri(faces,green,front[i][-1],front[i+1][-1],back[i][-1],false)
  tri(faces,green,front[i+1][-1],back[i+1][-1],back[i][-1],false)
 for j in samples.size()-1:
  tri(faces,green,front[0][j],front[0][j+1],back[0][j],false)
  tri(faces,green,back[0][j],front[0][j+1],back[0][j+1],false)
  tri(faces,green,front[-1][j],back[-1][j],front[-1][j+1],false)
  tri(faces,green,back[-1][j],back[-1][j+1],front[-1][j+1],false)
 var box:=AABB(faces[0],Vector3.ZERO);var roots:Dictionary={}
 for p:Vector3 in faces:box=box.expand(p);roots[p]=[Vector3(1,0,1).normalized(),1.0]
 var replacement:Dictionary=corner.duplicate(true)
 replacement.faces=faces;replacement.green=green;replacement.native_roots=roots
 replacement.bounds=replacement.transform*box;replacement.top=replacement.bounds.end.y;replacement.base=replacement.bounds.position.y
 replacement.replay_recipe={"kind":"study_loft","height":4.0,"seed":2697992464,"left_z":left_z,"right_x":right_x}
 forms[forms.find(corner)]=replacement
 print("SURFACE_LOFT sections=",[a.size(),b.size()]," reach=",[left_z,right_x]," faces=",faces.size()/3)
 return true

static func section(form:Dictionary,point:Vector3,top:float)->PackedVector2Array:
 var unique:Dictionary={}
 var x:=snappedf(point.x,.25)
 for p:Vector3 in form.faces:
  if absf(p.x-x)<.001 and p.z> -1.1999:unique[Vector2(p.z,p.y)]=true
 var values:Array=unique.keys()
 values.sort_custom(func(a:Vector2,b:Vector2)->bool:return a.y>b.y or (a.y==b.y and a.x<b.x))
 var result:=PackedVector2Array()
 for i in values.size():
  var p:Vector2=values[i]
  if p.y>top:continue
  if result.is_empty() and i>0:
   var previous:Vector2=values[i-1]
   if p.y<top:result.append(previous.lerp(p,(top-previous.y)/(p.y-previous.y)))
  result.append(p)
 return result
static func distances(points:PackedVector2Array)->PackedFloat32Array:
 var result:=PackedFloat32Array([0.0])
 for i in range(1,points.size()):result.append(result[-1]+points[i].distance_to(points[i-1]))
 var total:=result[-1]
 for i in result.size():result[i]/=total
 return result
static func main_tread(form:Dictionary,point:Vector3)->Array:
 var groups:=LEDGES.nearest_row(LEDGES.columns(form),point.x)
 var widest:Array=[];var width:=0.0
 for group:Array in groups:
  if group[0].y>4 or group[-1].y<0:continue
  if group[-1].x-group[0].x>width:widest=group;width=group[-1].x-group[0].x
 return widest
static func parameters(points:PackedVector2Array,tread:Array)->PackedFloat32Array:
 assert(not tread.is_empty())
 var result:=distances(points)
 var inner:=-1;var outer:=-1
 for i in points.size():
  if points[i].distance_to(tread[0])<.001:inner=i
  if points[i].distance_to(tread[-1])<.001:outer=i
 assert(inner>0 and outer>inner and outer<points.size()-1)
 var a:=result[inner];var b:=result[outer]
 for i in result.size():
  if i<=inner:result[i]=.4*result[i]/a
  elif i<=outer:result[i]=lerpf(.4,.6,(result[i]-a)/(b-a))
  else:result[i]=lerpf(.6,1.0,(result[i]-b)/(1.0-b))
 return result
static func at(points:PackedVector2Array,lengths:PackedFloat32Array,s:float)->Vector2:
 if s<=0:return points[0]
 for i in range(1,lengths.size()):
  if s<=lengths[i]:return points[i-1].lerp(points[i],(s-lengths[i-1])/(lengths[i]-lengths[i-1]))
 return points[-1]
static func tri(faces:PackedVector3Array,green:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3,turf:bool)->void:
 if a==b or b==c or c==a:return
 faces.append_array(PackedVector3Array([a,b,c]))
 if turf and (c-a).cross(b-a).normalized().y>.72:green.append_array(PackedVector3Array([a,b,c]))
