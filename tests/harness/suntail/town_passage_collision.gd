extends SceneTree
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const REVIEW := preload("res://tests/harness/suntail/kit_town_review.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var cache := EnvironmentRenderCache.new(catalog)
	var checked := 0
	var blocked := 0
	var jobs: Array = []
	for scale: StringName in [&"compact", &"standard", &"large", &"grand"]:
		for seed_value in range(1, 13):
			var source := WarrenMazeSitePlanner.plan(seed_value, {}, WarrenVillageScaleProfile.for_id(scale), &"", false)
			if source != null and not source.excavation.tunnel_cells.is_empty(): jobs.append([seed_value, scale, source])
	for job: Array in jobs:
		var seed_value := "%d/%s" % [job[0], job[1]]
		var source: WarrenMazeSourcePlan = job[2]
		var spatial := FROZEN.spatial(source, program)
		var payload := REVIEW.town_payload(spatial, spatial.compiled_fabric_cache(), false)
		var town := Node3D.new()
		get_root().add_child(town)
		town.transform = Transform3D(Basis.from_scale(Vector3(2, 1.5, 2)), Vector3.ZERO)
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO, 1, town, payload)
		while queue.pending_count() > 0:
			queue.drain(100000, 100000, 100000)
			await process_frame
		await physics_frame
		await physics_frame
		var shape := CapsuleShape3D.new()
		shape.radius = 0.39746094
		shape.height = 2.244
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.margin = 0.02
		var space := town.get_world_3d().direct_space_state
		for cell: Vector3i in source.excavation.tunnel_cells:
			var roof := source.passage_headroom_top(cell)
			var fine_roof := Vector3i(cell.x * 2, roof, cell.z * 2)
			print("CEILING_PLAN ", cell, " roof=", roof, " source=", source.solid_at(Vector3i(cell.x, roof, cell.z)), " grid=", spatial.grid.use_at(fine_roof), " retained=", spatial.compiled_fabric_cache().retained_terrace_cells.has(fine_roof))
			var centre := town.transform * (Vector3(cell.x * 2 + 0.5, cell.y, cell.z * 2 + 0.5) * 1.5)
			for dx: float in [-1.5, 0, 1.5]:
				for dz: float in [-1.5, 0, 1.5]:
					var floor_query := PhysicsRayQueryParameters3D.create(centre + Vector3(dx, 0.8, dz), centre + Vector3(dx, -0.5, dz))
					var floor_hit := space.intersect_ray(floor_query)
					var floor_y := centre.y if floor_hit.is_empty() else float(floor_hit.position.y)
					var position := Vector3(centre.x + dx, floor_y + 1.162, centre.z + dz)
					query.transform = Transform3D(Basis.IDENTITY, position)
					var hits := space.intersect_shape(query, 32)
					checked += 1
					if not hits.is_empty():
						blocked += 1
						var hit_body: CollisionObject3D = hits[0].collider
						var owner := hit_body.shape_find_owner(hits[0].shape)
						print("BLOCKED ", seed_value, " ", cell, " ", position, " ", hit_body.shape_owner_get_owner(owner).name)
			# The carved roof must still be rendered, with matching collision.
			var ray := PhysicsRayQueryParameters3D.create(centre + Vector3.UP * 2.5, centre + Vector3.UP * 10)
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				blocked += 1
				print("MISSING_CEILING ", seed_value, " ", cell)
		print("PASSAGES ", seed_value, " count=", source.excavation.tunnel_cells.size())
		town.queue_free()
		await process_frame
	print("PASSAGE_COLLISION checked=", checked, " blocked=", blocked)
	quit(0 if blocked == 0 and checked > 0 else 1)
