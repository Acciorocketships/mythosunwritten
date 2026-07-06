# scripts/terrain/field/TerrainChunkMesher.gd
# Builds ONE continuous surface mesh for a chunk by sampling TerrainSurfaceField on a
# shared grid. Adjacent chunks sample the same boundary coordinates ⇒ no seams.
class_name TerrainChunkMesher
extends RefCounted

const TILE := 24.0
const CELLS_PER_CHUNK := 8
# 8 samples/cell (3u resolution) tessellates the smootherstep slope band finely
# enough to read as a smooth curve rather than a few flat facets.
const SAMPLES_PER_CELL := 12
const CHUNK_WORLD := TILE * CELLS_PER_CHUNK          # 192
const STEP := TILE / SAMPLES_PER_CELL                # 3.0
const GRID := CELLS_PER_CHUNK * SAMPLES_PER_CELL     # 64 quads per axis
const SEA_LEVEL := 2.0   # water surface ~half a storey above the storey-0 basin floor (a shallow pool)
const SKIRT_RECESS := 1.3 # the rock skirt sits this far behind the cell boundary — just behind the
                          # KayKit wall pieces (old-tile spacing: scalloped face spans PLACE+0.25..
                          # PLACE+1.0 = boundary-1.25..boundary-0.5) so the flat skirt never pokes
                          # THROUGH the scallop valleys. The skirt is a hidden watertight backstop.
const TOP_CLIP := 9.6     # the VISUAL cliff-top sheet stops here on lipped edges — 0.9 behind the
                          # 10.5 lip line, exactly like the old tiles' ground Center piece. The lip
                          # IS the edge from there out; a sheet running to ±12 poked out past/over
                          # the lip pieces (owner's "plane over the cliff edge lips"). Collision
                          # keeps the full extent so the lip band stays walkable.
const APRON := 2.4        # ground/skirt continuation depth under a HIGHER flat neighbour, sealing
                          # the recess band behind that neighbour's wall face + skirt (owner:
                          # "extend the tile at the current level underneath the higher tile").

const FOLIAGE_SCENES := {
	"grass": ["res://terrain/scenes/grass/Grass1.tscn", "res://terrain/scenes/grass/Grass2.tscn", "res://terrain/scenes/grass/Grass3.tscn"],
	"bush": ["res://terrain/scenes/bush/Bush1.tscn", "res://terrain/scenes/bush/Bush2.tscn"],
	"rock": ["res://terrain/scenes/rock/Rock1.tscn", "res://terrain/scenes/rock/Rock2.tscn"],
	"tree": ["res://terrain/scenes/tree/Tree1.tscn", "res://terrain/scenes/tree/Tree2.tscn"],
}

# scene path -> Array of [mesh: Mesh, local_xform: Transform3D], one entry per
# MeshInstance3D inside the foliage scene (KayKit gltf wrappers are visual-only:
# no collision, no scripts — verified before batching them; if a future foliage
# scene needs behaviour, it must not go through the MultiMesh path).
static var _foliage_piece_cache: Dictionary = {}

static func _foliage_pieces(path: String) -> Array:
	var got = _foliage_piece_cache.get(path)
	if got != null:
		return got
	var inst := (load(path) as PackedScene).instantiate()
	var out: Array = []
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var walk: Node = mi
		while walk != null and walk != inst:
			xf = (walk as Node3D).transform * xf
			walk = walk.get_parent()
		out.append([mi.mesh, xf])
	inst.free()
	_foliage_piece_cache[path] = out
	return out

var _material: Material = load("res://terrain/materials/ground.tres")
var _grass_uv: Vector2 = SlopeAtlas.grass_uv()
var _cliff_uv: Vector2 = SlopeAtlas.cliff_uv()
# The skirt renders with the KayKit wall piece's OWN material + a rock texel from its mesh, so
# wherever it peeks out between the scalloped modules it blends with them — the terrain atlas
# rock read as a clearly different colour (owner's round 3).
var _skirt_material: Material = null
var _skirt_uv := Vector2.ZERO

func _ensure_skirt_style() -> void:
	if _skirt_material != null:
		return
	CliffDressing._ensure_loaded()
	var wall_mesh: Mesh = CliffDressing._pieces["wall"][0]
	# THE shared de-sheened terrain material (also overridden onto every dressing piece)
	_skirt_material = CliffDressing.shared_material()
	var uvs: PackedVector2Array = wall_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	if uvs.size() > 0:
		_skirt_uv = uvs[0]
	if _skirt_material == null:
		_skirt_material = _material
		_skirt_uv = _cliff_uv
		return
	# ONE material for every terrain surface (owner round 8: "the cliff lip, the skirt, and
	# the slope are all different colours... it would be nice if they all used the same
	# [texture]"): the walkable sheet + aprons render with the same de-sheened KayKit palette,
	# grass texel sampled from the lip piece's top face — so lips, walls, skirt, sheet and
	# slopes all share one texture that can be retinted in one place.
	var lip_mesh: Mesh = CliffDressing._pieces["lip"][0]
	var larr := lip_mesh.surface_get_arrays(0)
	var lverts: PackedVector3Array = larr[Mesh.ARRAY_VERTEX]
	var lnorms: PackedVector3Array = larr[Mesh.ARRAY_NORMAL]
	var luvs: PackedVector2Array = larr[Mesh.ARRAY_TEX_UV]
	for i in lverts.size():
		if lnorms[i].y > 0.9 and lverts[i].y > -0.05:
			_material = _skirt_material
			_grass_uv = luvs[i]
			break
var _water_seed: int = 0   # set by streamer via set_seed(); 0 in tests

func set_seed(seed: int) -> void:
	_water_seed = seed

