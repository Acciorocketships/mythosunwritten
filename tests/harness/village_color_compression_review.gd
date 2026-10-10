extends RefCounted
## Reversible material substitution. Retained originals mean the renderer's
## live total includes both versions; report image-byte savings separately.
var _seen := {}
var _candidates := {}
var _restore: Array = []
var _used := {}

func run(review: Node) -> void:
	var audit: Array = JSON.parse_string(FileAccess.get_file_as_string("/tmp/oct9-village-opaque/audit.json"))
	for entry: Dictionary in audit: _candidates[entry.path] = entry
	RenderingServer.global_shader_parameter_set(&"review_visual_time",12.0)
	await review._capture_all(60)
	for visual: EnvironmentVisual in review._streamer._environment_cache._visuals.values():
		for piece: EnvironmentVisualPiece in visual.pieces:
			_material(piece.material_override)
			_mesh(piece.mesh)
			_mesh(piece.shadow_mesh)
	for node: Node in review.get_tree().root.find_children("*","GeometryInstance3D",true,false):
		_material(node.material_override)
		if node is MeshInstance3D:
			_mesh(node.mesh)
			if node.mesh != null:
				for i in node.mesh.get_surface_count(): _material(node.get_surface_override_material(i))
		elif node is MultiMeshInstance3D and node.multimesh != null: _mesh(node.multimesh.mesh)
	await review._capture_all(61)
	var source_bytes := 0
	var packed_bytes := 0
	for path: String in _used:
		source_bytes += int(_candidates[path].source_bytes)
		packed_bytes += int(_candidates[path].packed_bytes)
	var result := {"textures":_used.size(),"material_slots":_restore.size(),"source_bytes":source_bytes,
		"packed_bytes":packed_bytes,"paths":_used.keys(),"scope":"substituted texture storage; originals retained for restoration"}
	FileAccess.open(review._output_dir+"/compression-review.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	for item: Array in _restore:
		if item[0] is ShaderMaterial: item[0].set_shader_parameter(item[1],item[2])
		else: item[0].set(item[1],item[2])
	print("VILLAGE_COLOR_COMPRESSION_REVIEW ",JSON.stringify(result))

func _mesh(mesh: Mesh) -> void:
	if mesh == null: return
	for i in mesh.get_surface_count(): _material(mesh.surface_get_material(i))

func _material(material: Material) -> void:
	if material == null or _seen.has(material.get_instance_id()): return
	_seen[material.get_instance_id()] = true
	if material is ShaderMaterial and material.shader != null:
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			_replace(material,uniform.name,material.get_shader_parameter(uniform.name))
	elif material is StandardMaterial3D:
		for property: Dictionary in material.get_property_list():
			if property.type == TYPE_OBJECT and int(property.usage) & PROPERTY_USAGE_STORAGE:
				_replace(material,property.name,material.get(property.name))

func _replace(material: Material, slot: String, value: Variant) -> void:
	if not value is Texture2D or not _candidates.has(value.resource_path): return
	var path: String = value.resource_path
	var replacement := load(_candidates[path].output) as Texture2D
	assert(replacement != null)
	_restore.append([material,slot,value])
	_used[path] = true
	if material is ShaderMaterial: material.set_shader_parameter(slot,replacement)
	else: material.set(slot,replacement)
