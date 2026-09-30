extends RefCounted
func run(review:Node3D)->void:
 var view:Dictionary=review._views.filter(func(v:Dictionary)->bool:return v.id=="front")[0]
 review._camera.fov=view.fov;review._camera.look_at_from_position(view.position,view.target,Vector3.UP)
 var rows:=[]
 for pixel:Vector2 in [Vector2(850,205),Vector2(850,240),Vector2(850,285),Vector2(1150,220),Vector2(1150,265),Vector2(1150,320),Vector2(130,330),Vector2(130,365),Vector2(1360,110),Vector2(1360,130)]:
  var from:Vector3=review._camera.project_ray_origin(pixel);var to:Vector3=from+review._camera.project_ray_normal(pixel)*1000.0
  var hit:Dictionary=review.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to))
  rows.append({"pixel":pixel,"point":hit.get("position"),"normal":hit.get("normal"),"grade":rad_to_deg(acos(clampf(hit.get("normal",Vector3.UP).y,-1,1)))})
 FileAccess.open(review._output_dir+"/circled-rays.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("[crown_rays] ",JSON.stringify(rows))
