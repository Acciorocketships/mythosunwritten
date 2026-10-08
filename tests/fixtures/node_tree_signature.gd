extends RefCounted
## A node tree as text: every node's name, class and child order, with the
## size of what it carries (mesh surfaces and vertex counts, MultiMesh
## instances, collision shape faces and transforms, particle amounts), so two
## builds of one chunk can be compared node for node.

static func of(node: Node) -> String:
	var lines := PackedStringArray()
	_walk(node, 0, lines)
	return "\n".join(lines)


static func _walk(node: Node, depth: int, lines: PackedStringArray) -> void:
	# Auto names (@Class@N) number every node made in the process: drop N.
	var name := String(node.name)
	if name.begins_with("@"):
		name = name.substr(0, name.rfind("@") + 1)
	var line := "%s%s [%s]" % ["  ".repeat(depth), name, node.get_class()]
	if node is Node3D:
		line += " xf=%s" % str((node as Node3D).transform)
	if node is MeshInstance3D:
		line += _mesh((node as MeshInstance3D).mesh)
	elif node is MultiMeshInstance3D:
		var mm := (node as MultiMeshInstance3D).multimesh
		if mm != null:
			line += " instances=%d%s" % [mm.instance_count, _mesh(mm.mesh)]
	elif node is CollisionShape3D:
		var shape := (node as CollisionShape3D).shape
		line += " shape=%s" % (shape.get_class() if shape != null else "none")
		if shape is ConcavePolygonShape3D:
			line += " faces=%d" % (shape as ConcavePolygonShape3D).get_faces().size()
	elif node is GPUParticles3D:
		line += " amount=%d" % (node as GPUParticles3D).amount
	lines.append(line)
	for child in node.get_children():
		_walk(child, depth + 1, lines)


static func _mesh(mesh: Mesh) -> String:
	if mesh == null:
		return " mesh=none"
	if not mesh is ArrayMesh:
		return " mesh=%s" % mesh.get_class()
	var parts := PackedStringArray()
	for s in mesh.get_surface_count():
		parts.append(str((mesh as ArrayMesh).surface_get_array_len(s)))
	return " surfaces=[%s]" % ",".join(parts)
