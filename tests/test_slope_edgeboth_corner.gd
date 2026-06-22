# A convex corner that drops two storeys must get the 2-storey diagonal-ramp
# corner, even when it lives on a variant that ALSO carries an inner-corner notch.
# The only such variant is cliff-inner-corner-edge-both (edges back+right meet at a
# convex BR corner; FL is an inner notch). When that BR corner sits one diagonal
# step above a pit, the old selection (which upgraded only cliff-corner/peninsula/
# island) left it a plain 1-storey corner -> it bottomed out at a -4 ledge with a
# sheer ~4u triangular drop into the -8 pit. This guard pins both the selection and
# the resulting surface continuity.
extends GutTest

const TILE := 24.0

# Heightfield: (0,0) at storey 2 is a cliff-inner-corner-edge-both with back+right
# walls (storey 1), an FL inner notch (storey 1), and a 2-storey BR diagonal drop
# (backright at storey 0). Clamp-stable (each cell <= min cardinal + 1).
static func _storey(cx: int, cz: int) -> int:
	if cx >= 1 and cz >= 1: return 0          # pit (backright quadrant)
	if cz >= 1 and cx <= 0: return 1          # back wall row
	if cx >= 1 and cz <= 0: return 1          # right wall col
	if cx == -1 and cz == -1: return 1        # FL inner notch
	return 2                                   # high plateau (cx<=0, cz<=0)

func _plan() -> HeightfieldPlan:
	var plan := HeightfieldPlan.new(0)
	plan.set_raw_height_override(func(cx, cz): return float(_storey(cx, cz)) * HeightfieldPlan.STOREY_HEIGHT)
	return plan

func test_edge_both_classifies_and_drops_two_storeys() -> void:
	var plan := _plan()
	# Sanity: the field really is the edge-both shape with a 2-storey BR diagonal.
	assert_eq(plan.storey_at(0, 0), 2, "center storey")
	assert_eq(plan.storey_at(1, 1), 0, "backright pit is 2 storeys down")
	assert_eq(plan.storey_at(0, 1), 1, "back wall 1 down")
	assert_eq(plan.storey_at(1, 0), 1, "right wall 1 down")
	var rec: Dictionary = HeightfieldInstantiator.placement_for_cell(plan, 0, 0)
	assert_eq(String(rec["family"]), "cliff")
	# The base classification is the edge-both variant ...
	var understacks: Array = rec["understacks"]
	var deep := 0
	for u in understacks:
		if not bool(u["is_level"]):
			deep += 1
	assert_eq(deep, 1, "exactly one 2-storey (cliff) diagonal at the BR corner")
	# ... and because that convex corner drops two storeys, the selected variant
	# must be the stacked (ramp) variant, not the plain edge-both tile.
	assert_string_contains(String(rec["variant_tag"]), "stacked",
		"BR convex corner drops 2 storeys -> must use the ramp variant, got '%s'" % String(rec["variant_tag"]))

func test_edge_both_corner_surface_is_continuous() -> void:
	var lib := TerrainModuleLibrary.new()
	add_child_autofree(lib)
	lib.init()
	var plan := _plan()
	var holder := Node3D.new()
	add_child_autofree(holder)
	for cz in range(-2, 3):
		for cx in range(-2, 3):
			var rec: Dictionary = HeightfieldInstantiator.placement_for_cell(plan, cx, cz)
			if String(rec["family"]) == "ground":
				continue
			HeightfieldInstantiator.spawn_placement(rec, lib, holder)
	# Scan the surface around the BR corner of cell (0,0): the shared corner with
	# the pit is at world (+12, +12). A continuous ramp descends there with no jump.
	var buckets := _gather(holder)
	var offenders := 0
	var worst := 0.0
	var x := 0.0
	while x <= 22.0:
		var z := 0.0
		while z <= 22.0:
			var h := _surface_h(buckets, x, z)
			if h > -1e8:
				for d in [Vector2(1, 0), Vector2(0, 1)]:
					var h2 := _surface_h(buckets, x + d.x, z + d.y)
					if h2 > -1e8 and absf(h2 - h) > 1.5:
						offenders += 1
						worst = maxf(worst, absf(h2 - h))
			z += 1.0
		x += 1.0
	assert_eq(offenders, 0, "BR corner surface has %d discontinuities (worst %.2f)" % [offenders, worst])

# --- triangle-accurate top-surface sampler (shared shape with test_diag_seams) ---
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
			var idx := PackedInt32Array()
			if idx_v == null or (idx_v as PackedInt32Array).is_empty():
				for i in range(verts.size()):
					idx.append(i)
			else:
				idx = idx_v
			for t in range(0, idx.size() - 2, 3):
				var a: Vector3 = xf * verts[idx[t]]
				var b: Vector3 = xf * verts[idx[t + 1]]
				var c: Vector3 = xf * verts[idx[t + 2]]
				var key := Vector2i(int(round(((a.x + b.x + c.x) / 3.0) / TILE)), int(round(((a.z + b.z + c.z) / 3.0) / TILE)))
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append([a, b, c])
	return buckets

func _tri_h(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	var det := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(det) < 1e-9:
		return -INF
	var l1 := ((b.z - c.z) * (p.x - c.x) + (c.x - b.x) * (p.y - c.z)) / det
	var l2 := ((c.z - a.z) * (p.x - c.x) + (a.x - c.x) * (p.y - c.z)) / det
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
