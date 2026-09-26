extends RefCounted
## Worker-pure union of authored roof surfaces. Only intersecting pieces are
## converted to triangles; ordinary roofs retain their instanced kit meshes.
## Source UVs/normals/materials survive clipping, and collision uses the exact
## resulting triangles. No renderer resources are loaded on the worker.
const DATA_PATH := "res://terrain/environment/geometry/suntail_roofs.bin"
const EPS := 0.0001

static func roof_volume(wing: Dictionary, kit: BuildingKit) -> Dictionary:
	var r: Rect2i = wing.rect
	var axis := int(wing.axis)
	var u0 := float(r.position[axis] - int(wing.extend_min)) * kit.module_width - 1.0
	var u1 := float(r.end[axis] + int(wing.extend_max)) * kit.module_width + 1.0
	var v0 := float(r.position[1 - axis]) * kit.module_width
	var v1 := float(r.end[1 - axis]) * kit.module_width
	var y := float(wing.eave_band) * kit.band_height()
	var rise := kit.roof_row_rise / kit.module_width
	var planes: Array[Plane] = []
	var u := Vector3.RIGHT if axis == 0 else Vector3.BACK
	var v := Vector3.BACK if axis == 0 else Vector3.RIGHT
	planes.append(Plane(u, u1))
	planes.append(Plane(-u, -u0))
	planes.append(Plane(v, v1 + 0.6))
	planes.append(Plane(-v, -v0 + 0.6))
	planes.append(Plane(Vector3.DOWN, -y + 0.2))
	# The authored roof rises 3 m per 2 m row. Its upper skin is 0.12 m
	# above that datum. This clips buried boards without eating the valley.
	var n := Vector3.UP - v * rise
	planes.append(Plane(n.normalized(), (y - v0 * rise + 0.12) / n.length()))
	n = Vector3.UP + v * rise
	planes.append(Plane(n.normalized(), (y + v1 * rise + 0.12) / n.length()))
	var lo := u * u0 + v * (v0 - 0.6) + Vector3.UP * (y - 0.2)
	var hi := u * u1 + v * (v1 + 0.6) + Vector3.UP * (y + (v1 - v0) * rise * 0.5 + 0.12)
	return {"planes": planes, "bounds": AABB(lo, hi - lo)}

static func box_volume(box: AABB) -> Dictionary:
	return {"bounds": box, "planes": [Plane(Vector3.RIGHT, box.end.x),
		Plane(Vector3.LEFT, -box.position.x), Plane(Vector3.UP, box.end.y),
		Plane(Vector3.DOWN, -box.position.y), Plane(Vector3.BACK, box.end.z),
		Plane(Vector3.FORWARD, -box.position.z)]}

static func append(placements: Array[Dictionary], roofs: Array[Dictionary],
		walls: Array[Dictionary], kit: BuildingKit, map: Transform3D,
		payload: EnvironmentInstancePayload) -> Dictionary:
	var data: Dictionary = FileAccess.open(DATA_PATH, FileAccess.READ).get_var()
	var volumes: Array[Dictionary] = []
	for roof: Dictionary in roofs: volumes.append(roof_volume(roof, kit))
	var clipped := 0
	var removed := 0
	for placement: Dictionary in placements:
		var roof_index := int(placement.get("roof_index", -1))
		if roof_index < 0 or not data.has(placement.asset_id):
			BuildingKitAssembler.append_to_payload([placement], map, payload)
			continue
		var transform: Transform3D = placement.transform
		var surfaces: Array = data[placement.asset_id]
		var bounds := AABB()
		var first := true
		for surface: Dictionary in surfaces:
			for v: Vector3 in surface.vertices:
				var p := transform * v
				bounds = AABB(p, Vector3.ZERO) if first else bounds.expand(p)
				first = false
		var cutters: Array[Dictionary] = []
		for i in volumes.size():
			if i != roof_index and bounds.intersects(volumes[i].bounds): cutters.append(volumes[i])
		for wall: Dictionary in walls:
			if wall.bounds.end.y > float(roofs[roof_index].eave_band) * kit.band_height() + 0.2 and bounds.intersects(wall.bounds): cutters.append(wall)
		if cutters.is_empty():
			BuildingKitAssembler.append_to_payload([placement], map, payload)
			continue
		var results: Array[Dictionary] = []
		var changed := false
		for surface: Dictionary in surfaces:
			var mesh := trim_surface(surface, transform, cutters)
			results.append(mesh)
			changed = changed or bool(mesh.changed)
		if not changed:
			BuildingKitAssembler.append_to_payload([placement], map, payload)
			continue
		clipped += 1
		for surface_index in surfaces.size():
			var surface: Dictionary = surfaces[surface_index]
			var mesh: Dictionary = results[surface_index]
			if mesh.vertices.is_empty():
				removed += 1
				continue
			var normal_map := map.basis.inverse().transposed()
			for i in mesh.vertices.size():
				mesh.vertices[i] = map * mesh.vertices[i]
				mesh.normals[i] = (normal_map * mesh.normals[i]).normalized()
			mesh.tangents = _tangents(mesh)
			for index: int in mesh.indices: mesh.collision_faces.append(mesh.vertices[index])
			mesh.stable_id = StringName("%s.union.%d.%d" % [placement.stable_id, surface.piece, surface.surface])
			mesh.anchor = map * transform.origin
			mesh.material_asset_id = placement.asset_id
			mesh.material_piece = surface.piece
			mesh.material_surface = surface.surface
			payload.add_surface_mesh(mesh)
	return {"clipped": clipped, "removed": removed}

