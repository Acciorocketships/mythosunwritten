extends GutTest

func test_photographed_bridge_routes_do_not_cross_another_bridge_wall() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen = preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-16-manual/05-town-rails/current-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var spans := SettlementFabricAssembler.maze_skywalk_spans(fabric)
	var collisions := []
	for i in spans.size():
		var payload := SettlementFabricAssembler.maze_skywalks_from([spans[i]],fabric)
		for box: Dictionary in payload.collision_boxes:
			if not "/barrier/" in String(box.stable_id): continue
			var inverse := (box.transform as Transform3D).affine_inverse()
			var bounds := AABB(-(box.size as Vector3)*.5,box.size).grow(.2)
			for j in spans.size():
				if i==j: continue
				var span: Dictionary = spans[j]
				for lane: Vector3i in SettlementFabricAssembler._skywalk_candidate_walk_lanes(span):
					var a := Vector3(lane)*FabricRecipe.CELL_SIZE+Vector3.UP*.7
					var b := Vector3(lane+(span.step as Vector3i)*(int(span.gap)+1))*FabricRecipe.CELL_SIZE+Vector3.UP*.7
					if bounds.intersects_segment(inverse*a,inverse*b): collisions.append([i,j,box.stable_id])
	assert_gt(spans.size(),0,"Preserve usable crossings in the photographed town")
	assert_eq(collisions,[],"Complete native bridge walls must not obstruct a neighboring accepted route")
