class_name VillagePlan
extends RefCounted

## Canonical settlement-record builder. The inhabited urban fabric is solved
## and committed as one transaction; optional props may only claim space after
## that transaction succeeds. Projection consumes only sealed complete records.
const SEED_VERSION := 1
const PLAZA_RADIUS := PathProgram.PLAZA_RADIUS
const SURFACE_PRIORITY := FeatureGroundField.PATH_PRIORITY + 20
const _SALT_TIER := 7039
const _SALT_THEME := 7121
const _SALT_STREET_DIRECTION := 7331
const _SALT_WARREN_GEOMETRY := 7459
const _CACHE_CAP := 64

var _world_seed: int
var _program: VillageProgram
var _fields: WorldFieldBlockCache
var _records: Dictionary = {}
var _stats := {"queries": 0, "builds": 0, "evictions": 0}
## True when the last _build's warren search stopped on its time budget
## rather than a verdict. Such records must not enter the cache: each later
## query runs another budgeted slice (resumed through the solution pin
## cache) until the search seals or is genuinely exhausted.
var _last_build_budget_interrupted := false

func _init(world_seed: int, program: VillageProgram,
		fields: WorldFieldBlockCache = null) -> void:
	assert(program != null and program.settlement_fabric_program != null,
		"VillagePlan requires the canonical warren fabric program")
	_world_seed = world_seed
	_program = program
	_fields = fields

func record_for(frame: VillageFrame) -> VillageRecord:
	_stats.queries += 1
	if frame == null or frame.is_dormant():
		return null
	if _records.has(frame.settlement_id):
		return _records[frame.settlement_id]
	if _records.size() >= _CACHE_CAP:
		_records.clear()
		_stats.evictions += 1
	var record := _build(frame)
	if not _last_build_budget_interrupted:
		_records[frame.settlement_id] = record
	_stats.builds += 1
	return record

func stats() -> Dictionary:
	var out := _stats.duplicate()
	out["cache"] = _records.size()
	return out

func _build(frame: VillageFrame) -> VillageRecord:
	var tier := _tier(frame)
	var theme := VillageProgram.THEMES[_bounded_roll(frame, _SALT_THEME,
		VillageProgram.THEMES.size())]
	var payload := EnvironmentInstancePayload.new()
	var surfaces: Array[FeatureGroundShape] = []
	var clearances: Array[FeatureGroundShape] = []
	var occupancy := VillageOccupancy.new()
	var street_axis := _street_axis(frame)
	var terrain := VillageTerrainView.from_fields(_fields) \
		if _fields != null else VillageTerrainView.from_region(
			frame.region, frame.water)
	var urban_fabric := VillageWarrenFabricSolver.solve(terrain,
		_warren_seed(frame), frame.settlement_id, frame.centre, street_axis,
		_program, _world_seed)
	_last_build_budget_interrupted = String(urban_fabric.reason) \
		.begins_with("volume_production search budget")
	if urban_fabric.accepted:
		_materialize_urban_fabric(urban_fabric, payload, surfaces,
			clearances, occupancy)
	var outskirts := VillageOutskirtsSolver.solve(terrain,
		frame.settlement_id, frame.centre, street_axis, tier, theme, _program,
		urban_fabric, occupancy.volumes(), frame.path_ground) \
			if urban_fabric.accepted \
			and urban_fabric.requires_outskirts() else null
	if outskirts != null and outskirts.accepted:
		_materialize_outskirts(outskirts, payload, surfaces, clearances,
			occupancy)
	var prop_results: Dictionary = {}
	for slot: VillagePropSlotSpec in _program.prop_slots_for_tier(tier):
		if not urban_fabric.accepted:
			prop_results[slot.stable_key] = &"urban_fabric_unavailable"
			continue
		# The one canonical transaction owns markets, furnishing, and clearance;
		# a second post-pass cannot scatter overlapping legacy props around it.
		prop_results[slot.stable_key] = &"generated_fabric_owned"
	var bounds := _record_bounds(frame.centre, payload, surfaces, clearances,
		occupancy.volumes(), _program)
	var record := VillageRecord.new(frame.settlement_id, frame.centre, bounds,
		payload, surfaces, clearances, occupancy.volumes())
	record.tier = tier
	record.theme = theme
	record.street_axis = street_axis
	record.urban_fabric = urban_fabric
	record.outskirts = outskirts
	record.prop_results = prop_results
	assert(record.validate(_program), "VillageRecord exceeds its compiled contract")
	return record


