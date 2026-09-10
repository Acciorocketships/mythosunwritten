extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program)
	var plan := spatial.compiled_fabric_cache()
	var transaction := SettlementFabricAssembler.maze_ground_skin_transaction(plan)
	for z in range(-4,-1):
		for y in range(0,4):
			var cell := Vector3i(5,y,z)
			var key := Vector4i(5,y,z,1)
			print("GARDEN ",cell," retained=",transaction.retained.get(cell)," next retained=",transaction.retained.get(cell+Vector3i.RIGHT)," next solid=",transaction.solids.get(cell+Vector3i.RIGHT)," exposed=",transaction.shell.exposed.get(key)," face=",transaction.shell.faces.get(key)," treatment=",transaction.shell.treatments.get(key))
	FileAccess.open("/tmp/september7-garden-transaction.txt",FileAccess.WRITE).store_string(var_to_str(transaction))
	quit()
