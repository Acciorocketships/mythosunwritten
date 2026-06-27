# scripts/terrain/field/CliffDressing.gd
# Hangs real KayKit cliff pieces (rock wall slabs + beveled grass lip + inner/outer
# corner pieces) on the field mesh's cliff edges. The field mesh stays the walkable base
# + collision; these are visual only, batched into one MultiMesh per piece type per chunk.
#
# `compute()` returns the placement DATA (plain Transform3D arrays) so it is unit-testable
# in headless mode, where MultiMesh.get_instance_transform does not read back. `build()`
# turns that data into MultiMeshInstance3D nodes. Placement reference:
# terrain/scenes/cliff/CliffSide.tscn and CliffCorner.tscn.
class_name CliffDressing
extends RefCounted

const SCENES := {
	"wall": "res://terrain/gltf/hill/hill_cliff_tall_h_side_color_12.tscn",
	"lip": "res://terrain/gltf/hill/hill_top_h_side_color_12.tscn",
	"outer_wall": "res://terrain/gltf/hill/hill_cliff_tall_i_outer_corner_color_12.tscn",
	"outer_lip": "res://terrain/gltf/hill/hill_top_i_outer_corner_color_12.tscn",
	"inner_wall": "res://terrain/gltf/hill/hill_cliff_tall_i_inner_corner_color_12.tscn",
	"inner_lip": "res://terrain/gltf/hill/hill_top_a_inner_corner_color_12.tscn",
}

const TILE := 24.0
const STOREY := 4.0
const EDGE := 12.0          # piece sits at the cell boundary (the low slope reaches it)
const EXTRA_WALL_ROWS := 2  # over-extend the wall below the neighbour so a sloping base
                            # never exposes a gap under the wall
const END := 10.5           # the |offset| of an edge's two end pieces (the corner slots)
const OFFSETS := [-10.5, -7.5, -4.5, -1.5, 1.5, 4.5, 7.5, 10.5]
const CARDINALS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const CORNERS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

static var _pieces: Dictionary = {}   # name -> [mesh, local_transform]

# Returns {wall, lip, outer_wall, outer_lip, inner_wall, inner_lip} -> Array[Transform3D].
static func compute(region, lo_cx: int, lo_cz: int, cells: int) -> Dictionary:
	var out := {"wall": [], "lip": [], "outer_wall": [], "outer_lip": [], "inner_wall": [], "inner_lip": []}
	for cz in range(lo_cz, lo_cz + cells):
		for cx in range(lo_cx, lo_cx + cells):
			_cell(region, cx, cz, out)
	return out

static func _drop(region, cx: int, cz: int, dir: Vector2i) -> int:
	return int(region.storey_at(cx, cz)) - int(region.storey_at(cx + dir.x, cz + dir.y))

