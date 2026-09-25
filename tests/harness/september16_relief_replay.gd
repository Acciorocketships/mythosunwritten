extends "res://tests/harness/september16_manual_qa.gd"
## Same frozen geometry, collision and camera; refresh only the stone normals.
func _capture_views(world:Node3D)->void:
 var relief=preload("res://scripts/terrain/field/CliffRockRelief.gd")
 var count:=0
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  if not node.has_meta("relief_faces"):continue
  var original:=node.multimesh.mesh.get_aabb()
  node.multimesh.mesh=relief.mesh({"faces":node.get_meta("relief_faces"),"green":node.get_meta("relief_green")})
  assert(node.multimesh.mesh.get_aabb().is_equal_approx(original))
  count+=1
 assert(count>0)
 print("RELIEF_NORMAL_REPLAY ",count)
 await super._capture_views(world)