# Chunk (ccx,ccz) covers cells [ccx*8 .. ccx*8+7]; its world origin (min corner):
func _origin(chunk: Vector2i) -> Vector2:
	return Vector2(float(chunk.x) * CHUNK_WORLD, float(chunk.y) * CHUNK_WORLD)

# Pure decoration placement for a chunk: scene path -> Array[Transform3D]
# (position + yaw; the per-piece gltf local transform is applied at build).
# Split from build_chunk so tests can assert placements headlessly, where
# MultiMesh does not read back instance transforms (same pattern as
# CliffDressing.compute/build).
func compute_decorations(region, chunk: Vector2i) -> Dictionary:
	var by_scene: Dictionary = {}
	for cz in range(chunk.y * CELLS_PER_CHUNK, chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
		for cx in range(chunk.x * CELLS_PER_CHUNK, chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
			var wc := Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)
			if Helper.is_water(wc, _water_seed):
				continue
			var sy := TerrainSurfaceField.surface_y(region, wc.x, wc.z)
			for d: Dictionary in DecorationScatter.cell_decorations(Vector2i(cx, cz), _water_seed, sy):
				var variants: Array = FOLIAGE_SCENES.get(d["tag"], [])
				if variants.is_empty():
					continue
				var pick: int = int(d["yaw"] / TAU * variants.size()) % variants.size()
				var path: String = variants[pick]
				# Sit each decoration on the surface at ITS OWN jittered position, not the
				# cell centre — otherwise decorations on a slope float above / sink below
				# the ground (the cell-centre height differs from the local height).
				var dp: Vector3 = d["pos"]
				var tf := Transform3D(Basis(Vector3.UP, d["yaw"]),
					Vector3(dp.x, TerrainSurfaceField.surface_y(region, dp.x, dp.z), dp.z))
				if not by_scene.has(path):
					by_scene[path] = []
				by_scene[path].append(tf)
	return by_scene

func build_chunk(plan, chunk: Vector2i) -> Node3D:
	_ensure_skirt_style()
	# Region centred on the chunk; radius covers the chunk plus a neighbour ring for ramps.
	var centre_cx := chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var centre_cz := chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var region = plan.compute_region(centre_cx, centre_cz, CELLS_PER_CHUNK)
	var o := _origin(chunk)
	var st := SurfaceTool.new()    # VISUAL sheet: clipped back to TOP_CLIP under the lips
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# COLLISION sheet: full extent (the lip band stays walkable). Raw triangle
	# soup straight into a ConcavePolygonShape3D — no SurfaceTool, no ArrayMesh,
	# no create_trimesh_shape re-extraction.
	var col_faces := PackedVector3Array()
	col_faces.resize(GRID * GRID * 6)
	var col_i := 0
	var clip_cache := {}           # per-cell lipped-slot masks for the visual clip
	var baked_cache := {}          # per-cell baked surface samplers
	for iz in GRID:
		for ix in GRID:
			var x0 := o.x + ix * STEP
			var x1 := x0 + STEP
			var z0 := o.y + iz * STEP
			var z1 := z0 + STEP
			# PIN the quad to its OWN cell: evaluate all four corners as if they belong to this
			# quad's cell, so a cliff top renders FLAT right up to its boundary (no slanted face).
			# Where two cells differ in height the shared boundary vertices land at different y and
			# don't weld — leaving a clean vertical gap that the rock skirt (below) fills. On flats
			# and slopes the pinned heights match the neighbour's, so vertices weld and stay smooth.
			var qcx := TerrainSurfaceField._cell_of((x0 + x1) * 0.5)
			var qcz := TerrainSurfaceField._cell_of((z0 + z1) * 0.5)
			var qkey := Vector2i(qcx, qcz)
			var baked: PackedFloat32Array = baked_cache.get(qkey, PackedFloat32Array())
			if baked.is_empty():
				baked = TerrainSurfaceField.bake_cell(region, qcx, qcz)
				baked_cache[qkey] = baked
			var y00 := TerrainSurfaceField.sample_baked(baked, qcx, qcz, x0, z0)
			var y10 := TerrainSurfaceField.sample_baked(baked, qcx, qcz, x1, z0)
			var y11 := TerrainSurfaceField.sample_baked(baked, qcx, qcz, x1, z1)
			var y01 := TerrainSurfaceField.sample_baked(baked, qcx, qcz, x0, z1)
			# Grid quads are the WALKABLE surface — flat tops + gentle (≤1 storey) slopes — always
			# grass. Cliff FACES are the separate vertical rock skirts, not slanted grid quads.
			var uv := _grass_uv
			var v00 := Vector3(x0, y00, z0)
			var v10 := Vector3(x1, y10, z0)
			var v11 := Vector3(x1, y11, z1)
			var v01 := Vector3(x0, y01, z1)
			col_faces[col_i] = v00
			col_faces[col_i + 1] = v10
			col_faces[col_i + 2] = v11
			col_faces[col_i + 3] = v00
			col_faces[col_i + 4] = v11
			col_faces[col_i + 5] = v01
			col_i += 6
			# The visual sheet pulls back to TOP_CLIP on lipped edges (the KayKit lip is the
			# visible edge there — a sheet running to the boundary pokes out past/over it).
			var c00 := _clip_vert(region, clip_cache, qcx, qcz, v00)
			var c10 := _clip_vert(region, clip_cache, qcx, qcz, v10)
			var c11 := _clip_vert(region, clip_cache, qcx, qcz, v11)
			var c01 := _clip_vert(region, clip_cache, qcx, qcz, v01)
			_tri(st, c00, c10, c11, uv)
			_tri(st, c00, c11, c01, uv)
	# Cliff FACES: a VERTICAL rock skirt down each cliff-top wall edge, filling the vertical gap the
	# pinned grid leaves between a cliff top and the lower cell. This is the actual rock cliff face
	# (replacing the old slanted grey quads); the KayKit wall pieces dress it, and it doubles as the
	# collision wall so the player can't walk through. Double-sided so it never reads as see-through.
	var skirt := SurfaceTool.new()
	skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skirtc := SurfaceTool.new()   # collision wall: flat planes ON the cell boundaries
	skirtc.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_wall := false
	var lo_cx := chunk.x * CELLS_PER_CHUNK
	var lo_cz := chunk.y * CELLS_PER_CHUNK
	for cz in range(lo_cz, lo_cz + CELLS_PER_CHUNK):
		for cx in range(lo_cx, lo_cx + CELLS_PER_CHUNK):
			if not TerrainSurfaceField.is_flat_cell(region, cx, cz):
				continue   # only flat-rendered cells leave vertical gaps at their boundaries
			var h_hi: float = region.surface_height(cx, cz)
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if TerrainSurfaceField.own_edge_flat(region, cx, cz, dir):
					if _emit_wall(skirt, skirtc, region, cx, cz, dir, h_hi):
						any_wall = true

	# Weld coincident grid vertices BEFORE generating normals so shared vertices get
	# averaged (smooth) normals instead of per-face (flat) ones — this is what makes
	# the slopes read as smooth curves rather than angular facets.
	st.index()
	st.generate_normals()
	st.set_material(_material)
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	var mi := MeshInstance3D.new()
	mi.name = "Surface"
	mi.mesh = st.commit()
	root.add_child(mi)

	# Ground APRONS: continue each cell's ground sheet APRON deep under every HIGHER flat
	# neighbour, sealing the slot floor behind that neighbour's recessed wall face (owner:
	# "extend the tile at the current level underneath the higher tile"). Separate mesh so the
	# Surface sheet keeps its exact one-quad-per-grid-cell structure.
	var ast := SurfaceTool.new()
	ast.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_apron := false
	for cz in range(lo_cz, lo_cz + CELLS_PER_CHUNK):
		for cx in range(lo_cx, lo_cx + CELLS_PER_CHUNK):
			if _emit_aprons(ast, region, clip_cache, cx, cz):
				any_apron = true
	var apron_mesh: Mesh = null
	if any_apron:
		# no index()/generate_normals(): normals are explicit verticals (welding the two
		# windings would zero them out and break the lighting)
		ast.set_material(_material)
		apron_mesh = ast.commit()
		var am := MeshInstance3D.new()
		am.name = "Aprons"
		am.mesh = apron_mesh
		root.add_child(am)

	# NO per-chunk water quads: they hovered at SEA_LEVEL over flat storey-0 ground with the
	# ground-material fallback (water.tres doesn't exist) and read as floating brown planes
	# (owner's screenshot). The global WaterSurface scene is the water visual; Helper.is_water
	# still gates decorations below.

	# Decorations: foliage batched into one MultiMesh per (scene, mesh piece) —
	# same pattern as CliffDressing. ~50 scene instantiations per chunk became
	# a handful of MultiMeshes: fewer nodes, fewer draw calls, cheap eviction.
	var deco := Node3D.new()
	deco.name = "Decorations"
	var by_scene := compute_decorations(region, chunk)
	for path in by_scene:
		var tfs: Array = by_scene[path]
		for piece in _foliage_pieces(path):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = piece[0]
			mm.instance_count = tfs.size()
			for i in tfs.size():
				mm.set_instance_transform(i, tfs[i] * piece[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d" % [String(path).get_file().get_basename(), deco.get_child_count()]
			mmi.multimesh = mm
			deco.add_child(mmi)
	root.add_child(deco)

	# KayKit cliff dressing: real rock wall + grass-lip pieces on the cliff edges.
	var dressing := CliffDressing.build(region, lo_cx, lo_cz, CELLS_PER_CHUNK)
	root.add_child(dressing)

	# Collision: trimesh from the FULL walkable sheet (not the lip-clipped visual — the player
	# must still stand on the lip band), plus a second trimesh of the cliff-wall quads.
	var body := StaticBody3D.new()
	body.name = "Body"
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var col_shape := ConcavePolygonShape3D.new()
	col_shape.set_faces(col_faces)
	cs.shape = col_shape
	body.add_child(cs)
	if apron_mesh != null:
		# The apron can be the only floor in a recess band (beyond the cell boundary, where the
		# main sheet ends) — without collision the player falls through it (owner round 4).
		var cs3 := CollisionShape3D.new()
		cs3.name = "CollisionShape3D_aprons"
		cs3.shape = apron_mesh.create_trimesh_shape()
		body.add_child(cs3)
	if any_wall:
		skirt.generate_normals()
		skirt.set_material(_skirt_material)
		var skirt_mesh := skirt.commit()
		var sf := MeshInstance3D.new()
		sf.name = "CliffFaces"
		sf.mesh = skirt_mesh
		root.add_child(sf)
		# The collision wall is its own boundary-plane mesh, NOT the recessed visual skirt —
		# see _emit_wall (owner round 7: jumping capsules wedged in the recess pocket).
		var cs2 := CollisionShape3D.new()
		cs2.name = "CollisionShape3D_walls"
		cs2.shape = skirtc.commit().create_trimesh_shape()
		body.add_child(cs2)
	root.add_child(body)

	return root

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv: Vector2) -> void:
	for v in [a, b, c]:
		st.set_uv(uv)
		st.add_vertex(v)

const LIP_LIFT := 0.05    # matches CliffDressing.LIP_LIFT — clipped sheet edges rise to the lip
                          # top plane so no hairline slit shows at the lip back

# Which 3-unit slots of this flat cell's edges carry a lip — the same rule CliffDressing uses
# (slot dips ≥ EXPOSE_EPS on a flat-backed edge) — plus WHICH CELL CORNERS carry a dressing
# corner piece (CliffDressing.corner_flags — the dressing's own decision, so sheet and pieces
# always agree). Slots are ordered along pdir=(dir.y,dir.x). Returns {"dirs": {dir: {"lips",
# "prof"}}, "corners": {cdir: kind}}, or null when nothing on this cell is lipped.
func _cell_clip_info(region, cache: Dictionary, cx: int, cz: int):
	var key := Vector2i(cx, cz)
	if cache.has(key):
		return cache[key]
	var out = null
	if TerrainSurfaceField.is_flat_cell(region, cx, cz):
		var h: float = region.surface_height(cx, cz)
		var dirs := {}
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not TerrainSurfaceField.own_edge_flat(region, cx, cz, dir):
				continue
			var prof := TerrainSurfaceField.edge_profile(region, cx, cz, dir, CliffDressing.PROFILE_SAMPLES)
			var lips := []
			var any_lip := false
			var any_dip := false
			for slot in 8:
				var dipped: bool = h - CliffDressing._slot_min(prof, -10.5 + 3.0 * float(slot)) >= TerrainSurfaceField.EXPOSE_EPS
				lips.append(dipped)
				any_lip = any_lip or dipped
			for f in prof:
				if f < h - 0.01:
					any_dip = true
					break
			if any_lip or any_dip:
				dirs[dir] = {"lips": lips if any_lip else [], "prof": prof}
		# corners are kept even when dirs is empty: a classic inner-corner cell has all-flush
		# edges (nothing to clip on ITSELF) but its corner piece caps the point where the
		# walling arms' lip runs end — _corner_capped must be able to see it.
		var corners: Dictionary = CliffDressing.corner_flags(region, cx, cz)
		if not dirs.is_empty() or not corners.is_empty():
			out = {"dirs": dirs, "corners": corners}
	cache[key] = out
	return out

# Pointwise neighbour surface from a cached 25-sample edge profile (1u spacing, along pdir).
func _prof_at(prof: PackedFloat32Array, along: float) -> float:
	var a := clampf(along + 12.0, 0.0, 24.0)
	var i := int(floorf(a))
	if i >= 24:
		return prof[24]
	return lerpf(prof[i], prof[i + 1], a - float(i))

# Is slot s of this cell's `dir` edge lipped? Out-of-range slots look across the cell seam into
# the CONTINUATION cell's colinear edge — so two cells always agree about their shared corner.
func _slot_lipped(region, cache: Dictionary, cx: int, cz: int, dir: Vector2i, s: int) -> bool:
	if s < 0 or s > 7:
		var pdir := Vector2i(dir.y, dir.x)
		var step := 1 if s > 7 else -1
		cx += pdir.x * step
		cz += pdir.y * step
		s = 0 if s > 7 else 7
	var info = _cell_clip_info(region, cache, cx, cz)
	if info == null or not info["dirs"].has(dir):
		return false
	var lips: Array = info["dirs"][dir]["lips"]
	return lips.size() > 0 and lips[s]

# Does a dressing corner piece sit on the cell-corner POINT toward `cdir` — placed by ANY of
# the FOUR same-height cells sharing it? A classic inner corner is owned by the DIAGONAL cell
# while the walling arms' lip runs end on the same point (owner round 4: the arm's taper draped
# a flap through the inner piece — "ground plane sticking out of inner corner lip"). The height
# gate keeps a higher cell's own corner piece (a different storey's junction) from holding this
# cell's clip open with nothing at this level to cover the band.
func _corner_capped(region, cache: Dictionary, cx: int, cz: int, cdir: Vector2i) -> bool:
	var h: float = region.surface_height(cx, cz)
	for o in [Vector2i(0, 0), Vector2i(cdir.x, 0), Vector2i(0, cdir.y), cdir]:
		var info = _cell_clip_info(region, cache, cx + o.x, cz + o.y)
		if info == null:
			continue
		var oc := Vector2i(cdir.x - 2 * o.x, cdir.y - 2 * o.y)   # the same point, seen from that cell
		if info["corners"].has(oc) and absf(region.surface_height(cx + o.x, cz + o.y) - h) < 0.01:
			return true
	return false

# Feathered clip weight along the edge at along-position a (measured along pdir, -12..12):
# 1 inside lipped slots, tapering linearly to 0 at any slot boundary shared with an UNLIPPED
# slot — including across the cell seam. This keeps the sheet C0-continuous: a lipped cell
# never tears away from an unclipped neighbour (the owner's triangular holes), and the clip
# fades out exactly where the lip run ends.
func _edge_w(region, cache: Dictionary, cx: int, cz: int, dir: Vector2i, a: float) -> float:
	var s := clampi(int(floorf((a + 12.0) / 3.0)), 0, 7)
	var w_c := 1.0 if _slot_lipped(region, cache, cx, cz, dir, s) else 0.0
	var t := (a - (-10.5 + 3.0 * float(s))) / 1.5   # -1 at the slot's low corner, +1 at its high corner
	var nb := s + 1 if t >= 0.0 else s - 1
	var nb_lipped := _slot_lipped(region, cache, cx, cz, dir, nb)
	if not nb_lipped and (nb < 0 or nb > 7):
		# This slot boundary IS a cell corner. When a dressing corner PIECE sits on it, the lip
		# line TURNS there and keeps going — the clip must hold its weight, else the sheet
		# drapes into a steep flap through/behind the cap (owner round 4: the "slight gap" slit
		# at the lip back + a needle sliver poking from the wall at a slope-facing wrap corner).
		# Only a truly uncapped run end tapers out.
		var pdir := Vector2i(dir.y, dir.x)
		nb_lipped = _corner_capped(region, cache, cx, cz, dir + (pdir if nb > 7 else -pdir))
	var w_corner := w_c if nb_lipped else 0.0
	return lerpf(w_c, w_corner, clampf(absf(t), 0.0, 1.0))

# Adjust a flat-top vertex for its cell's edges (visual sheet only):
#  - PULL it back toward TOP_CLIP on lipped edges (the KayKit lip is the visible edge there),
#    scaled by the feathered weight; the pulled edge rises by LIP_LIFT to tuck flush under the
#    lip's raised top. Near-degenerate offsets (not zero) preserve the quad structure.
#  - BLEND it down (capped at EXPOSE_EPS) onto a neighbour that has dipped LESS than the lip
#    threshold, scaled by (1-w): sub-lip dips weld instead of opening a hairline slit at the
#    boundary (the owner's dark dashes where a slope flattens out).
func _clip_vert(region, cache: Dictionary, qcx: int, qcz: int, v: Vector3) -> Vector3:
	var info = _cell_clip_info(region, cache, qcx, qcz)
	if info == null:
		return v
	var h: float = region.surface_height(qcx, qcz)
	var lx := v.x - float(qcx) * TILE
	var lz := v.z - float(qcz) * TILE
	var lift := 0.0
	var down := 0.0
	for dir in info["dirs"]:
		var coord := lx * float(dir.x) + lz * float(dir.y)       # distance toward this edge
		var along := lx * float(dir.y) + lz * float(dir.x)       # signed along pdir=(dir.y,dir.x)
		var w := _edge_w(region, cache, qcx, qcz, dir, along)
		var f := clampf((coord - TOP_CLIP) / (TILE * 0.5 - TOP_CLIP), 0.0, 1.0)
		if f > 0.0 and w < 1.0:
			# UNCAPPED drape: where the clip fades out, the edge follows the neighbour all the
			# way down (a hovering full-height flare read as "ground plane sticking out" at
			# lip-run ends/steps — owner round 4). The cell's own wall modules back the fold.
			var dip := maxf(h - _prof_at(info["dirs"][dir]["prof"], along), 0.0)
			down = maxf(down, dip * f * (1.0 - w))
		if w <= 0.0:
			continue
		var target := TILE * 0.5 - (TILE * 0.5 - TOP_CLIP) * w
		if coord > target:
			# 0.02 keeps the compressed band a few cm wide — truly degenerate slivers get
			# zero-area normals and render as dark dashes. The lift tucks the edge 1cm BELOW
			# the lip's raised top: flush to the eye, no coplanar z-fight with the lip.
			var pulled := target + (coord - target) * 0.02
			if dir.x != 0:
				lx = pulled * float(dir.x)
			else:
				lz = pulled * float(dir.y)
			lift = maxf(lift, (LIP_LIFT - 0.01) * w)
	# INNER-CORNER pull: a flat cell that OWNS a classic inner corner (its diagonal is the
	# pocket) has no dressed edge of its own there, so its bare sheet ran flat to the very
	# corner point and poked out through the rounded front of the inner-corner piece as a
	# green flap over the pocket (owner round 11: "corner of plane sticking out of cliff lip
	# inner corner"). Tuck the corner-point VERTEX diagonally 1.3 under the piece. Only that
	# one vertex: a wider (TOP_CLIP) zone deforms quads whose far verts reach past the
	# piece's 3x3 footprint and tears an uncovered hole at the cell seam (the blue triangle);
	# pulling just the point keeps all deformation under the piece's grass top. (Ghost
	# corners need no pull: their diagonal cell is a HIGHER flat, already edge-clipped.)
	for cdir in info["corners"]:
		var kind: String = info["corners"][cdir]
		if kind == "inner":
			var tuck := TILE * 0.5 - 1.3
			var ccx := lx * float(cdir.x)
			var ccz := lz * float(cdir.y)
			if ccx > tuck and ccz > tuck:
				lx = (tuck + (ccx - tuck) * 0.02) * float(cdir.x)
				lz = (tuck + (ccz - tuck) * 0.02) * float(cdir.y)
				lift = maxf(lift, LIP_LIFT - 0.01)
		# ("outer" one-armed flush-step corners need NO corner pull here: the dressed
		# arm's edge clip holds full weight through the corner — _slot_lipped's
		# continuation rule sees the taller cell's collinear lip run — so the boundary
		# row retracts along that axis alone and the cap's L-band covers the vacated
		# strip. A diagonal tuck abandons ground the band can't roof: a water-blue
		# wedge opened beside the cap.)
	return Vector3(float(qcx) * TILE + lx, v.y + lift - down, float(qcz) * TILE + lz)

# Ground aprons: continue this cell's ground sheet APRON deep under each FLAT neighbour whose
# edge toward us is EXPOSED — a higher cliff, or a same-level cliff top this cell's slope dips
# under (the owner's "gap between slope and cliff at the same level"). The strip sits at this
# cell's boundary profile (welding to the main sheet), floors the recess band behind the
# neighbour's wall face, and is clamped by both cells' clips so its ends never poke out through
# a perpendicular wall face (the owner's floating green planes).
#
# (Round 11's "lip shelf" — a second grass strip up under the lip front roofing the slot
# between the lower sheet's edge and the wall face — is GONE: at tall cliffs it read as a
# plane jutting out below the lip from any low angle, owner rounds 12-13. The round-11
# "tiny gaps" it papered over are handled at ground level where they actually live.)
func _emit_aprons(st: SurfaceTool, region, clip_cache: Dictionary, cx: int, cz: int) -> bool:
	var emitted := false
	var active := {}
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		active[dir] = TerrainSurfaceField.is_exposed_edge(region, cx + dir.x, cz + dir.y, Vector2i(-dir.x, -dir.y))
	for dir in active:
		if not active[dir]:
			continue
		var ncx: int = cx + dir.x
		var ncz: int = cz + dir.y
		var h_n: float = region.surface_height(ncx, ncz)
		var pdir := Vector2i(dir.y, dir.x)
		var bx := float(cx) * TILE + float(dir.x) * TILE * 0.5
		var bz := float(cz) * TILE + float(dir.y) * TILE * 0.5
		var out := Vector3(float(dir.x) * APRON, 0.0, float(dir.y) * APRON)
		# A one-armed "outer" capped corner on this edge (water flush-step): the taller
		# neighbour's perpendicular clip FADES OUT at its run end, so an unclamped strip
		# pokes past the turned corner column's face as a flat green square over the
		# water. Clamp the along-range to the wall-face line (SKIRT_RECESS behind the
		# boundary) — the strip still floors the recess slot right up to the column.
		var a_lo := -TILE * 0.5
		var a_hi := TILE * 0.5
		var cap_hi := false
		var cap_lo := false
		var info_own = _cell_clip_info(region, clip_cache, cx, cz)
		if info_own != null:
			for ccdir in info_own["corners"]:
				var ckind: String = info_own["corners"][ccdir]
				if ccdir.x * dir.x + ccdir.y * dir.y != 1:
					continue   # corner not on this edge
				var hi_end: bool = ccdir.x * pdir.x + ccdir.y * pdir.y > 0
				if ckind == "outer":
					if info_own["dirs"].has(Vector2i(ccdir.x, 0)) and info_own["dirs"].has(Vector2i(0, ccdir.y)):
						continue   # classic outer (both arms dressed): edge clips already retract
					if hi_end:
						a_hi = TILE * 0.5 - SKIRT_RECESS
						cap_hi = true
					else:
						a_lo = -(TILE * 0.5 - SKIRT_RECESS)
						cap_lo = true
				elif ckind == "inner":
					# Carved-pocket diagonal corner: the inner piece roofs the band and
					# the strip legitimately runs to the boundary — only bypass the
					# generic clips there (the inner tuck would drag the strip's end
					# diagonally off the boundary and open a hole over the pocket).
					if hi_end:
						cap_hi = true
					else:
						cap_lo = true
		for i in SAMPLES_PER_CELL:
			var a0 := clampf(-TILE * 0.5 + STEP * float(i), a_lo, a_hi)
			var a1 := clampf(-TILE * 0.5 + STEP * float(i + 1), a_lo, a_hi)
			if a1 - a0 < 0.01:
				continue   # segment fully behind the capped corner's wall face
			var p0 := Vector3(bx + float(pdir.x) * a0, 0.0, bz + float(pdir.y) * a0)
			var p1 := Vector3(bx + float(pdir.x) * a1, 0.0, bz + float(pdir.y) * a1)
			p0.y = TerrainSurfaceField.surface_y_in_cell(region, p0.x, p0.z, cx, cz)
			p1.y = TerrainSurfaceField.surface_y_in_cell(region, p1.x, p1.z, cx, cz)
			if p0.y > h_n - 0.05 and p1.y > h_n - 0.05:
				continue   # flush with the neighbour's top — nothing to floor here
			# inner verts weld to this cell's (possibly clipped) sheet edge; outer verts tuck
			# under the neighbour's top and pull back from its perpendicular clip lines
			var q0: Vector3 = p0 + out
			var q1: Vector3 = p1 + out
			q0.y = minf(q0.y, h_n - 0.05)
			q1.y = minf(q1.y, h_n - 0.05)
			# Inside the capped-corner band the strip must reach the corner column's
			# face: the cap piece roofs its inner edge and the a_hi/a_lo clamp already
			# holds its end 0.05 behind the column's deepest face plane. The generic
			# clips would pull both edges back to TOP_CLIP and reopen the slot floor.
			if not ((cap_hi and a0 >= TOP_CLIP) or (cap_lo and a0 <= -TOP_CLIP)):
				p0 = _clip_vert(region, clip_cache, cx, cz, p0)
				q0 = _clip_perp(region, clip_cache, ncx, ncz, dir, q0)
			if not ((cap_hi and a1 >= TOP_CLIP) or (cap_lo and a1 <= -TOP_CLIP)):
				p1 = _clip_vert(region, clip_cache, cx, cz, p1)
				q1 = _clip_perp(region, clip_cache, ncx, ncz, dir, q1)
			_apron_quad(st, p0, p1, q0, q1)
			emitted = true
	for cdir in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		if not (active[Vector2i(cdir.x, 0)] and active[Vector2i(0, cdir.y)]):
			continue
		if int(region.storey_at(cx + cdir.x, cz + cdir.y)) < int(region.storey_at(cx, cz)):
			continue   # diagonal hole — a floating corner patch would poke into open air
		var px := float(cx) * TILE + float(cdir.x) * TILE * 0.5
		var pz := float(cz) * TILE + float(cdir.y) * TILE * 0.5
		var y := TerrainSurfaceField.surface_y_in_cell(region, px, pz, cx, cz)
		var a := Vector3(px, y, pz)
		var b := a + Vector3(float(cdir.x) * APRON, 0.0, 0.0)
		var c := a + Vector3(0.0, 0.0, float(cdir.y) * APRON)
		var d2 := a + Vector3(float(cdir.x) * APRON, 0.0, float(cdir.y) * APRON)
		_apron_quad(st, a, b, c, d2)
		emitted = true
	# (Round 8 floored the flush-step cap notch with a flat grass patch here; the owner
	# rejected it — round 9 extends the run's straight modules to the boundary and turns
	# the cap lip one slot INTO the taller cell instead, so there is no notch to floor.)
	return emitted

# The TOP face must wind like the sheet's top faces (right-hand geometric normal DOWN — the
# front side seen from above in this project), lit UP. Half the directions used to wind the
# other way, so the face visible from above was the DOWN-lit copy — the owner's dark/wrong-
# colour "ground skirt". The flipped copy sits 2cm lower (never z-fights) with a DOWN normal.
func _apron_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, q0: Vector3, q1: Vector3) -> void:
	var drop := Vector3(0.0, -0.02, 0.0)
	for tri in [[p0, q0, q1], [p0, q1, p1]]:
		var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0])
		var order: Array = tri if n.y < 0.0 else [tri[0], tri[2], tri[1]]
		st.set_normal(Vector3.UP)
		for v in order:
			st.set_uv(_grass_uv)
			st.add_vertex(v)
		st.set_normal(Vector3.DOWN)
		for i in [0, 2, 1]:
			st.set_uv(_grass_uv)
			st.add_vertex(order[i] + drop)

