extends RefCounted
## A raised collinear run hands over at the actual end of its taller neighbor.
## Continue their measured profiles above the supporting terrace, rather than
## leaving an independent basal outcrop across the lower corner's crown.
const PROFILE=preload("res://scripts/terrain/field/CliffInnerSurface.gd")
const LEDGES=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
const LENGTH:=3.0
static func apply(forms:Array,region:HeightfieldRegion=null,features:FeatureContext=null,reject:Callable=Callable())->int:
 var ordered:Array=forms.duplicate()
 ordered.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.anchor<b.anchor)
 var changed:=0
 for tall:Dictionary in ordered:
  var tr:Dictionary=tall.get("replay_recipe",{})
  if tr.get("kind","")!="wall" or not tr.has("inner_connections"):continue
  for raised:Dictionary in ordered:
   var rr:Dictionary=raised.get("replay_recipe",{})
   if rr.get("kind","")!="wall" or rr.has("step_surface") or raised.id==tall.id:continue
   var relative:Transform3D=tall.transform.affine_inverse()*raised.transform
   if relative.basis.x.dot(Vector3.RIGHT)<.999 or relative.basis.z.dot(Vector3.BACK)<.999 or absf(relative.origin.z)>.001:continue
   var rise:float=relative.origin.y
   if rise<3.999 or absf(rise+rr.height-tr.height)>.001:continue
   var side:float=signf(relative.origin.x)
   var edge:float=side*tr.width*.5
   # Both runs use the same quarter-metre native sampling lattice. Remove only
   # cardinal-transform roundoff before selecting/clipping a lattice section.
   var start:float=snappedf(edge-relative.origin.x,.25)
   var overlap:float=rr.width*.5+side*start
   if overlap<.25 or overlap>3.01:continue
   var finish:float=start+side*LENGTH
   if absf(finish)>rr.width*.5-.25:continue
   var a:=PROFILE.section(tall,Vector3(edge,0,0),tr.height)
   var floor_y:=INF
   for p:Vector3 in raised.faces:floor_y=minf(floor_y,p.y)
   var clipped:=PackedVector2Array()
   for p:Vector2 in a:
    p.y-=rise
    if p.y>=floor_y:clipped.append(p)
    else:
     if not clipped.is_empty() and clipped[-1].y>floor_y:clipped.append(clipped[-1].lerp(p,(floor_y-clipped[-1].y)/(p.y-clipped[-1].y)))
     break
   a=clipped
   var b:=PROFILE.section(raised,Vector3(finish,0,0),rr.height)
   var at:Array=[]
   for group:Array in LEDGES.nearest_row(LEDGES.columns(tall),edge):
    if group[-1].y<floor_y+rise:continue
    if at.is_empty() or group[-1].x-group[0].x>at[-1].x-at[0].x:at=group.duplicate()
   for i in at.size():at[i]-=Vector2(0,rise)
   var bt:=PROFILE.main_tread(raised,Vector3(finish,0,0),rr.height)
   var ad:=PROFILE.parameters(a,at);var bd:=PROFILE.parameters(b,bt)
   if ad.is_empty() or bd.is_empty():continue
   var recipe:Dictionary={"a":a,"b":b,"ad":ad,"bd":bd,"start":start,"finish":finish,"side":side}
   var candidate:Dictionary=raised.duplicate(true)
   rebuild(candidate,recipe)
   var box:AABB=candidate.bounds
   var footprint:=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
   if region!=null and region.has_grade_effect_in(footprint.grow(.1)):continue
   if features!=null and features.overlaps_clearance(FeatureGroundShape.axis_rect(footprint),.3):continue
   if reject.is_valid() and reject.call(candidate):continue
   forms[forms.find(raised)]=candidate
   ordered[ordered.find(raised)]=candidate
   changed+=1
 return changed

