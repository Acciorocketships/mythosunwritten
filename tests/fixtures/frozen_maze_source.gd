extends RefCounted

## Frozen CPU-side inputs for visual regression tests. These retain the
## photographed rooms and lawns when the procedural street algorithm changes.
## Production never reads them; all geometry is compiled by the current code.
static func read(path: String, finish: bool = true) -> WarrenMazeSourcePlan:
	var data: Dictionary = str_to_var(FileAccess.get_file_as_string(path))
	var massif := WarrenMassif.with_columns(data.world_seed,
		data.massif_columns, data.massif_core)
	massif.form_id = StringName(data.get("massif_form", &"hill"))
	massif.open_court = data.get("massif_open_court", {})
	for key: String in data.get("massif_state", {}):
		massif.set(key, data.massif_state[key])
	assert(massif.seal(), massif.last_rejection)
	var excavation := WarrenExcavation.new(data.world_seed)
	for key: String in data.excavation:
		excavation.set(key, data.excavation[key])
	assert(excavation.seal(), excavation.last_rejection)
	var profile := WarrenVillageScaleProfile.for_id(data.profile)
	for key: String in data.get("profile_state", {}):
		profile.set(key, data.profile_state[key])
	var source := WarrenMazeSourcePlan.new(data.world_seed,
		profile, massif, excavation)
	for key: String in data.source:
		source.set(key, data.source[key])
	if finish:
		source.finish_construction()
	return source


static func spatial(source: WarrenMazeSourcePlan,
		program: SettlementFabricProgram) -> WarrenSpatialPlan:
	# The production composition, roof withdrawals included (October 8).
	var composed := WarrenVolumetricSolver.compose_maze_source(source, program, true)
	assert(not composed.is_empty(), WarrenVolumetricSolver.last_failure)
	if composed.is_empty():
		return null
	var result := composed.plan as WarrenSpatialPlan
	result.cache_compiled_fabric(composed.fabric)
	return result
