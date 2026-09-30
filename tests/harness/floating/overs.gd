extends SceneTree
const USE := ["OUT", "ALLOC", "PUB_AIR", "DAY_AIR", "PRIV", "STRUCT", "SERVICE"]
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for job in OS.get_cmdline_user_args()[0].split(","):
		var parts := job.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(parts[1])))
		var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		for record: Dictionary in source.audit.get("plot_outcomes", {}).get("tunnel_roofs", []):
			if String(record.reason) != "": continue
			var walk := record.walk as Vector3i
			var line := "OVER %s %s floor=%d" % [job, walk, int(record.floor)]
			for y in range(source.passage_headroom_top(walk), int(record.floor) + 3):
				var f := Vector3i(walk.x * 2, y, walk.z * 2)
				line += " | %d:%s/%s" % [y, USE[spatial.grid.use_at(f)], spatial.grid.owner_name_at(f)]
			print(line)
		var audit: Dictionary = spatial.audit
		for key in audit.keys():
			if String(key).contains("back_room"):
				print("AUDIT ", job, " ", key, "=", str(audit[key]).left(400))
	quit()
