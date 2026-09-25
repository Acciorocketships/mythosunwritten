extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program)
	var plan := spatial.compiled_fabric_cache()
	var pose := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*2),Vector3(238.5,8.08,-365.5))
	var grade := VillageWarrenFabricSolver._ground_grade(&"reported",spatial,plan,pose)
	for z in range(5,17):
		var row := []
		for x in range(1,14): row.append(grade._claims.get(Vector2i(x,z),null))
		print("CLAIMS z=",z," worldz=",-365.5+z*3," x=241.5..277.5 ",row)
	var points := []
	for z in range(-353,-319):
		for x in range(241,278):
			var p := Vector2(x,z)
			points.append([x,z,grade.surface_y(p,8.0)])
	FileAccess.open("/tmp/september7-slope-source.txt",FileAccess.WRITE).store_string(var_to_str({"claims":grade._claims,"origin":grade._origin,"pitch":grade._targets.pitch}))
	FileAccess.open("/tmp/september7-slope-grid.json",FileAccess.WRITE).store_string(JSON.stringify(points))
	quit()
