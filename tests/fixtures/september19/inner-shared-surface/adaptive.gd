extends RefCounted
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const LOOKUP=preload("res://tests/fixtures/september19/inner-union/blend.gd")
static func apply(forms:Array)->Dictionary:
 var stats:={"corners":0,"triangles":0,"missing":0}
 for form:Dictionary in forms:
  if form.get("replay_recipe",{}).get("kind","")!="inner_corner":continue
  var inverse:Transform3D=form.transform.affine_inverse()
  var fields:Array=[]
  for other:Dictionary in forms:
   if other==form or other.get("replay_recipe",{}).get("kind","")!="wall":continue
   if not (form.bounds as AABB).grow(.2).intersects(other.bounds):continue
   var transform:Transform3D=inverse*other.transform
   var normal:Vector3=transform.basis.z
   if not ((normal.dot(Vector3.BACK)>.99 and absf(transform.origin.z)<.01) or (normal.dot(Vector3.RIGHT)>.99 and absf(transform.origin.x)<.01)):continue
   var grid:Dictionary={};var triangles:Array=[]
   var faces:PackedVector3Array=other.faces
   for i in range(0,faces.size(),3):
    var a:Vector3=transform*faces[i];var b:Vector3=transform*faces[i+1];var c:Vector3=transform*faces[i+2]
    var pa:=Vector2(a.x-a.z,a.y);var pb:=Vector2(b.x-b.z,b.y);var pc:=Vector2(c.x-c.z,c.y)
    var den:float=(pb-pa).cross(pc-pa)
    if absf(den)<.00001:continue
    var low:=pa.min(pb).min(pc);var high:=pa.max(pb).max(pc)
    if low.x>6 or high.x< -6:continue
    var id:=triangles.size()
    triangles.append([pa,pb,pc,den,(a.x+a.z)*.5,(b.x+b.z)*.5,(c.x+c.z)*.5])
    for x in range(maxi(-12,floori(low.x*2)),mini(12,floori(high.x*2))+1):
     for y in range(floori(low.y*2),ceili(high.y*2)+1):
      var key:=Vector2i(x,y)
      if not grid.has(key):grid[key]=[]
      grid[key].append(id)
   var treads:Array=[]
   for i in range(0,other.green.size(),3):
    var points:Array=[]
    for j in 3:
     var v:Vector3=transform*other.green[i+j]
     points.append(Vector3(v.x-v.z,v.y,(v.x+v.z)*.5))
    treads.append(points)
   fields.append([grid,triangles,treads])
  if fields.is_empty():continue
  var height:float=form.replay_recipe.height
  var floor_y:=0.0
  for p:Vector3 in form.faces:floor_y=minf(floor_y,p.y)
  var count:=61;var columns:Array=[];var all_bands:Array=[];var roots:Dictionary={}
  for column in count:
   var u:float=lerpf(-6,6,float(column)/(count-1))
   var intervals:Array=[]
   for field:Array in fields:
    for tri:Array in field[2]:
     var hits:Array=[]
     for edge in 3:
      var a:Vector3=tri[edge];var b:Vector3=tri[(edge+1)%3]
      if absf(a.x-b.x)<.000001:continue
      var t:float=(u-a.x)/(b.x-a.x)
      if t>=0 and t<=1:hits.append(a.lerp(b,t))
     if hits.size()<2:continue
     var mid:Vector3=(hits[0]+hits[1])*.5
     var front_depth:float=_sample(u,mid.y,fields)
     if is_finite(front_depth) and front_depth-(mid.z-absf(u)*.5)<.34:
      intervals.append([minf(hits[0].y,hits[1].y)-.002,maxf(hits[0].y,hits[1].y)+.002])
   intervals.sort_custom(func(a:Array,b:Array)->bool:return a[0]<b[0])
   var merged:Array=[]
   for interval:Array in intervals:
    interval[0]=maxf(floor_y+.01,interval[0]);interval[1]=minf(height-.01,interval[1])
    if interval[1]<=interval[0]:continue
    if not merged.is_empty() and interval[0]<=merged[-1][1]+.01:merged[-1][1]=maxf(merged[-1][1],interval[1])
    else:merged.append(interval.duplicate())
   var points:=PackedVector3Array();var bands:Array=[]
   points.append(_point(u,height,height,fields,form,roots))
   var previous:float=height
   for cut in range(merged.size()-1,-1,-1):
    var interval:Array=merged[cut]
    var start:=points.size()-1
    for y:float in CRAGS._height_samples(previous,interval[1]):points.append(_point(u,y,height,fields,form,roots))
    bands.append([start,points.size()-1,false]);start=points.size()-1
    for t:float in [.25,.5,.75,1.0]:points.append(_point(u,lerpf(interval[1],interval[0],t),height,fields,form,roots))
    bands.append([start,points.size()-1,true]);previous=interval[0]
   var start:=points.size()-1
   for y:float in CRAGS._height_samples(previous,floor_y):points.append(_point(u,y,height,fields,form,roots))
   bands.append([start,points.size()-1,false])
   columns.append(points);all_bands.append(bands)
  var faces:=PackedVector3Array();var green:=PackedVector3Array()
  # Loft matching ledge bands, retaining source heights and curved tread samples.
  for column in count-1:
   var left:PackedVector3Array=columns[column];var right:PackedVector3Array=columns[column+1]
   # Matching uses radial depth in a temporary unfolded profile.
   var lp:=PackedVector3Array();var rp:=PackedVector3Array()
   for v:Vector3 in left:lp.append(Vector3(v.x-v.z,v.y,minf(v.x,v.z)))
   for v:Vector3 in right:rp.append(Vector3(v.x-v.z,v.y,minf(v.x,v.z)))
   for join:Array in CRAGS._matched_bands(lp,rp,all_bands[column],all_bands[column+1]):
    var a:Array=join[0];var b:Array=join[1];var i:int=a[0];var j:int=b[0]
    while i<a[1] or j<b[1]:
     var advance:=false
     if i<a[1] and j<b[1]:
      advance=float(i+1-a[0])/(a[1]-a[0])<=float(j+1-b[0])/(b[1]-b[0]) if a[2] else left[i+1].y>=right[j+1].y
     if j==b[1] or advance:
      _tri(faces,green,left[i],right[j],left[i+1],a[2]);i+=1
     else:
      _tri(faces,green,left[i],right[j],right[j+1],a[2]);j+=1
  # Seal all single-use boundary edges against the buried diagonal back plane.
  var front_faces:=faces.duplicate();var edges:Dictionary={}
  for i in range(0,front_faces.size(),3):
   for j in 3:
    var a:Vector3=front_faces[i+j];var b:Vector3=front_faces[i+(j+1)%3]
    var key:Array=[a,b] if a<b else [b,a]
    if edges.has(key):edges.erase(key)
    else:edges[key]=[a,b]
   var a:=_back(front_faces[i]);var b:=_back(front_faces[i+1]);var c:=_back(front_faces[i+2])
   roots[a]=[Vector3(1,0,1).normalized(),1.0];roots[b]=roots[a];roots[c]=roots[a]
   _tri(faces,green,a,c,b,false)
  for edge:Array in edges.values():
   var a:Vector3=edge[0];var b:Vector3=edge[1];var c:=_back(a);var d:=_back(b)
   _tri(faces,green,a,c,b,false);_tri(faces,green,b,c,d,false)
  form.faces=faces;form.green=green;form.native_roots=roots
  var bounds:=AABB(faces[0],Vector3.ZERO)
  for p:Vector3 in faces:bounds=bounds.expand(p)
  form.bounds=form.transform*bounds
  stats.corners+=1;stats.triangles+=faces.size()/3
 return stats
