# scripts/terrain/water/WaterSurfaceBuilder.gd
# Per-chunk water: pond quad sheets at storey-aligned levels, river ribbon
# meshes following the monotone surface profile, and Area3D swim volumes.
# Built beside each terrain chunk and parented under it, so streaming
# eviction frees water with the ground it belongs to.
class_name WaterSurfaceBuilder
extends RefCounted

const TILE := 24.0
const CELLS_PER_CHUNK := 8            # = TerrainChunkMesher.CELLS_PER_CHUNK
const CHUNK_WORLD := TILE * CELLS_PER_CHUNK
const RIBBON_DEPTH_OFFSET := 1.5      # river surface above its carved bed
const STOREY := 4.0                   # = HeightfieldPlan.STOREY_HEIGHT
const FLOOR_CLEARANCE := 0.8          # river surface above the QUANTIZED floor estimate
const STEEP_RISE := 5.0               # bed drop per sample that reads as rapids=1
const POND_SKIP_T := 0.85             # drop ribbon samples this deep into a pond footprint
const VOLUME_STRIDE := 4              # river swim-box every N samples
const WATER_LAYER := 1 << 7

static var _pond_material: ShaderMaterial = null
static var _river_material: ShaderMaterial = null


## Water surface height per polyline sample: bed + offset, flattened into the
## terminal pond (backwater) and made monotone by a single backward pass —
## walking upstream, the surface may only rise. Pure function of the trace.
## The carved channel renders storey-QUANTIZED, and rounding can lift the
## floor up to half a storey above the bed — clearing the quantized floor
## estimate too keeps reaches just past a step from submerging under terrain.
static func surface_profile(river: RiverTrace) -> PackedFloat32Array:
	var n: int = river.points.size()
	var prof: PackedFloat32Array = PackedFloat32Array()
	prof.resize(n)
	for i in n:
		var floor_est: float = roundf(river.beds[i] / STOREY) * STOREY
		prof[i] = maxf(river.beds[i] + RIBBON_DEPTH_OFFSET, floor_est + FLOOR_CLEARANCE)
	if river.pond != null:
		prof[n - 1] = maxf(river.pond.surface_y(), river.beds[n - 1] + 0.2)
	for i in range(n - 2, -1, -1):
		prof[i] = maxf(prof[i], prof[i + 1])
	return prof


## 0 (calm) .. 1 (waterfall) steepness per sample, from the bed's local drop.
static func steepness_profile(river: RiverTrace) -> PackedFloat32Array:
	var n: int = river.points.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var a: int = maxi(i - 1, 0)
		var b: int = mini(i + 1, n - 1)
		var drop: float = river.beds[a] - river.beds[b]
		out[i] = clampf(drop / (STEEP_RISE * float(b - a if b > a else 1)), 0.0, 1.0)
	return out


static func _material(shader_path: String) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(shader_path)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.008
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	mat.set_shader_parameter("noise_tex", tex)
	return mat


static func pond_material() -> ShaderMaterial:
	if _pond_material == null:
		_pond_material = _material("res://terrain/water/water_pond.gdshader")
	return _pond_material


static func river_material() -> ShaderMaterial:
	if _river_material == null:
		_river_material = _material("res://terrain/water/water_river.gdshader")
	return _river_material


## Build the water node for a chunk, or null when the chunk is dry.
func build_chunk(water: WaterPlan, chunk: Vector2i) -> Node3D:
	var centre_cx: int = chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var centre_cz: int = chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var bodies: Dictionary = water.bodies_near(Vector2i(centre_cx, centre_cz), CELLS_PER_CHUNK / 2 + 1)
	if bodies.ponds.is_empty() and bodies.rivers.is_empty():
		return null
	var chunk_rect: Rect2 = Rect2(
		Vector2(float(chunk.x), float(chunk.y)) * CHUNK_WORLD, Vector2(CHUNK_WORLD, CHUNK_WORLD))
	var root: Node3D = Node3D.new()
	root.name = "Water"
	var any: bool = false
	any = _build_ponds(water, bodies.ponds, chunk_rect, root) or any
	any = _build_rivers(water, bodies.rivers, chunk_rect, root) or any
	if not any:
		root.free()
		return null
	return root


# --- ponds ------------------------------------------------------

