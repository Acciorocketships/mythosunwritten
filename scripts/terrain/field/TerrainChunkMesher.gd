# scripts/terrain/field/TerrainChunkMesher.gd
# Builds ONE continuous surface mesh for a chunk by sampling TerrainSurfaceField on a
# shared grid. Adjacent chunks sample the same boundary coordinates ⇒ no seams.
class_name TerrainChunkMesher
extends RefCounted

const TILE := 24.0
const CELLS_PER_CHUNK := 8
# 8 samples/cell (3u resolution) tessellates the smootherstep slope band finely
# enough to read as a smooth curve rather than a few flat facets.
const SAMPLES_PER_CELL := 8
const CHUNK_WORLD := TILE * CELLS_PER_CHUNK          # 192
const STEP := TILE / SAMPLES_PER_CELL                # 3.0
const GRID := CELLS_PER_CHUNK * SAMPLES_PER_CELL     # 64 quads per axis
const SEA_LEVEL := 0.0

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
			var v00 := Vector3(x0, TerrainSurfaceField.surface_y(region, x0, z0), z0)
			var v10 := Vector3(x1, TerrainSurfaceField.surface_y(region, x1, z0), z0)
			var v11 := Vector3(x1, TerrainSurfaceField.surface_y(region, x1, z1), z1)
			var v01 := Vector3(x0, TerrainSurfaceField.surface_y(region, x0, z1), z1)
			_tri(st, v00, v10, v11)
			_tri(st, v00, v11, v01)
	# Cliff walls: where a cardinal neighbour is ≥2 storeys lower, drop a vertical rock
	# quad along the shared edge into the SAME SurfaceTool (so it welds + normals +
	# collides as one mesh, one material).
	var lo_cx := chunk.x * CELLS_PER_CHUNK
	var lo_cz := chunk.y * CELLS_PER_CHUNK
	for cz in range(lo_cz, lo_cz + CELLS_PER_CHUNK):
		for cx in range(lo_cx, lo_cx + CELLS_PER_CHUNK):
			var s: int = region.storey_at(cx, cz)
			var h_hi: float = region.surface_height(cx, cz)
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if s - int(region.storey_at(cx + dir.x, cz + dir.y)) >= 2:
					_emit_wall(st, cx, cz, dir, h_hi, region.surface_height(cx + dir.x, cz + dir.y))

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

	# Water shim: flat quads at sea level over water cells
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_water := false
	for cz in range(chunk.y * CELLS_PER_CHUNK, chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
		for cx in range(chunk.x * CELLS_PER_CHUNK, chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
			var wc := Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)
			if not Helper.is_water(wc, _water_seed):
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

	# Collision: trimesh from the surface mesh
	var body := StaticBody3D.new()
	body.name = "Body"
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	root.add_child(body)

	return root

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v in [a, b, c]:
		st.set_uv(_grass_uv)
		st.add_vertex(v)

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
