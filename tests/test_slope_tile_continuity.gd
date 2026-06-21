# Cross-tile slope continuity: adjacent cliff tiles must form a continuous surface
# at their shared boundary (no vertical gap). Catches "the slopes don't line up"
# — where a tile's slope fails to descend to meet its lower neighbour, leaving a
# step/hole instead of a continuous walkable surface.
#
# !!! KNOWN-FAILING (intentional TODO) !!!
# This test currently FAILS. It documents the goal — fully continuous slopes across
# tile boundaries — which the current one-tile-per-cell, one-storey-slope model does
# NOT achieve in diagonal staircases:
#   * ~4u gaps at multi-storey corner VERTICES (4 cells spanning 2 storeys at a
#     point) — a single one-storey tile cannot bridge a 2-storey junction.
#   * ~1.4u gaps along diagonal-staircase EDGES (consecutive corner tiles descend at
#     different offsets).
# A complete fix needs multi-cell slope spanning (slopes authored across >1 tile),
# the architectural change deferred during the stacked-corner work. Keep this test
# as the target; make it green by fixing the geometry, not by weakening the bound.
#
# Method (no physics): instantiate the cliff tiles the heightfield would place over
# a region, then for each shared boundary sample both tiles' top-surface mesh
# vertices near the boundary plane and compare heights. A real gap shows up as a
# pair of boundary points at the same (x,z) whose Y differs (continuous ~ 0).
extends GutTest

const TILE := 24.0
const EPS := 0.25       # vertex within this of the boundary plane counts as "on it"
const XZ_MATCH := 0.4   # two boundary verts at ~same horizontal position
const GAP_TOL := 0.5    # flag gaps bigger than this (storey = 4; continuous ~ 0)
const REGION := 5       # cells from origin to scan (each axis)

var _lib: TerrainModuleLibrary

func before_all() -> void:
	_lib = TerrainModuleLibrary.new()
	add_child_autofree(_lib)
	_lib.init()

func test_adjacent_cliff_tiles_surfaces_are_continuous() -> void:
	var plan := HeightfieldPlan.new(12345, 56.0, 12, "mean")
	var holder := Node3D.new()
	add_child_autofree(holder)

	var tiles := {}
	var recs := {}
	for cz in range(-REGION, REGION + 1):
		for cx in range(-REGION, REGION + 1):
			var rec: Dictionary = HeightfieldInstantiator.placement_for_cell(plan, cx, cz)
			recs[Vector2i(cx, cz)] = rec
			if String(rec["family"]) != "cliff":
				continue
			var node := _spawn(rec, holder)
			if node != null:
				tiles[Vector2i(cx, cz)] = node

	var offenders := []
	for cell in tiles.keys():
		for off in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nb: Vector2i = cell + off
			if not tiles.has(nb):
				continue
			var gap := _boundary_gap(tiles[cell], tiles[nb], cell, off)
			if gap > GAP_TOL:
				offenders.append("%s|%s gap=%.2f (%s -> %s)" % [
					cell, off, gap,
					String(recs[cell]["variant_tag"]), String(recs[nb]["variant_tag"])])

	assert_eq(offenders.size(), 0,
		"%d cliff-tile boundaries have a surface gap > %.1f:\n%s" % [
			offenders.size(), GAP_TOL, "\n".join(PackedStringArray(offenders.slice(0, 15)))])

func _spawn(rec: Dictionary, parent: Node3D) -> Node3D:
	var modules: TerrainModuleList = _lib.get_by_tags(TagList.new([String(rec["variant_tag"])]))
	if modules.is_empty():
		return null
	var template: TerrainModule = _lib.get_random(modules, true)
	var inst: Node3D = template.scene.instantiate()
	inst.transform = Transform3D(
		Basis(Vector3.UP, float(rec["yaw"])),
		Vector3(float(rec["world_x"]), float(rec["origin_y"]), float(rec["world_z"])))
	parent.add_child(inst)
	return inst

func _world_xf(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node3D = node
	while n != root and n != null:
		xf = n.transform * xf
		n = n.get_parent() as Node3D
	return root.transform * xf

func _boundary_verts(tile: Node3D, axis: int, pv: float) -> Array:
	var out := []
	for mi in _mesh_instances(tile):
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var xf: Transform3D = _world_xf(mi, tile)
		for v in verts:
			var w: Vector3 = xf * v
			if absf((w.x if axis == 0 else w.z) - pv) <= EPS:
				out.append(w)
	return out

func _boundary_gap(a: Node3D, b: Node3D, cell: Vector2i, off: Vector2i) -> float:
	var axis := 0 if off.x != 0 else 1
	var pv: float = (float(cell.x) + 0.5) * TILE if axis == 0 else (float(cell.y) + 0.5) * TILE
	var va := _boundary_verts(a, axis, pv)
	var vb := _boundary_verts(b, axis, pv)
	if va.is_empty() or vb.is_empty():
		return 0.0
	var worst := 0.0
	for pa in va:
		var fa: float = pa.z if axis == 0 else pa.x
		var best_d := 999.0
		var best_dy := 0.0
		for pb in vb:
			var d: float = absf(fa - (pb.z if axis == 0 else pb.x))
			if d < best_d:
				best_d = d
				best_dy = absf(pa.y - pb.y)
		if best_d <= XZ_MATCH and best_dy > worst:
			worst = best_dy
	return worst

func _mesh_instances(node: Node) -> Array:
	var out := []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_mesh_instances(c))
	return out
