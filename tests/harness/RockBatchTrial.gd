extends RefCounted
## Test-only rebatching of large rocks. Keep every mesh, transform, colour,
## contact plane, material and collision; pebbles retain their fade batches.
var _sources: Array[MultiMeshInstance3D] = []
var _roots: Dictionary = {}

func _init(chunks: Array) -> void:
	for chunk: Node in chunks:
		var slope := chunk.find_child("CliffSlopeRocks", true, false)
		if slope == null: continue
		var sources: Array[MultiMeshInstance3D] = []
		for node: Node in slope.get_children():
			if node is MultiMeshInstance3D and node.visibility_range_end == 0:
				sources.append(node)
		_sources.append_array(sources)
		for size in [64,96]:
			var root := rebatch(sources, size)
			root.visible = false
			slope.add_child(root)
			if not _roots.has(size): _roots[size] = []
			_roots[size].append(root)

static func rebatch(sources: Array[MultiMeshInstance3D], size: float) -> Node3D:
	var root := Node3D.new()
	var groups := {}
	for node: MultiMeshInstance3D in sources:
		var source := node.multimesh
		for i in source.instance_count:
			var pose := node.transform * source.get_instance_transform(i)
			var key := [source.mesh.get_instance_id(), node.material_override.get_instance_id(),
				Vector2i(floori(pose.origin.x / size),floori(pose.origin.z / size))]
			if not groups.has(key): groups[key] = {"source":node,"instances":[]}
			groups[key].instances.append([pose, source.get_instance_color(i), source.get_instance_custom_data(i)])
	for group: Dictionary in groups.values():
		var source: MultiMeshInstance3D = group.source
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = source.multimesh.mesh
		mm.instance_count = group.instances.size()
		for i in mm.instance_count:
			mm.set_instance_transform(i,group.instances[i][0])
			mm.set_instance_color(i,group.instances[i][1])
			mm.set_instance_custom_data(i,group.instances[i][2])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = source.material_override
		node.cast_shadow = source.cast_shadow
		node.lod_bias = source.lod_bias
		root.add_child(node)
	return root

func mode(name: String) -> void:
	var size := 64 if name == "rock_tiles_64" else (96 if name == "rock_tiles_96" else 0)
	for source in _sources: source.visible = size == 0
	for key: int in _roots:
		for root: Node3D in _roots[key]: root.visible = size == key

func restore() -> void:
	mode("")
	for roots: Array in _roots.values():
		for root: Node in roots: root.queue_free()
