extends SceneTree

## Read-only diagnostic for the self-contained runtime mesh emitted by the
## environment bake. It reports each material surface's independent bounds so
## accidental billboard/smoke/glow geometry cannot hide inside a merged asset.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var source_path := ""
	var asset_id := &"sfv.building.interior.orange.002"
	for index in args.size():
		if args[index] == "--asset" and index + 1 < args.size():
			asset_id = StringName(args[index + 1])
		elif args[index] == "--source" and index + 1 < args.size():
			source_path = args[index + 1]
	if not source_path.is_empty():
		var packed := load(source_path) as PackedScene
		assert(packed != null, "Missing source: %s" % source_path)
		var source_root := packed.instantiate()
		_probe_source_node(source_root, source_root, Transform3D.IDENTITY)
		source_root.free()
		quit()
		return
	var catalog := EnvironmentCatalog.load_default()
	var descriptor := catalog.descriptor(asset_id)
	assert(descriptor != null, "Unknown asset: %s" % asset_id)
	var visual := load(descriptor.visual_path) as EnvironmentVisual
	assert(visual != null)
	for piece_index in visual.pieces.size():
		var piece := visual.pieces[piece_index] as EnvironmentVisualPiece
		for surface_index in piece.mesh.get_surface_count():
			var arrays := piece.mesh.surface_get_arrays(surface_index)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] \
				if arrays[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
			var bounds := AABB()
			var has_bounds := false
			var pale_bounds := AABB()
			var pale_count := 0
			for vertex: Vector3 in vertices:
				bounds = AABB(vertex, Vector3.ZERO) if not has_bounds \
					else bounds.expand(vertex)
				has_bounds = true
			for vertex_index in mini(vertices.size(), colors.size()):
				var color := colors[vertex_index]
				if color.r > 0.82 and color.g > 0.82 and color.b > 0.82:
					pale_bounds = AABB(vertices[vertex_index], Vector3.ZERO) \
						if pale_count == 0 else pale_bounds.expand(vertices[vertex_index])
					pale_count += 1
			var material := piece.mesh.surface_get_material(surface_index)
			print("asset=%s piece=%d surface=%d material=%s vertices=%d bounds=%s pale=%d pale_bounds=%s" % [
				asset_id, piece_index, surface_index,
				"<null>" if material == null else material.resource_name,
				vertices.size(), bounds, pale_count, pale_bounds])
	quit()


func _probe_source_node(root_node: Node, node: Node,
		parent_transform: Transform3D) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform *= (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in mesh_instance.mesh.get_surface_count():
				var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
				var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] \
					if arrays[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
				var bounds := AABB()
				var has_bounds := false
				for vertex: Vector3 in vertices:
					var world_vertex := transform * vertex
					bounds = AABB(world_vertex, Vector3.ZERO) if not has_bounds \
						else bounds.expand(world_vertex)
					has_bounds = true
				var material := mesh_instance.get_active_material(surface_index)
				var standard := material as StandardMaterial3D
				var material_detail := "" if standard == null else \
					" albedo=%s texture=%s emission=%s" % [standard.albedo_color,
						standard.albedo_texture != null, standard.emission]
				print("path=%s surface=%d material=%s%s vertices=%d colors=%d bounds=%s" % [
					root_node.get_path_to(node), surface_index,
					"<null>" if material == null else material.resource_name,
					material_detail, vertices.size(), colors.size(), bounds])
	for child: Node in node.get_children():
		_probe_source_node(root_node, child, transform)
