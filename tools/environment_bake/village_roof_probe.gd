extends SceneTree

## Read-only source-pack probe for modular roof pieces. It reports the authored
## aggregate visual bounds after import, so junction contracts can be authored
## from measured seams rather than guessed pivots or visual repair offsets.


func _init() -> void:
	var paths := _requested_paths()
	if paths.is_empty():
		push_error("Usage: -- <res://roof-piece.fbx> ...")
		quit(2)
		return
	var output: Array[Dictionary] = []
	for path: String in paths:
		var scene := load(path) as PackedScene
		if scene == null:
			output.append({"path": path, "error": "could not load"})
			continue
		var root := scene.instantiate()
		var measured := _measure(root, Transform3D.IDENTITY)
		root.free()
		if not bool(measured.has_bounds):
			output.append({"path": path, "error": "no visual geometry"})
			continue
		var bounds := measured.bounds as AABB
		output.append({
			"path": path,
			"mesh_count": int(measured.mesh_count),
			"position": [bounds.position.x, bounds.position.y,
				bounds.position.z],
			"size": [bounds.size.x, bounds.size.y, bounds.size.z],
			"end": [bounds.end.x, bounds.end.y, bounds.end.z],
		})
	print(JSON.stringify(output, "  "))
	quit()


func _requested_paths() -> PackedStringArray:
	var args := OS.get_cmdline_user_args()
	var out := PackedStringArray()
	for argument: String in args:
		if argument.begins_with("res://"):
			out.append(argument)
	return out


func _measure(node: Node, parent_transform: Transform3D) -> Dictionary:
	var local_transform := Transform3D.IDENTITY
	if node is Node3D:
		local_transform = (node as Node3D).transform
	var transform := parent_transform * local_transform
	var has_bounds := false
	var bounds := AABB()
	var mesh_count := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			bounds = transform * mesh.get_aabb()
			has_bounds = bounds.has_volume()
			mesh_count = 1
	for child: Node in node.get_children():
		var measured := _measure(child, transform)
		mesh_count += int(measured.mesh_count)
		if not bool(measured.has_bounds):
			continue
		var child_bounds := measured.bounds as AABB
		bounds = child_bounds if not has_bounds else bounds.merge(child_bounds)
		has_bounds = true
	return {
		"has_bounds": has_bounds,
		"bounds": bounds,
		"mesh_count": mesh_count,
	}
