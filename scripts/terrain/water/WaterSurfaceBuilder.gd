# scripts/terrain/water/WaterSurfaceBuilder.gd
# Per-chunk water as a SECOND HEIGHTFIELD: one sheet per chunk whose per-cell
# level comes from the covering body (pond level, or the river's monotone
# surface profile), flood-filled across every submerged cell and overshot one
# cell INTO the banks — the depth buffer then clips the sheet exactly where
# terrain rises through it, so the visible waterline is the true terrain/plane
# intersection, never a mesh edge (water always reaches land at its own
# height). A single unified shader renders still and flowing water; CUSTOM0
# carries the per-vertex flow vector (zero in lakes) and steepness, so
# lake→river transitions are seamless. Swim volumes ride along as Area3Ds.
# Built beside each terrain chunk and parented under it (evicts together).
class_name WaterSurfaceBuilder
extends RefCounted

const TILE := 24.0
const CELLS_PER_CHUNK := 8            # = TerrainChunkMesher.CELLS_PER_CHUNK
const CHUNK_WORLD := TILE * CELLS_PER_CHUNK
const RIBBON_DEPTH_OFFSET := 1.5      # river surface above its carved bed
const STOREY := 4.0                   # = HeightfieldPlan.STOREY_HEIGHT
const FLOOR_CLEARANCE := 0.8          # river surface above the QUANTIZED floor estimate
const STEEP_RISE := 5.0               # bed drop per sample that reads as rapids=1
const WET_EPS := 0.15                 # ground this far under the level counts as wet
const SHELF_DEPTH := 4.5              # flood only spreads over shelves this shallow
const CHANNEL_MARGIN := TILE * 0.75   # river level reaches this far past the carve width
const FLOOD_STEPS := 2                # submerged-shelf flood distance (cells)
const FIELD_MARGIN := 3               # region margin = FLOOD_STEPS + rim ring
const VOLUME_STRIDE := 4              # river swim-box every N samples
const WATER_LAYER := 1 << 7

const _CARDINALS_8 := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

static var _sheet_material: ShaderMaterial = null


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


## The storey-quantized ground the mesher will roughly render at a cell (raw
## noise minus carve, "mean"-rounded to the 4m grid, floored at storey 0).
## The trickle-down clamp can only LOWER cells further, and the rim overshoot
## absorbs that slack.
static func ground_estimate(water: WaterPlan, cx: int, cz: int) -> float:
	var raw: float = water.noise_h(Vector2(float(cx) * TILE, float(cz) * TILE)) \
		- water.carve_at_cell(cx, cz)
	return maxf(roundf(raw / STOREY) * STOREY, 0.0)