## Two upward-facing triangles for quad a-b-c-d (corners in walk order:
## (x0,z0) → (x0+T,z0) → (x0+T,z0+T) → (x0,z0+T)). Winding chosen so
## generate_normals() yields +Y.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(d)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


func _build_ponds(water: WaterPlan, ponds: Array, chunk_rect: Rect2, root: Node3D) -> bool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads: int = 0
	var done: Dictionary = {}
	for pond in ponds:
		if done.has(pond):
			continue
		done[pond] = true
		var cells: Array = []
		var lo_cx: int = int(floor(chunk_rect.position.x / TILE + 0.5))
		var lo_cz: int = int(floor(chunk_rect.position.y / TILE + 0.5))
		for dz in CELLS_PER_CHUNK:
			for dx in CELLS_PER_CHUNK:
				var cx: int = lo_cx + dx
				var cz: int = lo_cz + dz
				var p: Vector2 = Vector2(float(cx) * TILE, float(cz) * TILE)
				if pond.footprint_t(p) >= 1.0:
					continue
				# Islands: skip cells whose carved ground still clears the surface.
				var ground: float = water.noise_h(p) - water.carve_at_cell(cx, cz)
				if ground >= pond.surface_y() - 0.25:
					continue
				cells.append(Vector2i(cx, cz))
		for c in cells:
			var x0: float = float(c.x) * TILE - TILE * 0.5
			var z0: float = float(c.y) * TILE - TILE * 0.5
			var y: float = pond.surface_y()
			_quad(st, Vector3(x0, y, z0), Vector3(x0 + TILE, y, z0),
				Vector3(x0 + TILE, y, z0 + TILE), Vector3(x0, y, z0 + TILE))
			quads += 1
		if not cells.is_empty():
			_pond_volume(pond, cells, root)
	if quads == 0:
		return false
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "PondSheet"
	mi.mesh = st.commit()
	mi.material_override = WaterSurfaceBuilder.pond_material()
	root.add_child(mi)
	return true


func _pond_volume(pond: PondStamp, cells: Array, root: Node3D) -> void:
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var area: Area3D = Area3D.new()
	area.name = "PondVolume"
	area.collision_layer = WATER_LAYER
	area.collision_mask = 0
	area.monitoring = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	var span: Vector2 = Vector2(float(hi.x - lo.x + 1), float(hi.y - lo.y + 1)) * TILE
	var height: float = pond.surface_y() - pond.bed_y() + 1.0
	box.size = Vector3(span.x, height, span.y)
	shape.shape = box
	area.add_child(shape)
	area.position = Vector3(
		(float(lo.x) + float(hi.x)) * 0.5 * TILE,
		pond.surface_y() - height * 0.5,
		(float(lo.y) + float(hi.y)) * 0.5 * TILE)
	area.set_meta("surface_y", pond.surface_y())
	root.add_child(area)


# --- rivers -----------------------------------------------------

## Averaged unit tangent at sample i (mean of the adjacent segment tangents).
## Both quads meeting at a sample use THIS tangent for their shared edge, so
## the ribbon is crack-free at bends (per-quad perpendiculars left mitre gaps
## and overlaps — overlapping translucent quads double-blended into hard-edged
## bright patches).
static func _tangent_at(river: RiverTrace, i: int) -> Vector2:
	var n: int = river.points.size()
	var t: Vector2 = Vector2.ZERO
	if i > 0:
		t += (river.points[i] - river.points[i - 1]).normalized()
	if i < n - 1:
		t += (river.points[i + 1] - river.points[i]).normalized()
	if t.length_squared() < 0.000001:
		return Vector2.RIGHT
	return t.normalized()


## Ribbon samples inside a pond footprint are dropped: the pond sheet owns
## that water, and a ribbon continuing across it z-fights the sheet (the
## bright plate over the pond in the owner's screenshot).
static func _sample_in_pond(river: RiverTrace, p: Vector2) -> bool:
	if river.source_pool != null and river.source_pool.footprint_t(p) < POND_SKIP_T:
		return true
	if river.pond != null and river.pond.footprint_t(p) < POND_SKIP_T:
		return true
	return false


