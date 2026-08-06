extends SceneTree

## Headless structural diagnostic for one production settlement. This keeps
## rejection analysis on the same field/cache path as runtime generation.
func _init() -> void:
	var seed_value := 2697992464
	var super_cell := Vector2i(0, -1)
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		match args[index]:
			"--seed":
				if index + 1 < args.size():
					seed_value = int(args[index + 1])
			"--super-x":
				if index + 1 < args.size():
					super_cell.x = int(args[index + 1])
			"--super-z":
				if index + 1 < args.size():
					super_cell.y = int(args[index + 1])
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var feature_program := FeatureProgram.compile(
		EnvironmentCatalog.load_default())
	assert(feature_program != null)
	var fields := WorldFieldBlockCache.new(heightfield, water,
		feature_program.query_margin,
		feature_program.shore_distance_limit,
		feature_program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var world := WorldFeaturePlan.new(seed_value, water, fields,
		feature_program, settlements)
	var frame := world.frame_for(super_cell)
	assert(frame != null)
	var started := Time.get_ticks_usec()
	var plan := world.village_plan().record_for(frame)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var fabric := plan.urban_fabric
	var report := {
		"seed": seed_value,
		"super_cell": [super_cell.x, super_cell.y],
		"settlement_id": String(frame.settlement_id),
		"tier": String(plan.tier),
		"accepted": fabric.accepted,
		"reason": String(fabric.reason),
		"payload_instances": plan.payload.instance_count,
		"elapsed_ms": elapsed_ms,
		"candidate_audit": fabric.candidate_audit.map(
			func(value: Dictionary) -> Dictionary:
				var copy := value.duplicate()
				copy.reason = StringName(copy.reason)
				return copy),
	}
	if fabric.massing != null:
		report["massing"] = _massing_report(fabric.massing)
	if fabric.accepted:
		if fabric.generation_kind in [
				VillageUrbanFabricPlan.GenerationKind.SECTIONAL_WARREN,
				VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN]:
			report["fabric_audit"] = fabric.fabric_audit
			report["route_signature"] = String(
				fabric.fabric_audit.maze_route_signature)
			report["construction_signature"] = String(
				fabric.fabric_audit.construction_signature)
		else:
			report["route_stairs"] = _route_stair_report(fabric, frame)
	print(JSON.stringify(report, "  "))
	quit(0 if fabric.accepted else 1)


static func _massing_report(massing: VillageMassingPlan) -> Dictionary:
	return {
		"accepted": massing.accepted,
		"reason": String(massing.reason),
		"buildings": massing.building_count,
		"elevation_bands": massing.elevation_band_count,
		"half_rises": massing.half_rise_count,
		"terrain_support_ratio": massing.terrain_support_ratio,
		"mean_nearest_distance": massing.mean_nearest_distance,
	}


static func _route_stair_report(fabric: VillageUrbanFabricPlan,
		frame: VillageFrame) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for run: VillageRouteStairRun in fabric.route_stairs.runs:
		var link: VillageCirculationLink
		for candidate: VillageCirculationLink in fabric.circulation.links:
			if candidate.stable_key == run.link_key:
				link = candidate
				break
		assert(link != null)
		var start := _point_on_link(link, run.start_distance)
		var end := _point_on_link(link, run.end_distance)
		var start_ground := TerrainSurfaceField.surface_y(frame.region,
			start.x, start.z)
		var end_ground := TerrainSurfaceField.surface_y(frame.region,
			end.x, end.z)
		out.append({
			"key": String(run.stable_key),
			"link_kind": link.kind,
			"interval": [run.start_distance, run.end_distance],
			"from_y": run.from_y,
			"to_y": run.to_y,
			"start": [start.x, start.y, start.z],
			"end": [end.x, end.y, end.z],
			"terrain": [start_ground, end_ground],
		})
	return out


static func _point_on_link(link: VillageCirculationLink,
		distance: float) -> Vector3:
	var travelled := 0.0
	for index in range(1, link.samples.size()):
		var a := link.samples[index - 1]
		var b := link.samples[index]
		var span := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		if travelled + span >= distance - 0.001:
			var t := 0.0 if span <= 0.001 else clampf(
				(distance - travelled) / span, 0.0, 1.0)
			return a.lerp(b, t)
		travelled += span
	return link.samples[-1]
