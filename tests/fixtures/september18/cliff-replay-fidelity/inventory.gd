extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var world:Node3D=load("res://docs/qa/2026-09-18-manual/83-cliff-fresh-world/fresh-P12/world.scn").instantiate();root.add_child(world)
 var out:Array=[]
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  if not node.has_meta("relief_faces"):continue
  var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(0)
  if Vector2(pose.origin.x+452,pose.origin.z+272).length()>85:continue
  var faces:PackedVector3Array=node.get_meta("relief_faces")
  var back:=0;var offgrid:=0;var box:=AABB(faces[0],Vector3.ZERO)
  for p:Vector3 in faces:
   box=box.expand(p)
   if absf(p.z+1.2)<.0001:back+=1
   if absf(p.x/.25-roundf(p.x/.25))>.001:offgrid+=1
  out.append({"pose":str(pose),"bounds":str(box),"vertices":faces.size(),"back":back,"offgrid":offgrid})
 print(JSON.stringify(out,"  "))
 FileAccess.open("res://docs/qa/2026-09-18-manual/87-cliff-replay-fidelity/inventory.json",FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
 quit()
