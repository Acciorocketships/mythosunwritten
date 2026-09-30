extends SceneTree
## -- CITY PROFILE X Z : source facts for one macro column.
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(int(a[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(a[1])))
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	var column := Vector2i(int(a[2]), int(a[3]))
	var solid := []
	var kinds := []
	for y in range(0, 12):
		var c := Vector3i(column.x, y, column.y)
		solid.append("1" if source.solid_at(c) else ("P" if source.passage_kinds.has(c) else ("c" if source.excavation.carved.has(c) else "0")))
	for plot: Dictionary in source.plots:
		if (plot.cells as Array).has(column):
			kinds.append("%s:%s[%d,%d)" % [plot.id, plot.kind, int(plot.floor), int(plot.top)])
	print("COLUMN ", column, " base=", source.massif.base_at(column), " top=", source.massif.top_at(column), " shoulder=", source.rock_shoulder(column), " bands0..11=", "".join(solid), " plots=", kinds)
	var slab := WarrenVolumetricSolver._maze_flat_slab_cells(spatial.source_volume)
	for y in range(0, 12):
		for f: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(column.x, y, column.y)):
			if slab.has(f): print("  flat-slab fine ", f)
	quit()
