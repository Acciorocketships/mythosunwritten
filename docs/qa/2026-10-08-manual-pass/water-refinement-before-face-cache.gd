extends RefCounted

## Refine the finished water surface where straight triangles undercut its
## continuous field. Shared edge splits are applied to every incident face;
## doing this before hole closure can turn a small repairable loop into an
## unfillable one. Border edges use only their own midpoint error to decide
## whether to split, so neighbouring chunks make the same decision even
## when their interior triangles need different amounts of refinement.
const HEIGHT_ERROR := 0.08
const MIN_EDGE := 0.5
const MAX_ROUNDS := 4
const WELD_SCALE := 64.0


static func refine(st: Dictionary, sample_level: Callable) -> Dictionary:
	var initial: int = st.idx.size() / 3
	var rounds := 0
	var levels: Dictionary = {}
	var visible: Dictionary = {}
	for iteration in MAX_ROUNDS:
		var edges: Dictionary = {}
		var old: PackedInt32Array = st.idx
		for ti in range(0, old.size(), 3):
			var ids: Array[int] = [old[ti], old[ti + 1], old[ti + 2]]
			# A shared chunk edge must be decided independently of either face.
			for k in 3:
				var a: int = ids[k]
				var b: int = ids[(k + 1) % 3]
				var va: Vector3 = st.verts[a]
				var vb: Vector3 = st.verts[b]
				if not _border_edge(st.rect, va, vb):
					continue
				if (
					not _visible(st, a, levels, visible, sample_level)
					or not _visible(st, b, levels, visible, sample_level)
				):
					continue
				if Vector2(va.x, va.z).distance_to(Vector2(vb.x, vb.z)) <= MIN_EDGE:
					continue
				var mid: Vector3 = (va + vb) * .5
				if _level(Vector2(mid.x, mid.z), levels, sample_level) - mid.y > HEIGHT_ERROR:
					edges[Vector2i(mini(a, b), maxi(a, b))] = -1
			var eligible := true
			for vi: int in ids:
				if not _visible(st, vi, levels, visible, sample_level):
					eligible = false
					break
			if not eligible or not _needs_detail(st, ids, levels, sample_level):
				continue
			for k in 3:
				var a: int = ids[k]
				var b: int = ids[(k + 1) % 3]
				var va: Vector3 = st.verts[a]
				var vb: Vector3 = st.verts[b]
				if (
					not _border_edge(st.rect, va, vb)
					and Vector2(va.x, va.z).distance_to(Vector2(vb.x, vb.z)) > MIN_EDGE
				):
					edges[Vector2i(mini(a, b), maxi(a, b))] = -1
		if edges.is_empty():
			break
		rounds += 1
		for edge: Vector2i in edges:
			var a: Vector3 = st.verts[edge.x]
			var b: Vector3 = st.verts[edge.y]
			var v: Vector3 = (a + b) * .5
			var p := Vector2(v.x, v.z)
			var level := _level(p, levels, sample_level)
			if is_finite(level):
				v.y = level
			edges[edge] = _weld_vert(
				st,
				p,
				v.y,
				(
					(
						Vector3(st.normal_accum[edge.x]).normalized()
						+ Vector3(st.normal_accum[edge.y]).normalized()
					)
					. normalized()
				)
			)
		st.idx = PackedInt32Array()
		for ti in range(0, old.size(), 3):
			var ids: Array[int] = [old[ti], old[ti + 1], old[ti + 2]]
			var polygon: Array[int] = []
			for k in 3:
				var a: int = ids[k]
				var b: int = ids[(k + 1) % 3]
				polygon.append(a)
				var edge := Vector2i(mini(a, b), maxi(a, b))
				if edges.has(edge):
					polygon.append(edges[edge])
			if polygon.size() == 3:
				for vi: int in ids:
					st.idx.append(vi)
				continue
			var centre: Vector3 = (st.verts[ids[0]] + st.verts[ids[1]] + st.verts[ids[2]]) / 3.0
			var p := Vector2(centre.x, centre.z)
			var eligible := true
			for vi: int in ids:
				if not _visible(st, vi, levels, visible, sample_level):
					eligible = false
			var level := _level(p, levels, sample_level)
			if eligible and is_finite(level):
				centre.y = level
			var middle: int = _weld_vert(
				st,
				p,
				centre.y,
				(
					(
						Vector3(st.normal_accum[ids[0]]).normalized()
						+ Vector3(st.normal_accum[ids[1]]).normalized()
						+ Vector3(st.normal_accum[ids[2]]).normalized()
					)
					. normalized()
				)
			)
			for k in polygon.size():
				_emit_tri(st, polygon[k], polygon[(k + 1) % polygon.size()], middle)
	return {"initial_triangles": initial, "final_triangles": st.idx.size() / 3, "rounds": rounds}


static func _needs_detail(
	st: Dictionary, ids: Array[int], levels: Dictionary, sample_level: Callable
) -> bool:
	var a: Vector3 = st.verts[ids[0]]
	var b: Vector3 = st.verts[ids[1]]
	var c: Vector3 = st.verts[ids[2]]
	for v: Vector3 in [(a + b) * .5, (b + c) * .5, (c + a) * .5, (a + b + c) / 3.0]:
		var p := Vector2(v.x, v.z)
		var level := _level(p, levels, sample_level)
		if is_finite(level) and level - v.y > HEIGHT_ERROR:
			return true
	return false


static func _level(p: Vector2, levels: Dictionary, sample_level: Callable) -> float:
	if not levels.has(p):
		levels[p] = sample_level.call(p)
	return levels[p]


static func _visible(
	st: Dictionary, vi: int, levels: Dictionary, visible: Dictionary, sample_level: Callable
) -> bool:
	if not visible.has(vi):
		var v: Vector3 = st.verts[vi]
		var level := _level(Vector2(v.x, v.z), levels, sample_level)
		visible[vi] = is_finite(level) and absf(v.y - level) <= .08
	return visible[vi]


static func _border_edge(rect: Rect2, a: Vector3, b: Vector3) -> bool:
	return (
		(absf(a.x - rect.position.x) < .001 and absf(b.x - rect.position.x) < .001)
		or (absf(a.x - rect.end.x) < .001 and absf(b.x - rect.end.x) < .001)
		or (absf(a.z - rect.position.y) < .001 and absf(b.z - rect.position.y) < .001)
		or (absf(a.z - rect.end.y) < .001 and absf(b.z - rect.end.y) < .001)
	)


static func _weld_vert(st: Dictionary, p: Vector2, y: float, nrm: Vector3) -> int:
	var key := Vector3i(roundi(p.x * WELD_SCALE), roundi(p.y * WELD_SCALE), roundi(y * WELD_SCALE))
	if st.weld.has(key):
		var existing: int = st.weld[key]
		st.normal_accum[existing] += nrm
		return existing
	var vi: int = st.verts.size()
	st.verts.append(Vector3(p.x, y, p.y))
	st.normal_accum.append(nrm)
	st.weld[key] = vi
	return vi


static func _emit_tri(st: Dictionary, a: int, b: int, c: int) -> void:
	if a == b or b == c or c == a:
		return
	var normal: Vector3 = (st.verts[b] - st.verts[a]).cross(st.verts[c] - st.verts[a])
	if normal.length_squared() <= 0.00000001:
		return
	st.idx.append(a)
	st.idx.append(b if normal.y >= 0.0 else c)
	st.idx.append(c if normal.y >= 0.0 else b)
