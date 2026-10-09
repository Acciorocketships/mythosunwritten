extends RefCounted
func run(review: Node) -> void:
	var rows: Array = []
	var camera: Camera3D = review._camera
	var space: PhysicsDirectSpaceState3D = review.get_world_3d().direct_space_state
	for pixel: Vector2 in [Vector2(1000,430),Vector2(1100,455),Vector2(1200,480),Vector2(1300,515),Vector2(1100,440),Vector2(1100,470)]:
		var origin := camera.project_ray_origin(pixel)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(pixel)*500))
		if hit.is_empty(): continue
		var p: Vector3 = hit.position
		var chunk := FieldTerrainStreamer.chunk_of(p)
		if not review._inputs.has(chunk): continue
		var input: Dictionary = review._inputs[chunk]
		var region: HeightfieldRegion = input.region
		rows.append({"pixel":str(pixel),"point":str(p),"collider":str(hit.collider.get_path()),"kernel":TerrainTileField.surface_y(region,p.x,p.z),
			"water":input.water.level_at(Vector2(p.x,p.z)),"grades":region.terrain_grades.size()})
	print("RIVER_EDGE_PROBE ",JSON.stringify(rows))
	FileAccess.open(review._output_dir+"/river-edge-rays.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
