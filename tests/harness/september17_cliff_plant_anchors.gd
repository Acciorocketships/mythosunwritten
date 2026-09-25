extends SceneTree
func _initialize()->void:
 call_deferred("_run")
func _run()->void:
 var path:="res://docs/qa/2026-09-16-manual/10-rounded-ledges/production-01/world.scn"
 var world:Node3D=load(path).instantiate()
 world.process_mode=Node.PROCESS_MODE_DISABLED
 root.add_child(world)
 var anchors:=[];var center:=Vector3(-452,32,-272)
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  if not node.has_meta("relief_faces"):continue
  var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(0)
  if Vector2(pose.origin.x-center.x,pose.origin.z-center.z).length()>85:continue
  var faces:PackedVector3Array=node.get_meta("relief_faces")
  var box:=AABB(faces[0],Vector3.ZERO)
  for point:Vector3 in faces:box=box.expand(point)
  var left:=-INF;var right:=-INF
  for point:Vector3 in faces:
   if absf(point.x-box.position.x)<.001:left=maxf(left,point.z)
   if absf(point.x-box.end.x)<.001:right=maxf(right,point.z)
  anchors.append([pose,box.size.x,box.end.y,left<-.49,right<-.49])
 FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.WRITE).store_var(anchors)
 print("PLANT_ANCHORS ",anchors.size())
 world.free()
 quit()
