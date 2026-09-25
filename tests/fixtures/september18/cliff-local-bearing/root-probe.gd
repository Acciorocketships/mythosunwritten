extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var world:Node3D=load("res://docs/qa/2026-09-18-manual/60-cliff-local-bearing/fresh-P12/world.scn").instantiate()
 root.add_child(world)
 # Snapshot bodies preserve one source collision shape apiece. Isolate the
 # underlying native terrain without repeatedly ray-stepping through the
 # outcrop surfaces that are being measured.
 for shape:CollisionShape3D in world.find_children("*","CollisionShape3D",true,false):
  if shape.name==&"CliffRocks":shape.disabled=true
 await physics_frame
 await physics_frame
 var space:=world.get_world_3d().direct_space_state
 var discovered:=0;var near:=0;var total_columns:=0
 var samples:=0;var exposed:=0;var missing:=0;var worst:=0.0;var rows:Array=[]
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  if not node.has_meta("relief_faces"):continue
  discovered+=1
  var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(0)
  if pose.origin.distance_to(Vector3(-439.6,32,-297.5))>65:continue
  near+=1
  var columns:Dictionary={}
  var faces:PackedVector3Array=node.get_meta("relief_faces")
  for i in range(0,faces.size(),3):
   var normal:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
   if normal.y>-.5:continue
   for j in 3:
    var p:Vector3=faces[i+j]
    if p.z<=0 or p.y>.001:continue
    if not columns.has(p.x) or p.y<columns[p.x].y-.00001 or (absf(p.y-columns[p.x].y)<.00001 and p.z>columns[p.x].z):columns[p.x]=p
  total_columns+=columns.size()
  var index:=0
  for p:Vector3 in columns.values():
   index+=1
   if index%4!=0 or p.z<0:continue
   var point:Vector3=pose*p
   var origin:=point+Vector3.UP*64.0
   var found:=false
   for iteration in 32:
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,point-Vector3.UP*256.0,1))
    if hit.is_empty():break
    var body:CollisionObject3D=hit.collider
    var shape:Node=body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
    if shape.name==&"CliffRocks":origin=hit.position-Vector3.UP*.005;continue
    var gap:float=point.y-hit.position.y
    worst=maxf(worst,gap);samples+=1;found=true
    if gap>.06:exposed+=1;rows.append({"point":str(point),"ground":str(hit.position),"shape":str(shape.name),"gap":gap})
    break
   if not found:missing+=1;rows.append({"point":str(point),"missing":true})
 print("NATIVE_ROOT_DISCOVERY ",discovered," near=",near," columns=",total_columns)
 print("NATIVE_ROOT_PROBE samples=",samples," exposed=",exposed," missing=",missing," max_gap=",worst)
 FileAccess.open("res://docs/qa/2026-09-18-manual/60-cliff-local-bearing/root-probes.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"exposed":exposed,"missing":missing,"max_gap":worst,"rows":rows},"  "))
 quit(1 if samples<100 or exposed>0 or missing>0 else 0)