static func rebuild(form:Dictionary,recipe:Dictionary)->void:
 var a:PackedVector2Array=recipe.a;var b:PackedVector2Array=recipe.b
 var ad:PackedFloat32Array=recipe.ad;var bd:PackedFloat32Array=recipe.bd
 var side:float=recipe.side;var finish:float=recipe.finish
 var samples:Array[float]=[]
 for values:PackedFloat32Array in [ad,bd]:
  for value:float in values:
   if value not in samples:samples.append(value)
 samples.sort()
 var front:Array=[];var back:Array=[]
 for i in 41:
  var t:=i/40.0;var blend:=smoothstep(0,1,t)
  var row:=PackedVector3Array();var rear:=PackedVector3Array()
  for s:float in samples:
   var p:=PROFILE.at(a,ad,s).lerp(PROFILE.at(b,bd,s),blend)
   var x:=lerpf(recipe.start,finish,t)
   row.append(Vector3(x,p.y,p.x).snapped(Vector3.ONE*.0001))
   rear.append(Vector3(x,p.y,-1.2).snapped(Vector3.ONE*.0001))
  front.append(row);back.append(rear)
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 for i in 40:
  for j in samples.size()-1:
   var turf:bool=samples[j]>=.4-.00001 and samples[j+1]<=.6+.00001
   _tri(faces,green,front[i][j],front[i+1][j],front[i][j+1],turf,side)
   _tri(faces,green,front[i+1][j],front[i+1][j+1],front[i][j+1],turf,side)
   _tri(faces,green,back[i][j],back[i][j+1],back[i+1][j],false,side)
   _tri(faces,green,back[i+1][j],back[i][j+1],back[i+1][j+1],false,side)
  _tri(faces,green,front[i][0],back[i][0],front[i+1][0],false,side)
  _tri(faces,green,front[i+1][0],back[i][0],back[i+1][0],false,side)
  _tri(faces,green,front[i][-1],front[i+1][-1],back[i][-1],false,side)
  _tri(faces,green,front[i+1][-1],back[i+1][-1],back[i][-1],false,side)
 faces.append_array(_cap(front[0],back[0],-side))
 faces.append_array(_cap(front[-1],back[-1],side))
 # The two closed components share the measured section. Their internal caps
 # never extend outside it; retaining separate caps avoids open physical solids.
 var body:=_clip(form.faces,finish,side)
 var body_green:=_clip(form.green,finish,side)
 var body_front:=PackedVector3Array();var body_back:=PackedVector3Array()
 for p:Vector2 in b:
  body_front.append(Vector3(finish,p.y,p.x));body_back.append(Vector3(finish,p.y,-1.2))
 body.append_array(_cap(body_front,body_back,-side))
 faces.append_array(body);green.append_array(body_green)
 form.faces=faces;form.green=green
 form.replay_recipe["step_surface"]=recipe.duplicate(true)
 var box:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:box=box.expand(p)
 form.bounds=form.transform*box;form.base=form.bounds.position.y;form.top=form.bounds.end.y

static func _tri(faces:PackedVector3Array,green:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3,turf:bool,side:float)->void:
 if side<0:var swap:=b;b=c;c=swap
 if (b-a).cross(c-a).length_squared()<1e-16:return
 PROFILE.tri(faces,green,a,b,c,turf)

static func _cap(front:PackedVector3Array,back:PackedVector3Array,normal:float)->PackedVector3Array:
 # A flat ledge is a horizontal edge of this polygon, not a zero-height strip.
 # Retain its intermediate boundary samples when closing the physical solid.
 var outline:=PackedVector2Array();var reversed:=back.duplicate();reversed.reverse()
 for row:PackedVector3Array in [front,reversed]:
  for p:Vector3 in row:
   var q:=Vector2(p.z,p.y)
   if outline.is_empty() or q!=outline[-1]:outline.append(q)
 if outline[-1]==outline[0]:outline.resize(outline.size()-1)
 var clean:=PackedVector2Array()
 for i in outline.size():
  var a:=outline[posmod(i-1,outline.size())];var b:=outline[i];var c:=outline[(i+1)%outline.size()]
  if absf((b-a).cross(c-b))>.0000001:clean.append(b)
 var indices:=Geometry2D.triangulate_polygon(clean)
 assert(not indices.is_empty(),"The shared step section must close as a simple polygon")
 var triangles:Array=[]
 for i in range(0,indices.size(),3):triangles.append([clean[indices[i]],clean[indices[i+1]],clean[indices[i+2]]])
 for i in clean.size():
  var start:=outline.find(clean[i]);var finish:=outline.find(clean[(i+1)%clean.size()])
  var chain:Array[Vector2]=[outline[start]]
  while start!=finish:
   start=(start+1)%outline.size();chain.append(outline[start])
  if chain.size()<3:continue
  var found:=false
  for t in triangles.size():
   var tri:Array=triangles[t]
   for j in 3:
    var reverse:bool=tri[j]==chain[-1] and tri[(j+1)%3]==chain[0]
    if not reverse and not (tri[j]==chain[0] and tri[(j+1)%3]==chain[-1]):continue
    if reverse:chain.reverse()
    var other:Vector2=tri[(j+2)%3];triangles.remove_at(t)
    for n in chain.size()-1:triangles.append([chain[n],chain[n+1],other])
    found=true;break
   if found:break
  assert(found)
 var result:=PackedVector3Array()
 for tri:Array in triangles:
  var a:=Vector3(front[0].x,tri[0].y,tri[0].x);var b:=Vector3(front[0].x,tri[1].y,tri[1].x);var c:=Vector3(front[0].x,tri[2].y,tri[2].x)
  if (c-a).cross(b-a).x*normal<0:var swap:=b;b=c;c=swap
  result.append_array(PackedVector3Array([a,b,c]))
 return result

static func _clip(source:PackedVector3Array,x:float,side:float)->PackedVector3Array:
 var result:=PackedVector3Array()
 for i in range(0,source.size(),3):
  var polygon:Array[Vector3]=[]
  for j in 3:
   var a:=source[i+j];var b:=source[i+(j+1)%3]
   var inside:bool=(a.x-x)*side>=-.00001
   var next_inside:bool=(b.x-x)*side>=-.00001
   if inside:polygon.append(a)
   if inside!=next_inside:polygon.append(a.lerp(b,(x-a.x)/(b.x-a.x)).snapped(Vector3.ONE*.0001))
  for j in range(1,polygon.size()-1):
   if (polygon[j]-polygon[0]).cross(polygon[j+1]-polygon[0]).length_squared()<1e-16:continue
   result.append_array(PackedVector3Array([polygon[0],polygon[j],polygon[j+1]]))
 return result