## The per-cell water field over the chunk plus FIELD_MARGIN: for every cell
## that ends up in the sheet, {level, flow: Vector2, steep: float, wet: bool}.
## Three passes: (1) body influence assigns levels; (2) a bounded flood marks
## submerged shelves wet even past the carve (quantization can sink bank cells
## below the level); (3) every dry 8-neighbour of a wet cell joins as RIM at
## the wet level — the bank overshoot the depth buffer clips to the waterline.
## Pure function of (water plan, chunk): margin ≥ flood + rim keeps the field
## identical for border cells no matter which chunk computes them.
static func compute_field(water: WaterPlan, chunk: Vector2i) -> Dictionary:
	var centre_cx: int = chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var centre_cz: int = chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var bodies: Dictionary = water.bodies_near(
		Vector2i(centre_cx, centre_cz), CELLS_PER_CHUNK / 2 + 1 + FIELD_MARGIN)
	if bodies.ponds.is_empty() and bodies.rivers.is_empty():
		return {}
	var profs: Array = []
	var steeps: Array = []
	for river in bodies.rivers:
		profs.append(surface_profile(river))
		steeps.append(steepness_profile(river))

	# Pass 1: body influence.
	var lo: Vector2i = Vector2i(
		chunk.x * CELLS_PER_CHUNK - FIELD_MARGIN, chunk.y * CELLS_PER_CHUNK - FIELD_MARGIN)
	var n: int = CELLS_PER_CHUNK + 2 * FIELD_MARGIN
	var field: Dictionary = {}
	var ground: Dictionary = {}
	for dz in n:
		for dx in n:
			var cell: Vector2i = lo + Vector2i(dx, dz)
			var p: Vector2 = Vector2(float(cell.x) * TILE, float(cell.y) * TILE)
			var level: float = -INF
			var flow: Vector2 = Vector2.ZERO
			var steep: float = 0.0
			for pond in bodies.ponds:
				if pond.footprint_t(p) < 1.0:
					level = maxf(level, pond.surface_y())
			for r in bodies.rivers.size():
				var river: RiverTrace = bodies.rivers[r]
				var reach: float = WaterPlan.W_MAX + WaterPlan.FEATHER + CHANNEL_MARGIN
				if not river.bounds().grow(reach).has_point(p):
					continue
				var best_j: int = -1
				var best_d: float = INF
				for j in river.points.size():
					var d: float = p.distance_to(river.points[j])
					if d < best_d:
						best_d = d
						best_j = j
				if best_j >= 0 and best_d <= river.widths[best_j] + WaterPlan.FEATHER + CHANNEL_MARGIN:
					var lv: float = profs[r][best_j]
					if lv > level:
						level = lv
						steep = steeps[r][best_j]
						var j1: int = maxi(best_j - 1, 0)
						var j2: int = mini(best_j + 1, river.points.size() - 1)
						if j2 > j1:
							flow = (river.points[j2] - river.points[j1]).normalized()
			if level == -INF:
				continue
			ground[cell] = ground_estimate(water, cell.x, cell.y)
			field[cell] = {
				"level": level, "flow": flow, "steep": steep,
				"wet": ground[cell] < level - WET_EPS,
			}

	# Pass 2: bounded flood — submerged shelves continue the neighbouring level.
	for _step in FLOOD_STEPS:
		var grew: Array = []
		for cell in field:
			if not field[cell].wet:
				continue
			for d in _CARDINALS_8:
				var nb: Vector2i = cell + d
				if nb.x < lo.x or nb.y < lo.y or nb.x >= lo.x + n or nb.y >= lo.y + n:
					continue
				if field.has(nb) and field[nb].wet:
					continue
				if not ground.has(nb):
					ground[nb] = ground_estimate(water, nb.x, nb.y)
				var lv: float = field[cell].level
				# Spread only over SHALLOW shelves (quantization sank a bank
				# cell just under the level). A floor far below belongs to a
				# lower reach/body — painting this level over it would hover
				# a sheet above the drop (the floating plates at cascades).
				if ground[nb] < lv - WET_EPS and ground[nb] > lv - SHELF_DEPTH:
					if field.has(nb):
						lv = maxf(lv, field[nb].level)
					grew.append([nb, {
						"level": lv, "flow": field[cell].flow,
						"steep": field[cell].steep, "wet": true,
					}])
		for g in grew:
			field[g[0]] = g[1]

	# Pass 3: rim overshoot — dry 8-neighbours that rise ABOVE the wet level
	# join at that level so the sheet dives into the bank and the depth buffer
	# draws the true waterline (islands included). Neighbours far BELOW the
	# level are skipped: they belong to a lower reach, and a plane there would
	# hover in midair over the drop; corner averaging between wet cells of
	# different levels bridges cascades on its own.
	var rims: Dictionary = {}
	for cell in field:
		if not field[cell].wet:
			continue
		for d in _CARDINALS_8:
			var nb: Vector2i = cell + d
			if field.has(nb) and field[nb].wet:
				continue
			if not ground.has(nb):
				ground[nb] = ground_estimate(water, nb.x, nb.y)
			if ground[nb] < field[cell].level - WET_EPS:
				continue   # a drop-off, not a bank
			var prev = rims.get(nb)
			if prev == null or field[cell].level > prev.level:
				rims[nb] = {
					"level": field[cell].level, "flow": field[cell].flow,
					"steep": field[cell].steep, "wet": false,
				}
	for nb in rims:
		field[nb] = rims[nb]

	# Drop influence-only cells that are neither wet nor rim (dry banks whose
	# own level never met water — e.g. island interiors).
	var out: Dictionary = {}
	for cell in field:
		if field[cell].wet or rims.has(cell):
			out[cell] = field[cell]
	return out


static func _make_material() -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://terrain/water/water_unified.gdshader")
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.008
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	mat.set_shader_parameter("noise_tex", tex)
	return mat


static func sheet_material() -> ShaderMaterial:
	if _sheet_material == null:
		_sheet_material = _make_material()
	return _sheet_material


