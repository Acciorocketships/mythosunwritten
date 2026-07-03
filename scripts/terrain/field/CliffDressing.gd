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
const PLACE := 10.5         # wall/lip/corner node origin — the OLD-TILE spacing (git 0bcc47ea
                            # CliffCorner.tscn), which is the only grid the 3-unit KayKit modules tile
                            # on: straight pieces at ±1.5..±10.5 along the 10.5 line, the corner piece
                            # AT (±10.5, ±10.5) in the end slot the edges drop. At 11.0 every corner
                            # left a 0.5 slit to the last straight piece and the corner lip protruded
                            # past the ±12 boundary (the owner's gaps + planes sticking out). The rock
                            # face spans PLACE+0.25..PLACE+1.0 (10.75..11.5), recessed inside the cell;
                            # the mesh skirt sits just behind it (TerrainChunkMesher.SKIRT_RECESS).
const PROFILE_SAMPLES := 24 # edge-profile resolution: 25 points, one per unit along the 24u edge.
                            # Wall depth is PER SLOT from the neighbour's actual boundary surface
                            # (TerrainSurfaceField.edge_profile): exactly the storey drop against a
                            # flat neighbour (no jutting slab below its thin surface), deeper where a
                            # slope neighbour dips along the edge (no see-through void — owner).
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

# Rows needed to cover a face of height `dip` (storey-quantised, rounded UP so the wall always
# reaches past the exposed face; the sub-storey overshoot is buried under the neighbour's surface).
static func _rows(dip: float) -> int:
	return int(ceil((dip - 0.01) / STOREY))

# Min of profile over the slot centred at `off` (span off±1.5; profile points are 1u apart).
static func _slot_min(prof: PackedFloat32Array, off: float) -> float:
	var i0 := maxi(0, int(off - 1.5 + 12.0))
	var i1 := mini(prof.size() - 1, int(off + 1.5 + 12.0))
	var m := 1e9
	for i in range(i0, i1 + 1):
		m = minf(m, prof[i])
	return m

# The neighbour surface at the very corner `cdir` of the cell: min of both arm profiles over
# their corner-end slot — how deep the two arms' walls reach where they meet. The DIAGONAL
# pocket's own deeper band is deliberately excluded: that band is a CONCAVE junction owned by
# the pocket cell's ghost inner corner (an outer piece diving down there reads convex where the
# walls turn concave, and z-fights the inner piece — owner round 4).
static func _corner_min(region, cx: int, cz: int, cdir: Vector2i, prof: Dictionary) -> float:
	var end_off := END if (cdir.x * cdir.y) == 1 else -END   # corner sits at the +pdir end iff x*y==1
	return minf(_slot_min(prof[Vector2i(cdir.x, 0)], end_off), _slot_min(prof[Vector2i(0, cdir.y)], end_off))

