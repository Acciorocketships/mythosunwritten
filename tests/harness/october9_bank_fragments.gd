extends RefCounted
func run(review:Node)->void:
	var camera:Camera3D=review._camera
	camera.fov=60.0
	camera.look_at_from_position(Vector3(-60.09403,107.6657,1180.82),Vector3(-39.17648,75.66567,1144.4),Vector3.UP)
	camera.force_update_transform()
	await review.get_tree().process_frame
	var rows:=[]
	for y in range(390,490,10):
		for x in range(850,1010,10):
			var pixel:=Vector2(x,y)
			var origin:=camera.project_ray_origin(pixel)
			var direction:=camera.project_ray_normal(pixel)
			var hit:=camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*1000,1))
			if hit.is_empty():continue
			var at:Vector3=hit.position
			var chunk:=FieldTerrainStreamer.chunk_of(at)
			if not review._inputs.has(chunk):continue
			var water:WaterFieldContext=review._inputs[chunk].water
			var level:=water.level_at(Vector2(at.x,at.z))
			rows.append({"pixel":str(pixel),"at":str(at),"water":level if is_finite(level) else null,"depth":level-at.y if is_finite(level) else null,"collider":str(hit.collider.get_path())})
	FileAccess.open(review._output_dir+"/bank-fragments.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("BANK_FRAGMENT_RAYS ",rows.size())
