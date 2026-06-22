# tests/test_slope_orientation.gd
# Verifies the assembled variant scenes ramp DOWN toward the correct exposed
# edges/corners (catches a mirrored EDGE_ANGLE/CORNER_ANGLE rotation). Works on
# world-space vertices of the baked component meshes — no rendering needed.
extends GutTest

const BOUND := 12.0   # tile half-width (slope bottom sits at the boundary)
const TOL := 0.06     # plateau flatness tolerance

func _world_verts(scene_path: String) -> PackedVector3Array:
	var inst := (load(scene_path) as PackedScene).instantiate()
	add_child_autofree(inst)
	var out := PackedVector3Array()
	_collect(inst, out)
	return out

func _collect(node: Node, out: PackedVector3Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mi := node as MeshInstance3D
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var gx := mi.global_transform
		for v in verts:
			out.append(gx * v)
	for c in node.get_children():
		_collect(c, out)

func _min_y(verts: PackedVector3Array) -> float:
	var m := 1.0
	for v in verts:
		m = minf(m, v.y)
	return m

func test_all_geometry_within_band() -> void:
	# Every vertex of every variant stays within the [-4, 0] height band.
	for n in ["CliffSide", "CliffIsland", "CliffInCorner", "CliffInCornerEdgeBoth"]:
		var verts := _world_verts("res://terrain/scenes/slope/%s.tscn" % n)
		assert_gt(verts.size(), 0, n)
		for v in verts:
			assert_between(v.y, -4.05, 0.05, "%s vertex out of band" % n)

func test_side_dips_only_at_front() -> void:
	var verts := _world_verts("res://terrain/scenes/slope/CliffSide.tscn")
	assert_almost_eq(_min_y(verts), -4.0, 0.2)  # slope reaches the bottom
	# All dipping verts must be in the FRONT half (z < 0); the slope faces front.
	# (50% band: front cells span z in [-12, 0], so low verts reach up toward z=0.)
	for v in verts:
		if v.y < -0.5:
			assert_lt(v.z, 0.0, "CliffSide low vertex not at front")
	# Everything behind the front cells (z >= 0) is flat plateau (50% band).
	for v in verts:
		if v.z >= 0.1:
			assert_almost_eq(v.y, 0.0, TOL, "CliffSide back not flat")

func test_right_edge_ramps_toward_right() -> void:
	# CliffInCornerEdge2 slopes the RIGHT edge (+x) and has an inner corner at FL.
	# Verifies the +x rotation: a dip exists at the right boundary, and the only
	# left-side dip is the FL inner corner (front-left), not a mirrored right edge.
	var verts := _world_verts("res://terrain/scenes/slope/CliffInCornerEdge2.tscn")
	assert_almost_eq(_min_y(verts), -4.0, 0.2)
	var right_low := false
	for v in verts:
		if v.y < -3.0 and v.x > 6.0:
			right_low = true
	assert_true(right_low, "right edge must ramp down toward +x")
	# Any dip on the left half must be the FL inner corner (front, z<0).
	for v in verts:
		if v.y < -1.0 and v.x < -6.0:
			assert_lt(v.z, 0.0, "unexpected left-side dip away from FL inner corner")

func test_island_dips_on_all_four_edges() -> void:
	var verts := _world_verts("res://terrain/scenes/slope/CliffIsland.tscn")
	var front := false
	var back := false
	var left := false
	var right := false
	for v in verts:
		if v.y < -3.0:
			if v.z < -6.0: front = true
			if v.z > 6.0: back = true
			if v.x < -6.0: left = true
			if v.x > 6.0: right = true
	assert_true(front and back and left and right, "island must drop on all 4 edges")

func test_inner_corner_dips_at_fl_exterior() -> void:
	# CliffInCorner: concave notch only near the FL exterior corner (-12,-12).
	var verts := _world_verts("res://terrain/scenes/slope/CliffInCorner.tscn")
	assert_almost_eq(_min_y(verts), -4.0, 0.3)
	for v in verts:
		if v.y < -1.0:
			assert_lt(v.x, 0.0, "inner-corner dip not on left side")
			assert_lt(v.z, 0.0, "inner-corner dip not on front side")
