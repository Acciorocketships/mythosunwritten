extends GutTest
## Town taste knobs (Oct 7) task 6: satellite reach, a suburban band of small
## detached cottages, and lone cottages without a road. Every knob's default
## reproduces today's town field and lanes.

const FIELD := preload("res://scripts/terrain/features/villages/fabric/WarrenTownField.gd")
const DEFAULTS := {&"satellite_reach_scale": 1.0, &"suburb_house_count": 0.0,
	&"lone_house_path_chance": 1.0}


func _profile(scale: StringName, seed_value: int, overrides: Dictionary) -> WarrenVillageScaleProfile:
	var profile := WarrenVillageScaleProfile.for_id(scale)
	var program := TownOddsProgram.builtin()
	if not overrides.is_empty():
		program = program.with_overrides(overrides)
	TownCharacter.attach(profile, program, seed_value)
	return profile


func _field(seed_value: int, scale: StringName, overrides: Dictionary) -> Dictionary:
	return FIELD.sample(seed_value, _profile(scale, seed_value, overrides))


func _source(seed_value: int, scale: StringName, overrides: Dictionary) -> WarrenMazeSourcePlan:
	return WarrenMazeSitePlanner.plan(seed_value, {}, _profile(scale, seed_value, overrides), &"", false)


func _satellite_distance(field: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for index in range(1, field.lobes.size()):
		if bool(field.lobes[index].get("suburb", false)): continue
		total += (field.lobes[index].centre as Vector2).length()
		count += 1
	return total / float(maxi(count, 1))


func test_default_values_reproduce_the_field_exactly() -> void:
	for town: Array in [[13, &"standard"], [53, &"grand"], [7, &"compact"], [21, &"large"]]:
		var base := _field(town[0], town[1], {})
		var explicit := _field(town[0], town[1], DEFAULTS)
		assert_eq(var_to_str(explicit.lobes), var_to_str(base.lobes))
		assert_eq(var_to_str(explicit.solid), var_to_str(base.solid))
		assert_eq(var_to_str(explicit.house_sites), var_to_str(base.house_sites))
		assert_eq(var_to_str(explicit.open_spaces), var_to_str(base.open_spaces))


func test_a_smaller_reach_pulls_satellites_toward_the_core() -> void:
	var before := 0.0
	var after := 0.0
	for seed_value in range(20):
		before += _satellite_distance(_field(seed_value, &"standard", {}))
		after += _satellite_distance(_field(seed_value, &"standard",
			{&"satellite_reach_scale": 0.6}))
	gut.p("mean satellite distance %.2f -> %.2f" % [before / 20.0, after / 20.0])
	assert_lt(after, before * 0.8)


func test_suburb_band_adds_cottages_near_the_core_edge() -> void:
	for town: Array in [[13, &"standard"], [53, &"grand"]]:
		var base := _field(town[0], town[1], {})
		var field := _field(town[0], town[1], {&"suburb_house_count": 4.0})
		var radius := float(WarrenVillageScaleProfile.for_id(town[1]).radius_cells)
		var added := 0
		for site: Dictionary in field.house_sites:
			var lobe: Dictionary = field.lobes[int(site.lobe)]
			if not bool(lobe.get("suburb", false)): continue
			added += 1
			var distance := (site.centre as Vector2).length()
			assert_between(distance, radius * 0.95, radius * 1.45)
			assert_eq(int(lobe.storeys), 1, "suburb cottages are small")
		gut.p("%d:%s house sites %d -> %d (suburb %d)" % [town[0], town[1],
			base.house_sites.size(), field.house_sites.size(), added])
		assert_gte(added, 2, "%d:%s" % [town[0], town[1]])
		# Every suburb site is admitted by the same garden rule as any cottage.
		for space: Dictionary in field.open_spaces:
			if String(space.id).begins_with("house.garden."):
				assert_gte((space.cells as Dictionary).size(), 4)


func _house_lanes(source: WarrenMazeSourcePlan, kind: StringName) -> Array:
	return source.excavation.lanes.filter(func(lane: Dictionary) -> bool:
		return StringName(lane.get("feature_kind", &"")) == kind)


func test_lone_cottages_keep_a_door_without_a_road() -> void:
	var overrides := {&"suburb_house_count": 4.0}
	var roads := 0
	var footways := 0
	for town: Array in [[13, &"standard"], [53, &"grand"]]:
		var with_roads := _source(town[0], town[1], overrides)
		assert_not_null(with_roads, WarrenMazeSitePlanner.last_failure)
		var skipped_overrides := overrides.duplicate()
		skipped_overrides[&"lone_house_path_chance"] = 0.0
		var source := _source(town[0], town[1], skipped_overrides)
		assert_not_null(source, WarrenMazeSitePlanner.last_failure)
		if with_roads == null or source == null: continue
		roads += _house_lanes(with_roads, &"house_site_access").size()
		var lanes := _house_lanes(source, &"house_site_footway")
		footways += lanes.size()
		# A footway only crosses natural ground at its cottage's grade.
		for lane: Dictionary in lanes:
			for cell: Vector3i in lane.cells:
				var column := Vector2i(cell.x, cell.z)
				assert_eq(cell.y, source.massif.base_at(column))
				assert_eq(source.massif.bearing_at(column), source.massif.base_at(column))
		# Every remaining road is a cottage whose approach is not open ground.
		for lane: Dictionary in _house_lanes(source, &"house_site_access"):
			assert_false(WarrenMazeCarver._is_open_footway(source.massif, lane.cells))
		# Every cottage is still an addressed house on the walk graph.
		for column: Vector2i in source.massif.columns:
			if not source.massif.columns[column].has("house_site"): continue
			for index: int in source.plots_at(column):
				var plot: Dictionary = source.plots[index]
				if plot.kind != WarrenMazeSourcePlan.PLOT_HOUSE: continue
				assert_true(source.passage_kinds.has(plot.door_walk))
	gut.p("house roads %d with chance 1 -> footways %d with chance 0" % [roads, footways])
	assert_gt(roads, 0, "the evidence towns must carve cottage roads by default")
	assert_gt(footways, 0)


func test_footways_are_not_painted() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	program.town_odds = program.town_odds.with_overrides({&"suburb_house_count": 4.0,
		&"lone_house_path_chance": 0.0})
	var spatial := WarrenVolumetricSolver.generate(13, {}, program, profile)
	assert_not_null(spatial)
	if spatial == null: return
	var surfaces := spatial.compiled_fabric_cache().surface_plan
	assert_false(surfaces.footway_columns.is_empty())
	var streets := surfaces.cells_for_kind(PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET)
	var painted := surfaces.painted_street_cells()
	assert_lt(painted.size(), streets.size())
	for cell: Vector3i in painted:
		assert_false(surfaces.footway_columns.has(Vector2i(cell.x, cell.z)))
