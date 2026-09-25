extends "res://tests/harness/september10_city_form_qa.gd"

var _flat_region: HeightfieldRegion
var _outskirts: VillageOutskirtsPlan

func _solve_production_site(catalog: EnvironmentCatalog) -> VillageUrbanFabricPlan:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-24, 25):
		for x in range(-24, 25):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 0
	_flat_region = HeightfieldRegion.new(storeys, levels)
	var terrain := VillageTerrainView.from_region(_flat_region)
	var program := VillageProgram.compile({}, catalog)
	var spatial := WarrenVolumetricSolver.solve(_world_seed, {},
		program.settlement_fabric_program, WarrenVillageScaleProfile.for_id(_scale_id))
	if spatial == null:
		push_error(WarrenVolumetricSolver.last_failure)
		return null
	var fabric := spatial.compiled_fabric_cache()
	var placement := VillageWarrenFabricSolver._placement(terrain, spatial,
		Vector2.ZERO, Vector2.DOWN)
	placement["local_bounds"] = VillageWarrenFabricSolver._local_bounds(fabric)
	var id := StringName("form.%d" % _world_seed)
	var urban := VillageWarrenFabricSolver._materialize(terrain, id, spatial,
		fabric, placement, program, _world_seed)
	_outskirts = VillageOutskirtsConstruction.generate(terrain, id, Vector2.ZERO,
		Vector2.DOWN, &"village", &"blue", program, urban, null)
	assert(_outskirts.validate(program.outskirts_program, &"village"))
	urban.entries.append_array(_outskirts.entries)
	urban.surfaces.append_array(_outskirts.surfaces)
	urban.clearances.append_array(_outskirts.clearances)
	var physical: Array[VillageOccupancyVolume] = []
	for volume: VillageOccupancyVolume in urban.volumes:
		if volume.role != VillageOccupancy.Role.GROUND_EXCLUSIVE:
			physical.append(volume)
	var conflicts := VillageOccupancy.first_cross_conflict(_outskirts.volumes, physical)
	var record := {"seed": _world_seed, "world_transform": str(urban.world_transform),
		"houses": _outskirts.placements.size(), "audit": _outskirts.audit,
		"cross_conflict": str(conflicts), "entries": _outskirts.entries}
	# Frozen baseline predates the added count; audit remains readable there.
	var shared: Variant = _outskirts.get("shared_street_house_count")
	record["shared_houses"] = int(shared) if shared != null else 0
	FileAccess.open(_output_dir.path_join("frontages.json"), FileAccess.WRITE).store_string(JSON.stringify(record,"  "))
	assert(conflicts.is_empty(), "native houses and access lanes must clear completed town")
	return urban

func _build_production_terrain(world_frame: Transform3D) -> void:
	var water_plan := TerrainWorldTuning.make_water(_world_seed)
	var heightfield := TerrainWorldTuning.make_heightfield(_world_seed, water_plan)
	var region := _flat_region.with_terrain_grades([_production_urban.terrain_grade])
	var water := _empty_water(region, Vector2i.ZERO)
	water._coverage = Rect2(-576, -576, 1152, 1152)
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(_world_seed)
	mesher.prepare_resources()
	var ground := FeatureGroundField.new(_production_urban.surfaces,
		_production_urban.clearances, 0.0)
	var features := FeatureContext.new(water._coverage, ground, EnvironmentInstancePayload.new())
	var root := Node3D.new()
	root.transform = world_frame.affine_inverse()
	add_child(root)
	for z in range(-1, 2):
		for x in range(-1, 2):
			root.add_child(mesher.build_chunk(heightfield, Vector2i(x, z), region, water, features))

func _review_views() -> Array[Dictionary]:
	return [
		{"id":"north-east", "eye":Vector3(95,75,95)},
		{"id":"south-west", "eye":Vector3(-95,65,-95)},
		{"id":"north-west", "eye":Vector3(-95,75,95)},
		{"id":"south-east", "eye":Vector3(95,65,-95)},
		{"id":"plan", "eye":Vector3(0,145,0.1)},
	]
