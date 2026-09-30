extends RefCounted
## Review probe: paints the terrain-covering parts of rock ground skirts
## magenta, captures `<iteration 90>`, then restores them.
func run(review: Node) -> void:
	var painted: Array[MeshInstance3D] = []
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color.MAGENTA
	for node: Node in review.get_tree().root.find_children("RockSkirts", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = paint
		painted.append(node)
	print("[skirt_paint] painted=", painted.size())
	await review._capture_all(90)
	for node: MeshInstance3D in painted:
		node.material_override = null
