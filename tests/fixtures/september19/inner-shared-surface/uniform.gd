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
   fields.append([grid,triangles])
  if fields.is_empty():continue
  var height:float=form.replay_recipe.height
  var floor_y:=0.0
  for p:Vector3 in form.faces:floor_y=minf(floor_y,p.y)
  var columns:=61;var rows:=ceili((height-floor_y)/.1)+1
  var front:=PackedVector3Array();var back:=PackedVector3Array();var roots:Dictionary={}
  for row in rows:
   var y:float=lerpf(floor_y,height,float(row)/(rows-1))
   for column in columns:
    var u:float=lerpf(-6,6,float(column)/(columns-1))
    var native:=CORNER._inner_native(u,y,form.transform)
    var depth:float=native[0];var found:=false
    for field:Array in fields:
     var value:float=LOOKUP._front(Vector2(u,clampf(y,.001,height-.001)),field[0],field[1])-absf(u)*.5
     if not is_finite(value):continue
     if not found:depth=value;found=true
     else:
      var h:=maxf(0,1.2-absf(depth-value))/1.2
      depth=maxf(depth,value)+h*h*.3
    if not found:stats.missing+=1
    var fade:=smoothstep(0.0,1.4,6-absf(u))*smoothstep(.35,1.8,height-y)
    depth=lerpf(float(native[0])-.03,depth+.025,fade)
    var p:=Vector3(maxf(u,0)+depth,y,maxf(-u,0)+depth).snapped(Vector3.ONE*.0001)
    var q:=Vector3(maxf(u,0)-1.2,y,maxf(-u,0)-1.2).snapped(Vector3.ONE*.0001)
    front.append(p);back.append(q)
    roots[p]=[native[1],smoothstep(.015,.18,depth-float(native[0]))]
    roots[q]=[Vector3(1,0,1).normalized(),1.0]
  var faces:=PackedVector3Array();var green:=PackedVector3Array()
  for row in rows-1:
   for column in columns-1:
    var i:=row*columns+column
    _tri(faces,green,front[i],front[i+columns],front[i+1],true)
    _tri(faces,green,front[i+1],front[i+columns],front[i+columns+1],true)
    _tri(faces,green,back[i],back[i+1],back[i+columns],false)
    _tri(faces,green,back[i+1],back[i+columns+1],back[i+columns],false)
  for col in columns-1:
   for row:int in [0,rows-1]:
    var i:=row*columns+col
    if row==0:
     _tri(faces,green,front[i],front[i+1],back[i],false);_tri(faces,green,front[i+1],back[i+1],back[i],false)
    else:
     _tri(faces,green,front[i],back[i],front[i+1],false);_tri(faces,green,front[i+1],back[i],back[i+1],false)
  for row in rows-1:
   for col:int in [0,columns-1]:
    var i:=row*columns+col
    if col==0:
     _tri(faces,green,front[i],back[i],front[i+columns],false);_tri(faces,green,front[i+columns],back[i],back[i+columns],false)
    else:
     _tri(faces,green,front[i],front[i+columns],back[i],false);_tri(faces,green,front[i+columns],back[i+columns],back[i],false)
  form.faces=faces;form.green=green;form.native_roots=roots
  var bounds:=AABB(faces[0],Vector3.ZERO)
  for p:Vector3 in faces:bounds=bounds.expand(p)
  form.bounds=form.transform*bounds
  stats.corners+=1;stats.triangles+=faces.size()/3
 return stats
static func _tri(faces:PackedVector3Array,green:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3,turf:bool)->void:
 faces.append_array(PackedVector3Array([a,b,c]))
 if turf and (c-a).cross(b-a).normalized().y>.8:green.append_array(PackedVector3Array([a,b,c]))
