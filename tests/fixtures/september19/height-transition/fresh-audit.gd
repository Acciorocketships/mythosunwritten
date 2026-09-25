extends SceneTree
const ROOT="res://docs/qa/2026-09-19-manual/99-height-transition/"
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
func _initialize()->void:call_deferred("run")
func key(a:Vector3,b:Vector3,c:Vector3)->Array:
 var points:Array=[a.snapped(Vector3.ONE*.001),b.snapped(Vector3.ONE*.001),c.snapped(Vector3.ONE*.001)]
 points.sort();return points
func run()->void:
 var world:Node3D=load(ROOT+"fresh-grass-P12/world.scn").instantiate();root.add_child(world)
 CRAGS.prepare();CORNER.prepare()
 var records:Array=[];var expected:Dictionary={};var feet:Dictionary={};var mismatches:=0;var joined:=0;var inner:=0;var outer:=0
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  var recipe:Dictionary=node.get_meta("relief_recipe",{})
  if recipe.is_empty():continue
  var connected:bool=recipe.has("inner_connections")
  if not connected and not recipe.has("edge_heights") and recipe.kind not in ["corner","inner_corner"]:continue
  var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(0)
  if Vector2(pose.origin.x+452,pose.origin.z+272).length()>85:continue
  if connected:joined+=1
  elif recipe.kind=="inner_corner":inner+=1
  elif recipe.kind=="corner":outer+=1
  var faces:PackedVector3Array=node.get_meta("relief_faces");var green:PackedVector3Array=node.get_meta("relief_green")
  var rebuilt:=REPLAY.rebuild(pose,faces,recipe,CRAGS,CORNER)
  var same:bool=rebuilt.faces==faces and rebuilt.green==green
  if not same:
   mismatches+=1
   FileAccess.open(ROOT+"replay-mismatch.bin",FileAccess.WRITE).store_var([pose,faces,green,recipe])
   var deltas:Array=[]
   if rebuilt.faces.size()==faces.size():
    for i in faces.size():
     if faces[i]!=rebuilt.faces[i] and deltas.size()<12:deltas.append([str(faces[i]),str(rebuilt.faces[i])])
   print("REPLAY_DIFFERENCE stored=",faces.size()," rebuilt=",rebuilt.faces.size()," examples=",deltas)
  var minimum:=INF
  for p:Vector3 in faces:minimum=minf(minimum,p.y)
  var floors:Dictionary={}
  for p:Vector3 in faces:floors[p.x]=minf(floors.get(p.x,INF),p.y)
  for p:Vector3 in faces:
   var floor_y:float=floors[p.x] if recipe.kind=="wall" else minimum
   if absf(p.y-floor_y)<.001:feet[pose*p]=true
  for i in range(0,faces.size(),3):expected[key(pose*faces[i],pose*faces[i+1],pose*faces[i+2])]=false
  records.append({"kind":recipe.kind,"pose":str(pose),"recipe":str(recipe),"triangles":faces.size()/3,"exact_current":same})
 var count:=expected.size();var shapes:=0
 for shape:CollisionShape3D in world.find_children("*","CollisionShape3D",true,false):
  if shape.name!=&"CliffRocks":continue
  shapes+=1
  var points:PackedVector3Array=shape.shape.get_faces()
  var pose:Transform3D=shape.global_transform
  for i in range(0,points.size(),3):
   var triangle:=key(pose*points[i],pose*points[i+1],pose*points[i+2])
   if expected.has(triangle):expected[triangle]=true
  shape.disabled=true
 var absent:=0
 for present:bool in expected.values():
  if not present:absent+=1
 await physics_frame
 await physics_frame
 var space:=world.get_world_3d().direct_space_state
 var exposed:=0;var missing:=0
 for p:Vector3 in feet:
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*64,p-Vector3.UP*128,1))
  if hit.is_empty():missing+=1
  elif p.y>hit.position.y-.05:exposed+=1
 var report:Dictionary={"joined_walls":joined,"fallback_inner":inner,"outer":outer,"exact_replay_mismatches":mismatches,"distinct_triangles":count,"missing_collision_triangles":absent,"collision_shapes":shapes,"foot_probes":feet.size(),"exposed_feet":exposed,"missing_ground":missing,"forms":records}
 FileAccess.open(ROOT+"fresh-grass-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FRESH_JOIN_AUDIT ",JSON.stringify(report))
 quit(0 if joined>=6 and inner==0 and outer>=4 and mismatches==0 and absent==0 and exposed==0 and missing==0 else 1)
