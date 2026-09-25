extends RefCounted
## Continue an existing ledge across a stepped concave turn. Profiles come from
## the adjoining solids; there is no independent corner shelf family.
const LEDGES=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
static func apply(forms:Array,region:HeightfieldRegion=null,features:FeatureContext=null,reject:Callable=Callable())->int:
 var count:=0
 for index in forms.size():
  var corner:Dictionary=forms[index]
  if corner.get("replay_recipe",{}).get("kind","")!="inner_corner":continue
  var candidate:=continuation(corner,forms)
  if candidate.is_empty():continue
  if region!=null:_seat(candidate,region)
  var box:AABB=candidate.bounds
  var footprint:=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
  if region!=null and region.has_grade_effect_in(footprint.grow(.1)):continue
  if features!=null and features.overlaps_clearance(FeatureGroundShape.axis_rect(footprint),.3,false):continue
  if reject.is_valid() and reject.call(candidate):continue
  forms[index]=candidate;count+=1
 return count

static func continuation(corner:Dictionary,forms:Array)->Dictionary:
 var inverse:Transform3D=corner.transform.affine_inverse()
 var height:float=corner.replay_recipe.height
 var parents:Array=[{},{}];var nearest:Array[float]=[INF,INF]
 for form:Dictionary in forms:
  var recipe:Dictionary=form.get("replay_recipe",{})
  if recipe.get("kind","")!="wall" or recipe.width<6 or recipe.height<height:continue
  var local:Transform3D=inverse*form.transform
  if absf(local.origin.y)>.001:continue
  var side:=-1;var along:=0.0
  if local.basis.z.dot(Vector3.RIGHT)>.99 and local.basis.x.dot(Vector3.FORWARD)>.99 and absf(local.origin.x)<.01:
   side=0;along=local.origin.z
  elif local.basis.z.dot(Vector3.BACK)>.99 and local.basis.x.dot(Vector3.RIGHT)>.99 and absf(local.origin.z)<.01:
   side=1;along=local.origin.x
  if side<0:continue
  var gap:float=along-float(recipe.width)*.5
  if gap<-.001 or gap>6.001 or gap>nearest[side]+.001:continue
  if absf(gap-nearest[side])<.001 and not parents[side].is_empty() and String(form.id)>=String(parents[side].id):continue
  parents[side]=form;nearest[side]=gap
 if parents[0].is_empty() or parents[1].is_empty():return {}
 var incoming:Dictionary=parents[0];var outgoing:Dictionary=parents[1]
 if incoming.replay_recipe.height==outgoing.replay_recipe.height:return {}
 if minf(incoming.replay_recipe.height,outgoing.replay_recipe.height)!=height:return {}
 # Choose the existing shoulder before its terminal taper. Continuing from
 # within that taper exposes an angular step against the original ledge.
 var rows:=LEDGES.columns(incoming);var keys:Array=rows.keys();keys.sort()
 var left_z:=0.0;var strongest:=-INF;var a:=PackedVector2Array();var ad:=PackedFloat32Array()
 var local_incoming:Transform3D=inverse*incoming.transform
 for x:float in keys:
  var along:float=local_incoming.origin.z-x
  if along<nearest[0]+1 or along>nearest[0]+4:continue
  for tread:Array in rows[x]:
   if tread[0].y>=height or tread[-1].y<=0 or tread[-1].x<=strongest:continue
   var points:=section(incoming,Vector3(x,0,0),height)
   var values:=parameters(points,tread)
   if values.is_empty():continue
   strongest=tread[-1].x;left_z=along;a=points;ad=values
 if a.is_empty():return {}
 var furthest:=-INF
 for point:Vector2 in a:furthest=maxf(furthest,point.x)
 var right_x:=ceilf((furthest+1.0)*4.0)/4.0
 var local_outgoing:Transform3D=inverse*outgoing.transform
 if right_x<=nearest[1]+.25 or right_x>=local_outgoing.origin.x+float(outgoing.replay_recipe.width)*.5-.25:return {}
 var point:=Vector3(right_x-local_outgoing.origin.x,0,0)
 var b:=section(outgoing,point,height)
 if b.size()<3:return {}
 var tread:=main_tread(outgoing,point,height)
 var bd:=parameters(b,tread)
 if bd.is_empty():return {}
 var outgoing_max:=-INF
 for p:Vector2 in b:outgoing_max=maxf(outgoing_max,p.x)
 if outgoing_max>left_z-.25:return {}
 var recipe:Dictionary={"kind":"inner_surface","height":height,"seed":corner.replay_recipe.seed,
  "left_z":left_z,"right_x":right_x,"a":a,"b":b,"ad":ad,"bd":bd}
 var result:=rebuild(corner.transform,recipe)
 result.id=corner.id;result.anchor=corner.anchor
 return result

