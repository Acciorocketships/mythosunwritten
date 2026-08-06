extends GutTest

class WetWater extends WaterFieldContext:
	func is_wet(_point: Vector2) -> bool:
		return true

func _flat_region() -> HeightfieldRegion:
	var plan := HeightfieldPlan.new(184, 1.0, 1, "mean")
	plan.set_raw_height_override(func(_x: int, _z: int) -> float:
		return 0.0)
	return plan.compute_region(0, 0, 40)

func _dry_water(region: HeightfieldRegion) -> WaterFieldContext:
	var water := WaterFieldContext.new()
	water._ctx = {"ponds": [], "rivers": [], "buckets": {},
		"region": region}
	water._region = region
	water._coverage = Rect2(-Vector2.ONE * 512.0,
		Vector2.ONE * 1024.0)
	water._shore_limit = 0.0
	return water

func _frame(water: WaterFieldContext = null) -> VillageFrame:
	var region := _flat_region()
	return VillageFrame.from_mask({"id": &"settlement.elevated.test",
		"cell": Vector2i.ZERO}, 1, region,
		water if water != null else _dry_water(region))

func _accepted_streets(program: VillageProgram, tier: StringName,
		axis := Vector2.RIGHT) -> Dictionary:
	var out: Dictionary = {}
	for street: VillageStreetSpec in program.streets_for_tier(tier):
		out[street.stable_key] = street.world_segment(Vector2.ZERO, axis)
	return out

func _solve(occupancy := VillageOccupancy.new(),
		water: WaterFieldContext = null,
		axis: Vector2 = Vector2.RIGHT) -> Dictionary:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var frame := _frame(water)
	return VillageElevatedDistrict.solve(frame, &"village", &"blue",
		axis, _accepted_streets(program, &"village", axis), program,
		occupancy)

func test_compiled_graph_has_only_inhabited_nodes_and_three_levels() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var vocabulary := program.elevated_program
	var buildings := vocabulary.buildings_for_tier(&"village")
	var routes := vocabulary.routes_for_tier(&"village")
	assert_eq(buildings.size(), 3)
	assert_eq(routes.size(), 4)
	var levels: Dictionary = {}
	var contacts: Dictionary = {}
	var ground_contacts: Dictionary = {}
	var turn_count := 0
	for route: VillageElevatedRouteSpec in routes:
		for index in route.points.size():
			var key := _contact_key(route.points[index], route.levels[index])
			contacts[key] = true
			if route.levels[index] == 0:
				ground_contacts[key] = true
			if index >= 2:
				var prior := route.points[index - 1] \
					- route.points[index - 2]
				var next := route.points[index] - route.points[index - 1]
				if is_zero_approx(prior.dot(next)):
					turn_count += 1
	for building: VillageElevatedBuildingSpec in buildings:
		levels[building.level] = true
		assert_true(contacts.has(_contact_key(building.local_door,
			building.level)), "every inhabited front door is a graph contact")
		var asset := program.assets[building.asset_id] as VillageAssetSpec
		assert_true(asset.is_enterable() and asset.requires_foundation(),
			"substantial elevated nodes are buildings on rock, never empty decks")
	assert_eq(levels.size(), 3)
	assert_true(levels.has(1) and levels.has(2) and levels.has(3))
	assert_gte(ground_contacts.size(), 2)
	assert_gte(turn_count, 4,
		"the vertical street is a multi-turn orthogonal web, not spokes")
	assert_eq(vocabulary.ground_activities_for_tier(&"village").size(), 1)

