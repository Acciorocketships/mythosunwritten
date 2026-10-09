extends RefCounted
func run(review:Node)->void:
	var water:WaterFieldContext=review._inputs[Vector2i(1,6)].water
	var c:Dictionary=water._ctx
	var rows:Array=[]
	for trace:RiverTrace in c.rivers:
		if trace.source_cell!=Vector2i(0,1):continue
		for i in range(1,mini(7,trace.points.size())):
			var a:=trace.points[i-1];var b:=trace.points[i]
			for j in ceili(a.distance_to(b)):
				var p:=a.lerp(b,float(j)/ceili(a.distance_to(b)))
				rows.append({"p":str(p),"station":i,"bed":trace.beds[i],"width":trace.widths[i],"ground":TerrainTileField.surface_y(water._region,p.x,p.y),"level":WaterField.level_at(c,p),"coarse":WaterField._fill_bilinear_coarse(c,p),"head":WaterField._fill_untapered_level(c,p),"channel":WaterField._channel_membership_level(c,p)})
	FileAccess.open(review._output_dir+"/spring-detail.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	review._camera.fov=62
	review._camera.look_at_from_position(Vector3(180,85,1110),Vector3(120,40,1036),Vector3.UP)
	review._camera.force_update_transform()
	await review.get_tree().physics_frame
	for pixel:Vector2 in [Vector2(715,510),Vector2(735,530),Vector2(760,550)]:
		var origin:Vector3=review._camera.project_ray_origin(pixel)
		var direction:Vector3=review._camera.project_ray_normal(pixel)
		var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*2000)
		var hit:Dictionary=review._camera.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():print("LIP_RAY pixel=",pixel," at=",hit.position," collider=",hit.collider.get_path())
	print("SPRING_DETAIL done")