static func rebuild(pose:Transform3D,recipe:Dictionary)->Dictionary:
 var a:PackedVector2Array=recipe.a;var b:PackedVector2Array=recipe.b
 var ad:PackedFloat32Array=recipe.ad;var bd:PackedFloat32Array=recipe.bd
 var left_z:float=recipe.left_z;var right_x:float=recipe.right_x
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
   var y:=minf(a[-1].y,b[-1].y) if s==1.0 else lerpf(pa.y,pb.y,t)
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
 var result:Dictionary={"faces":faces,"green":green,"native_roots":roots,"transform":pose,"anchor":pose.origin,
  "replay_recipe":recipe.duplicate(true),"id":"inner_surface/%s/%s"%[pose.origin,pose.basis],
  "asset":&"cliff.native_crag","kind":"rock","native_crag":true}
 result.bounds=pose*box;result.top=result.bounds.end.y;result.base=result.bounds.position.y
 return result

static func _seat(form:Dictionary,region:HeightfieldRegion)->void:
 var minimum:=INF
 for p:Vector3 in form.faces:minimum=minf(minimum,p.y)
 var floor_y:=minimum
 for p:Vector3 in form.faces:
  if p.y>minimum+.001:continue
  var world:Vector3=form.transform*p
  var ground:float=TerrainSurfaceField.surface_y(region,world.x,world.z)-form.transform.origin.y
  if ground>=-preload("res://scripts/terrain/field/CliffRockCrags.gd").SUPPORT_DROP:floor_y=minf(floor_y,ground-.2)
 if floor_y>=minimum:return
 for field:String in ["faces","green"]:
  var values:PackedVector3Array=form[field]
  for i in values.size():
   var old:Vector3=values[i]
   if old.y>minimum+.001:continue
   var p:=Vector3(old.x,floor_y,old.z)
   form.native_roots[p]=form.native_roots[old];values[i]=p
  form[field]=values
 var box:=AABB(form.faces[0],Vector3.ZERO)
 for p:Vector3 in form.faces:box=box.expand(p)
 form.bounds=form.transform*box;form.base=form.bounds.position.y

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
static func main_tread(form:Dictionary,point:Vector3,height:float)->Array:
 var groups:=LEDGES.nearest_row(LEDGES.columns(form),point.x)
 var widest:Array=[];var width:=0.0
 for group:Array in groups:
  if group[0].y>height or group[-1].y<0:continue
  if group[-1].x-group[0].x>width:widest=group;width=group[-1].x-group[0].x
 return widest
static func parameters(points:PackedVector2Array,tread:Array)->PackedFloat32Array:
 if tread.is_empty() or points.size()<3:return PackedFloat32Array()
 var result:=distances(points)
 var inner:=-1;var outer:=-1
 for i in points.size():
  if points[i].distance_to(tread[0])<.001:inner=i
  if points[i].distance_to(tread[-1])<.001:outer=i
 if inner<=0 or outer<=inner or outer>=points.size()-1:return PackedFloat32Array()
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
