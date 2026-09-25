class_name VillageElevatedProgram
extends RefCounted

## Compiled vocabulary and topology for the inhabited vertical-street graph.
## Buildings are the only substantial elevated nodes. Their unsupported
## footprints derive compact timber skirts; shared route contacts derive thin
## walkways, right-angle branches, and fixed stair transitions.
const ELIGIBLE_TIERS: Array[StringName] = [&"hamlet", &"village", &"town"]
const MAX_ROCK_SUPPORT_BURIAL := 5.95
const MAX_TIMBER_SUPPORT_BURIAL := 2.95
const MAX_SUPPORT_GROUND_SPAN := 2.95
const MAX_ROCK_STACK_MODULES := 8
const STAIR_SEGMENTS_PER_STOREY := 2
const PLINTH_WIDTH_FRACTION := 0.70
const PLINTH_DEPTH_FRACTION := 0.55
const SKIRT_APRON_ROWS := 1

var floor_asset_id := &"sfv.deck.floor.s.001"
var support_asset_id := &"sfv.deck.pillar.001"
var railing_asset_id := &"sfv.deck.railing.s.001"
var stair_asset_id := &"sfv.stair.s.001"
var rock_asset_id := &"sfv.foundation.rock.001"

var floor_aabb: AABB
var support_aabb: AABB
var railing_aabb: AABB
var stair_aabb: AABB
var floor_size := Vector2.ZERO
var stair_module_run := 0.0
var stair_run := 0.0
var stair_rise := 0.0
var building_table: Dictionary = {}
var route_table: Dictionary = {}
var ground_activity_table: Dictionary = {}
var referenced_asset_ids: Array[StringName] = []

static func compile(catalog: EnvironmentCatalog,
		assets: Dictionary) -> VillageElevatedProgram:
	if catalog == null:
		return null
	var program := VillageElevatedProgram.new()
	var contracts := {
		program.floor_asset_id: [&"deck", &"slab"],
		program.support_asset_id: [&"deck", &"support"],
		program.railing_asset_id: [&"deck", &"railing"],
		program.stair_asset_id: [&"stair"],
	}
	for asset_id: StringName in contracts:
		if not _validate_asset(catalog, asset_id, contracts[asset_id]):
			return null
		program.referenced_asset_ids.append(asset_id)
	if not _validate_asset(catalog, program.rock_asset_id,
			[&"foundation", &"slab"]):
		return null
	program.floor_aabb = catalog.descriptor(
		program.floor_asset_id).measured_aabb
	program.support_aabb = catalog.descriptor(
		program.support_asset_id).measured_aabb
	program.railing_aabb = catalog.descriptor(
		program.railing_asset_id).measured_aabb
	program.stair_aabb = catalog.descriptor(
		program.stair_asset_id).measured_aabb
	program.floor_size = Vector2(program.floor_aabb.size.x,
		program.floor_aabb.size.z)
	if not is_equal_approx(program.floor_size.x, VillageProgram.MODULE) \
			or not is_equal_approx(program.floor_size.y, VillageProgram.MODULE):
		push_error("Vertical streets require the reviewed 1.5m square floor tile")
		return null
	if absf(program.railing_aabb.size.x - VillageProgram.MODULE) > 0.001:
		push_error("Vertical streets require one exact railing per floor edge")
		return null
	# The source mesh extends a few millimetres beyond its authored 1.5 m
	# construction module. Planning on measured visual bounds makes adjoining
	# flights overlap and forces later stairs away from the terrain transition
	# they are meant to bridge. Freeze the semantic run to the module lattice;
	# the harmless visual lip may overlap its neighbour.
	if absf(program.stair_aabb.size.z - VillageProgram.MODULE) > 0.01:
		push_error("Vertical streets require a 1.5m stair module")
		return null
	program.stair_module_run = VillageProgram.MODULE
	program.stair_run = program.stair_module_run \
		* float(STAIR_SEGMENTS_PER_STOREY)
	program.stair_rise = program.stair_aabb.size.y \
		* float(STAIR_SEGMENTS_PER_STOREY)
	for required_id: StringName in [
			&"sfv.building.interior.blue.001", &"aws.building.003",
			&"sfm.stall.blue.007"]:
		if not assets.has(required_id):
			push_error("Vertical streets require reviewed content: %s" \
				% String(required_id))
			return null
	for tier: StringName in ELIGIBLE_TIERS:
		program._build_default_layout(tier)
		if not program._validate_layout(tier, assets):
			return null
	program.referenced_asset_ids.sort_custom(func(a: StringName,
			b: StringName) -> bool:
		return String(a) < String(b))
	return program