static func _materialize_urban_fabric(fabric: VillageUrbanFabricPlan,
		payload: EnvironmentInstancePayload,
		surfaces: Array[FeatureGroundShape],
		clearances: Array[FeatureGroundShape],
		occupancy: VillageOccupancy) -> void:
	assert(fabric != null and fabric.accepted)
	for entry: Dictionary in fabric.entries:
		# TASK I2. An entry may carry its own instance colour -- the garden turf
		# does, so a bench top is the same green as the ground it sits in. Every
		# channel that names none keeps the white it always had.
		payload.add(entry.asset_id, entry.transform,
			entry.get("color", Color.WHITE) as Color, entry.stable_id,
			bool(entry.get("collision_enabled", true)))
	for box: Dictionary in fabric.collision_boxes:
		payload.add_collision_box(box.transform as Transform3D,
			box.size as Vector3, StringName(box.get("stable_id", &"")))
	for mesh: Dictionary in fabric.surface_meshes:
		payload.add_surface_mesh(mesh)
	surfaces.append_array(fabric.surfaces)
	clearances.append_array(fabric.clearances)
	assert(occupancy.add_all(fabric.volumes),
		"validated urban fabric must commit atomically")


static func _materialize_outskirts(outskirts: VillageOutskirtsPlan,
		payload: EnvironmentInstancePayload,
		surfaces: Array[FeatureGroundShape],
		clearances: Array[FeatureGroundShape],
		occupancy: VillageOccupancy) -> void:
	assert(outskirts != null and outskirts.accepted)
	for entry: Dictionary in outskirts.entries:
		payload.add(entry.asset_id, entry.transform, Color.WHITE,
			entry.stable_id)
	surfaces.append_array(outskirts.surfaces)
	clearances.append_array(outskirts.clearances)
	assert(occupancy.add_all(outskirts.volumes))

func _street_axis(frame: VillageFrame) -> Vector2:
	var axis := Vector2(frame.dominant_axis)
	var positive := false
	var negative := false
	for direction: Vector2i in frame.incident_directions:
		var dot := Vector2(direction).dot(axis)
		positive = positive or dot > 0.5
		negative = negative or dot < -0.5
	if positive != negative:
		# Continue the village street through the plaza away from its sole
		# external approach, leaving the route mouth unobstructed.
		return -axis if positive else axis
	return axis if _bounded_roll(frame, _SALT_STREET_DIRECTION, 2) == 0 \
		else -axis

func _tier(frame: VillageFrame) -> StringName:
	return VillageProgram.production_tier(_roll(frame, _SALT_TIER))

func _roll(frame: VillageFrame, salt: int) -> float:
	var value := Helper._mix64(_world_seed ^ SEED_VERSION ^ salt)
	value = Helper._mix64(value ^ Helper._mix64(frame.cell.x))
	value = Helper._mix64(value ^ Helper._mix64(frame.cell.y))
	return float(value & 0x7FFFFFFF) / float(0x80000000)

func _bounded_roll(frame: VillageFrame, salt: int, bound: int) -> int:
	assert(bound > 0)
	return mini(bound - 1, int(floor(_roll(frame, salt) * float(bound))))


func _warren_seed(frame: VillageFrame) -> int:
	return warren_seed_for_cell(_world_seed, frame.cell)


static func warren_seed_for_cell(world_seed: int, cell: Vector2i) -> int:
	## Canonical derivation shared by production and fixed-seed construction
	## tests. Keeping this projection public avoids copying the seed salt into a
	## diagnostic and accidentally reviewing a different town.
	var value := Helper._mix64(world_seed ^ SEED_VERSION \
		^ _SALT_WARREN_GEOMETRY)
	value = Helper._mix64(value ^ Helper._mix64(cell.x))
	value = Helper._mix64(value ^ Helper._mix64(cell.y))
	return value

static func _record_bounds(centre: Vector2,
		payload: EnvironmentInstancePayload,
		surfaces: Array[FeatureGroundShape],
	clearances: Array[FeatureGroundShape],
		volumes: Array[VillageOccupancyVolume],
		program: VillageProgram) -> Rect2:
	var bounds := Rect2(centre - Vector2.ONE * PLAZA_RADIUS,
		Vector2.ONE * PLAZA_RADIUS * 2.0)
	for shape: FeatureGroundShape in surfaces + clearances:
		bounds = bounds.merge(shape.bounds())
	for volume: VillageOccupancyVolume in volumes:
		bounds = bounds.merge(volume.bounds_xz())
	for asset_id: StringName in payload.asset_ids():
		for transform: Transform3D in payload.batches[asset_id].transforms:
			var local_aabb: AABB = program.runtime_aabbs.get(asset_id, AABB())
			if local_aabb.has_volume():
				var world_aabb := transform * local_aabb
				bounds = bounds.expand(Vector2(world_aabb.position.x,
					world_aabb.position.z))
				bounds = bounds.expand(Vector2(world_aabb.end.x,
					world_aabb.end.z))
			else:
				bounds = bounds.expand(Vector2(transform.origin.x,
					transform.origin.z))
	return bounds
