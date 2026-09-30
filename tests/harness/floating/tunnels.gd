extends SceneTree
## -- CITY PROFILE : source facts for every bored tunnel cell.
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(int(a[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(a[1])))
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	var keys := source.excavation.tunnel_cells.keys()
	keys.sort()
	for walk: Vector3i in keys:
		var roof := source.passage_headroom_top(walk)
		var column := Vector2i(walk.x, walk.z)
		var plots := []
		for plot: Dictionary in source.plots:
			if (plot.cells as Array).has(column):
				plots.append("%s:%s[%d,%d)" % [plot.id, plot.kind, int(plot.floor), int(plot.top)])
		var solid := []
		for y in range(walk.y, roof + 4):
			solid.append("1" if source.solid_at(Vector3i(walk.x, y, walk.z)) else "0")
		var fine_uses := []
		for fine: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(walk.x, roof + 1, walk.z)):
			fine_uses.append(spatial.grid.use_at(fine) if spatial.grid.contains(fine) else -1)
		print("TUNNEL ", walk, " roof=", roof, " top=", source.massif.top_at(column), " shoulder=", source.rock_shoulder(column), " solid(walk..roof+3)=", "".join(solid), " plots=", plots, " above_crown_uses=", fine_uses)
	quit()