static func trim_surface(surface: Dictionary, transform: Transform3D,
		cutters: Array[Dictionary]) -> Dictionary:
	var out := {"vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"uvs": PackedVector2Array(), "indices": PackedInt32Array(),
		"collision_faces": PackedVector3Array(), "changed": false}
	var normal_map := transform.basis.inverse().transposed()
	var ids: PackedInt32Array = surface.indices
	for t in range(0, ids.size(), 3):
		var polygon: Array = []
		for k in 3:
			var i := ids[t + k]
			polygon.append({"p": transform * surface.vertices[i],
				"n": (normal_map * surface.normals[i]).normalized(), "uv": surface.uvs[i]})
		var pieces: Array = [polygon]
		for cutter: Dictionary in cutters:
			var remaining: Array = []
			for piece: Array in pieces:
				var fragments := subtract(piece, cutter.planes)
				if fragments.size() != 1 or not is_same(fragments[0], piece): out.changed = true
				remaining.append_array(fragments)
			pieces = remaining
			if pieces.is_empty(): break
		for piece: Array in pieces:
			for k in range(1, piece.size() - 1):
				var triangle: Array = [piece[0], piece[k], piece[k + 1]]
				if (triangle[1].p - triangle[0].p).cross(triangle[2].p - triangle[0].p).length_squared() < 1e-12: continue
				for vertex: Dictionary in triangle:
					out.indices.append(out.vertices.size())
					out.vertices.append(vertex.p)
					out.normals.append(vertex.n)
					out.uvs.append(vertex.uv)
	return out

## Disjoint outside fragments of a polygon minus one convex volume.
static func subtract(polygon: Array, planes: Array) -> Array:
	for plane: Plane in planes:
		var entirely_outside := true
		for vertex: Dictionary in polygon:
			if plane.distance_to(vertex.p) < -EPS: entirely_outside = false
		if entirely_outside: return [polygon]
	var outside: Array = []
	var inside := polygon
	for plane: Plane in planes:
		var keep := split(inside, plane, false)
		if keep.size() >= 3: outside.append(keep)
		inside = split(inside, plane, true)
		if inside.size() < 3: break
	return outside

static func split(polygon: Array, plane: Plane, negative: bool) -> Array:
	var out: Array = []
	if polygon.is_empty(): return out
	var previous: Dictionary = polygon.back()
	var pd := plane.distance_to(previous.p)
	for current: Dictionary in polygon:
		var cd := plane.distance_to(current.p)
		var pin := pd <= 0.0 if negative else pd >= 0.0
		var cin := cd <= 0.0 if negative else cd >= 0.0
		if pin != cin:
			var t := pd / (pd - cd)
			out.append({"p": previous.p.lerp(current.p, t),
				"n": previous.n.lerp(current.n, t).normalized(), "uv": previous.uv.lerp(current.uv, t)})
		if cin: out.append(current)
		previous = current
		pd = cd
	return out


## Reconstruct UV tangents after clipping/affine mapping so normal-mapped wood
## retains its board detail. The output is deindexed, so each corner has the
## exact tangent of its source UV triangle, orthogonalized to its smooth normal.
static func _tangents(mesh: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(mesh.vertices.size() * 4)
	for i in range(0, mesh.indices.size(), 3):
		var a: int = mesh.indices[i]
		var b: int = mesh.indices[i + 1]
		var c: int = mesh.indices[i + 2]
		var e1: Vector3 = mesh.vertices[b] - mesh.vertices[a]
		var e2: Vector3 = mesh.vertices[c] - mesh.vertices[a]
		var d1: Vector2 = mesh.uvs[b] - mesh.uvs[a]
		var d2: Vector2 = mesh.uvs[c] - mesh.uvs[a]
		var determinant := d1.x * d2.y - d1.y * d2.x
		var tangent := e1
		var bitangent := e2
		if absf(determinant) > 0.0000001:
			tangent = (e1 * d2.y - e2 * d1.y) / determinant
			bitangent = (e2 * d1.x - e1 * d2.x) / determinant
		for index: int in [a, b, c]:
			var normal: Vector3 = mesh.normals[index]
			var t := (tangent - normal * tangent.dot(normal)).normalized()
			if t.length_squared() < 0.5:
				t = normal.cross(Vector3.UP).normalized()
				if t.length_squared() < 0.5: t = normal.cross(Vector3.RIGHT).normalized()
			out[index * 4] = t.x
			out[index * 4 + 1] = t.y
			out[index * 4 + 2] = t.z
			out[index * 4 + 3] = -1.0 if normal.cross(t).dot(bitangent) < 0.0 else 1.0
	return out