static func _cell(region, cx: int, cz: int, out: Dictionary) -> void:
	# Only dress a CLIFF cell (a flat plateau with a ≥2 drop somewhere). Then EVERY drop
	# off it — including a 1-storey edge — is wall, so the cliff takes its whole drop and
	# adjacent slopes simply run into the wall face (no slope climbs to a cliff top).
	if not TerrainSurfaceField._is_cliff_top(region, cx, cz):
		return
	var s: int = region.storey_at(cx, cz)
	var h: float = region.surface_height(cx, cz)
	var cellpos := Vector3(float(cx) * TILE, h, float(cz) * TILE)
	var cliff := {}
	for dir in CARDINALS:
		cliff[dir] = _drop(region, cx, cz, dir) >= 1

	# --- straight edges (with corner/slope-aware extent, issue 5) ---
	for dir in CARDINALS:
		if not cliff[dir]:
			continue
		var drop: int = _drop(region, cx, cz, dir)
		var basis := Basis(Vector3.UP, _angle(dir))
		var edge := Vector3(float(dir.x) * EDGE, 0.0, float(dir.y) * EDGE)
		var perp := Vector3(float(dir.y), 0.0, float(dir.x))
		var pp := Vector2i(dir.y, dir.x)            # +offset perpendicular cardinal
		for off: float in OFFSETS:
			# Drop the end piece when its corner is owned by an outer-corner piece (the
			# perpendicular neighbour is also a cliff) OR the perpendicular neighbour is
			# lower (a slope) — so the wall doesn't run on past where the top is flat.
			if off > END - 0.1:
				if cliff.get(pp, false) or int(region.storey_at(cx + pp.x, cz + pp.y)) < s:
					continue
			if off < -(END - 0.1):
				if cliff.get(-pp, false) or int(region.storey_at(cx - pp.x, cz - pp.y)) < s:
					continue
			var base: Vector3 = cellpos + edge + perp * off
			out["lip"].append(Transform3D(basis, base))
			for k in (drop + EXTRA_WALL_ROWS):
				out["wall"].append(Transform3D(basis, base + Vector3(0.0, -STOREY * float(k + 1), 0.0)))

	# --- corners ---
	for cdir in CORNERS:
		var ca := Vector2i(cdir.x, 0)
		var cb := Vector2i(0, cdir.y)
		var cbasis := Basis(Vector3.UP, atan2(float(cdir.x), float(cdir.y)) - PI * 0.25)
		var cpos: Vector3 = cellpos + Vector3(float(cdir.x) * EDGE, 0.0, float(cdir.y) * EDGE)
		if cliff.get(ca, false) and cliff.get(cb, false):
			# Convex (outer) corner where two cliff edges meet (issue 3).
			var dr: int = maxi(_drop(region, cx, cz, ca), _drop(region, cx, cz, cb))
			out["outer_lip"].append(Transform3D(cbasis, cpos))
			for k in (dr + EXTRA_WALL_ROWS):
				out["outer_wall"].append(Transform3D(cbasis, cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
		elif (not cliff.get(ca, false)) and (not cliff.get(cb, false)):
			# Concave (inner) corner: the diagonal neighbour drops but the cardinals don't (issue 2).
			var ddrop: int = s - int(region.storey_at(cx + cdir.x, cz + cdir.y))
			if ddrop >= 2:
				out["inner_lip"].append(Transform3D(cbasis, cpos))
				for k in (ddrop + EXTRA_WALL_ROWS):
					out["inner_wall"].append(Transform3D(cbasis, cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))

static func build(region, lo_cx: int, lo_cz: int, cells: int) -> Node3D:
	_ensure_loaded()
	var data := compute(region, lo_cx, lo_cz, cells)
	var root := Node3D.new()
	root.name = "Cliffs"
	root.add_child(_multimesh(_pieces["wall"], data["wall"], "Walls"))
	root.add_child(_multimesh(_pieces["lip"], data["lip"], "Lips"))
	root.add_child(_multimesh(_pieces["outer_wall"], data["outer_wall"], "OuterWalls"))
	root.add_child(_multimesh(_pieces["outer_lip"], data["outer_lip"], "OuterLips"))
	root.add_child(_multimesh(_pieces["inner_wall"], data["inner_wall"], "InnerWalls"))
	root.add_child(_multimesh(_pieces["inner_lip"], data["inner_lip"], "InnerLips"))
	return root

# Rock face is native +z. Rotate so it points toward the drop direction `dir`.
static func _angle(dir: Vector2i) -> float:
	return atan2(float(dir.x), float(dir.y))

static func _ensure_loaded() -> void:
	if _pieces.is_empty():
		for key in SCENES:
			_pieces[key] = _piece(SCENES[key])

static func _piece(path: String) -> Array:
	var inst := (load(path) as PackedScene).instantiate()
	var mi := _find_mi(inst)
	var xf := Transform3D.IDENTITY
	var n: Node = mi
	while n != null and n != inst:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var out := [mi.mesh, xf]
	inst.free()
	return out

static func _multimesh(piece: Array, transforms: Array, nm: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = piece[0]
	mm.instance_count = transforms.size()
	var local: Transform3D = piece[1]
	for i in transforms.size():
		var t: Transform3D = transforms[i]
		mm.set_instance_transform(i, t * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	return mmi

static func _find_mi(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D: return n
	for c in n.get_children():
		var r := _find_mi(c)
		if r != null: return r
	return null