func _build_rivers(_water: WaterPlan, rivers: Array, chunk_rect: Rect2, root: Node3D) -> bool:
	var grown: Rect2 = chunk_rect.grow(TILE)
	var built: bool = false
	for river in rivers:
		var prof: PackedFloat32Array = WaterSurfaceBuilder.surface_profile(river)
		var steep: PackedFloat32Array = WaterSurfaceBuilder.steepness_profile(river)
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
		var strip: int = 0
		for i in range(0, river.points.size() - 1):
			# Keep segments overlapping the grown chunk (1 tile skirt kills
			# seams), outside pond footprints (the sheets own that water).
			if not (grown.has_point(river.points[i]) or grown.has_point(river.points[i + 1])):
				continue
			if _sample_in_pond(river, river.points[i]) or _sample_in_pond(river, river.points[i + 1]):
				continue
			_ribbon_quad(st, river, prof, steep, i)
			strip += 1
		if strip == 0:
			continue
		st.generate_normals()
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "River_%d_%d" % [river.source_cell.x, river.source_cell.y]
		mi.mesh = st.commit()
		mi.material_override = WaterSurfaceBuilder.river_material()
		root.add_child(mi)
		_river_volumes(river, prof, grown, root)
		built = true
	return built


func _ribbon_quad(st: SurfaceTool, river: RiverTrace, prof: PackedFloat32Array,
		steep: PackedFloat32Array, i: int) -> void:
	var a: Vector2 = river.points[i]
	var b: Vector2 = river.points[i + 1]
	var tan_a: Vector2 = WaterSurfaceBuilder._tangent_at(river, i)
	var tan_b: Vector2 = WaterSurfaceBuilder._tangent_at(river, i + 1)
	var perp_a: Vector2 = Vector2(-tan_a.y, tan_a.x)
	var perp_b: Vector2 = Vector2(-tan_b.y, tan_b.x)
	var la: Vector2 = a + perp_a * river.widths[i]
	var ra: Vector2 = a - perp_a * river.widths[i]
	var lb: Vector2 = b + perp_b * river.widths[i + 1]
	var rb: Vector2 = b - perp_b * river.widths[i + 1]
	var ya: float = prof[i]
	var yb: float = prof[i + 1]
	var ca: Color = Color(tan_a.x, 0.0, tan_a.y, steep[i])
	var cb: Color = Color(tan_b.x, 0.0, tan_b.y, steep[i + 1])
	# two triangles, wound so generate_normals() yields +Y (la is LEFT of flow)
	for v in [[la, ya, ca], [rb, yb, cb], [ra, ya, ca], [la, ya, ca], [lb, yb, cb], [rb, yb, cb]]:
		st.set_custom(0, v[2])
		st.set_uv(Vector2(0.0, float(i)))
		st.add_vertex(Vector3(v[0].x, v[1], v[0].y))


func _river_volumes(river: RiverTrace, prof: PackedFloat32Array, grown: Rect2, root: Node3D) -> void:
	var i: int = 0
	while i < river.points.size() - 1:
		var j: int = mini(i + VOLUME_STRIDE, river.points.size() - 1)
		var a: Vector2 = river.points[i]
		var b: Vector2 = river.points[j]
		if grown.has_point(a) or grown.has_point(b):
			var area: Area3D = Area3D.new()
			area.name = "RiverVolume"
			area.collision_layer = WATER_LAYER
			area.collision_mask = 0
			area.monitoring = false
			var shape: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			var depth: float = prof[i] - river.beds[i] + 1.0
			box.size = Vector3(a.distance_to(b) + 2.0, depth, river.widths[i] * 2.0 + 4.0)
			shape.shape = box
			area.add_child(shape)
			var mid: Vector2 = (a + b) * 0.5
			area.position = Vector3(mid.x, prof[i] - depth * 0.5, mid.y)
			var ang: float = atan2(b.x - a.x, b.y - a.y)
			area.rotation = Vector3(0.0, ang - PI * 0.5, 0.0)
			area.set_meta("surface_y", maxf(prof[i], prof[j]))
			var flow: Vector2 = (b - a).normalized()
			area.set_meta("flow", Vector3(flow.x, 0.0, flow.y))
			root.add_child(area)
		i = j
	# (Area boxes overlap slightly and hug the profile coarsely — swimming
	# tolerance, not rendering. VOLUME_STRIDE=4 => one box per 48 u.)
