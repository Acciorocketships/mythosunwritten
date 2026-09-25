extends "res://tests/harness/september16_manual_qa.gd"
func _capture_views(world:Node3D)->void:
 _camera.global_transform=Transform3D(Basis(Vector3(.972094,0,-.234591),Vector3(-.109752,.88381,-.45479),Vector3(.207334,.467845,.859147)),Vector3(-579.4999,51.03632,-697.455))
 _camera.fov=75
 await get_tree().physics_frame
 var rows:=[]
 for pixel:Vector2 in [Vector2(1020,475),Vector2(1015,500),Vector2(1030,520)]:
  var origin:=_camera.project_ray_origin(pixel);var direction:=_camera.project_ray_normal(pixel)
  var hit:=_camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*200,4,[_character.get_rid()]))
  var row:Dictionary={"pixel":str(pixel)}
  if not hit.is_empty():
   row.position=str(hit.position);row.collider=str(hit.collider.get_path())
   var body:CollisionObject3D=hit.collider
   row.shape=str(body.shape_owner_get_owner(body.shape_find_owner(hit.shape)).get_path())
  var closest:=200.0
  for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
   if not node.visible:continue
   var mesh:=node.multimesh.mesh
   for i in node.multimesh.instance_count:
    var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(i)
    var inverse:=pose.affine_inverse();var local_origin:Vector3=inverse*origin;var local_direction:Vector3=inverse.basis*direction
    if not mesh.get_aabb().intersects_segment(local_origin,local_origin+local_direction*closest):continue
    var faces:=mesh.get_faces()
    for j in range(0,faces.size(),3):
     var p=Geometry3D.ray_intersects_triangle(local_origin,local_direction,faces[j],faces[j+1],faces[j+2])
     if p==null:continue
     var distance:float=(pose*p).distance_to(origin)
     if distance<closest:
      closest=distance;row.visual=str(node.get_path());row.asset=str(node.get_meta("cliff_asset",""));row.instance=i;row.pose=str(pose);row.visual_hit=str(pose*p);row.triangle=[str(pose*faces[j]),str(pose*faces[j+1]),str(pose*faces[j+2])]
  rows.append(row)
 FileAccess.open(_output_dir.path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 await _shot("probe")
