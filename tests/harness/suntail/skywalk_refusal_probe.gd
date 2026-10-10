extends SceneTree


## Inspect a requested private crossing against the same sealed occupancy as selection.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[args.find("--seed") + 1])
	var profile := StringName(args[args.find("--profile") + 1])
	var fields := args[args.find("--cell") + 1].split(",")
	var cell := Vector3i(int(fields[0]), int(fields[1]), int(fields[2]))
	var step := Vector3i.RIGHT if args[args.find("--axis") + 1] == "x" else Vector3i.BACK
	var gap := int(args[args.find("--gap") + 1])
	var spatial := WarrenVolumetricSolver.generate(
		seed_value,
		{},
		SettlementFabricProgram.compile(EnvironmentCatalog.load_default()),
		WarrenVillageScaleProfile.for_id(profile)
	)
	assert(spatial != null, WarrenVolumetricSolver.last_failure)
	var fabric := spatial.compiled_fabric_cache()
	var inhabited := fabric.transformed_cells(&"inhabited")
	var solids := fabric.transformed_cells(&"solid")
	var occluders := fabric.transformed_cells(&"occluder")
	occluders.merge(fabric.passage_crown_cells)
	for support: Vector3i in fabric.planned_plaza_planting_cells:
		for band in WarrenVolumePlan.HEADROOM_BANDS:
			occluders[support + Vector3i.UP * (band + 1)] = &"planting"
	var retained := fabric.retained_terrace_cells
	var paved := SettlementFabricAssembler.public_floor_cells(fabric.surface_plan)
	var walked := SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)
	var stand := SettlementFabricAssembler.maze_construction_crown_cells(fabric)
	stand.merge(walked)
	var walked_bands := {}
	for at: Vector3i in walked:
		var column := Vector2i(at.x, at.z)
		if not walked_bands.has(column):
			walked_bands[column] = []
		walked_bands[column].append(at.y)
	var ends := []
	for at: Vector3i in [cell, cell + step * (gap + 1)]:
		ends.append(
			{
				"cell": at,
				"below": inhabited.get(at - Vector3i.UP),
				"floor": inhabited.get(at),
				"above": inhabited.get(at + Vector3i.UP)
			}
		)
	var occupied := []
	var cross := Vector3i(step.z, 0, step.x)
	for offset in range(1, gap + 1):
		for lateral in range(-1, 2):
			for rise in range(-1, SettlementFabricAssembler.SKYWALK_ENCLOSURE_HEAD_BANDS + 1):
				var at := cell + step * offset + cross * lateral + Vector3i.UP * rise
				var record := {"cell": at, "offset": offset, "lateral": lateral, "rise": rise}
				for pair: Array in [
					["stand", stand],
					["solid", solids],
					["occluder", occluders],
					["retained", retained],
					["paved", paved]
				]:
					if pair[1].has(at):
						record[pair[0]] = pair[1][at]
				if record.size() > 4:
					occupied.append(record)
	var result := {
		"ends": ends,
		"occupied": occupied,
		"gap":
		SettlementFabricAssembler._passage_house_gap(
			cell, step, inhabited, stand, solids, retained, occluders, paved
		),
		"site":
		SettlementFabricAssembler._skywalk_site_holds(
			cell,
			step,
			gap,
			{cell + step * (gap + 1): true},
			solids,
			retained,
			occluders,
			paved,
			walked_bands,
			false
		),
		"enclosure":
		SettlementFabricAssembler._skywalk_enclosure_clear(
			cell, step, gap, stand, solids, retained, occluders, paved, walked_bands
		)
	}
	FileAccess.open(args[args.find("--output") + 1], FileAccess.WRITE).store_string(
		JSON.stringify(result, "\t")
	)
	quit()
