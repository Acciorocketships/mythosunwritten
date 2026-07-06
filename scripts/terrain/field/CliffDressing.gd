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
const CORNER_LIP_LIFT := 0.05  # EXACTLY LIP_LIFT: corner caps and straight lip modules only
                               # ever BUTT (never overlap coplanar), so any difference shows as
                               # a step at the joint that reads as a slit ("gap next to corner",
                               # owner rounds 5-6 — "can you just make it 0?"). Old tiles: both 0.
const END := 10.5           # the |offset| of an edge's two end pieces (the corner slots)
const OFFSETS := [-10.5, -7.5, -4.5, -1.5, 1.5, 4.5, 7.5, 10.5]
const CARDINALS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const CORNERS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

static var _pieces: Dictionary = {}   # name -> [mesh, local_transform]
static var _shared_mat: Material = null

# THE terrain material: a de-sheened duplicate of the KayKit wall material, shared by every
# terrain surface — dressing pieces (via material_override), the walkable sheet, aprons and
# the rock skirt. One texture/material to retint everything at once (owner round 8); specular
# killed because it lit big flat surfaces a very different colour at some angles (round 7).
static func shared_material() -> Material:
	if _shared_mat != null:
		return _shared_mat
	_ensure_loaded()
	var mat := (_pieces["wall"][0] as Mesh).surface_get_material(0)
	if mat is StandardMaterial3D:
		mat = mat.duplicate()
		mat.roughness = 1.0
		mat.metallic_specular = 0.0
	_shared_mat = mat
	return _shared_mat

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

# What does the GHOST inner corner emit at pocket (cx,cz)'s cdir corner? Both cardinal arms
# must be HIGHER flat cells whose walls toward this cell meet concavely over its corner.
#   1 (full piece) — arms at DIFFERENT storeys still form a true concave: the piece belongs at
#     the LOWER arm's top, rounding its wall into the taller arm's wall face (owner round 10:
#     "missing an inner corner (lip + wall)").
#   2 (seam WALLS only) — the taller arm's wall CONTINUES past the corner across the lower
#     arm's side (the diagonal cell walls the same line). A concave LIP there would notch the
#     continuing walkable edge (owner round 6: "this is an inner corner but it should just be
#     an edge") — but the vertical seam where the two arms' walls meet concavely is otherwise
#     bare SKIRT: a smooth flat column that reads nothing like the sculpted modules (owner
#     round 14: "is this just a smooth curve and not the kaykit inner corner texture?").
#     Inner WALL rows round the seam, kept below every walkable top.
#   0 (nothing) — arms not both higher flat, or the classic case (level arms with the diagonal
#     cell the inner-corner owner), which the diagonal emits itself.
static func _ghost_mode(region, cx: int, cz: int, cdir: Vector2i) -> int:
	var ca := Vector2i(cdir.x, 0)
	var cb := Vector2i(0, cdir.y)
	if not TerrainSurfaceField.is_higher_flat(region, cx, cz, ca):
		return 0
	if not TerrainSurfaceField.is_higher_flat(region, cx, cz, cb):
		return 0
	if TerrainSurfaceField._is_inner_corner(region, cx + cdir.x, cz + cdir.y, Vector2i(-cdir.x, -cdir.y)):
		return 0
	var sa := int(region.storey_at(cx + ca.x, cz + ca.y))
	var sb := int(region.storey_at(cx + cb.x, cz + cb.y))
	# X-JUNCTION guard: when two SAME-storey plateaus touch only at the corner
	# POINT (equal arms, diagonal lower), there is no concave pocket to round,
	# and inner pieces here bridge the gap as floating plates (owner: "two
	# cliff tiles touching just by a corner ... inner corner tiles need to be
	# removed"). ONLY for equal arms: a lower cliff run meeting a higher one
	# (different-storey arms) IS a concave junction and keeps its corner piece
	# (owner: "should be a corner tile") — the sa != sb branch below owns it.
	if sa == sb and int(region.storey_at(cx + cdir.x, cz + cdir.y)) < sa:
		return 0
	# CARVED pockets (water banks): the round-8 "run-merge rows already round
	# the seam" assumption only holds for land runs — on water-carved banks
	# the seam stays a bare notch. Always emit the full corner piece where a
	# lower cliff run meets a higher one over water (owner: "should be a
	# corner tile", twice). Land pockets keep the run-merge behaviour below.
	if sa != sb and region.has_method("is_carved") and region.is_carved(cx, cz):
		# ...unless the DIAGONAL cell is a flat top LEVEL with the lower arm: then
		# it owns the corner classic-style (corner_map "inner"). Emitting from the
		# pocket too would double the piece, and only the diagonal's map entry lets
		# the sheet clip TUCK its corner point — a ghost piece under an untucked
		# sheet is buried in flat grass (owner: "we need to add a corner piece to
		# blend the lower cliff into the upper cliff", pointing at the buried
		# fragment poking through the ground).
		if _diagonal_owns_pocket_corner(region, cx, cz, cdir):
			return 0
		return 1
	if sa != sb:
		var ct := ca if sa > sb else cb   # the taller arm
		var cl := cb if sa > sb else ca   # the lower arm
		if TerrainSurfaceField.is_exposed_edge(region, cx + cdir.x, cz + cdir.y, Vector2i(-ct.x, -ct.y)):
			# The lower arm's run ENDS at this junction. If the diagonal walls across its line
			# too, that run gets an ext_outer cap (lip only — no walls) and the seam stays bare
			# → seam walls. Otherwise the run's ext_straight MERGE rows already round the seam
			# (round 8) — emitting more would double them.
			if TerrainSurfaceField.is_exposed_edge(region, cx + cdir.x, cz + cdir.y, Vector2i(-cl.x, -cl.y)):
				return 2
			return 0
	return 1

