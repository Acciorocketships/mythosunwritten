extends RefCounted
func run(review:Node)->void:
	for view:Dictionary in review._views:
		if view.get("id","")!="containment":continue
		review._camera.fov=view.fov
		review._camera.look_at_from_position(view.position,view.target,Vector3.UP)
		review._camera.force_update_transform()
	await review.get_tree().physics_frame
	var out:Array=[]
	for pixel:Vector2 in [Vector2(640,342),Vector2(1090,410),Vector2(700,350),Vector2(600,360)]:
		var origin:Vector3=review._camera.project_ray_origin(pixel)
		var direction:Vector3=review._camera.project_ray_normal(pixel)
		var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*2000)
		var hit:Dictionary=review._camera.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():out.append({"pixel":str(pixel),"at":str(hit.position),"collider":str(hit.collider.get_path())})
	FileAccess.open(review._output_dir+"/fan-rays.json",FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
	print("[oct8_fan_rays] ",out)