# Clamp a point's ALONG coordinates by cell (ncx,ncz)'s clip on its two edges perpendicular to
# `d` — used for apron ends reaching into that cell (never pull along d itself: the apron
# legitimately extends past that cell's d-facing clip line).
func _clip_perp(region, cache: Dictionary, ncx: int, ncz: int, d: Vector2i, v: Vector3) -> Vector3:
	var info = _cell_clip_info(region, cache, ncx, ncz)
	if info == null:
		return v
	var lx := v.x - float(ncx) * TILE
	var lz := v.z - float(ncz) * TILE
	for dir in info["dirs"]:
		if dir == d or dir == Vector2i(-d.x, -d.y):
			continue
		# An apron end BELOW the surface of the cell across this edge is buried inside solid
		# ground — clamping it collapses the last quad and opens a hole at the corner point
		# (owner round 9: "there is a gap in the ground right here"). Only clamp ends level
		# with or above that cell's airspace, where poking past the wall face would show.
		if v.y < TerrainSurfaceField.surface_y_in_cell(region, v.x, v.z, ncx + dir.x, ncz + dir.y) - 0.1:
			continue
		var coord := lx * float(dir.x) + lz * float(dir.y)
		var along := lx * float(dir.y) + lz * float(dir.x)
		var w := _edge_w(region, cache, ncx, ncz, dir, along)
		if w <= 0.0:
			continue
		var target := TILE * 0.5 - (TILE * 0.5 - TOP_CLIP) * w
		if coord > target:
			var pulled := target + (coord - target) * 0.001
			if dir.x != 0:
				lx = pulled * float(dir.x)
			else:
				lz = pulled * float(dir.y)
	return Vector3(float(ncx) * TILE + lx, v.y, float(ncz) * TILE + lz)

