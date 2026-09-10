@tool
class_name EnvironmentBakeGeometry
extends RefCounted

## Geometry-only structural bake operations. Keeping these outside the command
## runner makes material grouping and collision fitting directly testable on
## synthetic meshes without importing or writing an environment pack.

static func pose_meshes(source_root: Node, poses: Array) -> bool:
	## Authored source-space hinges, applied before both visual and collision bake.
	## Resolve every declaration first so an invalid manifest cannot partly pose a source.
	var resolved: Array[Dictionary] = []
	var seen: Dictionary = {}
	for value: Variant in poses:
		if not value is Dictionary: return false
		var pose: Dictionary = value
		var path := String(pose.get("path", ""))
		var pivot_values: Variant = pose.get("pivot", [])
		var yaw := float(pose.get("yaw_degrees", NAN))
		if path.is_empty() or seen.has(path) or not pivot_values is Array \
				or pivot_values.size()!=3 or not is_finite(yaw): return false
		var pivot := Vector3(float(pivot_values[0]),float(pivot_values[1]),float(pivot_values[2]))
		var node := source_root.get_node_or_null(NodePath(path)) as MeshInstance3D
		if node==null or node.mesh==null or not pivot.is_finite(): return false
		var rotation := Basis(Vector3.UP,deg_to_rad(yaw))
		var pose_transform := Transform3D(rotation,pivot-rotation*pivot)
		var parent_transform := relative_transform(node.get_parent() as Node3D,source_root)
		resolved.append({"node":node,"transform":parent_transform.affine_inverse()*pose_transform*relative_transform(node,source_root)})
		seen[path]=true
	for item: Dictionary in resolved:
		(item.node as Node3D).transform=item.transform
	return true


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
			var mesh := source.mesh as Mesh
			var source_surface := int(source.surface)
			var arrays := mesh.surface_get_arrays(source_surface)
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array \
				if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			# append_from does not reference an unindexed source once the
			# destination has indices. Normalize each input so later caps survive.
			if indices.is_empty():
				indices = PackedInt32Array()
				indices.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
				for index in indices.size(): indices[index] = index
				arrays[Mesh.ARRAY_INDEX] = indices
				var indexed := ArrayMesh.new()
				indexed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				mesh = indexed
				source_surface = 0
			surface.append_from(mesh, source_surface, source.transform as Transform3D)
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


static func coplanar_face_bounds(source: ArrayMesh, plane: Plane,
		tolerance: float = 0.00001) -> AABB:
	var bounds := AABB()
	var initialized := false
	var faces := source.get_faces()
	for offset in range(0, faces.size(), 3):
		if absf(plane.distance_to(faces[offset])) > tolerance \
				or absf(plane.distance_to(faces[offset + 1])) > tolerance \
				or absf(plane.distance_to(faces[offset + 2])) > tolerance:
			continue
		for corner in 3:
			if not initialized:
				bounds = AABB(faces[offset + corner], Vector3.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(faces[offset + corner])
	return bounds


static func coplanar_face_surfaces(source: ArrayMesh, plane: Plane,
		tolerance: float = 0.00001) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices.resize(vertices.size())
			for index in vertices.size(): indices[index] = index
		var triangles: Array[Dictionary] = []
		for offset in range(0, indices.size(), 3):
			if absf(plane.distance_to(vertices[indices[offset]])) > tolerance \
					or absf(plane.distance_to(vertices[indices[offset + 1]])) > tolerance \
					or absf(plane.distance_to(vertices[indices[offset + 2]])) > tolerance:
				continue
			for corner in 3:
				var vertex := _mesh_vertex(arrays, indices[offset + corner])
				triangles.append({"position": vertex.position,
					"normal": vertex.normal if vertex.has_normal else Vector3.UP,
					"uv": vertex.uv if vertex.has_uv else Vector2.ZERO,
					"color": vertex.color if vertex.has_color else Color.WHITE})
		if not triangles.is_empty():
			result.append({"material_surface": surface, "triangles": triangles})
	return result


static func omit_coplanar_faces(source: ArrayMesh, plane: Plane,
		tolerance: float = 0.00001) -> ArrayMesh:
	## A declared neighboring construction surface owns this interface. Remove
	## only triangles lying wholly on its plane; retain positions, UVs, normals,
	## materials and every vertical or sloping face. This is an offline asset
	## operation, not a runtime offset or a proximity-based mesh repair.
	if source == null or source.get_blend_shape_count() > 0:
		return null
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return null
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array \
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		if indices.is_empty():
			indices.resize(vertices.size())
			for index in vertices.size():
				indices[index] = index
		var kept := PackedInt32Array()
		for offset in range(0, indices.size(), 3):
			var lies_on_plane := true
			for corner in 3:
				lies_on_plane = lies_on_plane and absf(plane.distance_to(
					vertices[indices[offset + corner]])) <= tolerance
			if not lies_on_plane:
				kept.append_array(indices.slice(offset, offset + 3))
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count() - 1,
			source.surface_get_material(surface))
		result.surface_set_name(result.get_surface_count() - 1,
			source.surface_get_name(surface))
	return result if result.get_surface_count() > 0 else null


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


