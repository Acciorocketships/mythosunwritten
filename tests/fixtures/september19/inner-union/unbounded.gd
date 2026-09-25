extends RefCounted
## Experimental local diagonal union of concave rock with its actual neighbors.
static func apply(forms:Array)->Dictionary:
 var stats:Dictionary={"corners":0,"changed":0,"max_move":0.0,"collapsed":0}
 for form:Dictionary in forms:
  if form.get("replay_recipe",{}).get("kind","")!="inner_corner":continue
  var inverse:Transform3D=form.transform.affine_inverse()
  var grid:Dictionary={};var triangles:Array=[]
  for other:Dictionary in forms:
   if other==form or other.get("replay_recipe",{}).get("kind","")!="wall":continue
   if not (form.bounds as AABB).grow(.2).intersects(other.bounds):continue
   var transform:Transform3D=inverse*other.transform
   var faces:PackedVector3Array=other.faces
   for i in range(0,faces.size(),3):
    var a:Vector3=transform*faces[i];var b:Vector3=transform*faces[i+1];var c:Vector3=transform*faces[i+2]
    var pa:=Vector2(a.x-a.z,a.y);var pb:=Vector2(b.x-b.z,b.y);var pc:=Vector2(c.x-c.z,c.y)
    var den:float=(pb-pa).cross(pc-pa)
    if absf(den)<.00001:continue
    var low:=pa.min(pb).min(pc);var high:=pa.max(pb).max(pc)
    if low.x>6 or high.x< -6 or high.y<0 or low.y>float(form.replay_recipe.height):continue
    var id:=triangles.size()
    triangles.append([pa,pb,pc,den,(a.x+a.z)*.5,(b.x+b.z)*.5,(c.x+c.z)*.5])
    for x in range(maxi(-12,floori(low.x*2)),mini(12,floori(high.x*2))+1):
     for y in range(maxi(0,floori(low.y*2)),mini(ceilf(form.replay_recipe.height*2),floori(high.y*2))+1):
      var key:=Vector2i(x,y)
      if not grid.has(key):grid[key]=[]
      grid[key].append(id)
  if triangles.is_empty():continue
  stats.corners+=1
  var mapping:Dictionary={};var roots:Dictionary={}
  for p:Vector3 in form.faces:
   if mapping.has(p):continue
   var u:=p.x-p.z;var depth:=minf(p.x,p.z)
   var weight:=smoothstep(.1,.6,depth)*(1.0-smoothstep(4.5,6.0,absf(u)))*smoothstep(1.1,2.5,float(form.replay_recipe.height)-p.y)
   var target:float=(p.x+p.z)*.5
   if weight>0:
    var q:=Vector2(u,p.y)
    var other:=_front(q,grid,triangles)
    if is_finite(other):
     # A narrow smooth union avoids a hard crease where the surfaces cross.
     # A slight outward bias avoids coplanar faces in the overlapping solid.
     other+=.025
     var h:=maxf(0,.16-absf(target-other))/.16
     target=lerpf(target,maxf(target,other)+h*h*.04,weight)
   var delta:=target-(p.x+p.z)*.5
   var moved:Vector3=(p+Vector3(delta,0,delta)).snapped(Vector3.ONE*.0001)
   mapping[p]=moved
   roots[moved]=form.native_roots[p]
   if delta>.001:
    roots[moved]=[Vector3(1,0,1).normalized(),1.0]
    stats.changed+=1;stats.max_move=maxf(stats.max_move,delta)
  var stone:=PackedVector3Array();var turf:=PackedVector3Array()
  for index in 2:
   var source:PackedVector3Array=form.faces if index==0 else form.green
   var output:PackedVector3Array=stone if index==0 else turf
   for i in range(0,source.size(),3):
    var a:Vector3=mapping[source[i]];var b:Vector3=mapping[source[i+1]];var c:Vector3=mapping[source[i+2]]
    if a==b or b==c or a==c:stats.collapsed+=1;continue
    output.append_array(PackedVector3Array([a,b,c]))
  form.faces=stone;form.green=turf;form.native_roots=roots
  var bounds:=AABB(stone[0],Vector3.ZERO)
  for p:Vector3 in stone:bounds=bounds.expand(p)
  form.bounds=form.transform*bounds
 return stats
static func _front(q:Vector2,grid:Dictionary,triangles:Array)->float:
 var result:=-INF
 for id:int in grid.get(Vector2i(floori(q.x*2),floori(q.y*2)),[]):
  var t:Array=triangles[id]
  var b:float=(q-t[0]).cross(t[2]-t[0])/t[3]
  var c:float=(t[1]-t[0]).cross(q-t[0])/t[3]
  var a:=1.0-b-c
  if minf(a,minf(b,c))<-.00001:continue
  result=maxf(result,a*t[4]+b*t[5]+c*t[6])
 return result
