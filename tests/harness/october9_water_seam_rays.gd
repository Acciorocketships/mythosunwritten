extends RefCounted
func run(review: Node) -> void:
	var world: World3D = review._camera.get_world_3d()
	for screen: Vector2 in [Vector2(1000,450),Vector2(1100,460),Vector2(1300,510),Vector2(1400,550),Vector2(1100,440),Vector2(1100,480)]:
		var start: Vector3 = review._camera.project_ray_origin(screen)
		var direction: Vector3 = review._camera.project_ray_normal(screen)
		var hit := world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start+direction*500))
		if hit.is_empty():continue
		var p: Vector3 = hit.position
		var c := FieldTerrainStreamer.chunk_of(p)
		var details: Dictionary={"screen":str(screen),"world":str(p),"collider":str(hit.collider.get_path()),"chunk":str(c)}
		if review._inputs.has(c):
			var region = review._inputs[c].region
			details.kernel = TerrainTileField.surface_y(region,p.x,p.z)
			details.water = review._inputs[c].water.level_at(Vector2(p.x,p.z))
		print("SEAM_RAY ",JSON.stringify(details))
