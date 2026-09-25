extends SceneTree
## Authoring input only: export the measured catalogue stock in Godot winding.
func _initialize() -> void:
	var out := {}
	for key: String in ["wall", "outer_wall", "inner_wall", "lip", "outer_lip", "inner_lip"]:
		var visual := load("res://terrain/environment/visuals/kaykit/kaykit_cliff_"+key+".tres") as EnvironmentVisual
		var piece := visual.pieces[0]
		var points := []
		for v: Vector3 in piece.mesh.get_faces():
			v = piece.local_transform*v
			points.append([v.x,v.y,v.z])
		out[key] = {"points":points,"bounds":str(piece.mesh.get_aabb())}
	FileAccess.open("res://docs/qa/2026-09-15-manual/08-cliff-siding/prototype/native-stock.json",FileAccess.WRITE).store_string(JSON.stringify(out))
	quit()
