# Controlled-staircase continuity guard. Samples the actual top walkable surface
# (triangle-accurate, no physics) over staircases built from REAL placements
# (main tile + understacks via HeightfieldInstantiator.spawn_placement) and
# asserts there are no vertical discontinuities between adjacent sample points.
# Complements test_slope_tile_continuity (random field, mesh-vertex sampling):
# this one is deterministic, samples the interpolated surface, and pins the
# specific cases this fix targets. Guards the 2-storey diagonal-ramp corner.
extends GutTest

const TILE := 24.0
var _lib: TerrainModuleLibrary

func before_all() -> void:
	_lib = TerrainModuleLibrary.new()
	add_child(_lib)
	_lib.init()

func after_all() -> void:
	_lib.queue_free()

# --- triangle-accurate top-surface sampler ---------------------------------
func _world_xf(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node3D = node
	while n != root and n != null:
		xf = n.transform * xf
		n = n.get_parent() as Node3D
	return xf

func _mesh_instances(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_mesh_instances(c, out)

# Gather all triangles (world space) bucketed by tile-cell of their centroid.
func _gather(holder: Node3D) -> Dictionary:
	var buckets := {}
	var mis := []
	_mesh_instances(holder, mis)
	for mi in mis:
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		var xf: Transform3D = _world_xf(mi, holder)
		for s in range(mesh.get_surface_count()):
			var arr: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			var idx_v = arr[Mesh.ARRAY_INDEX]
			var idx: PackedInt32Array = PackedInt32Array()
			if idx_v == null or (idx_v as PackedInt32Array).is_empty():
				for i in range(verts.size()):
					idx.append(i)  # non-indexed: triangle soup
			else:
				idx = idx_v
			for t in range(0, idx.size() - 2, 3):
				var a: Vector3 = xf * verts[idx[t]]
				var b: Vector3 = xf * verts[idx[t + 1]]
				var c: Vector3 = xf * verts[idx[t + 2]]
				var ckx := int(round(((a.x + b.x + c.x) / 3.0) / TILE))
				var ckz := int(round(((a.z + b.z + c.z) / 3.0) / TILE))
				var key := Vector2i(ckx, ckz)
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append([a, b, c])
	return buckets

func _tri_h(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	# barycentric in XZ; return interpolated Y or -INF if outside
	var x1 := a.x; var z1 := a.z; var x2 := b.x; var z2 := b.z; var x3 := c.x; var z3 := c.z
	var det := (z2 - z3) * (x1 - x3) + (x3 - x2) * (z1 - z3)
	if absf(det) < 1e-9:
		return -INF
	var l1 := ((z2 - z3) * (p.x - x3) + (x3 - x2) * (p.y - z3)) / det
	var l2 := ((z3 - z1) * (p.x - x3) + (x1 - x3) * (p.y - z3)) / det
	var l3 := 1.0 - l1 - l2
	var e := -0.001
	if l1 < e or l2 < e or l3 < e:
		return -INF
	return l1 * a.y + l2 * b.y + l3 * c.y

func _surface_h(buckets: Dictionary, x: float, z: float) -> float:
	var best := -INF
	var cx := int(round(x / TILE))
	var cz := int(round(z / TILE))
	var p := Vector2(x, z)
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var key := Vector2i(cx + dx, cz + dz)
			if not buckets.has(key):
				continue
			for tri in buckets[key]:
				var h := _tri_h(p, tri[0], tri[1], tri[2])
				if h > best:
					best = h
	return best

func _spawn_region(fn: Callable, lo: int, hi: int) -> Node3D:
	var plan := HeightfieldPlan.new(0)
	plan.set_raw_height_override(fn)
	var holder := Node3D.new()
	add_child_autofree(holder)
	for cz in range(lo, hi + 1):
		for cx in range(lo, hi + 1):
			var rec: Dictionary = HeightfieldInstantiator.placement_for_cell(plan, cx, cz)
			if String(rec["family"]) == "ground":
				continue
			HeightfieldInstantiator.spawn_placement(rec, _lib, holder)
	return holder

# Scan the surface; report adjacent-sample vertical jumps far steeper than the
# max legit slope (HEIGHT over the 12u band ~ 0.5/u; a jump > 1.5 over a 1u step
# is a real discontinuity / gap).
func _scan(holder: Node3D, x0: float, x1: float, z0: float, z1: float, title: String) -> int:
	var buckets := _gather(holder)
	var step := 1.0
	var jump_tol := 1.5
	var offenders := []
	var x := x0
	while x <= x1:
		var z := z0
		while z <= z1:
			var h := _surface_h(buckets, x, z)
			if h > -1e8:
				var hx := _surface_h(buckets, x + step, z)
				var hz := _surface_h(buckets, x, z + step)
				if hx > -1e8 and absf(hx - h) > jump_tol:
					offenders.append([absf(hx - h), x, z, "x", h, hx])
				if hz > -1e8 and absf(hz - h) > jump_tol:
					offenders.append([absf(hz - h), x, z, "z", h, hz])
			z += step
		x += step
	offenders.sort_custom(func(a, b): return a[0] > b[0])
	gut.p("===== %s : %d discontinuities (>%.1f over %.0fu) =====" % [title, offenders.size(), jump_tol, step])
	for i in range(min(20, offenders.size())):
		var o = offenders[i]
		var cxa := int(round(float(o[1]) / TILE)); var cza := int(round(float(o[2]) / TILE))
		gut.p("  d=%.2f at (x=%.0f z=%.0f) cell(%d,%d) dir=%s  %.2f -> %.2f" % [
			o[0], o[1], o[2], cxa, cza, o[3], o[4], o[5]])
	return offenders.size()

func test_scan_1storey_diagonal() -> void:
	var holder := _spawn_region(
		func(cx, cz):
			var band: int = cx + cz
			var s := 2
			if band >= 1 and band <= 2:
				s = 1
			elif band >= 3:
				s = 0
			return float(s) * HeightfieldPlan.STOREY_HEIGHT,
		-2, 4)
	assert_eq(_scan(holder, 0.0, 60.0, 0.0, 60.0, "1-STOREY DIAGONAL"), 0)

func test_scan_2storey_pit() -> void:
	var holder := _spawn_region(
		func(cx, cz):
			var s := 1
			if cx <= 0 and cz <= 0:
				s = 2
			elif cx >= 1 and cz >= 1:
				s = 0
			return float(s) * HeightfieldPlan.STOREY_HEIGHT,
		-2, 3)
	# The 2-storey diagonal-ramp corner must descend continuously to the pit floor.
	assert_eq(_scan(holder, -6.0, 30.0, -6.0, 30.0, "2-STOREY PIT (diagonal-ramp corner)"), 0)

func test_scan_random_field_offender() -> void:
	# The lone test_slope_tile_continuity offender (cell (2,3)|+x, a peninsula-
	# stacked-fl beside a cliff-interior). Sampled triangle-accurately on the REAL
	# placement (base fill + stacked variants) to tell a true gap from a vertex-
	# matching artifact in that test.
	var plan := HeightfieldPlan.new(12345, 56.0, 12, "mean")
	var holder := Node3D.new()
	add_child_autofree(holder)
	for cz in range(0, 6):
		for cx in range(0, 5):
			var rec: Dictionary = HeightfieldInstantiator.placement_for_cell(plan, cx, cz)
			if String(rec["family"]) == "ground":
				continue
			HeightfieldInstantiator.spawn_placement(rec, _lib, holder)
	assert_eq(_scan(holder, 50.0, 70.0, 62.0, 82.0, "RANDOM FIELD around (2,3)"), 0)
