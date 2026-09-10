extends RefCounted

## Frozen CPU-side inputs for visual regression tests. These retain the
## photographed rooms and lawns when the procedural street algorithm changes.
## Production never reads them; all geometry is compiled by the current code.
static func read(path: String, finish: bool = true) -> WarrenMazeSourcePlan:
	var data: Dictionary = str_to_var(FileAccess.get_file_as_string(path))
	var massif := WarrenMassif.with_columns(data.world_seed,
		data.massif_columns, data.massif_core)
	assert(massif.seal(), massif.last_rejection)
	var excavation := WarrenExcavation.new(data.world_seed)
	for key: String in data.excavation:
		excavation.set(key, data.excavation[key])
	assert(excavation.seal(), excavation.last_rejection)
	var source := WarrenMazeSourcePlan.new(data.world_seed,
		WarrenVillageScaleProfile.for_id(data.profile), massif, excavation)
	for key: String in data.source:
		source.set(key, data.source[key])
	if finish:
		source.finish_construction()
	return source


static func spatial(source: WarrenMazeSourcePlan,
		program: SettlementFabricProgram) -> WarrenSpatialPlan:
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
	var result := WarrenVolumetricSolver.from_volume(volume, -1, program, false, true)
	assert(result != null, WarrenVolumetricSolver.last_failure)
	var fabric := WarrenSpatialFabricCompiler.generate(result, program, true)
	assert(fabric != null, WarrenSpatialFabricCompiler.last_failure)
	result.cache_compiled_fabric(fabric)
	return result
