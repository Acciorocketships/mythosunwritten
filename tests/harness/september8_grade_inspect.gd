extends SceneTree

func _init() -> void:
	var layers: Array = str_to_var(FileAccess.get_file_as_string("/tmp/september8-west-grade.txt"))
	for layer: Dictionary in layers:
		print("LAYER claims=",layer.claims.size()," continuous=",layer.continuous.size())
		for z in range(5,12):
			var row := []
			for x in range(-4,4): row.append(layer.claims.get(Vector2i(x,z),null))
			print("z=",z," ",row)
	quit()
