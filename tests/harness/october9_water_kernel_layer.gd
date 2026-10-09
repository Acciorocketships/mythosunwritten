extends RefCounted
func run(review: Node) -> void:
	var nodes: Array[Node3D] = []
	for node: Node in review.get_tree().get_nodes_in_group("water_surface"):
		if node is Node3D:
			nodes.append(node)
			node.visible = false
	for chunk: Vector2i in review._streamer._built:
		var root: Node = review._streamer._built[chunk]
		for mesh: Node in root.find_children("*", "MeshInstance3D", true, false):
			if str(mesh.get_path()).contains("CliffRockFormations"):
				nodes.append(mesh)
				mesh.visible = false
	var at := Vector3(318.5781, 59.67733, 1228.326)
	review._views.append({"id":"kernel_without_dressing","position":at+Vector3(45,45,45),"target":at,"fov":50.0})
	await review._capture_all(3)
	review._views.pop_back()
	for node: Node3D in nodes: node.visible = true
	print("WATER_LAYERS_DONE")
