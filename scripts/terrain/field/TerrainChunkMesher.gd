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

const FOLIAGE_SCENES := {
	"grass": ["res://terrain/scenes/grass/Grass1.tscn", "res://terrain/scenes/grass/Grass2.tscn", "res://terrain/scenes/grass/Grass3.tscn"],
	"bush": ["res://terrain/scenes/bush/Bush1.tscn", "res://terrain/scenes/bush/Bush2.tscn"],
	"rock": ["res://terrain/scenes/rock/Rock1.tscn", "res://terrain/scenes/rock/Rock2.tscn"],
	"tree": ["res://terrain/scenes/tree/Tree1.tscn", "res://terrain/scenes/tree/Tree2.tscn"],
}

var _material: Material = load("res://terrain/materials/ground.tres")
var _grass_uv: Vector2 = SlopeAtlas.grass_uv()
var _cliff_uv: Vector2 = SlopeAtlas.cliff_uv()
var _water_seed: int = 0   # set by streamer via set_seed(); 0 in tests
var _water_material: Material = load("res://terrain/materials/water.tres") if ResourceLoader.exists("res://terrain/materials/water.tres") else load("res://terrain/materials/ground.tres")

func set_seed(seed: int) -> void:
	_water_seed = seed

# Chunk (ccx,ccz) covers cells [ccx*8 .. ccx*8+7]; its world origin (min corner):
func _origin(chunk: Vector2i) -> Vector2:
	return Vector2(float(chunk.x) * CHUNK_WORLD, float(chunk.y) * CHUNK_WORLD)

