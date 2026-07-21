extends GutTest

const CORE := Rect2(Vector2.ZERO, Vector2.ONE * 192.0)

func _program() -> DressingProgram:
	var index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	return DressingCompiler.compile(index, EnvironmentCatalog.load_default())

func _dry_context(region: HeightfieldRegion, coverage: Rect2,
		shore_limit: float) -> WaterFieldContext:
	var context := WaterFieldContext.new()
	context._ctx = {"ponds": [], "rivers": [], "buckets": {}, "region": region}
	context._region = region
	context._coverage = coverage
	context._shore_limit = shore_limit
	return context

func _signature(payload: EnvironmentInstancePayload, filter_rect: Rect2 = Rect2()) -> Array:
	var out: Array = []
	for asset_id: StringName in payload.asset_ids():
		var batch: Dictionary = payload.batches[asset_id]
		for index in batch.transforms.size():
			var transform: Transform3D = batch.transforms[index]
			var point := Vector2(transform.origin.x, transform.origin.z)
			if filter_rect.has_area() and not (point.x >= filter_rect.position.x \
					and point.y >= filter_rect.position.y and point.x < filter_rect.end.x \
					and point.y < filter_rect.end.y):
				continue
			out.append([String(asset_id), transform, batch.colors[index]])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		var ao: Vector3 = (a[1] as Transform3D).origin
		var bo: Vector3 = (b[1] as Transform3D).origin
		return ao.x < bo.x if ao.x != bo.x else ao.z < bo.z)
	return out

func test_compiler_produces_resource_free_bounded_program() -> void:
	var program := _program()
	assert_not_null(program)
	assert_eq(program.sets.size(), 11)
	assert_lte(program.maximum_spacing_radius, DressingCompiler.LOCAL_SPACING_CAP)
	assert_gt(program.query_margin, program.maximum_spacing_radius)
	assert_almost_eq(program.maximum_feature_clearance, 2.0, 0.001)
	assert_lte(program.query_margin + program.shore_distance_limit,
		WaterField.FILL_MARGIN * WaterField.FILL_STEP - WaterContour.MARGIN,
		"compiled dressing is guaranteed to fit its canonical water context")
	assert_gt(program.estimated_proposals_per_chunk, 0)
	for index in 9:
		assert_true(StringName("lpfv.tree.%02d" % (index + 1)) in program.referenced_asset_ids)
	assert_false(&"lpfv.tree.10" in program.referenced_asset_ids)
	assert_false(&"lpfv.tree.blossom_01" in program.referenced_asset_ids)
	for asset_id: StringName in [&"lpfv.mushroom.01", &"lpfv.flower.01",
			&"lpfv.reeds.01", &"lpfv.log.01", &"lpfv.big_rock.01",
			&"sfv.lily_pad.01"]:
		assert_true(asset_id in program.referenced_asset_ids,
			"nature wave asset is active: %s" % asset_id)
	for set_data: Dictionary in program.sets:
		assert_gte(float(set_data.feature_clearance), 0.0)
		assert_false(_contains_resource(set_data), "compiled sets contain primitive worker data only")

func test_path_reservation_rejects_every_population_including_zero_margin() -> void:
	var plan := HeightfieldPlan.new(4242, 1.0, 1, "mean")
	var region := plan.compute_region(4, 4, 12)
	var program := _program()
	var water := _dry_context(region, CORE.grow(program.query_margin + 2.0),
		program.shore_distance_limit)
	var paths := PathContext.new(CORE, [CORE], [CORE],
		EnvironmentInstancePayload.new(), program.maximum_feature_clearance)
	var payload := DressingField.compute(program, 4242, CORE, region, water, paths)
	assert_eq(payload.instance_count, 0,
		"zero clearance still rejects the reservation interior")

func test_field_is_deterministic_grounded_and_half_open() -> void:
	var plan := HeightfieldPlan.new(4242, 40.0, 8, "mean")
	var region := plan.compute_region(4, 4, 12)
	var program := _program()
	var water := _dry_context(region, CORE.grow(program.query_margin + 2.0),
		program.shore_distance_limit)
	var a := DressingField.compute(program, 4242, CORE, region, water)
	var b := DressingField.compute(program, 4242, CORE, region, water)
	assert_eq(_signature(a), _signature(b))
	assert_gt(a.instance_count, 0)
	for asset_id: StringName in a.asset_ids():
		for transform: Transform3D in a.batches[asset_id].transforms:
			assert_gte(transform.origin.x, CORE.position.x)
			assert_lt(transform.origin.x, CORE.end.x)
			assert_gte(transform.origin.z, CORE.position.y)
			assert_lt(transform.origin.z, CORE.end.y)
			assert_almost_eq(transform.origin.y,
				TerrainSurfaceField.surface_y(region, transform.origin.x, transform.origin.z),
				0.001, "grounding uses the final jittered anchor")
			assert_gt(DressingEcology.land_occupancy01(
				Vector2(transform.origin.x, transform.origin.z), 4242), 0.0,
				"no land dressing can occupy a clearing or path centre")

func test_shifted_chunk_windows_produce_the_same_border_decisions() -> void:
	var union := Rect2(Vector2.ZERO, Vector2(384.0, 192.0))
	var left := Rect2(Vector2.ZERO, Vector2(192.0, 192.0))
	var right := Rect2(Vector2(192.0, 0.0), Vector2(192.0, 192.0))
	var plan := HeightfieldPlan.new(991177, 32.0, 8, "mean")
	var region := plan.compute_region(8, 4, 20)
	var program := _program()
	var water := _dry_context(region, union.grow(program.query_margin + 2.0),
		program.shore_distance_limit)
	var left_payload := DressingField.compute(program, 991177, left, region, water)
	var right_payload := DressingField.compute(program, 991177, right, region, water)
	var union_payload := DressingField.compute(program, 991177, union, region, water)
	assert_eq(_signature(left_payload), _signature(union_payload, left),
		"left chunk decisions do not depend on the query window")
	assert_eq(_signature(right_payload), _signature(union_payload, right),
		"right chunk decisions do not depend on the query window")

func test_tree_spacing_is_enforced_across_visual_variants() -> void:
	var plan := HeightfieldPlan.new(7, 24.0, 8, "mean")
	var region := plan.compute_region(4, 4, 12)
	var program := _program()
	var water := _dry_context(region, CORE.grow(program.query_margin + 2.0),
		program.shore_distance_limit)
	var payload := DressingField.compute(program, 7, CORE, region, water)
	var trees: Array[Vector2] = []
	for asset_id: StringName in payload.asset_ids():
		if not String(asset_id).contains("tree"):
			continue
		for transform: Transform3D in payload.batches[asset_id].transforms:
			trees.append(Vector2(transform.origin.x, transform.origin.z))
	for i in trees.size():
		for j in range(i + 1, trees.size()):
			assert_gte(trees[i].distance_to(trees[j]), 4.0 - 0.0001,
				"one tree population spaces every visual choice together")

static func _contains_resource(value: Variant) -> bool:
	if value is Resource or value is Node or value is Mesh or value is Material \
			or value is Texture2D or value is PackedScene or value is Shape3D:
		return true
	if value is Array:
		for item: Variant in value:
			if _contains_resource(item):
				return true
	elif value is Dictionary:
		for item: Variant in value.values():
			if _contains_resource(item):
				return true
	return false
