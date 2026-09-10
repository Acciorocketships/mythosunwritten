class_name FabricSurfaceOwnership
extends RefCounted

## Pure construction of an authored horizontal skin minus the rectangles
## owned by upper floors. No offsets, replacement material, or town admission:
## exposed source triangles retain their exact position and interpolated UVs.
static func uncovered_surface(source: Dictionary, pose: Transform3D,
		floor_rects: Array[Rect2], asset_id: StringName,
		stable_id: StringName) -> Dictionary:
	var result := {"stable_id": stable_id, "anchor": pose.origin,
		"vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"uvs": PackedVector2Array(), "colors": PackedColorArray(),
		"indices": PackedInt32Array(), "collision_faces": PackedVector3Array(),
		"visual_only": true, "material_asset_id": asset_id,
		"material_piece": int(source.get("material_piece", 0)),
		"material_surface": int(source.get("material_surface", 0))}
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var triangles: Array = source.triangles
	for offset in range(0, triangles.size(), 3):
		var triangle: Array[Dictionary] = []
		for corner in 3:
			var vertex: Dictionary = triangles[offset + corner].duplicate()
			vertex.position = pose * (vertex.position as Vector3)
			vertex.normal = (pose.basis * (vertex.normal as Vector3)).normalized()
			triangle.append(vertex)
		var polygons: Array = [triangle]
		for rect: Rect2 in floor_rects:
			var remaining: Array = []
			for polygon: Array[Dictionary] in polygons:
				remaining.append_array(_subtract_rect(polygon, rect))
			polygons = remaining
		for polygon: Array[Dictionary] in polygons:
			for fan in range(1, polygon.size() - 1):
				var a: Vector3 = polygon[0].position
				var b: Vector3 = polygon[fan].position
				var c: Vector3 = polygon[fan + 1].position
				if (b - a).cross(c - a).length_squared() <= 1e-18:
					continue
				for vertex: Dictionary in [polygon[0], polygon[fan], polygon[fan + 1]]:
					indices.append(vertices.size())
					vertices.append(vertex.position)
					normals.append(vertex.normal)
					uvs.append(vertex.uv)
					colors.append(vertex.color)
	result.vertices = vertices
	result.normals = normals
	result.uvs = uvs
	result.colors = colors
	result.indices = indices
	return result


static func _subtract_rect(polygon: Array[Dictionary], rect: Rect2) -> Array:
	## Successive half-spaces partition the exterior without overlapping corner
	## regions. Only the final inside polygon belongs to the floor and is omitted.
	var result: Array = []
	var inside := polygon
	for edge: Array in [[0, rect.position.x, true], [0, rect.end.x, false],
		[2, rect.position.y, true], [2, rect.end.y, false]]:
		var outside := _half_space(inside, int(edge[0]), float(edge[1]), not bool(edge[2]), false)
		if outside.size() >= 3: result.append(outside)
		inside = _half_space(inside, int(edge[0]), float(edge[1]), bool(edge[2]))
		if inside.is_empty(): break
	return result


static func _half_space(polygon: Array[Dictionary], axis: int, boundary: float,
		keep_above: bool, include_boundary: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if polygon.is_empty(): return result
	var previous := polygon[-1]
	var previous_distance := (previous.position as Vector3)[axis] - boundary
	var previous_inside := _inside(previous_distance, keep_above, include_boundary)
	for current: Dictionary in polygon:
		var distance := (current.position as Vector3)[axis] - boundary
		var is_inside := _inside(distance, keep_above, include_boundary)
		if is_inside != previous_inside:
			var weight := previous_distance / (previous_distance - distance)
			result.append({"position": (previous.position as Vector3).lerp(current.position, weight),
				"normal": (previous.normal as Vector3).lerp(current.normal, weight).normalized(),
				"uv": (previous.uv as Vector2).lerp(current.uv, weight),
				"color": (previous.color as Color).lerp(current.color, weight)})
		if is_inside: result.append(current)
		previous = current
		previous_distance = distance
		previous_inside = is_inside
	return result


static func _inside(distance: float, keep_above: bool, include_boundary: bool) -> bool:
	# The owner keeps the boundary. Its complement must be strict: a vertical
	# perimeter polygon can have positive 3D area while lying entirely on it.
	# Quarter-turn transforms can put a shared float32 boundary a fraction
	# of a micrometre on either side. Classify it once without moving vertices.
	if absf(distance) <= 0.000001: return include_boundary
	if keep_above:
		return distance >= 0.0 if include_boundary else distance > 0.0
	return distance <= 0.0 if include_boundary else distance < 0.0
