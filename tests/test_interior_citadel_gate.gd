extends GutTest


func test_interior_gate_enters_below_grade_then_climbs_to_upper_street() -> void:
	var columns := {}
	for x in range(-4, 5):
		for z in range(-2, 11):
			columns[Vector2i(x, z)] = {"base": 0, "top": 18, "plinth": 4 if z >= 1 else 0}
	var massif := WarrenMassif.with_columns(1, columns, 18)
	var excavation := WarrenExcavation.new(1)
	excavation.route = [Vector3i.ZERO]
	for band in range(WarrenExcavation.HEADROOM_BANDS):
		excavation.carved[Vector3i(0, band, 0)] = true
	var occupied := {Vector3i.ZERO: true}
	var gates := WarrenPlatformStreets._gate_flight(
		massif, excavation, occupied, [Vector3i.ZERO], true
	)
	assert_false(gates.is_empty(), "A broad district must admit an interior climb")
	if gates.is_empty():
		return
	assert_eq(gates[0].y, 4)
	assert_false(excavation.lanes[-1].gate_covers.is_empty())
	for lane: Dictionary in excavation.lanes:
		for cell: Vector3i in lane.gate_covers:
			var top: int = lane.gate_covers[cell]
			assert_lt(top, massif.bearing_at(Vector2i(cell.x, cell.z)))
			assert_false(
				excavation.carved.has(Vector3i(cell.x, top, cell.z)),
				"Ceiling stays above the full swept stair slot"
			)


func test_admitted_interior_gate_has_finished_roof_and_clear_headroom() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for seed_value: int in [63, 83, 103]:
		var spatial := WarrenVolumetricSolver.generate(
			seed_value, {}, program, WarrenVillageScaleProfile.for_id(&"grand")
		)
		assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
		if spatial == null:
			continue
		var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
		var covers := 0
		for lane: Dictionary in source.excavation.lanes:
			for cell: Vector3i in lane.get("gate_covers", {}):
				covers += 1
				var top: int = lane.gate_covers[cell]
				for fine: Vector3i in WarrenVolumetricSolver._fine_square(
					Vector3i(cell.x, top, cell.z)
				):
					assert_eq(
						spatial.grid.use_at(fine),
						WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,
						"Retained entrance ceiling must reach construction"
					)
					assert_eq(
						spatial.grid.use_at(fine + Vector3i.DOWN),
						WarrenSpatialGrid.Use.PUBLIC_AIR,
						"Entrance keeps full headroom"
					)
		assert_gt(covers, 0, "Exercise an actual interior gate")
		var fabric := spatial.compiled_fabric_cache()
		var kit := SuntailBuildingKit.create()
		var built := KitVillageBuildings.build(spatial, fabric, kit)
		assert_eq(KitFloatingMassAudit.audit(spatial, fabric, built.masses).count, 0)
		assert_eq(
			(
				preload("res://tests/fixtures/kit_roof_public_air_audit.gd")
				. audit(built, kit)
				. intrusions
			),
			0
		)
		var clearance := preload(
			"res://scripts/terrain/features/villages/kit/KitPublicClearance.gd"
		)
		var catalog := EnvironmentCatalog.load_default()
		for part: Dictionary in built.placements:
			if part.role == &"fort.block":
				assert_false(
					clearance.intersects_air(
						catalog.descriptor(part.asset_id).measured_aabb, part.transform, built.walls
					),
					"Fortification trim cannot protrude into stair headroom"
				)
		var roof := preload("res://tests/fixtures/kit_roof_audit.gd").audit(built, kit)
		for key: String in ["open_exposed", "gable_holes", "air_unsupported", "eaves_cut"]:
			assert_eq(int(roof[key]), 0, "%s: %s" % [seed_value, key])


func test_nested_climb_does_not_bore_through_the_next_higher_district() -> void:
	var columns := {}
	for x in range(-4, 5):
		for z in range(-2, 11):
			var plinth := 4 if z >= 1 else 0
			if z >= 5 and x >= 0:
				plinth = 8
			columns[Vector2i(x, z)] = {"base": 0, "top": 18, "plinth": plinth}
	var massif := WarrenMassif.with_columns(1, columns, 18)
	var excavation := WarrenExcavation.new(1)
	excavation.route = [Vector3i.ZERO]
	for band in range(WarrenExcavation.HEADROOM_BANDS):
		excavation.carved[Vector3i(0, band, 0)] = true
	var gates := WarrenPlatformStreets._gate_flight(
		massif, excavation, {Vector3i.ZERO: true}, [Vector3i.ZERO], true
	)
	assert_false(gates.is_empty())
	if gates.is_empty():
		return
	for cell: Vector3i in excavation.lanes[-1].cells:
		assert_lte(
			massif.plinth_at(Vector2i(cell.x, cell.z)),
			4,
			"The next ascent owns the higher district"
		)


func test_parapet_clearance_never_leaves_merlons_without_their_base() -> void:
	var kit := SuntailBuildingKit.create()
	var assembler := BuildingKitAssembler.new(kit)
	var mass := BuildingMass.new()
	mass.stable_id = &"parapet.test"
	var parts: Array[Dictionary] = []
	var ctx := {"mass": mass, "out": parts, "serial": 0}
	assembler._emit_parapet(ctx, Vector2.ZERO, 0, 0)
	assert_eq(parts.size(), 4)
	var catalog := EnvironmentCatalog.load_default()
	var box: AABB = parts[0].transform * catalog.descriptor(parts[0].asset_id).measured_aabb
	var cut := AABB(box.get_center() - Vector3.ONE * .01, Vector3.ONE * .02)
	var air := (
		preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd").box_volume(cut)
	)
	air["open"] = true
	var clearance := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
	var individually_clear := 0
	for part: Dictionary in parts:
		individually_clear += int(
			not clearance.intersects_air(
				catalog.descriptor(part.asset_id).measured_aabb, part.transform, [air]
			)
		)
	assert_gt(
		individually_clear, 0, "Some carried blocks would survive an incorrect per-piece test"
	)
	var omitted := clearance.fit_decor(parts, [air], catalog)
	assert_eq(int(omitted.get(&"fort.block", 0)), 4)
	assert_true(parts.is_empty(), "The entire supported section yields together")
