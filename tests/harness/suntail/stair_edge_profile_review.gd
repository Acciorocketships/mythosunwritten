extends "res://tests/harness/pure_village_lineup.gd"
const BUILDER = preload(
	"res://scripts/terrain/features/villages/fabric/WarrenTransitionSurfaceBuilder.gd"
)


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var catalog = EnvironmentCatalog.load_default()
	var kit = SuntailBuildingKit.create()
	KitSubstitution.prepare(catalog, kit)
	for inset in [0.0, .225]:
		var stage = Node3D.new()
		root.add_child(stage)
		_light(stage)
		var flight = WarrenVolumeTransition.new(
			&"profile",
			Vector3i.ZERO,
			Vector3i(0, 1, 2),
			WarrenVolumeTransition.Kind.STAIR,
			[] as Array[Vector3i]
		)
		assert(flight.seal())
		var mesh = BUILDER.build(
			&"profile", flight, flight.surface_cells(), [], false, Vector2(inset, 0)
		)
		var ends = BUILDER._span_endpoints(flight)
		var surfaces = [mesh]
		for upper in [false, true]:
			var landing = BUILDER._empty_payload(&"landing", [] as Array[Vector3i])
			landing["is_transition"] = false
			landing["structural_plank"] = true
			var a: Vector3 = ends.end if upper else ends.start - Vector3.BACK * 3
			BUILDER._append_ramp(landing, a, a + Vector3.BACK * 3, Vector3.LEFT)
			surfaces.append(landing)
		var payload = EnvironmentInstancePayload.new()
		for surface in surfaces:
			surface["anchor"] = Vector3.ZERO
			var drawn = KitSubstitution.redraw_public_surface(surface)
			payload.surface_meshes.append(drawn.mesh)
			for rail in drawn.rails:
				payload.add(rail.asset_id, rail.transform, Color.WHITE, rail.stable_id, false)
		var cache = EnvironmentRenderCache.new(catalog)
		cache.prepare(payload.asset_ids())
		var town = Node3D.new()
		town.scale = VillageWorldScale.frame_scale()
		stage.add_child(town)
		var queue = FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO, 1, town, payload)
		while queue.pending_count() > 0:
			queue.drain(100000, 100000, 100000)
			await process_frame
		var label = "default" if inset == 0 else "inset"
		await _shoot(
			stage,
			town.transform * Vector3(5, 4, 8),
			town.transform * Vector3(.75, 1, 4),
			label + "_whole"
		)
		await _shoot(
			stage,
			town.transform * Vector3(4, 2, 1),
			town.transform * Vector3(2.1, .6, 2.25),
			label + "_lower"
		)
		await _shoot(
			stage,
			town.transform * Vector3(4, 3, 7),
			town.transform * Vector3(2.1, 2, 5.25),
			label + "_upper"
		)
		stage.queue_free()
		await process_frame
	quit()