# Does this grid quad lie on a CLIFF FACE (→ rock) rather than a walkable slope (→ grass)?
# By cell config: the quad's corner cells span ≥2 storeys (a cliff), or a 1-storey step where
# every corner cell is a cliff top (a wall between two flat tiles). A slope — even a steep
# up-ramp one whose vertices span several metres — has cells ≤1 storey apart and not all cliff
# tops, so it stays grass.
func _is_cliff_quad(region, x0: float, x1: float, z0: float, z1: float) -> bool:
	var cells := [
		[int(roundf(x0 / TILE)), int(roundf(z0 / TILE))],
		[int(roundf(x1 / TILE)), int(roundf(z0 / TILE))],
		[int(roundf(x1 / TILE)), int(roundf(z1 / TILE))],
		[int(roundf(x0 / TILE)), int(roundf(z1 / TILE))],
	]
	var hi := -9999
	var lo := 9999
	for c in cells:
		var s := int(region.storey_at(c[0], c[1]))
		hi = maxi(hi, s)
		lo = mini(lo, s)
	if hi - lo >= 2:
		return true
	if hi - lo == 1:
		for c in cells:
			if not (TerrainSurfaceField._is_cliff_top(region, c[0], c[1]) or TerrainSurfaceField.has_inner_corner(region, c[0], c[1])):
				return false
		return true
	return false

