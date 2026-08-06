@tool
class_name EnvironmentBakeGeometry
extends RefCounted

## Geometry-only structural bake operations. Keeping these outside the command
## runner makes material grouping and collision fitting directly testable on
## synthetic meshes without importing or writing an environment pack.

static func merge_pieces(source_root: Node,
		correction: Transform3D,
		excluded_paths: Array[String] = []) -> ArrayMesh:
	var instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(source_root, instances)
	instances.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
		return String(source_root.get_path_to(a)) \
			< String(source_root.get_path_to(b)))
	var groups: Array[Dictionary] = []
	for instance: MeshInstance3D in instances:
		if excluded_paths.has(String(source_root.get_path_to(instance))):
			continue
		for surface_index in instance.mesh.get_surface_count():
			var material := instance.get_active_material(surface_index)
			var group_index := _material_group(groups, material)
			if group_index < 0:
				groups.append({"material": material, "sources": []})
				group_index = groups.size() - 1
			(groups[group_index].sources as Array).append({
				"mesh": instance.mesh,
				"surface": surface_index,
				"transform": correction * relative_transform(instance, source_root),
			})
	if groups.is_empty():
		return null
	var merged := ArrayMesh.new()
	for group: Dictionary in groups:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(group.material as Material)
		for source: Dictionary in group.sources:
			surface.append_from(source.mesh as Mesh, int(source.surface),
				source.transform as Transform3D)
		surface.index()
		surface.commit(merged)
	return merged

static func building_trimesh(mesh: Mesh,
		transform: Transform3D = Transform3D.IDENTITY) -> ConcavePolygonShape3D:
	var faces := triangle_faces(mesh, transform)
	if faces.is_empty():
		return null
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	return shape

static func ramp_box(mesh: Mesh, direction_xz: Vector2,
		thickness: float) -> EnvironmentCollisionPiece:
	if mesh == null or not direction_xz.is_finite() \
			or not is_finite(thickness) or thickness <= 0.0 \
			or direction_xz.length_squared() <= 0.000001:
		return null
	var direction := direction_xz.normalized()
	var forward := Vector3(direction.x, 0.0, direction.y)
	var lateral := Vector3(direction.y, 0.0, -direction.x)
	var bounds := mesh.get_aabb()
	if not bounds.has_volume():
		return null
	var run_interval := _projection_interval(bounds, forward)
	var lateral_interval := _projection_interval(bounds, lateral)
	var run := run_interval.y - run_interval.x
	var width := lateral_interval.y - lateral_interval.x
	var rise := bounds.size.y
	if run <= 0.0001 or width <= 0.0001 or rise <= 0.0001:
		return null
	var slope_length := Vector2(run, rise).length()
	var slope := (forward * run + Vector3.UP * rise) / slope_length
	var normal := slope.cross(lateral).normalized()
	if normal.y < 0.0:
		lateral = -lateral
		normal = slope.cross(lateral).normalized()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, thickness, slope_length)
	var top_centre := bounds.get_center()
	var piece := EnvironmentCollisionPiece.new()
	piece.shape = shape
	piece.local_transform = Transform3D(Basis(lateral, normal, slope),
		top_centre - normal * thickness * 0.5)
	return piece

static func triangle_faces(mesh: Mesh,
		transform: Transform3D = Transform3D.IDENTITY) -> PackedVector3Array:
	var faces := PackedVector3Array()
	if mesh == null:
		return faces
	for surface_index in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface_index) \
				!= Mesh.PRIMITIVE_TRIANGLES:
			return PackedVector3Array()
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		if indices == null or indices.is_empty():
			for vertex: Vector3 in vertices:
				faces.append(transform * vertex)
		else:
			for index: int in indices:
				faces.append(transform * vertices[index])
	return faces


static func ground_contact_points(pieces: Array[EnvironmentVisualPiece],
		ground_y: float, contact_band: float = 0.35,
		sample_pitch: float = 0.75) -> PackedVector2Array:
	## Reduce real near-ground vertices to a deterministic lightweight support
	## stencil. This happens in the editor bake; the worker never loads a mesh.
	## Quantisation bounds the descriptor size while retaining multiple disjoint
	## feet, porches, and wings instead of collapsing them into one rectangle.
	var out := PackedVector2Array()
	if not is_finite(ground_y) or not is_finite(contact_band) \
			or not is_finite(sample_pitch) or contact_band <= 0.0 \
			or sample_pitch <= 0.0:
		return out
	var keys: Dictionary = {}
	for piece: EnvironmentVisualPiece in pieces:
		if piece == null or piece.mesh == null or not piece.local_transform.is_finite():
			return PackedVector2Array()
		for surface_index in piece.mesh.get_surface_count():
			var arrays := piece.mesh.surface_get_arrays(surface_index)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for local_vertex: Vector3 in vertices:
				var vertex := piece.local_transform * local_vertex
				if vertex.y > ground_y + contact_band:
					continue
				var key := Vector2i(roundi(vertex.x / sample_pitch),
					roundi(vertex.z / sample_pitch))
				keys[key] = true
	var ordered: Array = keys.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for key: Vector2i in ordered:
		out.append(Vector2(key) * sample_pitch)
	return out

static func relative_transform(node: Node3D, root: Node) -> Transform3D:
	var out := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != root:
		var node_3d := cursor as Node3D
		if node_3d != null:
			out = node_3d.transform * out
		cursor = cursor.get_parent()
	return out

static func _collect_mesh_instances(node: Node,
		out: Array[MeshInstance3D]) -> void:
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh != null:
		out.append(instance)
	for child: Node in node.get_children():
		_collect_mesh_instances(child, out)

static func _material_group(groups: Array[Dictionary],
		material: Material) -> int:
	for index in groups.size():
		if groups[index].material == material:
			return index
	return -1

static func _projection_interval(bounds: AABB, axis: Vector3) -> Vector2:
	var minimum := INF
	var maximum := -INF
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			for z in [bounds.position.z, bounds.end.z]:
				var projection := Vector3(x, y, z).dot(axis)
				minimum = minf(minimum, projection)
				maximum = maxf(maximum, projection)
	return Vector2(minimum, maximum)