# The full-piece predicate — what run-end junction logic means by "an inner corner joins the
# runs here" (_inner_joined): seam-walls-only junctions keep their ext_outer run caps.
static func _ghost_fires(region, cx: int, cz: int, cdir: Vector2i) -> bool:
	return _ghost_mode(region, cx, cz, cdir) == 1

# Concave junctions over a POCKET cell — which in diagonal terraces is usually a SLOPE, so this
# must run for EVERY cell, not just flat ones (owner round 4: "no inner corner tile as there
# should be"). An inner piece joins the two arms' walls, spanning from this cell's pinned
# corner surface up to the LOWER arm's top.
static func _ghost_inner_corners(region, cx: int, cz: int, out: Dictionary) -> void:
	for cdir in CORNERS:
		var ca := Vector2i(cdir.x, 0)
		var cb := Vector2i(0, cdir.y)
		var mode := _ghost_mode(region, cx, cz, cdir)
		if mode == 0:
			continue
		var top_ref: float = minf(region.surface_height(cx + ca.x, cz + ca.y), region.surface_height(cx + cb.x, cz + cb.y))
		var px := float(cx) * TILE + float(cdir.x) * TILE * 0.5
		var pz := float(cz) * TILE + float(cdir.y) * TILE * 0.5
		if mode == 2:
			# seam walls only: stay below the diagonal's walkable top too (a lower diagonal's
			# own corner ghost owns the band above it — the round-10 gouge guard)
			top_ref = minf(top_ref, TerrainSurfaceField.surface_y_in_cell(region, px, pz, cx + cdir.x, cz + cdir.y))
		var base_y := TerrainSurfaceField.surface_y_in_cell(region, px, pz, cx, cz)
		if top_ref - base_y <= TerrainSurfaceField.EXPOSE_EPS:
			continue
		var gbasis := Basis(Vector3.UP, atan2(-float(cdir.x), -float(cdir.y)) - PI * 0.25)
		var glip_basis := Basis(Vector3.UP, atan2(-float(cdir.x), -float(cdir.y)) - PI * 0.25 + PI)
		var gpos := Vector3(float(cx) * TILE + float(cdir.x) * (PLACE + 3.0), top_ref, float(cz) * TILE + float(cdir.y) * (PLACE + 3.0))
		if mode == 1:
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
# into a ≥2-storey diagonal), or a RUN-END JUNCTION where a wall line runs into a HIGHER flat
# neighbour — "ext_straight" (the higher cell doesn't wall this direction: the run continues
# with a straight module into its wall face, owner round 7 "it should just be straight") or
# "abut" (the higher cell walls the SAME direction — a step: its own outer corner owns the
# junction and the run emits nothing, owner rounds 6-7). The SINGLE source of truth for corner
# pieces: _cell emits from this map, and the mesher's sheet clip (TerrainChunkMesher._edge_w)
# holds its weight ACROSS capped corners — the lip line TURNS or CONTINUES there rather than
# ending, so tapering the clip to zero draped a steep sheet flap through/behind the pieces
# (owner round 4 "slight gap"; round 5 "weird glitch" fold).
static func corner_map(region, cx: int, cz: int, cliff: Dictionary, prof: Dictionary) -> Dictionary:
	var s: int = region.storey_at(cx, cz)
	var h: float = region.surface_height(cx, cz)
	var out := {}
	for cdir in CORNERS:
		var ca := Vector2i(cdir.x, 0)
		var cb := Vector2i(0, cdir.y)
		var ddrop: int = s - int(region.storey_at(cx + cdir.x, cz + cdir.y))
		if cliff.get(ca, false) and cliff.get(cb, false):
			# Convex (outer) corner where two exposed edges meet — BOTH arms must actually dip
			# AT this corner. The cliff flags are edge-wide: a remote dip elsewhere on an edge
			# (e.g. a level plain neighbour sagging at its far corner) must not turn a straight
			# run's end into a corner piece cutting across the walkable strip (owner round 10:
			# "this is an outer corner lip that should be a normal edge").
			var off := END if (cdir.x * cdir.y) == 1 else -END
			if h - _slot_min(prof[ca], off) > TerrainSurfaceField.EXPOSE_EPS \
					and h - _slot_min(prof[cb], off) > TerrainSurfaceField.EXPOSE_EPS:
				out[cdir] = "outer"
		elif TerrainSurfaceField._is_inner_corner(region, cx, cz, cdir):
			out[cdir] = "inner"
		elif _diagonal_owns_pocket_corner(region, cx + cdir.x, cz + cdir.y, Vector2i(-cdir.x, -cdir.y)):
			# CARVED pocket (water) with unequal higher arms and this cell the
			# level-with-lower-arm diagonal: classic-style ownership. The WALL seam
			# below stays concave (inner rows), but the walkable TOP is a shore lip
			# turning at the junction — a flat inner tab read as "currently a flat
			# plane" (owner) — so the top piece is the convex outer cap wrapping
			# the pocket point. This entry also makes the sheet clip tuck the
			# corner point that buried the piece.
			out[cdir] = "pocket_cap"
		elif ddrop >= 2 and (cliff.get(ca, false) or cliff.get(cb, false)):
			# STEP corner: ONE cardinal is an exposed edge and the DIAGONAL drops ≥2 — the cliff turns
			# the corner, exposing the diagonal face. BUT if the wall continues STRAIGHT past this
			# corner (the level-side neighbour exposes the same way), the face is already covered and
			# a piece here is a spurious corner lip mid-edge (owner). Only dress a real turn.
			var wc: Vector2i = ca if cliff.get(ca, false) else cb
			var lc: Vector2i = cb if cliff.get(ca, false) else ca
			if not TerrainSurfaceField.is_exposed_edge(region, cx + lc.x, cz + lc.y, wc):
				out[cdir] = "step"
		if out.has(cdir):
			continue
		# Run-end junction: exactly one of this corner's edges carries the wall line, and the
		# cell across the OTHER axis is a higher flat cell the line runs into.
		for pair in [[ca, cb], [cb, ca]]:
			var d: Vector2i = pair[0]
			var p: Vector2i = pair[1]
			if not cliff.get(d, false):
				continue
			var pdir := Vector2i(d.y, d.x)
			var sgn := pdir.x * p.x + pdir.y * p.y   # which end of the run this corner is
			var run_ground := _slot_min(prof[d], float(sgn) * END)
			if h - run_ground < TerrainSurfaceField.EXPOSE_EPS:
				continue   # the wall line has already faded out before the junction
			if TerrainSurfaceField.is_higher_flat(region, cx, cz, p):
				# Run-end junctions into a taller cliff (owner rounds 6-9):
				#  - The taller cell walls the SAME direction (their sides are FLUSH — a step):
				#    "the edge should extend all the way to the cliff, and then the corner turns
				#    into the wall" (round 9). The run KEEPS its straight end module and a turned
				#    corner LIP sits one slot INTO the taller cell ("ext_outer") — at the taller
				#    cell's own corner column, whose wall rows already cover it (the lip is proud
				#    of the wall face, no z-fight). Round 8's cap at the run's own end slot
				#    stopped 1.25 short of the taller wall and needed a flat patch (rejected).
				#    EXCEPT when an inner-corner piece (ghost or classic) joins the two runs over
				#    the pocket cell: they "should stay as normal edges so they can connect to
				#    the inner corner piece between them" — plain end modules, no cap ("abut").
				#  - Otherwise the run "goes straight into the wall" (round 7): continue it with a
				#    STRAIGHT module one slot into the taller cell, buried behind its wall face,
				#    plus inner WALL rows merging the two perpendicular faces (round 8).
				if TerrainSurfaceField.is_exposed_edge(region, cx + p.x, cz + p.y, d):
					if _inner_joined(region, cx + d.x, cz + d.y, Vector2i(p.x - d.x, p.y - d.y)):
						out[cdir] = "abut"
					else:
						# Carved (water) flush steps use this same arrangement: the
						# run keeps its straight end module and the turned cap sits
						# one slot into the taller cell, at its corner column — "the
						# corner should go at the very end". (An "outer" cap at the
						# run's own corner slot put the turn one module too early:
						# owner drew the two pieces swapped.) The ext_outer emission
						# adds the cap's wall rows on carved pockets.
						out[cdir] = "ext_outer"
				else:
					out[cdir] = "ext_straight"
				break
			# The plateau continues LEVEL across the run's end, but the DIAGONAL cell is a
			# taller flat walling across the run's line (owner round 10, seed 1408162484): the
			# run dies against its perpendicular wall / corner column. Register the corner so
			# the sheet clip HOLDS (an uncapped end tapers to w=0 and drapes a fold onto the
			# walkable top — the owner's "weird dip") and keep the plain end module ("should
			# be a normal edge"); the pocket cell's ghost inner corner rounds the seam.
			if int(region.storey_at(cx + p.x, cz + p.y)) == s and \
					TerrainSurfaceField.is_higher_flat(region, cx, cz, cdir) and \
					TerrainSurfaceField.is_exposed_edge(region, cx + cdir.x, cz + cdir.y, Vector2i(-p.x, -p.y)):
				out[cdir] = "abut"
				break
	return out

