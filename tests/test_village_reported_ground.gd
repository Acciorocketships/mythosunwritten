extends GutTest

const FrozenSource = preload("res://tests/fixtures/frozen_maze_source.gd")

var _record: VillageRecord
var _historical_urban: VillageUrbanFabricPlan
var _catalog: EnvironmentCatalog
var _fields: WorldFieldBlockCache

## Regression for seed 2697992464, player (238.1,4,316.6), and the
## stacked street at (251,4,278.7), reported 2026-09-04.
func before_all() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := FeatureProgram.compile(catalog)
	var water := TerrainWorldTuning.make_water(2697992464)
	var heightfield := TerrainWorldTuning.make_heightfield(2697992464, water)
	var fields := WorldFieldBlockCache.new(heightfield, water,
		program.query_margin, program.shore_distance_limit, program.field_cache_cap)
	# Pin the photographed town identity. Site selection follows the current
	# world geography, which changed in the atmosphere rebuild; choosing the
	# current origin district would silently test a different building layout.
	var cell := Vector2i(11, 12)
	var centre := Vector2(cell) * TerrainSurfaceField.TILE
	var frame := VillageFrame.from_mask({"id": &"reported-september4-town",
		"cell": cell}, 4, fields.region_at(centre), fields.water_at(centre))
	var villages := VillagePlan.new(2697992464, program.villages, fields)
	var record := villages.record_for(frame)
	assert_not_null(record)
	if record == null:
		return
	_record = record
	_catalog = catalog
	_fields = fields
	# Keep the original source facts for the two specific building regressions.
	# The current generated town above still exercises terrain integration.
	var source := FrozenSource.read("res://tests/fixtures/reported-september4-source.txt")
	var spatial := FrozenSource.spatial(source, program.villages.settlement_fabric_program)
	var terrain := VillageTerrainView.from_fields(fields)
	var placement := VillageWarrenFabricSolver._placement(terrain, spatial, centre, Vector2.DOWN)
	placement["local_bounds"] = VillageWarrenFabricSolver._local_bounds(spatial.compiled_fabric_cache())
	_historical_urban = VillageWarrenFabricSolver._materialize(terrain, &"reported-fixture",
		spatial, spatial.compiled_fabric_cache(), placement, program.villages, 2697992464)


func test_reported_city_edits_ground_instead_of_emitting_ramp_sheets() -> void:
	var record := _record
	assert_false(record.is_empty(), "the photographed city must still exist")
	var duplicates: Array[String] = []
	for mesh: Dictionary in record.payload.surface_meshes:
		var id := String(mesh.get("stable_id", ""))
		if "public-terrain-handoff" in id or "public-terrain-street" in id:
			duplicates.append(id)
	assert_eq(duplicates, [] as Array[String],
		"ground streets and their transitions must belong to the edited terrain")
	assert_not_null(record.urban_fabric.get("terrain_grade"),
		"the sealed city must publish its grade for the terrain and collision")
	var grade := record.urban_fabric.terrain_grade
	var frame3 := record.urban_fabric.world_transform
	var errors: Array[Vector3] = []
	for cell: Vector3i in record.urban_fabric.fabric_plan.surface_plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET):
		var point := frame3 * (Vector3(cell) * FabricRecipe.CELL_SIZE)
		if absf(grade.surface_y(Vector2(point.x, point.z), 4.0)
				- (point.y - VillageWarrenFabricSolver.DATUM_GUARD)) > 0.001:
			errors.append(point)
	assert_eq(errors, [] as Array[Vector3],
		"terrain uses the ground datum, not the floor's existing anti-intersection guard")
	assert_gt(record.outskirts.placements.size(), 1,
		"grading cannot erase the surrounding neighbourhood")


func test_reported_stair_blocked_door_is_a_closed_facade() -> void:
	var found := false
	for entry: Dictionary in _historical_urban.entries:
		if String(entry.stable_id).ends_with("maze.house.007.part00.room00/south"):
			found = true
			assert_false("door" in String(entry.asset_id),
				"the annotated side-of-stair facade must not advertise a door")
	assert_true(found, "retain the house rather than deleting it to remove its door")
	var surface := _historical_urban.fabric_plan.surface_plan
	assert_gt(surface.entrance_records.size(), 0, "keep reachable exterior doors")
	for entrance: Dictionary in surface.entrance_records:
		for cell: Vector3i in entrance.guard_opening_cells:
			assert_false(surface.has_transition_geometry(cell))
			assert_true(surface.door_approach_is_clear(cell, entrance.facing))


func test_foundation_courses_cannot_float_below_upper_rooms() -> void:
	var suspended: Array[String] = []
	var grade := _record.urban_fabric.terrain_grade
	for entry: Dictionary in _record.urban_fabric.entries:
		if not "/terrain-foundation/" in String(entry.stable_id):
			continue
		var transform := entry.transform as Transform3D
		var bounds := transform * _catalog.descriptor(entry.asset_id).measured_aabb
		var centre := Vector2(bounds.get_center().x, bounds.get_center().z)
		var natural := TerrainSurfaceField.surface_y(_fields.region_at(centre),
			centre.x, centre.y)
		if bounds.position.y > grade.surface_y(centre, natural) + 0.2:
			suspended.append(String(entry.stable_id))
	assert_eq(suspended, [] as Array[String],
		"a skirt must reach ground; it cannot become a floating upper stone cube")


func test_reported_elevated_lawn_has_no_hanging_courses_or_grass_curtain() -> void:
	var urban := _historical_urban
	var fabric := urban.fabric_plan
	var transaction := SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	var suspended := transaction.suspended_plaza as Dictionary
	assert_gt(suspended.size(), 0, "exercise the photographed elevated lawn")
	var forbidden: Array[String] = []
	var substrate_count := 0
	for entry: Dictionary in urban.entries:
		var id := String(entry.stable_id)
		substrate_count += int("/turf-substrate/" in id)
		for cell: Vector3i in suspended:
			if "/maze-stone/%d/%d/%d/" % [cell.x, cell.y, cell.z] in id:
				forbidden.append(id)
	assert_eq(forbidden, [] as Array[String])
	assert_gt(substrate_count, 0, "one joined floor replaces suspended rock")
	for mesh: Dictionary in urban.surface_meshes:
		if not "/maze-ground-turf" in String(mesh.get("stable_id", "")):
			continue
		var cells := mesh.logical_cells as Array[Vector3i]
		var vertices := mesh.vertices as PackedVector3Array
		var collision := mesh.collision_faces as PackedVector3Array
		var curtains: Array[String] = []
		for index in cells.size():
			var cell := cells[index]
			if not suspended.has(cell):
				continue
			for corner in 16:
				# Real one-band slopes remain valid. Compare against the field's
				# own unmodified collision vertex, not an assumed flat height.
				var raw_index: int = (index * 4 + corner / 4) * 6 \
					+ [0, 1, 2, 5][corner % 4]
				var top: float = collision[raw_index].y
				if vertices[index * 16 + corner].y < top - 1.31:
					curtains.append("%s top=%s vertex=%s" % [cell, top,
						vertices[index * 16 + corner]])
		assert_eq(curtains, [] as Array[String],
			"a planted deck must not drape a grass sheet down through open air")