func eligible(tier: StringName) -> bool:
	return ELIGIBLE_TIERS.has(tier)

func buildings_for_tier(tier: StringName) -> Array[VillageElevatedBuildingSpec]:
	var out: Array[VillageElevatedBuildingSpec] = []
	out.assign(building_table.get(tier, []))
	return out

func routes_for_tier(tier: StringName) -> Array[VillageElevatedRouteSpec]:
	var out: Array[VillageElevatedRouteSpec] = []
	out.assign(route_table.get(tier, []))
	return out

func ground_activities_for_tier(
		tier: StringName) -> Array[VillageGroundActivitySpec]:
	var out: Array[VillageGroundActivitySpec] = []
	out.assign(ground_activity_table.get(tier, []))
	return out

func building_for(tier: StringName,
		key: StringName) -> VillageElevatedBuildingSpec:
	for building: VillageElevatedBuildingSpec in buildings_for_tier(tier):
		if building.stable_key == key:
			return building
	return null

func maximum_local_reach(tier: StringName) -> float:
	if not eligible(tier):
		return 0.0
	var reach := 0.0
	for building: VillageElevatedBuildingSpec in buildings_for_tier(tier):
		reach = maxf(reach, building.local_door.length())
	for route: VillageElevatedRouteSpec in routes_for_tier(tier):
		for point: Vector2 in route.points:
			reach = maxf(reach, point.length())
	return reach + floor_size.length()

func timber_module() -> SupportModule:
	return SupportModule.new(support_asset_id, support_aabb.size.y,
		Vector2(support_aabb.size.x, support_aabb.size.z) * 0.5,
		support_aabb.position.y)

func rock_module(program: VillageProgram) -> SupportModule:
	return SupportModule.new(rock_asset_id,
		program.foundation_module_height,
		Vector2(program.foundation_module_width,
			program.foundation_module_depth) * 0.5,
		program.foundation_local_bottom_y)

func level_y(datum_y: float, level: int) -> float:
	return datum_y + float(level) * VillageProgram.STOREY

func _build_default_layout(tier: StringName) -> void:
	# Three inhabited nodes face different directions and sit at three heights.
	# Their doors are graph contacts; changing the web is authored data only.
	building_table[tier] = [
		VillageElevatedBuildingSpec.new(&"lower.house",
			&"sfv.building.interior.blue.001", Vector2(-18.0, -45.0),
			Vector2.DOWN, 1),
		VillageElevatedBuildingSpec.new(&"middle.civic",
			&"aws.building.003", Vector2(18.0, -60.0),
			Vector2.RIGHT, 2),
		VillageElevatedBuildingSpec.new(&"upper.house",
			&"sfv.building.interior.blue.001", Vector2(-9.0, -81.0),
			Vector2.DOWN, 3),
	]
	route_table[tier] = [
		_route(&"ground.lower",
			[Vector2(-6.0, 0.0), Vector2(-6.0, -3.0),
				Vector2(-18.0, -3.0), Vector2(-18.0, -45.0)],
			[0, 1, 1, 1]),
		_route(&"lower.middle",
			[Vector2(-18.0, -45.0), Vector2(-18.0, -39.0),
				Vector2(21.0, -39.0), Vector2(21.0, -60.0),
				Vector2(18.0, -60.0)], [1, 1, 1, 1, 2]),
		_route(&"middle.upper",
			[Vector2(18.0, -60.0), Vector2(27.0, -60.0),
				Vector2(27.0, -78.0), Vector2(-9.0, -78.0),
				Vector2(-9.0, -81.0)], [2, 2, 2, 2, 3]),
		_route(&"middle.ground",
			[Vector2(21.0, -60.0), Vector2(30.0, -60.0),
				Vector2(30.0, -3.0), Vector2(6.0, -3.0),
				Vector2(6.0, 0.0)],
			[1, 1, 1, 1, 0]),
	]
	ground_activity_table[tier] = [
		VillageGroundActivitySpec.new(&"lower.market", &"lower.house",
			&"sfm.stall.blue.007",
			Vector2(-8.0, -43.5), Vector2.DOWN),
	]