# The cliff face: a VERTICAL rock skirt just behind the cell boundary (SKIRT_RECESS, hidden
# behind the KayKit wall pieces), spanning from the flat cliff top down to the NEIGHBOUR'S
# ACTUAL surface along the shared edge — its boundary profile, not its cell-centre height. A
# slope neighbour descends along the edge; stopping at the storey line left a see-through void
# under the wall, and a SAME-storey slope neighbour got no wall at all (owner's screenshots).
# Sampled on the same grid coordinates as the surface mesh so the skirt bottom tracks the
# neighbour's rendered boundary, dipping SKIRT_UNDERHANG below it (hidden behind the neighbour's
# ground sheet) so no razor-thin slit remains. Double-sided, rock UV; doubles as collision.
const SKIRT_UNDERHANG := 1.0
func _emit_wall(st: SurfaceTool, stcol: SurfaceTool, region, cx: int, cz: int, dir: Vector2i, y_hi: float) -> bool:
	var prof := TerrainSurfaceField.edge_profile(region, cx, cz, dir, SAMPLES_PER_CELL)
	var pdir := Vector2i(dir.y, dir.x)             # along-edge step (perpendicular to the drop)
	var ex := float(cx) * TILE + float(dir.x) * (TILE * 0.5 - SKIRT_RECESS)
	var ez := float(cz) * TILE + float(dir.y) * (TILE * 0.5 - SKIRT_RECESS)
	# The COLLISION wall is a separate flat plane ON the cell boundary: it meets the full-extent
	# collision sheet in a clean convex edge. Reusing the recessed visual skirt left an overhang
	# pocket under the lip band that wedged a jumping capsule (owner round 7: "when i jump i
	# often get stuck in the wall").
	var cex := float(cx) * TILE + float(dir.x) * TILE * 0.5
	var cez := float(cz) * TILE + float(dir.y) * TILE * 0.5
	# Where the cliff face TURNS at this cell's corner (the perpendicular edge drops too), stop
	# at the perpendicular skirt plane — a full-width tail would run SKIRT_RECESS past it and
	# poke out through the perpendicular KayKit wall face as a thin vertical fin (owner). Where
	# the along-edge neighbour is instead a HIGHER flat cell, CONTINUE the skirt APRON deep
	# into it: the perpendicular skirts cross behind the corner pieces (no open chimney).
	# Boundary-plane collision walls need no trims: perpendicular planes meet exactly at the
	# shared corner.
	var lo := -TILE * 0.5
	var hi := TILE * 0.5
	var lo_c := -TILE * 0.5
	var hi_c := TILE * 0.5
	if _skirt_turns(region, cx, cz, dir, -1):
		lo += SKIRT_RECESS
	elif TerrainSurfaceField.is_higher_flat(region, cx, cz, Vector2i(-pdir.x, -pdir.y)):
		lo -= APRON
		lo_c -= APRON
	if _skirt_turns(region, cx, cz, dir, +1):
		hi -= SKIRT_RECESS
	elif TerrainSurfaceField.is_higher_flat(region, cx, cz, pdir):
		hi += APRON
		hi_c += APRON
	var emitted := false
	for i in SAMPLES_PER_CELL:
		var f0 := minf(prof[i], y_hi)
		var f1 := minf(prof[i + 1], y_hi)
		if f0 > y_hi - 0.01 and f1 > y_hi - 0.01:
			continue   # flush span — no exposed face here
		var a0 := clampf(-TILE * 0.5 + STEP * float(i), lo, hi)
		var a1 := clampf(-TILE * 0.5 + STEP * float(i + 1), lo, hi)
		if _skirt_quad(st, ex, ez, pdir, a0, a1, y_hi, f0, f1):
			emitted = true
		var c0 := clampf(-TILE * 0.5 + STEP * float(i), lo_c, hi_c)
		var c1 := clampf(-TILE * 0.5 + STEP * float(i + 1), lo_c, hi_c)
		_skirt_quad(stcol, cex, cez, pdir, c0, c1, y_hi, f0, f1)
	# extension segments beyond the cell edge (under the higher neighbour), flat continuation
	# of the end samples
	if lo < -TILE * 0.5 and _skirt_quad(st, ex, ez, pdir, lo, -TILE * 0.5, y_hi, minf(prof[0], y_hi), minf(prof[0], y_hi)):
		emitted = true
	if hi > TILE * 0.5 and _skirt_quad(st, ex, ez, pdir, TILE * 0.5, hi, y_hi, minf(prof[SAMPLES_PER_CELL], y_hi), minf(prof[SAMPLES_PER_CELL], y_hi)):
		emitted = true
	if lo_c < -TILE * 0.5:
		_skirt_quad(stcol, cex, cez, pdir, lo_c, -TILE * 0.5, y_hi, minf(prof[0], y_hi), minf(prof[0], y_hi))
	if hi_c > TILE * 0.5:
		_skirt_quad(stcol, cex, cez, pdir, TILE * 0.5, hi_c, y_hi, minf(prof[SAMPLES_PER_CELL], y_hi), minf(prof[SAMPLES_PER_CELL], y_hi))
	return emitted

