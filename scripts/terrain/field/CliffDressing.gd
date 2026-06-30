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
const EDGE := 12.0          # WALL origin sits on the cell boundary so the KayKit wall's rock face
                            # stays in FRONT of the field's own rock face (else the field face
                            # occludes the modeled wall). The field cliff face is at the boundary.
const LIP_EDGE := 11.0      # but the grass LIP origin sits 1 unit inside, so its flat grass-top
                            # ends right AT the boundary and meets the flat field top seam-free
                            # (its bevel laps just over the drop). At the boundary the lip overhangs
                            # the drop and reads as detached from the flat surface behind it (owner).
const EXTRA_WALL_ROWS := 0  # the wall spans exactly the storey drop (cliff top → neighbour
                            # surface). Over-extending hangs the wall BELOW the neighbour's
                            # thin surface, where it sticks out into open air (a visible slab).
const LIP_LIFT := 0.05      # raise the grass lip a hair so it cleanly overlays the field
                            # grass (which now renders to the boundary) instead of z-fighting
const CORNER_LIP_LIFT := 0.10  # corner lips sit above edge lips so they win the small overlap
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
	# Only a CLIFF TOP (flat plateau with a ≥2 drop somewhere) is dressed; its WALL EDGES get a
	# rock wall + grass lip (TerrainSurfaceField._is_wall_edge: a ≥2 drop, or a 1-storey step to
	# another cliff top). 1-storey drops to non-cliff cells are walkable slopes (no lip), so the
	# flat top always backs every lip. A pure slope/flat cell has nothing to dress.
	if not TerrainSurfaceField._is_cliff_top(region, cx, cz) and not TerrainSurfaceField.has_inner_corner(region, cx, cz):
		return
	var s: int = region.storey_at(cx, cz)
	var cliff := {}
	for dir in CARDINALS:
		cliff[dir] = TerrainSurfaceField._is_wall_edge(region, cx, cz, dir)
	var h: float = region.surface_height(cx, cz)
	var cellpos := Vector3(float(cx) * TILE, h, float(cz) * TILE)

	# --- corners FIRST: classify each corner so the straight edges can drop their end pieces where
	# a corner piece will sit (no overlap — owner). ---
	var corner_here := {}   # cdir -> true when a corner piece is placed there
	for cdir in CORNERS:
		var ca := Vector2i(cdir.x, 0)
		var cb := Vector2i(0, cdir.y)
		var cbasis := Basis(Vector3.UP, atan2(float(cdir.x), float(cdir.y)) - PI * 0.25)
		var cpos: Vector3 = cellpos + Vector3(float(cdir.x) * EDGE, 0.0, float(cdir.y) * EDGE)          # wall
		var clip: Vector3 = cellpos + Vector3(float(cdir.x) * LIP_EDGE, 0.0, float(cdir.y) * LIP_EDGE)  # lip (inset)
		var ddrop: int = s - int(region.storey_at(cx + cdir.x, cz + cdir.y))
		if cliff.get(ca, false) and cliff.get(cb, false):
			# Convex (outer) corner where two cliff edges meet.
			var dr: int = maxi(maxi(_drop(region, cx, cz, ca), _drop(region, cx, cz, cb)), ddrop)
			out["outer_lip"].append(Transform3D(cbasis, clip + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
			for k in dr:
				out["outer_wall"].append(Transform3D(cbasis, cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
			corner_here[cdir] = true
		elif TerrainSurfaceField._is_inner_corner(region, cx, cz, cdir):
			# Concave (inner) corner: the diagonal pocket drops but BOTH cardinal arms stay level and
			# wall that pocket. The high corner cell gets the modeled inner-corner piece (even for a
			# 1-storey notch) instead of dipping into it as a slope (owner: "inner corner slope").
			out["inner_lip"].append(Transform3D(cbasis, clip + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
			for k in ddrop:
				out["inner_wall"].append(Transform3D(cbasis, cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
			corner_here[cdir] = true
		elif ddrop >= 2 and (cliff.get(ca, false) or cliff.get(cb, false)):
			# STEP corner: ONE cardinal is a cliff edge and the DIAGONAL drops ≥2 — the cliff turns
			# the corner, exposing the diagonal face. BUT if the wall continues STRAIGHT past this
			# corner (the level-side neighbour walls the same way), the face is already covered and a
			# piece here is a spurious corner lip mid-edge (owner). Only dress a real turn.
			var wc: Vector2i = ca if cliff.get(ca, false) else cb
			var lc: Vector2i = cb if cliff.get(ca, false) else ca
			if not TerrainSurfaceField._is_wall_edge(region, cx + lc.x, cz + lc.y, wc):
				out["outer_lip"].append(Transform3D(cbasis, clip + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
				for k in ddrop:
					out["outer_wall"].append(Transform3D(cbasis, cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
				corner_here[cdir] = true

	# --- straight edges: cover the edge, but DROP the end piece (|offset|==END) on a side where a
	# corner piece already sits, so edge and corner butt together with no overlap. ---
	for dir in CARDINALS:
		if not cliff[dir]:
			continue
		var drop: int = _drop(region, cx, cz, dir)
		var basis := Basis(Vector3.UP, _angle(dir))
		var edge := Vector3(float(dir.x) * EDGE, 0.0, float(dir.y) * EDGE)          # wall: on the boundary
		var lip_edge := Vector3(float(dir.x) * LIP_EDGE, 0.0, float(dir.y) * LIP_EDGE)  # lip: 1 unit inside
		var perp := Vector3(float(dir.y), 0.0, float(dir.x))
		var pdir := Vector2i(dir.y, dir.x)   # perpendicular cell step (which corner each end abuts)
		for off: float in OFFSETS:
			if absf(off) > END - 0.01:
				var corner: Vector2i = dir + (pdir if off > 0.0 else -pdir)
				if corner_here.get(corner, false):
					continue   # the corner piece fills this slot — don't overlap it
			var lip_base: Vector3 = cellpos + lip_edge + perp * off
			var wall_base: Vector3 = cellpos + edge + perp * off
			out["lip"].append(Transform3D(basis, lip_base + Vector3(0.0, LIP_LIFT, 0.0)))
			for k in (drop + EXTRA_WALL_ROWS):
				out["wall"].append(Transform3D(basis, wall_base + Vector3(0.0, -STOREY * float(k + 1), 0.0)))

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