static func clip_half_space(source: ArrayMesh, plane: Plane) -> ArrayMesh:
	## Use the same attribute-preserving clipper for a non-axis-aligned join.
	## The plane's positive half-space is discarded. Like a party seam, a miter
	## is deliberately uncapped: the perpendicular owner closes that cut.
	if source == null or plane.normal.length_squared() < 0.000001:
		return null
	var normal := plane.normal.normalized()
	var helper := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
	var tangent := helper.cross(normal).normalized()
	var frame := Basis(normal, tangent, normal.cross(tangent)).transposed()
	var aligned := transform_mesh(source, Transform3D(frame, Vector3.ZERO))
	var clipped := clip_axis_range(aligned, Vector3.AXIS_X,
		aligned.get_aabb().position.x - 1.0, plane.d / plane.normal.length())
	return transform_mesh(clipped, Transform3D(frame.transposed(), Vector3.ZERO))


static func transform_mesh(source: ArrayMesh, pose: Transform3D) -> ArrayMesh:
	if source == null:
		return null
	var out := ArrayMesh.new()
	for index in source.get_surface_count():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(source.surface_get_material(index))
		surface.append_from(source, index, pose)
		surface.commit(out)
	return out


static func finish_facade_sides(source: ArrayMesh, side: ArrayMesh,
		thickness: float) -> ArrayMesh:
	# Replace the raw cut ends with the authored wall's actual relief and UVs.
	# Both returned sides live inside the original doorway envelope. The body
	# ends inside their backing, so no old end face competes with the new skin.
	var box := source.get_aabb()
	var stock := side.get_aabb()
	assert(thickness > 0.0 and thickness * 2.0 < box.size.x)
	var assembly := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = clip_axis_range(source, Vector3.AXIS_X,
		box.position.x + thickness * 0.88, box.end.x - thickness * 0.88)
	assembly.add_child(body)
	for sign_value in [-1.0, 1.0]:
		var normal := Vector3.RIGHT * float(sign_value)
		var basis := Basis(Vector3.UP.cross(normal) * box.size.z / stock.size.x,
			Vector3.UP * 3.0 / stock.size.y, normal * thickness / stock.size.z)
		var anchor := Vector3(box.end.x if sign_value > 0.0 else box.position.x,
			0.0, box.get_center().z)
		var piece := MeshInstance3D.new()
		piece.mesh = side
		piece.transform = Transform3D(basis, anchor - basis * Vector3(
			stock.get_center().x, stock.position.y, stock.end.z))
		assembly.add_child(piece)
	var result := merge_pieces(assembly, Transform3D.IDENTITY)
	assembly.free()
	return result


static func closed_facade_miter(source: ArrayMesh, plane: Plane,
		material: Material, uv: Vector2) -> ArrayMesh:
	# A wall end is a solid timber joint. Preserve its outside triangles and
	# close the cut through the stock; an open cut exposes the plaster backing
	# when neighboring panels have different ornament projection depths.
	var clipped := clip_half_space(source, plane)
	var normal := plane.normal.normalized()
	var tangent := Vector3.UP.cross(normal).normalized()
	var origin := normal * plane.d / plane.normal.length()
	var points := PackedVector2Array()
	var vertices := triangle_faces(source)
	for offset in range(0, vertices.size(), 3):
		for edge in 3:
			var a := vertices[offset + edge]
			var b := vertices[offset + (edge + 1) % 3]
			var da := normal.dot(a - origin)
			var db := normal.dot(b - origin)
			if da * db >= 0.0: continue
			var point := a.lerp(b, da / (da - db)) - origin
			points.append(Vector2(point.dot(tangent), point.y))
	if points.size() < 3: return clipped
	var hull := Geometry2D.convex_hull(points)
	if hull.size() < 4: return clipped
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	cap.set_material(material)
	for index in range(1, hull.size() - 2):
		# Godot's front faces use clockwise winding.
		for point: Vector2 in [hull[0], hull[index + 1], hull[index]]:
			cap.set_normal(normal)
			cap.set_uv(uv)
			cap.add_vertex(origin + tangent * point.x + Vector3.UP * point.y)
	var cap_mesh := cap.commit()
	var assembly := Node3D.new()
	for mesh: ArrayMesh in [clipped, cap_mesh]:
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		assembly.add_child(piece)
	var result := merge_pieces(assembly, Transform3D.IDENTITY)
	assembly.free()
	return result


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