func _skirt_quad(st: SurfaceTool, ex: float, ez: float, pdir: Vector2i, a0: float, a1: float, y_hi: float, f0: float, f1: float) -> bool:
	if a1 - a0 < 0.001:
		return false
	if f0 > y_hi - 0.01 and f1 > y_hi - 0.01:
		return false
	var t0 := Vector3(ex + float(pdir.x) * a0, y_hi, ez + float(pdir.y) * a0)
	var t1 := Vector3(ex + float(pdir.x) * a1, y_hi, ez + float(pdir.y) * a1)
	var b0 := Vector3(t0.x, f0 - SKIRT_UNDERHANG, t0.z)
	var b1 := Vector3(t1.x, f1 - SKIRT_UNDERHANG, t1.z)
	for v in [t0, t1, b1, t0, b1, b0, t0, b1, t1, t0, b0, b1]:
		st.set_uv(_skirt_uv); st.add_vertex(v)
	return true

# Does the cliff face turn the corner at the `sgn` end of this edge — i.e. will the
# perpendicular edge carry its own skirt at the shared corner? True when the perpendicular
# neighbour's surface at the corner point sits below this cell's flat top.
func _skirt_turns(region, cx: int, cz: int, dir: Vector2i, sgn: int) -> bool:
	var pd := Vector2i(dir.y * sgn, dir.x * sgn)
	if not TerrainSurfaceField.own_edge_flat(region, cx, cz, pd):
		return false
	var px := float(cx) * TILE + (float(dir.x) + float(pd.x)) * TILE * 0.5
	var pz := float(cz) * TILE + (float(dir.y) + float(pd.y)) * TILE * 0.5
	var h: float = region.surface_height(cx, cz)
	return TerrainSurfaceField.surface_y_in_cell(region, px, pz, cx + pd.x, cz + pd.y) < h - 0.05
