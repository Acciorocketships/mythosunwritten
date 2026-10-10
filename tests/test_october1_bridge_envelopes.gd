extends GutTest
const AIR := preload("res://tests/fixtures/kit_roof_public_air_audit.gd")

func test_empty_recipe_box_space_does_not_erase_a_supported_bridge() -> void:
	# The bridge's aggregate recipe box crossed house.008's doorway storey.
	# The measured parts leave that space empty; both buildings must survive.
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(7, {}, program,
		WarrenVillageScaleProfile.for_id(&"large"))
	assert_not_null(spatial)
	if spatial == null:
		return
	var stamped := 0
	for outcome: Dictionary in spatial.audit.get("maze_bridge_outcomes", []):
		stamped += int(outcome.outcome == "stamped")
	assert_gt(stamped, 0, "the whole supported compound survives construction")
	var fabric := spatial.compiled_fabric_cache()
	for span: Dictionary in SettlementFabricAssembler.maze_skywalk_spans(fabric):
		if bool(span.get("private_connection", false)): continue
		for lane: Vector3i in SettlementFabricAssembler._skywalk_candidate_lanes(span):
			for end: Vector3i in [lane, lane + (span.step as Vector3i) * (int(span.gap) + 1)]:
				assert_false(fabric.surface_plan.has_transition_geometry(end),
					"a bridge meets a flat landing, never the side of a swept stair")
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial, fabric, kit)
	var floating := KitFloatingMassAudit.audit(spatial, fabric, built.masses)
	assert_eq(floating.count, 0, "the bridge and its bearings remain complete")
	var roof_air := AIR.audit(built, kit)
	assert_gt(int(roof_air.triangles), 1000)
	assert_eq(int(roof_air.intrusions), 0, "finished roofs preserve public clearance")

func test_both_kits_keep_measured_open_passage_collision() -> void:
	var ids: Array[StringName] = [&"suntail.frame.frame_wall_1_passage",
		&"suntail.stone.stone_wall_passage_deep",
		&"pure_village.wall.plaster.passage", &"pure_village.wall.stone.passage"]
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	cache.prepare(ids)
	for id: StringName in ids:
		var visual := cache.visual(id)
		assert_not_null(visual)
		if visual == null:
			continue
		var faces := PackedVector3Array()
		for piece: EnvironmentCollisionPiece in visual.collisions:
			var shape := piece.shape as ConcavePolygonShape3D
			assert_not_null(shape, "open frames retain measured mesh collision")
			if shape == null:
				continue
			for vertex: Vector3 in shape.get_faces():
				faces.append(piece.local_transform * vertex)
		assert_gt(faces.size(), 100, "%s retains its wall and jambs" % id)
		for x: float in [-0.18, 0.0, 0.18]:
			for y: float in [0.2, 0.6, 1.0]:
				var blocked := false
				for index in range(0, faces.size(), 3):
					if Geometry3D.segment_intersects_triangle(Vector3(x,y,-1),
							Vector3(x,y,1), faces[index], faces[index+1], faces[index+2]) != null:
						blocked = true
						break
				assert_false(blocked, "%s leaves the body corridor open at %s" % [id, Vector2(x,y)])
