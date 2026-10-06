extends "res://tests/harness/suntail/kit_town_review.gd"
func _shoot(stage:Node3D,eye:Vector3,target:Vector3,view_name:String,fov:=55.0)->void:
 await super._shoot(stage,eye,target,view_name,fov)
 if not view_name.ends_with("reverse"): return
 var camera:=Camera3D.new()
 camera.fov=fov
 stage.add_child(camera)
 camera.look_at_from_position(eye,target)
 var results:=[]
 for pixel in [Vector2(762,362),Vector2(766,366),Vector2(770,378),Vector2(766,382)]:
  var origin:=camera.project_ray_origin(pixel)
  var direction:=camera.project_ray_normal(pixel)
  var hits:=[]
  _pick_nodes(stage,origin,direction,hits)
  hits.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.distance<b.distance)
  results.append({"pixel":pixel,"hits":hits.slice(0,6)})
 FileAccess.open("/tmp/oct5-ridge-remnant-pick.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
 camera.queue_free()
func _pick_nodes(node:Node,origin:Vector3,direction:Vector3,hits:Array)->void:
 if node is MeshInstance3D and node.mesh!=null:
  _pick_mesh(node.mesh,node.global_transform,origin,direction,str(node.get_path()),hits)
 elif node is MultiMeshInstance3D and node.multimesh!=null:
  for i in node.multimesh.instance_count:
   _pick_mesh(node.multimesh.mesh,node.global_transform*node.multimesh.get_instance_transform(i),origin,direction,str(node.get_path())+"/"+str(i),hits)
 for child in node.get_children():_pick_nodes(child,origin,direction,hits)
func _pick_mesh(mesh:Mesh,pose:Transform3D,origin:Vector3,direction:Vector3,label:String,hits:Array)->void:
 var inv:=pose.affine_inverse()
 var start:=inv*origin
 var ray:=inv.basis*direction
 if mesh.get_aabb().intersects_ray(start,ray)==null:return
 var faces:=mesh.get_faces()
 var best:=INF
 var point:=Vector3.ZERO
 for i in range(0,faces.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(start,ray,faces[i],faces[i+1],faces[i+2])
  if hit==null:continue
  var world:Vector3=pose*hit
  var distance:=origin.distance_to(world)
  if distance<best:best=distance;point=world
 if best<INF:hits.append({"node":label,"point":point,"distance":best})
