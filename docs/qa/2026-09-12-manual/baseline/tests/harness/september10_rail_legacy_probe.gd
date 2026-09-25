extends SceneTree
const Old = preload("res://tests/fixtures/september10_rail_builder_before.gd")
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september8-night-center-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var transition: WarrenVolumeTransition = spatial.source_volume.transitions[8]
	var walls: Array[AABB] = []
	var cells := {}
	for cell: Vector3i in fabric.transformed_cells(&"solid",&"",&"roof"):cells[cell]=true
	for cell: Vector3i in fabric.retained_terrace_cells:cells[cell]=true
	for cell: Vector3i in cells:walls.append(AABB(Vector3(cell)*1.5-Vector3(.75,0,.75),Vector3.ONE*1.5))
	walls.append_array(SettlementFabricAssembler.maze_guard_wall_boxes(fabric,fabric.surface_plan))
	var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	cache.prepare(payload.asset_ids())
	var native_boxes := []
	var boxes: Array[AABB] = []
	for asset: StringName in payload.batches:
		if not String(asset).begins_with("sfv.fabric.wall.rock."):continue
		var batch: Dictionary = payload.batches[asset]
		for j in batch.transforms.size():
			for piece: EnvironmentVisualPiece in cache.visual(asset).pieces:
				var box: AABB = batch.transforms[j]*piece.local_transform*piece.mesh.get_aabb()
				boxes.append(box)
				if box.grow(.05).intersects(AABB(Vector3(2,3,2.17),Vector3(2,1.49,.16))):native_boxes.append([batch.ids[j],str(box)])
	for mesh: Dictionary in fabric.surface_plan.mesh_payloads:
		if String(mesh.get("stable_id",""))!="volume.transition.08.mesh":continue
		var old: Dictionary = Old.build(&"old",transition,mesh.claim_cells,walls)
		var report := {"old_vertices_identical":old.vertices==mesh.vertices,"old_collision_identical":old.collision_faces==mesh.collision_faces,"native_stone_overlapping_old_assertion_region":native_boxes}
		var ends := Old._span_endpoints(transition)
		var start: Vector3 = ends.start
		var run: Vector3 = ends.end-start
		var old_region := []
		for i in range(0,mesh.vertices.size(),4):
			var p: Vector3 = (mesh.vertices[i]+mesh.vertices[i+1]+mesh.vertices[i+2]+mesh.vertices[i+3])*0.25
			var t := Vector2(p.x-start.x,p.z-start.z).dot(Vector2(run.x,run.z))/Vector2(run.x,run.z).length_squared()
			if p.y>start.y+run.y*t+.4 and p.x>2 and p.x<4 and p.y>3 and p.y<4.49 and p.z>2.17 and p.z<2.33:
				var inside := false
				for box: AABB in boxes: inside=inside or box.grow(-.0001).has_point(p)
				old_region.append({"point":str(p),"inside_actual_stone_bounds":inside})
		report["old_assertion_points"]=old_region
		print("LEGACY_RAIL ",report)
		FileAccess.open("res://docs/qa/2026-09-10-manual/10-railings/legacy-probe.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