func test_flat_graph_is_atomic_connected_and_exactly_traversable() -> void:
	var result := _solve()
	assert_true(result.accepted, "flat reviewed modules must build: %s (%s)" \
		% [String(result.reason), String(result.get("diagnostic", ""))])
	if not result.accepted:
		return
	assert_eq(result.buildings.size(), 3)
	assert_eq(result.transitions.size(), 4)
	assert_eq(result.descents.size(), 2)
	assert_eq(result.level_count, 3)
	assert_false(result.undercroft.is_empty())
	assert_gte(float(result.undercroft.ceiling_y)
		- float(result.undercroft.ground_y),
		TraversalEnvelope.MIN_HEADROOM)
	assert_gt(result.rock_piece_count, 0)
	assert_gt(result.railing_count, 0)
	assert_gt(result.skirt_tile_count, 0)
	assert_gt(result.walkway_tile_count, 0)
	assert_eq(result.timber_tile_count,
		result.skirt_tile_count + result.walkway_tile_count)
	assert_lt(float(result.support_count),
		float(result.timber_tile_count) * 0.55,
		"six-metre alternating supports must leave lower streets open")
	for building: Dictionary in result.buildings:
		assert_false(StringName(building.building_asset_id).is_empty())
		assert_gt(int(building.rock_piece_count), 0)
		assert_gt(int(building.tile_count), 0,
			"each building owns an unsupported skirt at its front/overhang")
		var clearance_id := StringName("settlement.elevated.test.elevated.building.%s.clearance" \
			% String(building.key))
		assert_true(result.clearances.any(func(shape: FeatureGroundShape) -> bool:
			return shape.stable_id == clearance_id),
			"every elevated building reserves its full projected lot from nature")
	var ids: Dictionary = {}
	var duplicate_ids: Array[StringName] = []
	var scaled_ids: Array[StringName] = []
	for entry: Dictionary in result.entries:
		if ids.has(entry.stable_id):
			duplicate_ids.append(entry.stable_id)
		ids[entry.stable_id] = true
		if not (entry.transform as Transform3D).basis.get_scale().is_equal_approx(
				Vector3.ONE):
			scaled_ids.append(entry.stable_id)
	assert_true(duplicate_ids.is_empty(),
		"every materialized graph piece owns one stable identity: %s" \
		% [duplicate_ids])
	assert_true(scaled_ids.is_empty(),
		"collision-bearing modules are never stretched: %s" % [scaled_ids])
	var timber_on_rock: Array[String] = []
	for cell: Dictionary in result.walk_cells:
		for building: Dictionary in result.buildings:
			if _footprints_overlap(cell.point, Vector2.ONE * 0.75, 0.0,
					building.plinth_centre,
					building.plinth_half_extents,
					float(building.plinth_angle)):
				timber_on_rock.append("%s@%s" % [cell.kind, cell.point])
	assert_true(timber_on_rock.is_empty(),
		"timber exists only beyond the rock-supported footprint: %s" \
		% [timber_on_rock.slice(0, mini(8, timber_on_rock.size()))])
	for transition: Dictionary in result.transitions:
		assert_true(TraversalEnvelope.step_is_legal(
			float(transition.residual_step)),
			"every stair endpoint obeys the shared step contract")
	var overlaps: Array[String] = []
	for index in result.volumes.size():
		var a := result.volumes[index] as VillageOccupancyVolume
		for prior_index in index:
			var b := result.volumes[prior_index] as VillageOccupancyVolume
			if _incompatible(a, b) and a.overlaps(b):
				overlaps.append("%s/%s" % [a.stable_id, b.stable_id])
	assert_true(overlaps.is_empty(),
		"the accepted graph has no incompatible 3D overlap: %s" \
		% [overlaps.slice(0, mini(8, overlaps.size()))])
	for axis: Vector2 in [Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var rotated := _solve(VillageOccupancy.new(), null, axis)
		assert_true(rotated.accepted,
			"cardinal rotation must preserve the graph: %s/%s" % [axis,
				String(rotated.reason)])
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var frame := _frame()
	var mirrored := VillageElevatedDistrict.solve(frame, &"village", &"blue",
		Vector2.RIGHT, _accepted_streets(program, &"village"), program,
		VillageOccupancy.new(), null, -1.0)
	assert_true(mirrored.accepted,
		"whole-layout mirroring must preserve topology and traversal: %s" \
		% String(mirrored.reason))

func test_external_occupancy_rejects_without_leaking_any_graph_volume() -> void:
	var occupancy := VillageOccupancy.new()
	assert_true(occupancy.add(VillageOccupancyVolume.new(
		VillageOccupancy.Role.HEADROOM, Vector2(0.0, -43.0),
		Vector2(40.0, 40.0), 0.0, 0.0, 20.0,
		&"future.protected.airspace")))
	var result := _solve(occupancy)
	assert_false(result.accepted)
	assert_eq(result.reason, &"occupancy")
	assert_eq(occupancy.volumes().size(), 1,
		"the optional graph is one transaction, never a partial repair")
	assert_true(result.entries.is_empty())
	assert_true(result.buildings.is_empty())

func test_water_rejects_before_materialization() -> void:
	var wet := WetWater.new()
	var result := _solve(VillageOccupancy.new(), wet)
	assert_false(result.accepted)
	assert_eq(result.reason, &"building_plinth_water")
	assert_true(result.entries.is_empty())
	assert_true(result.volumes.is_empty())

static func _contact_key(point: Vector2, level: int) -> String:
	return "%d:%d:%d" % [roundi(point.x * 1000.0),
		roundi(point.y * 1000.0), level]

static func _incompatible(a: VillageOccupancyVolume,
		b: VillageOccupancyVolume) -> bool:
	if not a.owner_id.is_empty() and a.owner_id == b.owner_id:
		if (a.role == VillageOccupancy.Role.SOLID \
				and b.role == VillageOccupancy.Role.HEADROOM) \
				or (a.role == VillageOccupancy.Role.HEADROOM \
				and b.role == VillageOccupancy.Role.SOLID):
			return false
		if a.role == VillageOccupancy.Role.WALK_SURFACE \
				and b.role == VillageOccupancy.Role.WALK_SURFACE:
			return false
		if a.role == VillageOccupancy.Role.SOLID \
				and b.role == VillageOccupancy.Role.SOLID:
			return false
	if a.role == VillageOccupancy.Role.GROUND_EXCLUSIVE \
			or b.role == VillageOccupancy.Role.GROUND_EXCLUSIVE:
		return a.role == VillageOccupancy.Role.GROUND_EXCLUSIVE \
			and b.role == VillageOccupancy.Role.GROUND_EXCLUSIVE
	if a.role == VillageOccupancy.Role.SOLID \
			or b.role == VillageOccupancy.Role.SOLID:
		return true
	if a.role == VillageOccupancy.Role.HEADROOM \
			or b.role == VillageOccupancy.Role.HEADROOM:
		return a.role == VillageOccupancy.Role.WALK_SURFACE \
			or b.role == VillageOccupancy.Role.WALK_SURFACE
	return a.role == VillageOccupancy.Role.WALK_SURFACE \
		and b.role == VillageOccupancy.Role.WALK_SURFACE

static func _footprints_overlap(a_centre: Vector2, a_extents: Vector2,
		a_angle: float, b_centre: Vector2, b_extents: Vector2,
		b_angle: float) -> bool:
	var a_x := Vector2.RIGHT.rotated(a_angle)
	var a_z := Vector2.DOWN.rotated(a_angle)
	var b_x := Vector2.RIGHT.rotated(b_angle)
	var b_z := Vector2.DOWN.rotated(b_angle)
	var delta := b_centre - a_centre
	for axis: Vector2 in [a_x, a_z, b_x, b_z]:
		var a_radius := absf(axis.dot(a_x)) * a_extents.x \
			+ absf(axis.dot(a_z)) * a_extents.y
		var b_radius := absf(axis.dot(b_x)) * b_extents.x \
			+ absf(axis.dot(b_z)) * b_extents.y
		if absf(delta.dot(axis)) >= a_radius + b_radius - 0.001:
			return false
	return true
