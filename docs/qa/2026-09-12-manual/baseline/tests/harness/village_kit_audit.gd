@tool
extends SceneTree

## Prints source-space bounds for a curated list of imported village-kit scenes.
## This is an editor-side curation aid: runtime code must consume baked catalogue
## assets and never depend on source-pack paths.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var sources := _sources_from_args()
	var details := OS.get_cmdline_user_args().has("--details")
	if sources.is_empty():
		push_error("Usage: --source <res://...fbx> (repeatable)")
		quit(1)
		return
	for source: String in sources:
		_print_source(source, details)
	quit()


func _sources_from_args() -> Array[String]:
	var sources: Array[String] = []
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		if args[index] == "--source" and index + 1 < args.size():
			sources.append(args[index + 1])
			index += 2
			continue
		index += 1
	return sources


func _print_source(source: String, details: bool) -> void:
	var packed := load(source) as PackedScene
	if packed == null:
		push_error("Could not load village-kit source: %s" % source)
		return
	var root := packed.instantiate()
	var bounds := AABB()
	var has_bounds := false
	var mesh_count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative := _relative_transform(mesh_instance, root)
		var piece_bounds := relative * mesh_instance.mesh.get_aabb()
		if details:
			print("[village_kit_piece] path=%s transform=%s bounds=%s" % [
				String(root.get_path_to(mesh_instance)), relative, piece_bounds])
		bounds = piece_bounds if not has_bounds else bounds.merge(piece_bounds)
		has_bounds = true
		mesh_count += 1
	print("[village_kit] source=%s meshes=%d bounds=%s end=%s" % [
		source, mesh_count, bounds, bounds.end])
	root.free()


static func _relative_transform(node: Node3D, ancestor: Node) -> Transform3D:
	var transform := node.transform
	var parent := node.get_parent()
	while parent != null and parent != ancestor:
		if parent is Node3D:
			transform = (parent as Node3D).transform * transform
		parent = parent.get_parent()
	return transform
