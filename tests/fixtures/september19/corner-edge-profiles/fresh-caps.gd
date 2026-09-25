extends SceneTree
const ROOT="res://docs/qa/2026-09-19-manual/100-corner-edge-profiles/"
func _initialize()->void:call_deferred("run")
func run()->void:
 var world:Node3D=load(ROOT+"fresh-P12/world.scn").instantiate();root.add_child(world)
 var checked:=0;var outside:=0;var degenerate:=0;var walls:=0
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  var recipe:Dictionary=node.get_meta("relief_recipe",{})
  if recipe.get("kind","")!="wall":continue
  var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(0)
  if Vector2(pose.origin.x+452,pose.origin.z+272).length()>85:continue
  var result:=check_caps({"faces":node.get_meta("relief_faces"),"replay_recipe":recipe})
  walls+=1;checked+=result.checked;outside+=result.outside;degenerate+=result.degenerate
 var report:={"sampled_walls":walls,"cap_triangles":checked,"escaping_triangles":outside,"degenerate_triangles":degenerate}
 FileAccess.open(ROOT+"fresh-caps.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FRESH_CAPS ",JSON.stringify(report));quit(0 if walls==31 and outside==0 and degenerate==0 else 1)
func check_caps(form:Dictionary)->Dictionary:
 var recipe:Dictionary=form.replay_recipe
 var checked:=0;var outside:=0;var degenerate:=0
 var half:float=recipe.width*.5
 for end:float in [-half,half]:
  var side:Array=[];var edges:Dictionary={}
  for i in range(0,form.faces.size(),3):
   var a:Vector3=form.faces[i];var b:Vector3=form.faces[i+1];var c:Vector3=form.faces[i+2]
   if a.x!=end or b.x!=end or c.x!=end:continue
   var tri:Array=[Vector2(a.z,a.y),Vector2(b.z,b.y),Vector2(c.z,c.y)];side.append(tri)
   for j in 3:
    var edge:Array=[tri[j],tri[(j+1)%3]];edge.sort();edges[edge]=edges.get(edge,0)+1
  if side.is_empty():continue
  var adjacent:Dictionary={}
  for edge:Array in edges:
   if edges[edge]!=1:continue
   for j in 2:
    if not adjacent.has(edge[j]):adjacent[edge[j]]=[]
    adjacent[edge[j]].append(edge[1-j])
  var outline:=PackedVector2Array();var point:Vector2=adjacent.keys()[0];var previous:=Vector2(INF,INF)
  for step in adjacent.size():
   assert(adjacent[point].size()==2)
   outline.append(point)
   var next:Vector2=adjacent[point][0]
   if next==previous:next=adjacent[point][1]
   previous=point;point=next
  assert(point==outline[0])
  for tri:Array in side:
   var a:Vector2=tri[0];var b:Vector2=tri[1];var c:Vector2=tri[2]
   if absf((b-a).cross(c-a))<.0000001:degenerate+=1;continue
   checked+=1
   var escaped:=false
   for weights:Vector3 in [Vector3(.333333,.333333,.333334),Vector3(.8,.1,.1),Vector3(.1,.8,.1),Vector3(.1,.1,.8)]:
    var sample:Vector2=a*weights.x+b*weights.y+c*weights.z
    if not Geometry2D.is_point_in_polygon(sample,outline):escaped=true
   if escaped:outside+=1
 return {"outside":outside,"degenerate":degenerate,"checked":checked}