# Concave junctions over a POCKET cell — which in diagonal terraces is usually a SLOPE, so this
# must run for EVERY cell, not just flat ones (owner round 4: "no inner corner tile as there
# should be"). Both cardinal arms are HIGHER flat cells whose walls toward this cell meet over
# its corner; an inner piece joins them, spanning from this cell's pinned corner surface up to
# the lower arm's top. The classic rule (diagonal cell with LEVEL arms) is deduped away.
static func _ghost_inner_corners(region, cx: int, cz: int, out: Dictionary) -> void:
	for cdir in CORNERS:
		var ca := Vector2i(cdir.x, 0)
		var cb := Vector2i(0, cdir.y)
		if not TerrainSurfaceField.is_higher_flat(region, cx, cz, ca):
			continue
		if not TerrainSurfaceField.is_higher_flat(region, cx, cz, cb):
			continue
		if TerrainSurfaceField._is_inner_corner(region, cx + cdir.x, cz + cdir.y, Vector2i(-cdir.x, -cdir.y)):
			continue   # the classic case — the diagonal cell emits this piece itself
		var top_ref: float = minf(region.surface_height(cx + ca.x, cz + ca.y), region.surface_height(cx + cb.x, cz + cb.y))
		var px := float(cx) * TILE + float(cdir.x) * TILE * 0.5
		var pz := float(cz) * TILE + float(cdir.y) * TILE * 0.5
		var base_y := TerrainSurfaceField.surface_y_in_cell(region, px, pz, cx, cz)
		if top_ref - base_y <= TerrainSurfaceField.EXPOSE_EPS:
			continue
		var gbasis := Basis(Vector3.UP, atan2(-float(cdir.x), -float(cdir.y)) - PI * 0.25)
		var glip_basis := Basis(Vector3.UP, atan2(-float(cdir.x), -float(cdir.y)) - PI * 0.25 + PI)
		var gpos := Vector3(float(cx) * TILE + float(cdir.x) * (PLACE + 3.0), top_ref, float(cz) * TILE + float(cdir.y) * (PLACE + 3.0))
		out["inner_lip"].append(Transform3D(glip_basis, gpos + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
		for k in _rows(top_ref - base_y):
			out["inner_wall"].append(Transform3D(gbasis, gpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))

# Per-edge exposure of a flat cell: each neighbour's boundary profile plus whether the edge is
# EXPOSED (own edge flat at the top while the neighbour dips below it somewhere). Returns
# [cliff: Dictionary(dir->bool), prof: Dictionary(dir->PackedFloat32Array)].
static func _exposure(region, cx: int, cz: int) -> Array:
	var h: float = region.surface_height(cx, cz)
	var cliff := {}
	var prof := {}
	for dir in CARDINALS:
		prof[dir] = TerrainSurfaceField.edge_profile(region, cx, cz, dir, PROFILE_SAMPLES)
		var exposed := false
		if TerrainSurfaceField.own_edge_flat(region, cx, cz, dir):
			for f in prof[dir]:
				if f < h - TerrainSurfaceField.EXPOSE_EPS:
					exposed = true
					break
		cliff[dir] = exposed
	return [cliff, prof]

# Which corners of flat cell (cx,cz) carry a corner PIECE, and which kind: "outer" (two exposed
# edges meet), "inner" (level arms walling a diagonal pocket), "step" (one exposed edge turning
# into a ≥2-storey diagonal). The SINGLE source of truth for corner pieces: _cell emits from this
# map, and the mesher's sheet clip (TerrainChunkMesher._edge_w) holds its weight ACROSS capped
# corners — the lip line TURNS there rather than ending, so tapering the clip to zero draped a
# steep sheet flap through/behind the cap (owner round 4 "slight gap" + needle sliver).
static func corner_map(region, cx: int, cz: int, cliff: Dictionary, prof: Dictionary) -> Dictionary:
	var s: int = region.storey_at(cx, cz)
	var h: float = region.surface_height(cx, cz)
	var out := {}
	for cdir in CORNERS:
		var ca := Vector2i(cdir.x, 0)
		var cb := Vector2i(0, cdir.y)
		var ddrop: int = s - int(region.storey_at(cx + cdir.x, cz + cdir.y))
		if cliff.get(ca, false) and cliff.get(cb, false):
			# Convex (outer) corner where two exposed edges meet — deep as the face is AT the corner.
			if h - _corner_min(region, cx, cz, cdir, prof) > TerrainSurfaceField.EXPOSE_EPS:
				out[cdir] = "outer"
		elif TerrainSurfaceField._is_inner_corner(region, cx, cz, cdir):
			out[cdir] = "inner"
		elif ddrop >= 2 and (cliff.get(ca, false) or cliff.get(cb, false)):
			# STEP corner: ONE cardinal is an exposed edge and the DIAGONAL drops ≥2 — the cliff turns
			# the corner, exposing the diagonal face. BUT if the wall continues STRAIGHT past this
			# corner (the level-side neighbour exposes the same way), the face is already covered and
			# a piece here is a spurious corner lip mid-edge (owner). Only dress a real turn.
			var wc: Vector2i = ca if cliff.get(ca, false) else cb
			var lc: Vector2i = cb if cliff.get(ca, false) else ca
			if not TerrainSurfaceField.is_exposed_edge(region, cx + lc.x, cz + lc.y, wc):
				out[cdir] = "step"
	return out

# Standalone corner_map for callers that don't already hold the exposure data (the mesher's
# sheet clip). Empty for non-flat cells (they carry no dressing).
static func corner_flags(region, cx: int, cz: int) -> Dictionary:
	if not TerrainSurfaceField.is_flat_cell(region, cx, cz):
		return {}
	var e := _exposure(region, cx, cz)
	return corner_map(region, cx, cz, e[0], e[1])

static func _cell(region, cx: int, cz: int, out: Dictionary) -> void:
	# Ghost inner corners first: they belong to pocket cells of ANY type (see above).
	_ghost_inner_corners(region, cx, cz, out)
	# Only a FLAT-rendered cell (cliff top / inner-corner top) is dressed further. Its EXPOSED
	# edges get a rock wall + grass lip: any edge where the neighbour's boundary surface falls
	# below this flat top — a storey drop, or a SAME-storey slope neighbour descending along the
	# edge (the owner's "cliff next to a slope": the face must wrap around to the slope-facing
	# side). A pure slope/flat cell has nothing else to dress.
	if not TerrainSurfaceField.is_flat_cell(region, cx, cz):
		return
	var h: float = region.surface_height(cx, cz)
	var e := _exposure(region, cx, cz)
	var cliff: Dictionary = e[0]
	var prof: Dictionary = e[1]
	var cellpos := Vector3(float(cx) * TILE, h, float(cz) * TILE)

	# --- corners FIRST: every wall/lip node sits at PLACE (±10.5,±10.5) where the two edges meet —
	# like the old CliffCorner tile. The outer-corner WALL bridges the two edge walls. The inner-corner
	# LIP is rotated 180° from the inner WALL (the GLTF lip faces the opposite diagonal). `corner_here`
	# records which corners get a piece, so the straight edges drop their end slot there (no overlap). ---
	var corner_here := corner_map(region, cx, cz, cliff, prof)
	for cdir in corner_here:
		var cbasis := Basis(Vector3.UP, atan2(float(cdir.x), float(cdir.y)) - PI * 0.25)
		var cpos: Vector3 = cellpos + Vector3(float(cdir.x) * PLACE, 0.0, float(cdir.y) * PLACE)
		var px := float(cx) * TILE + float(cdir.x) * TILE * 0.5
		var pz := float(cz) * TILE + float(cdir.y) * TILE * 0.5
		match corner_here[cdir]:
			"outer":
				var cmin := _corner_min(region, cx, cz, cdir, prof)
				out["outer_lip"].append(Transform3D(cbasis, cpos + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
				for k in _rows(h - cmin):
					out["outer_wall"].append(Transform3D(cbasis, cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
			"inner":
				# Concave (inner) corner: the diagonal pocket drops but BOTH cardinal arms stay level
				# and wall that pocket. The modeled inner piece spans it (even a 1-storey notch). The
				# inner LIP faces the opposite diagonal from the inner WALL: +180° (owner's bug).
				var lip_basis := Basis(Vector3.UP, atan2(float(cdir.x), float(cdir.y)) - PI * 0.25 + PI)
				var pocket_y := TerrainSurfaceField.surface_y_in_cell(region, px, pz, cx + cdir.x, cz + cdir.y)
				out["inner_lip"].append(Transform3D(lip_basis, cpos + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
				for k in _rows(h - pocket_y):
					out["inner_wall"].append(Transform3D(cbasis, cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
			"step":
				var diag_y := TerrainSurfaceField.surface_y_in_cell(region, px, pz, cx + cdir.x, cz + cdir.y)
				out["outer_lip"].append(Transform3D(cbasis, cpos + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
				for k in _rows(h - diag_y):
					out["outer_wall"].append(Transform3D(cbasis, cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
	# (terraced-pocket "ghost" inner corners are handled by _ghost_inner_corners above,
	# which runs for every cell — the pocket is often a slope, not a flat cell)

	# --- straight edges: at PLACE, but DROP the end slot (|offset|==END) on a side where a corner
	# piece sits, so edge and corner butt together with no overlap (owner: corner edges must not
	# overlap). Wall + lip share the same in-plane origin. Each slot is dressed only where the
	# neighbour has actually dipped below the top (no lip spam on the flush part of a slope-facing
	# edge), with wall rows reaching the slot's LOWEST neighbour surface. ---
	for dir in CARDINALS:
		if not cliff[dir]:
			continue
		var basis := Basis(Vector3.UP, _angle(dir))
		var edge := Vector3(float(dir.x) * PLACE, 0.0, float(dir.y) * PLACE)
		var perp := Vector3(float(dir.y), 0.0, float(dir.x))
		var pdir := Vector2i(dir.y, dir.x)   # perpendicular step → which corner each end abuts
		for off: float in OFFSETS:
			if absf(off) > END - 0.01:
				var corner: Vector2i = dir + (pdir if off > 0.0 else -pdir)
				if corner_here.has(corner):
					continue   # the corner piece fills this slot — don't overlap it
			var dip: float = h - _slot_min(prof[dir], off)
			if dip < TerrainSurfaceField.EXPOSE_EPS:
				continue   # neighbour flush with the top here — nothing to cover
			var base: Vector3 = cellpos + edge + perp * off
			out["lip"].append(Transform3D(basis, base + Vector3(0.0, LIP_LIFT, 0.0)))
			for k in _rows(dip):
				out["wall"].append(Transform3D(basis, base + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
		# Owner round 2+3: where this wall line runs into a HIGHER flat neighbour, cap the run
		# with an OUTER CORNER piece one module INTO that cell — turning into its wall face
		# ("cliff edge lips extending into higher cliffs should end in a corner"). BUT when that
		# neighbour walls the SAME direction (the line continues at the higher level), its own
		# corner piece already owns the junction — emitting anything would z-fight it.
		for sgn in [-1, 1]:
			var p := Vector2i(pdir.x * sgn, pdir.y * sgn)
			if not TerrainSurfaceField.is_higher_flat(region, cx, cz, p):
				continue
			var nb := Vector2i(cx + p.x, cz + p.y)
			if TerrainSurfaceField.is_exposed_edge(region, nb.x, nb.y, dir):
				continue   # the higher cell continues this wall — its corner covers the junction
			var end_dip: float = h - _slot_min(prof[dir], float(sgn) * END)
			if end_dip < TerrainSurfaceField.EXPOSE_EPS:
				continue   # the wall line has already faded out before reaching the junction
			var cdir2 := Vector2i(dir.x + p.x, dir.y + p.y)
			var cbasis2 := Basis(Vector3.UP, atan2(float(cdir2.x), float(cdir2.y)) - PI * 0.25)
			var cpos2: Vector3 = cellpos + edge + perp * (float(sgn) * (END + 3.0))
			out["outer_lip"].append(Transform3D(cbasis2, cpos2 + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
			for k in _rows(end_dip):
				out["outer_wall"].append(Transform3D(cbasis2, cpos2 + Vector3(0.0, -STOREY * float(k + 1), 0.0)))

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
