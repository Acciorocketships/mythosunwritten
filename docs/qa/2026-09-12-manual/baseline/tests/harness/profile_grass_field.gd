extends SceneTree

## CPU micro-profile for one 24 m grass tile's field dependencies.

const COUNT := GrassField.SLOT_COUNT

func _init() -> void:
	var anchors: Array[Vector2] = []
	for index in COUNT:
		anchors.append(Vector2(
			(float(index % GrassField.SLOT_SIDE) + 0.37) * GrassField.SLOT_PITCH,
			(float(index / GrassField.SLOT_SIDE) + 0.63) * GrassField.SLOT_PITCH))
	var plan := HeightfieldPlan.new(4242, 1.0, 1, "mean")
	plan.set_raw_height_override(func(_x: int, _z: int) -> float: return 0.0)
	var region := plan.compute_region(4, 4, 12)
	var water := WaterFieldContext.new()
	water._ctx = {"ponds": [], "rivers": [], "buckets": {}, "region": region}
	water._region = region
	water._coverage = Rect2(Vector2(-4.0, -4.0), Vector2(32.0, 32.0))
	water._shore_limit = 0.3
	water._shore_curves_ready = true
	var surface_shapes: Array[FeatureGroundShape] = []
	var clearance_shapes: Array[FeatureGroundShape] = []
	var ground := FeatureGroundField.new(surface_shapes, clearance_shapes,
		GrassProgram.FEATURE_CLEARANCE)
	var features := FeatureContext.new(
		Rect2(Vector2.ZERO, Vector2.ONE * 24.0), ground,
		EnvironmentInstancePayload.new())

	var weights: Array[Dictionary] = []
	var started := Time.get_ticks_usec()
	for anchor: Vector2 in anchors:
		weights.append(Helper.biome_weights5(Vector3(anchor.x, 0.0, anchor.y), 4242))
	_print_phase("biome_weights5", started)
	started = Time.get_ticks_usec()
	for anchor: Vector2 in anchors:
		DressingEcology.land_occupancy01(anchor, 4242)
	_print_phase("land_occupancy01", started)
	started = Time.get_ticks_usec()
	var channel_hash := DressingCompiler.stable_id_hash(GrassProgram.CANOPY_CHANNEL)
	for anchor: Vector2 in anchors:
		DressingEcology.habitat01(anchor, 4242, channel_hash,
			GrassProgram.CANOPY_SCALE)
	_print_phase("canopy_habitat01", started)
	started = Time.get_ticks_usec()
	for value: Dictionary in weights:
		BiomeRegistry.blended_ground_tint(value)
	_print_phase("ground_tint", started)
	started = Time.get_ticks_usec()
	for anchor: Vector2 in anchors:
		TerrainSurfaceField.surface_y(region, anchor.x, anchor.y)
		TerrainSurfaceField.surface_y(region, anchor.x + 1.0, anchor.y)
		TerrainSurfaceField.surface_y(region, anchor.x - 1.0, anchor.y)
		TerrainSurfaceField.surface_y(region, anchor.x, anchor.y + 1.0)
		TerrainSurfaceField.surface_y(region, anchor.x, anchor.y - 1.0)
	_print_phase("terrain_five_samples", started)
	started = Time.get_ticks_usec()
	for anchor: Vector2 in anchors:
		water.is_wet(anchor)
		water.shore_distance_at(anchor)
	_print_phase("dry_water", started)
	started = Time.get_ticks_usec()
	for anchor: Vector2 in anchors:
		features.clearance_at(anchor)
	_print_phase("empty_feature_clearance", started)
	var settings := load("res://terrain/grass/settings.tres") as GrassSettings
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var program := GrassProgram.compile(settings, catalog, cache)
	started = Time.get_ticks_usec()
	var payload := GrassField.compute(program, 4242, Vector2i.ZERO,
		region, water, features)
	var elapsed := Time.get_ticks_usec() - started
	print("[grass_field_profile] optimized_compute total_usec=%d instances=%d" % [
		elapsed, payload.instance_count])
	quit()

func _print_phase(label: String, started: int) -> void:
	var elapsed := Time.get_ticks_usec() - started
	print("[grass_field_profile] %s total_usec=%d per_slot_usec=%.3f" % [
		label, elapsed, float(elapsed) / float(COUNT)])