func build_chunk(plan, chunk: Vector2i) -> Node3D:
	# Region centred on the chunk; radius covers the chunk plus a neighbour ring for ramps.
	var centre_cx := chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var centre_cz := chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var region = plan.compute_region(centre_cx, centre_cz, CELLS_PER_CHUNK)
	var o := _origin(chunk)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in GRID:
		for ix in GRID:
			var x0 := o.x + ix * STEP
			var x1 := x0 + STEP
			var z0 := o.y + iz * STEP
			var z1 := z0 + STEP
			var y00 := TerrainSurfaceField.surface_y(region, x0, z0)
			var y10 := TerrainSurfaceField.surface_y(region, x1, z0)
			var y11 := TerrainSurfaceField.surface_y(region, x1, z1)
			var y01 := TerrainSurfaceField.surface_y(region, x0, z1)
			# Render EVERY quad — the surface is continuous, so there is never a hole to see
			# through, for ANY heightfield. Texture a quad as ROCK only at a real CLIFF FACE; a
			# walkable slope (even a steep up-ramp one) stays grass. The cliff test is by CELL
			# CONFIG, not height: corner cells span ≥2 storeys, OR a 1-storey step where every
			# corner is a cliff top (a wall between two flat tiles). Up-ramp slope quads can reach
			# ~4m tall but their cells differ ≤1 storey and aren't all cliff tops → grass.
			var uv := _grass_uv if not _is_cliff_quad(region, x0, x1, z0, z1) else _cliff_uv
			var v00 := Vector3(x0, y00, z0)
			var v10 := Vector3(x1, y10, z0)
			var v11 := Vector3(x1, y11, z1)
			var v01 := Vector3(x0, y01, z1)
			_tri(st, v00, v10, v11, uv)
			_tri(st, v00, v11, v01, uv)
	# Cliff walls: where a cardinal neighbour is ≥2 storeys lower, drop a vertical quad
	# along the shared edge into a SEPARATE, COLLISION-ONLY SurfaceTool. The visible
	# cliff face comes from KayKit pieces (CliffDressing); these invisible quads only
	# stop the player from walking through the cliff.
	var cwall := SurfaceTool.new()
	cwall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_wall := false
	var lo_cx := chunk.x * CELLS_PER_CHUNK
	var lo_cz := chunk.y * CELLS_PER_CHUNK
	for cz in range(lo_cz, lo_cz + CELLS_PER_CHUNK):
		for cx in range(lo_cx, lo_cx + CELLS_PER_CHUNK):
			# Collision walls match CliffDressing exactly: one wall per cliff-top WALL EDGE
			# (≥2 drop, or a 1-drop between two cliff tops — see _is_wall_edge).
			var h_hi: float = region.surface_height(cx, cz)
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if TerrainSurfaceField._is_wall_edge(region, cx, cz, dir):
					_emit_wall(cwall, cx, cz, dir, h_hi, region.surface_height(cx + dir.x, cz + dir.y))
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

	# Water shim: shallow pools in genuinely LOW basins only. The river/pond noise (is_water)
	# is height-agnostic, so without this gate it drops a quad at sea level under high terrain
	# too — which then peeks out as stray blue in adjacent low ground. Only emit water where the
	# cell floor is at/below the water line, and sit the surface SEA_LEVEL above the floor.
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_water := false
	for cz in range(chunk.y * CELLS_PER_CHUNK, chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
		for cx in range(chunk.x * CELLS_PER_CHUNK, chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
			var wc := Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)
			if not Helper.is_water(wc, _water_seed):
				continue
			if region.surface_height(cx, cz) > SEA_LEVEL:   # only basins at/below the water line
				continue
			any_water = true
			var x0 := wc.x - TILE * 0.5; var x1 := wc.x + TILE * 0.5
			var z0 := wc.z - TILE * 0.5; var z1 := wc.z + TILE * 0.5
			var a := Vector3(x0, SEA_LEVEL, z0); var b := Vector3(x1, SEA_LEVEL, z0)
			var c := Vector3(x1, SEA_LEVEL, z1); var d := Vector3(x0, SEA_LEVEL, z1)
			for v in [a, b, c, a, c, d]:
				wst.set_uv(Vector2.ZERO); wst.add_vertex(v)
	var water := MeshInstance3D.new()
	water.name = "Water"
	if any_water:
		wst.generate_normals()
		wst.set_material(_water_material)
		water.mesh = wst.commit()
	root.add_child(water)

	# Decorations: scatter foliage on non-water land cells
	var deco := Node3D.new()
	deco.name = "Decorations"
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
				var inst: Node3D = (load(variants[pick]) as PackedScene).instantiate()
				# Sit each decoration on the surface at ITS OWN jittered position, not the
				# cell centre — otherwise decorations on a slope float above / sink below
				# the ground (the cell-centre height differs from the local height).
				var dp: Vector3 = d["pos"]
				inst.position = Vector3(dp.x, TerrainSurfaceField.surface_y(region, dp.x, dp.z), dp.z)
				inst.rotation.y = d["yaw"]
				deco.add_child(inst)
	root.add_child(deco)

	# KayKit cliff dressing: real rock wall + grass-lip pieces on the cliff edges.
	var dressing := CliffDressing.build(region, lo_cx, lo_cz, CELLS_PER_CHUNK)
	root.add_child(dressing)

	# Collision: trimesh from the walkable surface, plus a second trimesh of the
	# (invisible) cliff-wall quads so the player can't walk through a cliff face.
	var body := StaticBody3D.new()
	body.name = "Body"
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	if any_wall:
		var wall_mesh := cwall.commit()
		var cs2 := CollisionShape3D.new()
		cs2.name = "CollisionShape3D_walls"
		cs2.shape = wall_mesh.create_trimesh_shape()
		body.add_child(cs2)
	root.add_child(body)

	return root

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv: Vector2) -> void:
	for v in [a, b, c]:
		st.set_uv(uv)
		st.add_vertex(v)

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
			if not TerrainSurfaceField._is_cliff_top(region, c[0], c[1]):
				return false
		return true
	return false

# A vertical quad along the shared cell edge, rock UV, face toward `dir`.
func _emit_wall(st: SurfaceTool, cx: int, cz: int, dir: Vector2i, y_hi: float, y_lo: float) -> void:
	var ccx := float(cx) * TILE
	var ccz := float(cz) * TILE
	# Edge endpoints (the boundary line perpendicular to dir), at the cell's +dir edge.
	var ex := ccx + float(dir.x) * (TILE * 0.5)
	var ez := ccz + float(dir.y) * (TILE * 0.5)
	# Perp axis along the edge:
	var perp := Vector2(float(dir.y), float(dir.x)) * (TILE * 0.5)   # half-edge offset
	var p0 := Vector2(ex - perp.x, ez - perp.y)
	var p1 := Vector2(ex + perp.x, ez + perp.y)
	var t0 := Vector3(p0.x, y_hi, p0.y)
	var t1 := Vector3(p1.x, y_hi, p1.y)
	var b0 := Vector3(p0.x, y_lo, p0.y)
	var b1 := Vector3(p1.x, y_lo, p1.y)
	# Wind both triangles so the face points outward (+dir).
	for v in [t0, t1, b1, t0, b1, b0]:
		st.set_uv(_cliff_uv); st.add_vertex(v)
