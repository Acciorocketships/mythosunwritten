extends SceneTree
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
const WALL=preload("res://tests/fixtures/september18/cliff-stone-volumes/final.gd")
const CORNER=preload("res://tests/fixtures/september18/cliff-stone-volumes/bounded-corner.gd")
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var world:Node3D=load("res://docs/qa/2026-09-18-manual/83-cliff-fresh-world/fresh-P12/world.scn").instantiate();root.add_child(world)
 var out:Array=[];var errors:=0;var corners:=0
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  if not node.has_meta("relief_faces"):continue
  var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(0)
  if Vector2(pose.origin.x+452,pose.origin.z+272).length()>85:continue
  var faces:PackedVector3Array=node.get_meta("relief_faces")
  var replay:=REPLAY.rebuild(pose,faces,{},WALL,CORNER)
  var same:bool=replay.faces==faces
  var same_green:bool=replay.green==node.get_meta("relief_green")
  if not same or not same_green:errors+=1
  if replay.has("native_roots"):corners+=1
  var back:=0;var offgrid:=0;var box:=AABB(faces[0],Vector3.ZERO)
  for p:Vector3 in faces:
   box=box.expand(p)
   if absf(p.z+1.2)<.0001:back+=1
   if absf(p.x/.25-roundf(p.x/.25))>.001:offgrid+=1
  out.append({"pose":str(pose),"bounds":str(box),"vertices":faces.size(),"back":back,"offgrid":offgrid,"same_faces":same,"same_green":same_green})
 print(JSON.stringify(out,"  "))
 FileAccess.open("res://docs/qa/2026-09-18-manual/87-cliff-replay-fidelity/historical-identity.json",FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
 print("SNAPSHOT_IDENTITY forms=",out.size()," corners=",corners," mismatches=",errors)
 quit(1 if errors>0 else 0)