static func _tri(faces:PackedVector3Array,green:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3,turf:bool)->void:
 faces.append_array(PackedVector3Array([a,b,c]))
 if turf and (c-a).cross(b-a).normalized().y>.8:green.append_array(PackedVector3Array([a,b,c]))

static func _sample(u:float,y:float,fields:Array)->float:
 var depth:=-INF
 for field:Array in fields:
  var value:float=LOOKUP._front(Vector2(u,y),field[0],field[1])-absf(u)*.5
  if not is_finite(value):continue
  if not is_finite(depth):depth=value
  else:
   var h:=maxf(0,1.2-absf(depth-value))/1.2
   depth=maxf(depth,value)+h*h*.3
 return depth
static func _point(u:float,y:float,height:float,fields:Array,form:Dictionary,roots:Dictionary)->Vector3:
 var native:=CORNER._inner_native(u,y,form.transform)
 var depth:=_sample(u,clampf(y,.001,height-.001),fields)
 if not is_finite(depth):depth=native[0]
 var fade:=smoothstep(0.0,1.4,6-absf(u))*smoothstep(.35,1.8,height-y)
 depth=lerpf(float(native[0])-.03,depth+.025,fade)
 var p:=Vector3(maxf(u,0)+depth,y,maxf(-u,0)+depth).snapped(Vector3.ONE*.0001)
 roots[p]=[native[1],smoothstep(.015,.18,depth-float(native[0]))]
 return p
static func _back(p:Vector3)->Vector3:
 var u:=p.x-p.z
 return Vector3(maxf(u,0)-1.2,p.y,maxf(-u,0)-1.2).snapped(Vector3.ONE*.0001)
