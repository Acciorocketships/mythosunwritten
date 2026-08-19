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


static func mirror_axis(source: ArrayMesh, axis: int) -> ArrayMesh:
	## Bake one handed facade variant without ever putting a negative-scale
	## transform into the runtime construction graph. Positions, normals, and
	## tangents are reflected, then every triangle winding is reversed so the
	## mirrored asset keeps the source asset's outward faces and back-face cull.
	## UVs deliberately remain unchanged: the texture follows the reflected
	## joinery instead of becoming a second, unrelated material treatment.
	if source == null or axis < Vector3.AXIS_X or axis > Vector3.AXIS_Z \
			or source.get_blend_shape_count() > 0:
		return null
	var mirrored := ArrayMesh.new()
	for surface_index in source.get_surface_count():
		if source.surface_get_primitive_type(surface_index) \
				!= Mesh.PRIMITIVE_TRIANGLES:
			return null
		var arrays := source.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if vertices.is_empty() or vertices.size() % 3 != 0 \
				and (not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array \
				or (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty()):
			return null
		for vertex_index in vertices.size():
			var vertex := vertices[vertex_index]
			vertex[axis] = -vertex[axis]
			vertices[vertex_index] = vertex
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
			for normal_index in normals.size():
				var normal := normals[normal_index]
				normal[axis] = -normal[axis]
				normals[normal_index] = normal
			arrays[Mesh.ARRAY_NORMAL] = normals
		if arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
			var tangents := arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
			if tangents.size() != vertices.size() * 4:
				return null
			for tangent_index in vertices.size():
				var component := tangent_index * 4 + axis
				tangents[component] = -tangents[component]
				# Reflection reverses tangent-space handedness.
				tangents[tangent_index * 4 + 3] = \
					-tangents[tangent_index * 4 + 3]
			arrays[Mesh.ARRAY_TANGENT] = tangents
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array \
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array \
			else PackedInt32Array()
		if indices.is_empty():
			indices.resize(vertices.size())
			for index in vertices.size():
				indices[index] = index
		if indices.size() % 3 != 0:
			return null
		for triangle_index in range(0, indices.size(), 3):
			var second := indices[triangle_index + 1]
			indices[triangle_index + 1] = indices[triangle_index + 2]
			indices[triangle_index + 2] = second
		arrays[Mesh.ARRAY_INDEX] = indices
		mirrored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var output_index := mirrored.get_surface_count() - 1
		mirrored.surface_set_material(output_index,
			source.surface_get_material(surface_index))
		mirrored.surface_set_name(output_index,
			source.surface_get_name(surface_index))
	return mirrored if mirrored.get_surface_count() > 0 else null


static func clip_axis_range(source: ArrayMesh, axis: int, minimum: float,
		maximum: float) -> ArrayMesh:
	## Clip a static triangle mesh to one finite axis interval while retaining
	## every source surface/material and interpolating the ordinary authored
	## vertex channels. The cut deliberately remains open: this operation exists
	## for semantic party seams where another measured piece closes the same
	## plane. Inventing a cap would add a visible wall that the source asset never
	## authored.
	if source == null or axis < Vector3.AXIS_X or axis > Vector3.AXIS_Z \
			or not is_finite(minimum) or not is_finite(maximum) \
			or maximum <= minimum or source.get_blend_shape_count() > 0:
		return null
	var clipped := ArrayMesh.new()
	for surface_index in source.get_surface_count():
		if source.surface_get_primitive_type(surface_index) \
				!= Mesh.PRIMITIVE_TRIANGLES:
			return null
		var arrays := source.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		if vertices.is_empty():
			continue
		var emitted: Array[Dictionary] = []
		var triangle_count := indices.size() / 3 \
			if not indices.is_empty() else vertices.size() / 3
		for triangle_index in triangle_count:
			var polygon: Array[Dictionary] = []
			for corner in 3:
				var stream_index := triangle_index * 3 + corner
				var vertex_index := indices[stream_index] \
					if not indices.is_empty() else stream_index
				polygon.append(_mesh_vertex(arrays, vertex_index))
			polygon = _clip_polygon_axis(polygon, axis, minimum, true)
			polygon = _clip_polygon_axis(polygon, axis, maximum, false)
			for fan_index in range(1, polygon.size() - 1):
				emitted.append(polygon[0])
				emitted.append(polygon[fan_index])
				emitted.append(polygon[fan_index + 1])
		if emitted.is_empty():
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(source.surface_get_material(surface_index))
		for vertex: Dictionary in emitted:
			if bool(vertex.has_normal):
				surface.set_normal(vertex.normal as Vector3)
			if bool(vertex.has_uv):
				surface.set_uv(vertex.uv as Vector2)
			if bool(vertex.has_uv2):
				surface.set_uv2(vertex.uv2 as Vector2)
			if bool(vertex.has_color):
				surface.set_color(vertex.color as Color)
			if bool(vertex.has_tangent):
				var tangent := vertex.tangent as Vector4
				surface.set_tangent(Plane(tangent.x, tangent.y, tangent.z,
					tangent.w))
			surface.add_vertex(vertex.position as Vector3)
		surface.index()
		var committed := surface.commit(clipped)
		if committed == null:
			return null
		clipped.surface_set_name(clipped.get_surface_count() - 1,
			source.surface_get_name(surface_index))
	return clipped if clipped.get_surface_count() > 0 else null


static func _mesh_vertex(arrays: Array, index: int) -> Dictionary:
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array \
		if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array \
		else PackedVector3Array()
	var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array \
		if arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array \
		else PackedVector2Array()
	var uv2s := arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array \
		if arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array \
		else PackedVector2Array()
	var colors := arrays[Mesh.ARRAY_COLOR] as PackedColorArray \
		if arrays[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
	var tangents := arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array \
		if arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array \
		else PackedFloat32Array()
	return {
		"position": (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)[index],
		"normal": normals[index] if normals.size() > index else Vector3.ZERO,
		"uv": uvs[index] if uvs.size() > index else Vector2.ZERO,
		"uv2": uv2s[index] if uv2s.size() > index else Vector2.ZERO,
		"color": colors[index] if colors.size() > index else Color.WHITE,
		"tangent": Vector4(tangents[index * 4], tangents[index * 4 + 1],
			tangents[index * 4 + 2], tangents[index * 4 + 3]) \
			if tangents.size() >= index * 4 + 4 else Vector4.ZERO,
		"has_normal": normals.size() > index,
		"has_uv": uvs.size() > index,
		"has_uv2": uv2s.size() > index,
		"has_color": colors.size() > index,
		"has_tangent": tangents.size() >= index * 4 + 4,
	}


static func _clip_polygon_axis(polygon: Array[Dictionary], axis: int,
		threshold: float, keep_greater: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if polygon.is_empty():
		return out
	var previous := polygon.back() as Dictionary
	var previous_coordinate := (previous.position as Vector3)[axis]
	var previous_inside := previous_coordinate >= threshold - 0.000001 \
		if keep_greater else previous_coordinate <= threshold + 0.000001
	for current: Dictionary in polygon:
		var current_coordinate := (current.position as Vector3)[axis]
		var current_inside := current_coordinate >= threshold - 0.000001 \
			if keep_greater else current_coordinate <= threshold + 0.000001
		if current_inside != previous_inside:
			var denominator := current_coordinate - previous_coordinate
			if absf(denominator) > 0.000001:
				var weight := clampf((threshold - previous_coordinate) \
					/ denominator, 0.0, 1.0)
				out.append(_interpolate_mesh_vertex(previous, current, weight,
					axis, threshold))
		if current_inside:
			out.append(current)
		previous = current
		previous_coordinate = current_coordinate
		previous_inside = current_inside
	return out


static func _interpolate_mesh_vertex(left: Dictionary, right: Dictionary,
		weight: float, axis: int, threshold: float) -> Dictionary:
	var position := (left.position as Vector3).lerp(
		right.position as Vector3, weight)
	position[axis] = threshold
	var normal := (left.normal as Vector3).lerp(
		right.normal as Vector3, weight)
	if normal.length_squared() > 0.000001:
		normal = normal.normalized()
	var tangent := (left.tangent as Vector4).lerp(
		right.tangent as Vector4, weight)
	var tangent_xyz := Vector3(tangent.x, tangent.y, tangent.z)
	if tangent_xyz.length_squared() > 0.000001:
		tangent_xyz = tangent_xyz.normalized()
		tangent = Vector4(tangent_xyz.x, tangent_xyz.y, tangent_xyz.z,
			tangent.w)
	return {
		"position": position,
		"normal": normal,
		"uv": (left.uv as Vector2).lerp(right.uv as Vector2, weight),
		"uv2": (left.uv2 as Vector2).lerp(right.uv2 as Vector2, weight),
		"color": (left.color as Color).lerp(right.color as Color, weight),
		"tangent": tangent,
		"has_normal": bool(left.has_normal) and bool(right.has_normal),
		"has_uv": bool(left.has_uv) and bool(right.has_uv),
		"has_uv2": bool(left.has_uv2) and bool(right.has_uv2),
		"has_color": bool(left.has_color) and bool(right.has_color),
		"has_tangent": bool(left.has_tangent) and bool(right.has_tangent),
	}

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
