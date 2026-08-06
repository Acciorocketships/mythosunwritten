extends GutTest

func _flat_region() -> HeightfieldRegion:
	var plan := HeightfieldPlan.new(83, 1.0, 1, "mean")
	plan.set_raw_height_override(func(_x: int, _z: int) -> float: return 0.0)
	return plan.compute_region(0, 0, 8)

func _dry_water(region: HeightfieldRegion) -> WaterFieldContext:
	var water := WaterFieldContext.new()
	water._ctx = {"ponds": [], "rivers": [], "buckets": {}, "region": region}
	water._region = region
	water._coverage = Rect2(-Vector2.ONE * 192.0, Vector2.ONE * 384.0)
	water._shore_limit = 0.0
	return water

func _context(cell: Vector2i, mask: int) -> FeatureContext:
	var surfaces: Array[FeatureGroundShape] = []
	var clearances: Array[FeatureGroundShape] = []
	var masks := {cell: mask}
	var ground := FeatureGroundField.new(surfaces, clearances, 0.0, masks)
	return FeatureContext.new(Rect2(-Vector2.ONE * 192.0,
		Vector2.ONE * 384.0), ground, EnvironmentInstancePayload.new(), masks)

func test_frame_has_sorted_incidents_and_stable_dominant_axis() -> void:
	var cell := Vector2i(3, -2)
	var region := _flat_region()
	var frame := VillageFrame.build({"id": &"settlement.test", "cell": cell},
		_context(cell, 1 | 2 | 4), region, _dry_water(region))
	assert_eq(frame.incident_directions,
		[Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT])
	assert_eq(frame.dominant_axis, Vector2i.RIGHT)
	assert_eq(frame.connection_signature, &"settlement.test:07")
	assert_false(frame.is_dormant())

func test_unconnected_frame_is_explicitly_dormant() -> void:
	var region := _flat_region()
	var frame := VillageFrame.build({"id": &"settlement.dormant",
		"cell": Vector2i.ZERO}, _context(Vector2i.ZERO, 0), region,
		_dry_water(region))
	assert_true(frame.is_dormant())

func test_program_rejects_unbounded_reach_and_record_sorts_semantics() -> void:
	assert_null(VillageProgram.compile({"max_asset_reach": 49.0}),
		"144m anchors plus 49m assets exceed the 192m settlement inset")
	assert_push_error("record radius exceeds settlement inset")
	var program := VillageProgram.compile({"max_asset_reach": 12.0,
		"max_ground_shape_reach": 8.0})
	assert_not_null(program)
	assert_eq(program.max_record_radius, 156.0)
	var canonical_bound := program.record_bound(Vector2.ZERO)
	var surfaces: Array[FeatureGroundShape] = [
		FeatureGroundShape.circle(Vector2.ZERO, 2.0,
			FeatureGroundField.WORN_PATH, 10, &"shape.b"),
		FeatureGroundShape.circle(Vector2(3.0, 0.0), 1.0,
			FeatureGroundField.WORN_PATH, 10, &"shape.a"),
	]
	var clearances: Array[FeatureGroundShape] = []
	var volumes: Array[VillageOccupancyVolume] = []
	var record := VillageRecord.new(&"village.test", Vector2.ZERO,
		Rect2(Vector2(-4.0, -3.0), Vector2(8.0, 6.0)),
		EnvironmentInstancePayload.new(), surfaces, clearances, volumes)
	record.street_axis = Vector2.RIGHT
	assert_eq(record.surface_shapes[0].stable_id, &"shape.a")
	assert_false(record.validate(program),
		"a rejected structural transaction cannot leak sorted ground shapes")
	var bounded_record := VillageRecord.new(&"village.bound", Vector2.ZERO,
		canonical_bound, EnvironmentInstancePayload.new(), [], [], [])
	bounded_record.street_axis = Vector2.RIGHT
	bounded_record.urban_fabric = VillageUrbanFabricPlan.new()
	assert_true(bounded_record.validate(program),
		"the canonical square query envelope must validate against itself")