# An inner-corner piece (classic, from the diagonal cell, or a ghost from the pocket cell)
# joins the two runs meeting over pocket (px,pz)'s qdir corner — their end modules butt into
# it, so the runs carry no caps of their own. Mirrors _ghost_inner_corners' fire condition.
static func _inner_joined(region, px: int, pz: int, qdir: Vector2i) -> bool:
	if TerrainSurfaceField._is_inner_corner(region, px + qdir.x, pz + qdir.y, Vector2i(-qdir.x, -qdir.y)):
		return true
	return _ghost_fires(region, px, pz, qdir) or _diagonal_owns_pocket_corner(region, px, pz, qdir)

# A carved unequal-arm pocket corner is owned by its DIAGONAL cell when that diagonal is a
# flat top LEVEL with the lower arm: the piece lives in the diagonal's corner slot (the same
# slot the pocket's ghost would use), so ownership moves into corner_map — the single source
# of truth — and the mesher's inner tuck exposes the piece's front over the pocket point.
# (cx,cz) is the POCKET cell; cdir the corner as seen from the pocket.
static func _diagonal_owns_pocket_corner(region, cx: int, cz: int, cdir: Vector2i) -> bool:
	if not (region.has_method("is_carved") and region.is_carved(cx, cz)):
		return false
	var ca := Vector2i(cdir.x, 0)
	var cb := Vector2i(0, cdir.y)
	if not TerrainSurfaceField.is_higher_flat(region, cx, cz, ca):
		return false
	if not TerrainSurfaceField.is_higher_flat(region, cx, cz, cb):
		return false
	if int(region.storey_at(cx + ca.x, cz + ca.y)) == int(region.storey_at(cx + cb.x, cz + cb.y)):
		return false
	if not TerrainSurfaceField.is_flat_cell(region, cx + cdir.x, cz + cdir.y):
		return false
	var lower_h: float = minf(region.surface_height(cx + ca.x, cz + ca.y),
		region.surface_height(cx + cb.x, cz + cb.y))
	return absf(region.surface_height(cx + cdir.x, cz + cdir.y) - lower_h) < 0.01

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
				# The corner WALL module is 2.5 wide — 0.5 short of its slot at the post side. At
				# a classic convex corner that inset faces air, but a row whose face is BURIED on
				# one arm (the neighbour's grass tops the whole row: flush-step caps, terraced
				# stacks) is a straight stretch of the OTHER arm's wall plane, and the inset there
				# reads as a recessed-skirt slit (owner round 8 spot 3). Such rows use the
				# full-width STRAIGHT module facing the exposed arm, tiling flush to the corner.
				var end_off := END if (cdir.x * cdir.y) == 1 else -END
				var ca := Vector2i(cdir.x, 0)
				var cb := Vector2i(0, cdir.y)
				var ga := _slot_min(prof[ca], end_off)
				var gb := _slot_min(prof[cb], end_off)
				for k in _rows(h - cmin):
					var row_top := h - STOREY * float(k)
					var buried_a: bool = ga >= row_top - TerrainSurfaceField.EXPOSE_EPS
					var buried_b: bool = gb >= row_top - TerrainSurfaceField.EXPOSE_EPS
					var row_pos: Vector3 = cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)
					if buried_a and buried_b:
						continue
					elif buried_a:
						out["wall"].append(Transform3D(Basis(Vector3.UP, _angle(cb)), row_pos))
					elif buried_b:
						out["wall"].append(Transform3D(Basis(Vector3.UP, _angle(ca)), row_pos))
					else:
						out["outer_wall"].append(Transform3D(cbasis, row_pos))
			"inner":
				# Concave (inner) corner: the diagonal pocket drops but BOTH cardinal arms stay level
				# and wall that pocket. The modeled inner piece spans it (even a 1-storey notch). The
				# inner LIP faces the opposite diagonal from the inner WALL: +180° (owner's bug).
				var lip_basis := Basis(Vector3.UP, atan2(float(cdir.x), float(cdir.y)) - PI * 0.25 + PI)
				var pocket_y := TerrainSurfaceField.surface_y_in_cell(region, px, pz, cx + cdir.x, cz + cdir.y)
				out["inner_lip"].append(Transform3D(lip_basis, cpos + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
				for k in _rows(h - pocket_y):
					out["inner_wall"].append(Transform3D(cbasis, cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
			"pocket_cap":
				# Carved-pocket diagonal cap: the wall seam below is CONCAVE (the two
				# arms' walls meet over the water pocket — inner rows round it), but
				# the walkable TOP is a shore lip TURNING at the junction (owner:
				# "should be a corner where the corner is in the lower right" — an
				# inner tab there read as a bare flat plane, and a cap in this cell's
				# own slot floats mid-ground as a raised pad). Like the flush-step's
				# ext_outer cap, the turned lip sits one slot INTO the TALLER arm's
				# cell at THIS cell's height: its lower-arm-facing side rides proud
				# of the taller wall over the water, the taller-arm side stays
				# buried, and the turn wraps the pocket point.
				var pocket_y2 := TerrainSurfaceField.surface_y_in_cell(region, px, pz, cx + cdir.x, cz + cdir.y)
				var sa2 := int(region.storey_at(cx + cdir.x, cz))
				var sb2 := int(region.storey_at(cx, cz + cdir.y))
				var tdir := Vector2i(cdir.x, 0) if sa2 > sb2 else Vector2i(0, cdir.y)
				var tpos: Vector3 = cpos + Vector3(float(tdir.x) * 3.0, 0.0, float(tdir.y) * 3.0)
				# Arc at the POCKET POINT: arms face the water (lower-arm side) and
				# the shore behind — flipping the taller-arm axis. With the arc on
				# the taller side instead, it buries deep in the wall and a bare
				# grey wedge shows at the jog between the shore line and the wall.
				var wdir: Vector2i = cdir - tdir * 2
				var wbasis := Basis(Vector3.UP, atan2(float(wdir.x), float(wdir.y)) - PI * 0.25)
				out["outer_lip"].append(Transform3D(wbasis, tpos + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
				# A straight module in THIS cell's corner slot continues the lower
				# arm's shore line across the 1-slot jog to the cap's turn (the
				# lip line and the taller wall face are offset by the recess —
				# without it a bare notch shows right at the turn).
				out["lip"].append(Transform3D(Basis(Vector3.UP, _angle(tdir)), cpos + Vector3(0.0, LIP_LIFT, 0.0)))
				for k in _rows(h - pocket_y2):
					out["inner_wall"].append(Transform3D(cbasis, cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
			"step":
				var diag_y := TerrainSurfaceField.surface_y_in_cell(region, px, pz, cx + cdir.x, cz + cdir.y)
				out["outer_lip"].append(Transform3D(cbasis, cpos + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
				for k in _rows(h - diag_y):
					out["outer_wall"].append(Transform3D(cbasis, cpos + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
			"ext_outer":
				# Flush-step run end (round 9): the straight edge keeps its end module (the
				# edge loop below emits it — ext kinds don't drop the end slot), and the
				# turned corner LIP sits one slot INTO the taller cell, at the taller cell's
				# own corner column. Its wall rows already cover that column down to the low
				# ground (the per-row straight substitution), so the cap adds no walls. The
				# cap is oriented like the RUN CELL's own corner at cdir (owner round 10:
				# "corner turned the wrong way, it should line up with the edge"): its visible
				# arm starts AT the boundary and continues the run's lip line along the taller
				# column's face; the other arm points INTO the taller cell and stays buried.
				var de: Vector2i = Vector2i(cdir.x, 0) if cliff.get(Vector2i(cdir.x, 0), false) else Vector2i(0, cdir.y)
				var pe := Vector2i(cdir.x - de.x, cdir.y - de.y)
				var edge3 := Vector3(float(de.x) * PLACE, 0.0, float(de.y) * PLACE)
				var perp3 := Vector3(float(de.y), 0.0, float(de.x))
				var pdir3 := Vector2i(de.y, de.x)
				var sgn3 := pdir3.x * pe.x + pdir3.y * pe.y
				var cpos3: Vector3 = cellpos + edge3 + perp3 * (float(sgn3) * (END + 3.0))
				out["outer_lip"].append(Transform3D(cbasis, cpos3 + Vector3(0.0, CORNER_LIP_LIFT, 0.0)))
				# WATER-bank flush steps have no run-merge rows covering the
				# seam (that shortcut is a land-run property): without walls the
				# cap floats over a bare notch (owner, twice: "should be a
				# corner tile"). Give the cap its turned wall rows down to the
				# carved pocket, like a real outer corner.
				if region.has_method("is_carved") and region.is_carved(cx + cdir.x, cz + cdir.y):
					var pocket_y3: float = TerrainSurfaceField.surface_y_in_cell(
						region, px, pz, cx + cdir.x, cz + cdir.y)
					for k in _rows(h - pocket_y3):
						out["outer_wall"].append(Transform3D(
							cbasis, cpos3 + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
			"ext_straight":
				# Run-end junction into a higher flat cell that doesn't wall this direction:
				# the run "goes straight into the wall" (owner round 7) — continue it with a
				# STRAIGHT module (lip + wall rows) one slot into the higher cell, keeping the
				# run's own rotation; it ends buried behind the higher cell's wall face. The
				# straight face and the taller PERPENDICULAR wall face meet concavely: inner
				# WALL rows merge them at each storey (owner round 8 — "the wall should be an
				# inner corner that merges the cliff outcropping with the taller cliff wall";
				# the lip stays straight: "the lip part is good now").
				var d: Vector2i = Vector2i(cdir.x, 0) if cliff.get(Vector2i(cdir.x, 0), false) else Vector2i(0, cdir.y)
				var pp := Vector2i(cdir.x - d.x, cdir.y - d.y)
				var edge2 := Vector3(float(d.x) * PLACE, 0.0, float(d.y) * PLACE)
				var perp2 := Vector3(float(d.y), 0.0, float(d.x))
				var pdir2 := Vector2i(d.y, d.x)
				var sgn2 := pdir2.x * pp.x + pdir2.y * pp.y
				var cpos2: Vector3 = cellpos + edge2 + perp2 * (float(sgn2) * (END + 3.0))
				var end_dip: float = h - _slot_min(prof[d], float(sgn2) * END)
				var sbasis := Basis(Vector3.UP, _angle(d))
				out["lip"].append(Transform3D(sbasis, cpos2 + Vector3(0.0, LIP_LIFT, 0.0)))
				var open := Vector2i(d.x - pp.x, d.y - pp.y)   # the concave opening's diagonal
				var mbasis := Basis(Vector3.UP, atan2(float(open.x), float(open.y)) - PI * 0.25)
				for k in _rows(end_dip):
					out["wall"].append(Transform3D(sbasis, cpos2 + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
					out["inner_wall"].append(Transform3D(mbasis, cpos2 + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
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
				var kind: String = corner_here.get(corner, "")
				if kind in ["outer", "inner", "step"]:
					continue   # the corner piece fills this slot — don't overlap it
				# (ext/abut junction corners keep the end module: the run reaches the
				# boundary; any cap sits one module BEYOND the cell edge)
			var dip: float = h - _slot_min(prof[dir], off)
			if dip < TerrainSurfaceField.EXPOSE_EPS:
				continue   # neighbour flush with the top here — nothing to cover
			var base: Vector3 = cellpos + edge + perp * off
			out["lip"].append(Transform3D(basis, base + Vector3(0.0, LIP_LIFT, 0.0)))
			for k in _rows(dip):
				out["wall"].append(Transform3D(basis, base + Vector3(0.0, -STOREY * float(k + 1), 0.0)))
		# (run-end junctions into higher flat neighbours — outer/inner extension caps — are
		# emitted from corner_map above, so the mesher's clip can hold across them too)

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
	# every piece renders with THE shared de-sheened terrain material (owner round 8: the lip,
	# skirt and slope must be visually continuous from every angle)
	mmi.material_override = shared_material()
	return mmi

static func _find_mi(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D: return n
	for c in n.get_children():
		var r := _find_mi(c)
		if r != null: return r
	return null