## Build the water node for a chunk, or null when the chunk is dry.
func build_chunk(water: WaterPlan, chunk: Vector2i) -> Node3D:
	var field: Dictionary = compute_field(water, chunk)
	if field.is_empty():
		return null
	var lo_cx: int = chunk.x * CELLS_PER_CHUNK
	var lo_cz: int = chunk.y * CELLS_PER_CHUNK

	# Shared corner heights/attributes: average level + flow, max steepness of
	# the included cells around each corner — a watertight sheet that slopes
	# smoothly along rivers and stays dead flat on lakes.
	var corner_level: Dictionary = {}
	var corner_flow: Dictionary = {}
	var corner_steep: Dictionary = {}
	var corner_count: Dictionary = {}
	for cell in field:
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var k: Vector2i = cell + off
			corner_level[k] = corner_level.get(k, 0.0) + field[cell].level
			corner_flow[k] = corner_flow.get(k, Vector2.ZERO) + field[cell].flow
			corner_steep[k] = maxf(corner_steep.get(k, 0.0), field[cell].steep)
			corner_count[k] = corner_count.get(k, 0) + 1

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var quads: int = 0
	for cell in field:
		if cell.x < lo_cx or cell.x >= lo_cx + CELLS_PER_CHUNK \
				or cell.y < lo_cz or cell.y >= lo_cz + CELLS_PER_CHUNK:
			continue   # margin cells only shape shared corners
		_sheet_quad(st, cell, corner_level, corner_flow, corner_steep, corner_count)
		quads += 1
	if quads == 0:
		return null

	var root: Node3D = Node3D.new()
	root.name = "Water"
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "WaterSheet"
	mi.mesh = st.commit()
	mi.material_override = WaterSurfaceBuilder.sheet_material()
	root.add_child(mi)
	_build_volumes(water, chunk, field, root)
	return root


## One cell of the sheet: two triangles over the cell footprint with shared
## corner heights (wound so generate_normals() yields +Y).
func _sheet_quad(st: SurfaceTool, cell: Vector2i, corner_level: Dictionary,
		corner_flow: Dictionary, corner_steep: Dictionary, corner_count: Dictionary) -> void:
	var keys: Array = [
		cell, cell + Vector2i(1, 0), cell + Vector2i(1, 1), cell + Vector2i(0, 1),
	]   # min corner, +x, +xz, +z — walk order around the quad
	var pos: Array = []
	var cust: Array = []
	for k in keys:
		var cnt: float = float(corner_count[k])
		var lvl: float = corner_level[k] / cnt
		var fl: Vector2 = corner_flow[k] / cnt
		pos.append(Vector3(
			(float(k.x) - 0.5) * TILE, lvl, (float(k.y) - 0.5) * TILE))
		cust.append(Color(fl.x, 0.0, fl.y, corner_steep[k]))
	# triangles (0,3,2) and (0,2,1) face +Y
	for idx in [0, 3, 2, 0, 2, 1]:
		st.set_custom(0, cust[idx])
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(pos[idx])


# --- swim volumes ------------------------------------------------

func _build_volumes(water: WaterPlan, chunk: Vector2i, field: Dictionary, root: Node3D) -> void:
	var centre_cx: int = chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var centre_cz: int = chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var bodies: Dictionary = water.bodies_near(Vector2i(centre_cx, centre_cz), CELLS_PER_CHUNK / 2 + 1)
	var lo_cx: int = chunk.x * CELLS_PER_CHUNK
	var lo_cz: int = chunk.y * CELLS_PER_CHUNK
	var grown: Rect2 = Rect2(
		Vector2(float(chunk.x), float(chunk.y)) * CHUNK_WORLD,
		Vector2(CHUNK_WORLD, CHUNK_WORLD)).grow(TILE)
	var done_ponds: Dictionary = {}
	for pond in bodies.ponds:
		if done_ponds.has(pond):
			continue
		done_ponds[pond] = true
		var cells: Array = []
		for cell in field:
			if not field[cell].wet:
				continue
			if cell.x < lo_cx or cell.x >= lo_cx + CELLS_PER_CHUNK \
					or cell.y < lo_cz or cell.y >= lo_cz + CELLS_PER_CHUNK:
				continue
			if pond.footprint_t(Vector2(float(cell.x) * TILE, float(cell.y) * TILE)) < 1.2:
				cells.append(cell)
		if not cells.is_empty():
			_pond_volume(pond, cells, root)
	for river in bodies.rivers:
		_river_volumes(river, WaterSurfaceBuilder.surface_profile(river), grown, root)


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
