extends SceneTree
## -- CITY PROFILE MX MZ : final grid uses/owners on one macro column (fine x/z min corner).
const USE := ["OUT", "ALLOC", "PUB_AIR", "DAY_AIR", "PRIV", "STRUCT", "SERVICE"]
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := WarrenMazeSitePlanner.plan(int(a[0]), {}, WarrenVillageScaleProfile.for_id(StringName(a[1])), &"", false)
	var spatial := FROZEN.spatial(source, program)
	var fabric := spatial.compiled_fabric_cache()
	for i in range(2, a.size(), 2):
		var m := Vector2i(int(a[i]), int(a[i + 1]))
		var line := "COL %s shoulder=%d solid=" % [m, source.rock_shoulder(m)]
		for y in range(0, 10):
			line += "1" if source.solid_at(Vector3i(m.x, y, m.y)) else "0"
		for y in range(0, 9):
			var f := Vector3i(m.x * 2, y, m.y * 2)
			line += " | %d:%s/%s%s" % [y, USE[spatial.grid.use_at(f)], String(spatial.grid.owner_name_at(f)).trim_prefix("spatial."), "(R)" if fabric.retained_terrace_cells.has(f) else ""]
		print(line)
	quit()