func _validate_layout(tier: StringName, assets: Dictionary) -> bool:
	var building_keys: Dictionary = {}
	var required_contacts: Dictionary = {}
	var maximum_level := 0
	for building: VillageElevatedBuildingSpec in buildings_for_tier(tier):
		var asset := assets.get(building.asset_id) as VillageAssetSpec
		if building_keys.has(building.stable_key) or asset == null \
				or not asset.is_enterable() or not asset.requires_foundation():
			push_error("Elevated nodes must be unique enterable buildings on rock plinths")
			return false
		building_keys[building.stable_key] = true
		required_contacts[_contact_key(building.local_door,
			building.level)] = building.stable_key
		maximum_level = maxi(maximum_level, building.level)
	var adjacency: Dictionary = {}
	var route_keys: Dictionary = {}
	var ground_contacts: Dictionary = {}
	for route: VillageElevatedRouteSpec in routes_for_tier(tier):
		if route_keys.has(route.stable_key):
			push_error("Vertical route keys must be unique")
			return false
		route_keys[route.stable_key] = true
		for index in route.points.size():
			var key := _contact_key(route.points[index], route.levels[index])
			if not adjacency.has(key):
				adjacency[key] = []
			if route.levels[index] == 0:
				ground_contacts[key] = true
			if index == 0:
				continue
			var prior_key := _contact_key(route.points[index - 1],
				route.levels[index - 1])
			var delta := route.points[index] - route.points[index - 1]
			var level_delta := route.levels[index] - route.levels[index - 1]
			if not _cardinal(delta):
				push_error("Vertical routes must remain orthogonal")
				return false
			if level_delta == 0:
				if not _module_aligned(delta.length()):
					push_error("Walkway segments must fit the 1.5m lattice")
					return false
			elif absi(level_delta) != 1 \
					or absf(delta.length() - stair_run) > 0.001:
				push_error("Level transitions require one compiled stair run")
				return false
			(adjacency[key] as Array).append(prior_key)
			(adjacency[prior_key] as Array).append(key)
	for contact: String in required_contacts:
		if not adjacency.has(contact):
			push_error("Every elevated front door must be a route contact: %s" \
				% String(required_contacts[contact]))
			return false
	if ground_contacts.size() < 2 or maximum_level < 3 \
			or not _connected(adjacency):
		push_error("Vertical street graph requires three levels and two ground contacts")
		return false
	for activity: VillageGroundActivitySpec in ground_activities_for_tier(tier):
		if not building_keys.has(activity.building_key) \
				or not assets.has(activity.asset_id):
			push_error("Ground activity must bind to an inhabited overhang")
			return false
	return true

static func _route(key: StringName, point_values: Array,
		level_values: Array) -> VillageElevatedRouteSpec:
	var points: Array[Vector2] = []
	var levels: Array[int] = []
	for value: Variant in point_values:
		points.append(value as Vector2)
	for value: Variant in level_values:
		levels.append(int(value))
	return VillageElevatedRouteSpec.new(key, points, levels)

static func _validate_asset(catalog: EnvironmentCatalog,
		asset_id: StringName, tags: Array) -> bool:
	var descriptor := catalog.descriptor(asset_id)
	if descriptor == null or descriptor.collision_piece_count <= 0 \
			or not descriptor.measured_aabb.has_volume():
		push_error("Vertical street vocabulary requires collidable asset: %s" \
			% String(asset_id))
		return false
	for value: Variant in tags:
		var tag := StringName(value)
		if not descriptor.tags.has(tag):
			push_error("Vertical street asset lacks tag %s: %s" % [
				String(tag), String(asset_id)])
			return false
	return true

static func _contact_key(point: Vector2, level: int) -> String:
	return "%d:%d:%d" % [roundi(point.x * 1000.0),
		roundi(point.y * 1000.0), level]

static func _cardinal(delta: Vector2) -> bool:
	return delta.length_squared() > 0.0001 \
		and (is_zero_approx(delta.x) or is_zero_approx(delta.y))

static func _module_aligned(value: float) -> bool:
	return absf(value / VillageProgram.MODULE \
		- roundf(value / VillageProgram.MODULE)) <= 0.001

static func _connected(adjacency: Dictionary) -> bool:
	if adjacency.is_empty():
		return false
	var pending: Array[String] = [String(adjacency.keys()[0])]
	var seen: Dictionary = {}
	while not pending.is_empty():
		var key: String = pending.pop_back()
		if seen.has(key):
			continue
		seen[key] = true
		for neighbour: String in adjacency[key]:
			pending.append(neighbour)
	return seen.size() == adjacency.size()
