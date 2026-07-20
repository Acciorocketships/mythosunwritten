extends GutTest

const SEED := 2697992464
# Verified isolated pond with a gentle closed shoreline. The historical
# (0,-6) water regression site is wall/deep-water dominated and therefore
# cannot exercise the emergent-depth band by construction.
const CHUNK := Vector2i(-4, -18)

func test_context_matches_water_field_and_has_canonical_dry_nan() -> void:
	var water := WaterPlan.new(SEED, 22.0, 8)
	var plan := HeightfieldPlan.new(SEED, 22.0, 8, "mean", 3)
	plan.set_water_plan(water)
	var centre := CHUNK * 8 + Vector2i(4, 4)
	var region := plan.compute_region(centre.x, centre.y, 8)
	var core := Rect2(Vector2(CHUNK) * 192.0, Vector2.ONE * 192.0)
	var dressing_index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var dressing_program := DressingCompiler.compile(dressing_index, EnvironmentCatalog.load_default())
	var context := WaterFieldContext.build(water,
		core.grow(dressing_program.query_margin), region,
		dressing_program.shore_distance_limit)
	var raw := context.raw_context()
	var wet_count := 0
	var dry_count := 0
	for z in range(int(core.position.y), int(core.end.y) + 1, 12):
		for x in range(int(core.position.x), int(core.end.x) + 1, 12):
			var point := Vector2(x, z)
			var wet := WaterField.wet(raw, region, point)
			assert_eq(context.is_wet(point), wet)
			if wet:
				wet_count += 1
				assert_almost_eq(context.level_at(point), WaterField.level_at(raw, point), 0.00001)
				assert_lte(context.shore_distance_at(point), 0.0)
			else:
				dry_count += 1
				assert_true(is_nan(context.level_at(point)), "dry level uses NAN, never a magic height")
				assert_gte(context.shore_distance_at(point), 0.0)
	assert_gt(wet_count, 0)
	assert_gt(dry_count, 0)
	var production_payload := DressingField.compute(dressing_program, SEED,
		core, region, context)
	var production_reeds := 0
	if production_payload.batches.has(&"lpfv.reeds.01"):
		production_reeds = production_payload.batches[&"lpfv.reeds.01"].transforms.size()
	assert_gte(production_reeds, 3,
		"the authored pond site visibly contains a reed fringe, not only a theoretical qualifier")

	# Exercise floating water placement and bed-rooted emergent reeds against
	# this SAME typed context. Reeds must be wet and close to the inward shore,
	# never scattered along the dry bank.
	# Dense test-only slot budgets avoid depending on authored art density.
	var focused := DressingProgram.new()
	focused.query_margin = dressing_program.query_margin
	for set_data: Dictionary in dressing_program.sets:
		if set_data.id in [&"ambient.reeds", &"ambient.lily_pad"]:
			var dense := set_data.duplicate(true)
			dense.fill_per_cell = PackedFloat32Array([16.0, 16.0, 16.0, 16.0, 16.0])
			dense.habitat_layers = []
			dense.slot_count = 16
			focused.sets.append(dense)
	var payload := DressingField.compute(focused, SEED, core, region, context)
	var lilies := 0
	var reeds := 0
	for asset_id: StringName in payload.asset_ids():
		for transform: Transform3D in payload.batches[asset_id].transforms:
			var point := Vector2(transform.origin.x, transform.origin.z)
			if String(asset_id).begins_with("sfv.lily"):
				lilies += 1
				assert_true(context.is_wet(point))
				assert_almost_eq(transform.origin.y, context.level_at(point), 0.001)
			elif asset_id == &"lpfv.reeds.01":
				reeds += 1
				assert_true(context.is_wet(point))
				assert_between(-context.shore_distance_at(point), 0.0, 4.0)
				assert_between(context.signed_depth_at(point), 0.05, 3.2)
				assert_almost_eq(transform.origin.y,
					TerrainSurfaceField.surface_y(region, point.x, point.y), 0.001)
	assert_gt(lilies, 0, "floating lily pads qualify from the shared water surface")
	assert_gt(reeds, 0, "reeds qualify in the canonical wet inward-shore band")
