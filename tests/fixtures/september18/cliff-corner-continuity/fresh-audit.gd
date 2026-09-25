extends SceneTree
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var world:Node3D=load("res://docs/qa/2026-09-18-manual/88-cliff-corner-continuity/fresh-P12/world.scn").instantiate();root.add_child(world)
 for shape:CollisionShape3D in world.find_children("*","CollisionShape3D",true,false):
  if shape.name==&"CliffRocks":shape.disabled=true
 await physics_frame
 await physics_frame
 var space:=world.get_world_3d().direct_space_state
 var records:Array=[];var failures:=0;var samples:=0;var exposed:=0;var missing:=0;var inner:=0;var outer:=0
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  var recipe:Dictionary=node.get_meta("relief_recipe",{})
  if recipe.get("kind","") not in ["corner","inner_corner"]:continue
  var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(0)
  if Vector2(pose.origin.x+452,pose.origin.z+272).length()>85:continue
  if recipe.kind=="inner_corner":inner+=1
  else:outer+=1
  var faces:PackedVector3Array=node.get_meta("relief_faces");var green:PackedVector3Array=node.get_meta("relief_green")
  var rebuilt:=REPLAY.rebuild(pose,faces,recipe,CRAGS,CORNER)
  var same:bool=rebuilt.faces==faces and rebuilt.green==green
  if not same:failures+=1
  var minimum:=INF
  for p:Vector3 in faces:minimum=minf(minimum,p.y)
  var feet:Dictionary={}
  for p:Vector3 in faces:
   if absf(p.y-minimum)<.001:feet[p]=true
  var index:=0
  for p:Vector3 in feet:
   index+=1
   if index%3!=0:continue
   var point:Vector3=pose*p
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*64,point-Vector3.UP*128,1))
   samples+=1
   if hit.is_empty():missing+=1
   elif point.y>hit.position.y-.05:exposed+=1
  records.append({"kind":recipe.kind,"pose":str(pose),"height":recipe.height,"faces":faces.size(),"floor":minimum,"exact_current":same})
 var report:Dictionary={"inner":inner,"outer":outer,"exact_mismatches":failures,"root_samples":samples,"exposed_roots":exposed,"missing_ground":missing,"forms":records}
 FileAccess.open("res://docs/qa/2026-09-18-manual/88-cliff-corner-continuity/fresh-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FRESH_CORNER_AUDIT ",JSON.stringify(report))
 quit(1 if failures>0 or inner<1 or outer<1 or samples<20 or exposed>0 or missing>0 else 0)
