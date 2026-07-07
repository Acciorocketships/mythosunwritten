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
# Max hover of ANY field cell's level over its real rendered ground (pass-1
# floor-consistency). Legit in-channel water reaches bed+RIBBON_DEPTH_OFFSET
# with the bed up to half a storey (2m) above its quantized floor = 3.5m; a
# neighbouring terrace one full storey (4m) down must NEVER qualify — levels
# painted over it hover the sheet in mid-air (the owner's floating water).
const SHELF_DEPTH := 3.7
# River level reaches only a hair past the CARVE width: the carve guarantees
# those cells sit at the bed. A generous margin painted the river's level onto
# terrain dips beyond the channel — water sheets embedded in hillsides.
const CHANNEL_MARGIN := 4.0
# Flood runs until it MEETS RISING GROUND (bounded here for purity/perf):
# stopping mid-shelf left the sheet's dip boundary in open water — a sunken
# edge band with the shelf continuing beyond it (owner's shore gaps).
const FLOOD_STEPS := 6                # submerged-shelf flood distance (cells)
const FIELD_MARGIN := 7               # region margin = FLOOD_STEPS + rim ring
# Corners only average adjacent cells within this of the cell's own level:
# bigger jumps SPLIT the sheet (two clean edges at the cliff the wall hides)
# instead of bridging them with giant slanted curtain quads ("water coming
# out of the wall", stray polygons on hillsides). Under a storey, so normal
# sloping reaches stay watertight.
const BRIDGE_MAX := 2.5
# Flood (pass 2) rescues neighbour cells whose REAL rendered ground sits
# under the level: quantization-sunk banks and side shelves are honest water
# (they are below the surface!) — leaving the shallow band dry rendered the
# sheet's edge hovering over it (films, fall shoulders poking over side
# shelves). Bounded well below one full storey: terraces 4m down belong to a
# lower reach — flooding them hung plates over every cliff lip.
const FLOOD_MAX := 2.5
const VOLUME_STRIDE := 4              # river swim-box every N samples
const WATER_LAYER := 1 << 7
# Sub-quads per cell edge. The shader displaces real chop waves (~14-26m
# wavelength); 24m cell quads can't bend, 3m vertex pitch can.
const SUBDIV := 8

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


## The per-cell water field over the chunk plus FIELD_MARGIN: for every cell
## that ends up in the sheet, {level, flow: Vector2, steep: float, wet: bool}.
## `region` is the chunk's heightfield region (the REAL clamped/rendered
## terrain): the raw-noise estimate this used to reason about sat storeys
## ABOVE the rendered ground wherever the trickle-down clamp lowered cells —
## exactly at cascade staircases — so rims and reach levels hung in mid-air
## (the owner's floating planes). Three passes: (1) body influence assigns
## levels — each cell takes the nearest FLOOR-CONSISTENT sample, and is wet
## only if carved or inside the channel width; (2) a bounded flood marks
## submerged shelves wet past the carve (quantization can sink bank cells
## below the level); (3) every dry 8-neighbour of a wet cell joins as RIM at
## the wet level — the bank overshoot the depth buffer clips to the waterline.
## Pure function of (water plan, chunk, region): margin ≥ flood + rim keeps
## the field identical for border cells no matter which chunk computes them.
static func compute_field(water: WaterPlan, chunk: Vector2i, region) -> Dictionary:
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
			var real: float = region.surface_height(cell.x, cell.y)
			var level: float = -INF
			var flow: Vector2 = Vector2.ZERO
			var steep: float = 0.0
			var in_channel := false
			# Inside a pond footprint the POND owns the water level: a river's
			# higher upstream profile leaking in via nearest-sample lookup
			# painted raised rectangular sheets hovering over lakes. But only
			# where the REAL rendered floor supports it — the trickle-down
			# clamp can sink bowl cells at cliff staircases storeys below the
			# stamp, and an unchecked pond level there hangs the sheet in
			# mid-air (healthy bowls sit exactly 3.0m over their quantized
			# floor, within SHELF_DEPTH).
			var pond_level: float = -INF
			var pond_interior := false
			for pond in bodies.ponds:
				var ft: float = pond.footprint_t(p)
				if ft < 1.0:
					pond_level = maxf(pond_level, pond.surface_y())
					if ft < 0.75:
						pond_interior = true
			# Floor-consistency applies to the pond's RIM BAND only: a
			# clamp-sunk cell deep INSIDE the footprint is deep lake water,
			# not a hover risk — dropping it opened see-through holes mid-pond
			# (owner: "gap where you can see under the water").
			if pond_level - real > SHELF_DEPTH and not pond_interior:
				pond_level = -INF
			level = pond_level
			for r in bodies.rivers.size():
				var river: RiverTrace = bodies.rivers[r]
				var reach: float = WaterPlan.W_MAX + WaterPlan.FEATHER + CHANNEL_MARGIN
				if not river.bounds().grow(reach).has_point(p):
					continue
				var best_j: int = -1
				var best_d: float = INF
				var low_j: int = -1     # nearest sample whose surface the REAL floor supports
				var low_d: float = INF
				# Flow is the DISTANCE-WEIGHTED average tangent of every sample
				# in reach — the nearest-sample tangent alone flips between
				# adjacent reaches at bends, making water run bank-to-bank.
				var flow_acc: Vector2 = Vector2.ZERO
				for j in river.points.size():
					var d: float = p.distance_to(river.points[j])
					if d < best_d:
						best_d = d
						best_j = j
					if profs[r][j] - real <= SHELF_DEPTH and d < low_d:
						low_d = d
						low_j = j
					var infl: float = river.widths[j] + WaterPlan.FEATHER + CHANNEL_MARGIN
					if d < infl and j < river.points.size() - 1:
						var w: float = 1.0 - d / infl
						flow_acc += (river.points[j + 1] - river.points[j]).normalized() * w * w
				if best_j < 0:
					continue
				# CASCADE consistency: a cell belongs to the reach whose surface
				# its REAL rendered floor supports. At a drop lip the nearest
				# sample is often the UPSTREAM one — its level would hover
				# storeys above the clamped gorge floor (the owner's floating
				# planes). Snap to the nearest floor-consistent sample instead;
				# the waterfall ribbons span the face between the reaches.
				var j_use: int = best_j
				var d_use: float = best_d
				if profs[r][best_j] - real > SHELF_DEPTH:
					j_use = low_j
					d_use = low_d
				if j_use < 0:
					continue
				var infl_best: float = river.widths[j_use] + WaterPlan.FEATHER + CHANNEL_MARGIN
				if d_use <= infl_best:
					var lv: float = profs[r][j_use]
					# Rivers may not RAISE the level inside a pond footprint —
					# the pond owns its surface (backwater already flattens the
					# profile to the pond level at the mouth).
					if pond_level > -INF:
						lv = minf(lv, pond_level)
					if lv > level:
						level = lv
						steep = steeps[r][j_use]
						in_channel = d_use <= river.widths[j_use]
						if flow_acc.length_squared() > 0.000001:
							# Flow fades to ZERO at the channel edge — no flux
							# into or out of the banks; wide pools read still.
							var edge_t: float = clampf(1.5 * (1.0 - d_use / infl_best), 0.0, 1.0)
							flow = flow_acc.normalized() * edge_t
			if level == -INF:
				continue
			ground[cell] = real
			# ANCHORED water only: a wet cell is part of the water network —
			# carved (basin/channel bed) or inside the channel's own width
			# (flat-valley reaches carve ~0 where bed meets ground). DEPTH is
			# NOT evidence: a dry terrace below an upstream reach's level is
			# not water (the owner's floating tiles beside cascades).
			var anchored: bool = in_channel or water.carve_at_cell(cell.x, cell.y) > 0.05
			field[cell] = {
				"level": level, "flow": flow, "steep": steep,
				"wet": anchored and real < level - WET_EPS,
				"ground": real, "shore": 0.0,
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
					ground[nb] = region.surface_height(nb.x, nb.y)
				var lv: float = field[cell].level
				# Spread over every SUBMERGED shelf (real ground under the
				# level, down to FLOOD_MAX). A floor far below belongs to a
				# lower reach/body — painting this level over it would hover
				# a sheet above the drop (the floating plates at cascades).
				if ground[nb] < lv - WET_EPS and ground[nb] > lv - FLOOD_MAX:
					if field.has(nb):
						lv = maxf(lv, field[nb].level)
					# Flooded shelves are pool water: still (zero flow).
					grew.append([nb, {
						"level": lv, "flow": Vector2.ZERO,
						"steep": field[cell].steep, "wet": true,
						"ground": ground[nb], "shore": 0.0,
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
				ground[nb] = region.surface_height(nb.x, nb.y)
			# Skip only genuine DROP-OFFS (a lower reach owns that water; the
			# flood pass already claimed every submerged shelf).
			if ground[nb] < field[cell].level - 0.5:
				continue
			var prev = rims.get(nb)
			if prev == null or field[cell].level > prev.level:
				# Rim overshoot dives into the bank: still water (zero flow —
				# flux through the shoreline must be zero). Shore feeds the
				# foam lap line and the swell kill; WALL shores (bank well
				# above the water) get a reduced value — a full-strength lap
				# line traced every quantized wall in solid white, outlining
				# the cell grid (owner: "completely rectangular coastline").
				rims[nb] = {
					"level": field[cell].level, "flow": Vector2.ZERO,
					"steep": field[cell].steep, "wet": false,
					"ground": ground[nb],
					"shore": 1.0 if ground[nb] <= field[cell].level + 0.6 else 0.45,
				}
	for nb in rims:
		field[nb] = rims[nb]

	# Shore damping: wet cells TOUCHING the shore slow down; the waterline
	# vertices themselves reach ZERO via corner-averaging with the rim cells
	# (which always carry zero flow) — that is the actual no-flux boundary.
	# Moderate, NOT heavy: narrow channels are entirely shore-adjacent cells,
	# and heavy damping froze whole rivers still. The same touch also grades
	# the baked shore proximity one cell into the water for the foam lap line.
	# CREST cells (either side of a waterfall split) damp HARD: the sheet
	# there must barely swell or the moving surface hinges against the pinned
	# crest edge and the static slab — a visible crease and breathing slit
	# (owner: "water not blending into waterfall").
	for cell in field:
		if not field[cell].wet:
			continue
		for d in _CARDINALS_8:
			var nb: Vector2i = cell + d
			if not field.has(nb) or not field[nb].wet:
				field[cell].flow *= 0.5
				field[cell].shore = maxf(field[cell].shore, 0.6)
				break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cell + d
			if field.has(nb) and field[nb].wet \
					and absf(field[cell].level - field[nb].level) > BRIDGE_MAX:
				field[cell].shore = maxf(field[cell].shore, 0.8)
				break

	# Drop influence-only cells that are neither wet nor rim (dry banks whose
	# own level never met water — e.g. island interiors).
	var out: Dictionary = {}
	for cell in field:
		if field[cell].wet or rims.has(cell):
			out[cell] = field[cell]
	return out


static var _noise_texture: NoiseTexture2D = null
static var _fall_material: ShaderMaterial = null


static func _noise_tex() -> NoiseTexture2D:
	if _noise_texture == null:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = 7
		noise.frequency = 0.008
		_noise_texture = NoiseTexture2D.new()
		_noise_texture.noise = noise
		_noise_texture.seamless = true
	return _noise_texture


static func _make_material() -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://terrain/water/water_unified.gdshader")
	mat.set_shader_parameter("noise_tex", _noise_tex())
	return mat


static func sheet_material() -> ShaderMaterial:
	if _sheet_material == null:
		_sheet_material = _make_material()
	return _sheet_material


static func waterfall_material() -> ShaderMaterial:
	if _fall_material == null:
		_fall_material = ShaderMaterial.new()
		_fall_material.shader = load("res://terrain/water/waterfall.gdshader")
		_fall_material.set_shader_parameter("noise_tex", _noise_tex())
	return _fall_material


## Waterfall curtains, derived from the FIELD itself: wherever a WET cell's
## level sits more than BRIDGE_MAX above what lies across a cardinal edge —
## a lower pool, a lower rim's ground, or bare terrain outside the field —
## the sheet deliberately ends (corner averaging refuses to bridge) and a
## curtain fills exactly that face. Drops onto DRY ground curtain too (weir
## edges, reach ends): the sheet must never end in mid-air with an uncovered
## face below it (the owner's floating edges). {mid, tangent, half_width,
## top, bottom, kind}; top == the upstream level EXACTLY — the crest corners
## snap to the same value, so lip and sheet always meet. A curtain is owned
## by the chunk containing its WET upper cell. Pure fn of (field, chunk, region).
static func compute_ribbons(field: Dictionary, chunk: Vector2i, region) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lo_cx: int = chunk.x * CELLS_PER_CHUNK
	var lo_cz: int = chunk.y * CELLS_PER_CHUNK
	for cell: Vector2i in field:
		if not field[cell].wet:
			continue
		if cell.x < lo_cx or cell.x >= lo_cx + CELLS_PER_CHUNK \
				or cell.y < lo_cz or cell.y >= lo_cz + CELLS_PER_CHUNK:
			continue
		var lvl: float = field[cell].level
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cell + d
			var kind: String
			var bottom: float
			if field.has(nb) and field[nb].wet:
				if lvl - field[nb].level <= BRIDGE_MAX:
					continue
				kind = "wet"
				# Deep enough under the plunge pool that the flattened tail
				# stays submerged through the LOWEST swell trough (the pool
				# swells ~±0.8m; a shallow tail breached as a white slab).
				bottom = field[nb].level - 0.9
			else:
				var g: float = field[nb].ground if field.has(nb) \
					else region.surface_height(nb.x, nb.y)
				if lvl - g <= BRIDGE_MAX:
					continue
				kind = "dry"
				bottom = g - 0.5
			out.append({
				"mid": Vector2((float(cell.x) + float(d.x) * 0.5) * TILE,
						(float(cell.y) + float(d.y) * 0.5) * TILE),
				"tangent": Vector2(float(d.x), float(d.y)),
				# A hair wider than the cell: perpendicular slabs at an
				# L-corner OVERLAP instead of butt-jointing with a notch
				# (owner: "waterfalls not smoothly connected at corners").
				"half_width": TILE * 0.5 + 0.7,
				"top": lvl,
				"bottom": bottom,
				"kind": kind,
			})
	return out


# Horizontal throw of the arc as a fraction of the drop, clamped. The curtain
# is a PROJECTILE parabola parametrized by flight time t: offset grows
# linearly, fall quadratically — the water exits the lip travelling
# HORIZONTALLY, tangent-continuous with the flat sheet above, then bends into
# the drop (owner: "the water should exit the top travelling horizontally,
# then curve down").
const FALL_REACH := 0.35
const FALL_REACH_MIN := 1.5
const FALL_REACH_MAX := 6.0
const FALL_PAR_ROWS := 5         # parabola segments of the curtain
const FALL_FILLET_ROWS := 5      # circular ease-out segments at the plunge
const FALL_OVERLAP := 1.1        # upstream embed under the upper sheet
const FALL_BEND_SLOPE := 4.0     # world slope where the plunge arc takes over


## Waterfall centreline rows: [centre: Vector2, y, width_scale, uv_y] for the
## front sheet plus the back sheet offset along the local curve normal. The
## profile is an OGEE: an upstream overlap row embedded just under the upper
## sheet (no slit can open when the sheet swells), a horizontal-exit parabola,
## then a C1 mirrored-parabola FILLET that flattens back to horizontal right
## at the lower surface — the fall bends smoothly into the pool instead of
## stabbing it at an angle (owner: "a smooth curve back up to connect with
## the water at the bottom") — and a flat submerged runout. uv_y == the
## normalized height fraction (0 crest .. 1 plunge, >1 runout).
static func fall_rows(r: Dictionary) -> Dictionary:
	var mid: Vector2 = r.mid
	var tangent: Vector2 = r.tangent
	var top: float = r.top
	var bottom: float = r.bottom
	var h: float = maxf(top - bottom, 0.5)
	var reach: float = clampf(h * FALL_REACH, FALL_REACH_MIN, FALL_REACH_MAX)
	# Hand the parabola off to the fillet once it steepens to FALL_BEND_SLOPE;
	# the fillet is a CIRCULAR ARC sampled uniformly in angle — its chords
	# flatten progressively to exactly horizontal at the lower surface, so
	# the fall never stabs the pool at an angle however tall the drop is.
	var t_star: float = minf(FALL_BEND_SLOPE * reach / (2.0 * h), 0.97)
	var fillet_h: float = h * (1.0 - t_star * t_star)   # drop the arc covers
	var slope0: float = 2.0 * h * t_star / reach
	var th0: float = atan(slope0)
	var arc_r: float = fillet_h / maxf(1.0 - cos(th0), 0.02)
	var x_star: float = reach * t_star
	var y_star: float = bottom + fillet_h
	var front: Array = []
	front.append([mid - tangent * FALL_OVERLAP, top - 0.16, 1.0, 0.0])
	for i in FALL_PAR_ROWS + 1:
		var t: float = t_star * float(i) / float(FALL_PAR_ROWS)
		var y: float = top - h * t * t
		front.append([mid + tangent * (reach * t), y,
			1.0 + 0.20 * (top - y) / h, (top - y) / h])
	for j in range(1, FALL_FILLET_ROWS + 1):
		var th: float = th0 * (1.0 - float(j) / float(FALL_FILLET_ROWS))
		var x: float = x_star + arc_r * (sin(th0) - sin(th))
		var y: float = y_star - arc_r * (cos(th) - cos(th0))
		front.append([mid + tangent * x, y,
			1.0 + 0.20 * (top - y) / h, (top - y) / h])
	var x_end: float = x_star + arc_r * sin(th0)
	front.append([mid + tangent * (x_end + 1.6), bottom - 0.12, 1.36, 1.04])
	front.append([mid + tangent * (x_end + 3.2), bottom - 0.28, 1.5, 1.08])
	# Back sheet: each row pushed along the local curve normal (finite
	# difference in the (along, y) plane), so the slab keeps uniform thickness
	# from the rolled-over lip to the submerged runout.
	var thick: float = clampf(h * 0.10, 0.4, 1.2)
	var back: Array = []
	for i in front.size():
		var a: int = maxi(i - 1, 0)
		var b: int = mini(i + 1, front.size() - 1)
		var da: float = (front[b][0] - front[a][0]).dot(tangent)
		var dy: float = front[b][1] - front[a][1]
		var n: Vector2 = Vector2(-dy, da).normalized()   # (along, y) upstream-up
		back.append([front[i][0] - tangent * (n.x * thick),
			front[i][1] - n.y * thick, front[i][2], front[i][3]])
	return {"front": front, "back": back,
		"plunge": Vector3(mid.x + tangent.x * x_end, bottom + 0.15,
			mid.y + tangent.y * x_end),
		"plunge_half_width": r.half_width * 1.2}


## One waterfall: a THICK slab of falling water across the channel — a front
## ogee sheet, a back sheet offset along the curve normal, side walls and a
## rolled-over lip cap, so the fall reads as a volume of water, not a curved
## plane (owner: "they need some depth"). The plunge foam is PARTICLE mist
## (built beside the mesh), not painted churn. cull_disabled renders
## interiors when swimming.
static func _ribbon_mesh(st: SurfaceTool, r: Dictionary) -> void:
	var rows: Dictionary = fall_rows(r)
	var front: Array = rows.front
	var back: Array = rows.back
	var across: Vector2 = Vector2(-r.tangent.y, r.tangent.x) * r.half_width
	_layer_strip(st, front, across, false)
	_layer_strip(st, back, across, true)
	for s in [-1.0, 1.0]:
		for i in front.size() - 1:
			_slab_quad(st,
				[_row_edge(front[i], across, s), _row_edge(front[i + 1], across, s),
					_row_edge(back[i + 1], across, s), _row_edge(back[i], across, s)],
				[front[i][3], front[i + 1][3], back[i + 1][3], back[i][3]])
	# Lip cap: closes the slab's top edge — the water rolling over the crest.
	_slab_quad(st,
		[_row_edge(front[0], across, -1.0), _row_edge(front[0], across, 1.0),
			_row_edge(back[0], across, 1.0), _row_edge(back[0], across, -1.0)],
		[0.0, 0.0, 0.0, 0.0])


## One row edge position: row = [centre: Vector2, y, width_scale, uv_y],
## s = -1 (left) or +1 (right) across the flow.
static func _row_edge(row: Array, across: Vector2, s: float) -> Vector3:
	return Vector3(row[0].x + across.x * row[2] * s, row[1], row[0].y + across.y * row[2] * s)


## One quad, vertices in walk order with per-vertex uv.y (uv.x from position).
static func _slab_quad(st: SurfaceTool, vs: Array, uv_y: Array) -> void:
	var uv_x: Array = [0.0, 1.0, 1.0, 0.0]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_uv(Vector2(uv_x[idx], uv_y[idx]))
		st.add_vertex(vs[idx])


## Quads between consecutive rows ([centre: Vector2, y, width_scale, uv_y]);
## `flip` reverses the winding so the back layer faces away from the slab.
static func _layer_strip(st: SurfaceTool, rows: Array, across: Vector2, flip: bool) -> void:
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var vs: Array = [_row_edge(a, across, -1.0), _row_edge(a, across, 1.0),
			_row_edge(b, across, 1.0), _row_edge(b, across, -1.0)]
		var uv_y: Array = [a[3], a[3], b[3], b[3]]
		if flip:
			vs = [vs[0], vs[3], vs[2], vs[1]]
			uv_y = [uv_y[0], uv_y[3], uv_y[2], uv_y[1]]
		_slab_quad(st, vs, uv_y)


## Build the water node for a chunk, or null when the chunk is dry. `region`
## is the chunk's heightfield region (the streamer computes it for the mesher
## and shares it here — the water field must see the REAL rendered terrain).
func build_chunk(water: WaterPlan, chunk: Vector2i, region) -> Node3D:
	var field: Dictionary = compute_field(water, chunk, region)
	if field.is_empty():
		return null
	var lo_cx: int = chunk.x * CELLS_PER_CHUNK
	var lo_cz: int = chunk.y * CELLS_PER_CHUNK
	var cm: Dictionary = corner_map(field, region)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var quads: int = 0
	for cell in field:
		if cell.x < lo_cx or cell.x >= lo_cx + CELLS_PER_CHUNK \
				or cell.y < lo_cz or cell.y >= lo_cz + CELLS_PER_CHUNK:
			continue   # margin cells only shape shared corners
		for v in sheet_cell_grid(cell, field, cm, water, region):
			st.set_custom(0, v.cust)
			st.set_uv(Vector2(0.0, 0.0))
			st.add_vertex(v.pos)
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
	var ribbons: Array[Dictionary] = compute_ribbons(field, chunk, region)
	if not ribbons.is_empty():
		var rst: SurfaceTool = SurfaceTool.new()
		rst.begin(Mesh.PRIMITIVE_TRIANGLES)
		for r in ribbons:
			_ribbon_mesh(rst, r)
		rst.generate_normals()
		var rmi: MeshInstance3D = MeshInstance3D.new()
		rmi.name = "Waterfalls"
		rmi.mesh = rst.commit()
		rmi.material_override = WaterSurfaceBuilder.waterfall_material()
		root.add_child(rmi)
		# Plunge mist rides each fall, but GPUParticles3D allocates renderer
		# objects — NEVER construct them on the worker thread (SIGABRT race).
		# Stash the ribbon data; the streamer calls build_mist at main-thread
		# integration, same pattern as the biome FX nodes.
		root.set_meta("mist_ribbons", ribbons)
	_build_volumes(water, chunk, field, root)
	return root


## Main-thread pass: build the plunge-mist emitters for a just-integrated
## chunk node (the worker stashed the ribbon data as metadata). Soft particle
## spray where each fall lands — replaces the painted churn apron (owner:
## "you have just textured the water and that looks bad"). Render-only.
static func build_mist(chunk_node: Node3D) -> void:
	if Helper.is_headless():
		return
	for water_root in chunk_node.get_children():
		if not water_root.has_meta("mist_ribbons"):
			continue
		for r in water_root.get_meta("mist_ribbons"):
			water_root.add_child(_mist_node(r))
		water_root.remove_meta("mist_ribbons")


## Corner adjacency map: for every grid corner touched by the field, the four
## sharer CELLS around it — present cells carry their field entry; absent
## cells carry a stub with the REAL rendered ground (so corner logic can bury
## edges under the terrain beyond the sheet). Pure fn of (field, region).
static func corner_map(field: Dictionary, region) -> Dictionary:
	var cm: Dictionary = {}
	for cell in field:
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var k: Vector2i = cell + off
			if cm.has(k):
				continue
			var sharers: Dictionary = {}
			for sh: Vector2i in [k + Vector2i(-1, -1), k + Vector2i(0, -1),
					k + Vector2i(-1, 0), k]:
				if field.has(sh):
					sharers[sh] = field[sh]
				else:
					sharers[sh] = {
						"level": -INF, "wet": false, "missing": true,
						"ground": region.surface_height(sh.x, sh.y),
						"flow": Vector2.ZERO, "steep": 0.0, "shore": 0.0,
					}
			cm[k] = sharers
	return cm


## One sheet corner for a quad at own_level. Averages the sharers within
## BRIDGE_MAX of own_level, then:
## CREST SNAP — when lower water (or a curtained dry drop) lies across a
## cardinal edge through this corner, the corner sits EXACTLY at own_level:
## the pool spills over at its own surface and the waterfall slab's top
## (also == level) meets it seamlessly (owner: "the waterfall must connect
## to the water it comes out of"). shore=1 there kills the swell in the
## shader and feeds the crest foam.
## SHORE DIP — corners touching a dry rim sink just below the lowest bank
## ground: the visible waterline is the terrain intersection.
## DROP BURY — lower terrain at this corner with NO curtain over it (diagonal
## pockets, shallow missing cells) pulls the corner under that ground, so no
## edge ever hangs in mid-air (the owner's floating edge fins).
static func _corner(k: Vector2i, own_level: float, cm: Dictionary) -> Dictionary:
	var sharers: Dictionary = cm[k]
	var lvl_sum: float = 0.0
	var fl: Vector2 = Vector2.ZERO
	var stp: float = 0.0
	var sho: float = 0.0
	var cnt: int = 0
	var bank_ground: float = INF
	var low_gnd: float = INF
	var wet_cells: Array = []
	var low_cells: Array = []
	for sh: Vector2i in sharers:
		var e: Dictionary = sharers[sh]
		var missing: bool = e.get("missing", false)
		if missing:
			if e.ground < own_level - BRIDGE_MAX:
				low_cells.append(sh)
				low_gnd = minf(low_gnd, e.ground)
			elif e.ground < own_level - 0.1:
				# Slightly-lower missing terrain (no curtain there): bury
				# the edge under it, never hover above it.
				low_gnd = minf(low_gnd, e.ground)
			continue
		if absf(e.level - own_level) > BRIDGE_MAX:
			if e.level < own_level:
				low_cells.append(sh)
				low_gnd = minf(low_gnd, e.ground)
			continue
		lvl_sum += e.level
		fl += e.flow
		stp = maxf(stp, e.steep)
		sho += e.get("shore", 0.0)
		cnt += 1
		if e.wet:
			wet_cells.append(sh)
		else:
			bank_ground = minf(bank_ground, e.ground)
	if cnt == 0:
		return {"y": own_level, "flow": Vector2.ZERO, "steep": stp, "shore": 1.0}
	# Crest: a counted WET sharer cardinal-adjacent to a low sharer — exactly
	# the pairs compute_ribbons hangs curtains on, so crest corners and
	# curtain tops derive from the same data and can never disagree.
	for w: Vector2i in wet_cells:
		for l: Vector2i in low_cells:
			if absi(w.x - l.x) + absi(w.y - l.y) == 1:
				return {"y": own_level, "flow": fl / float(cnt),
					"steep": maxf(stp, 0.6), "shore": 1.0}
	var lvl: float = lvl_sum / float(cnt)
	if bank_ground < INF:
		lvl = minf(lvl, bank_ground - 0.08)
	if low_gnd < INF:
		lvl = minf(lvl, low_gnd - 0.08)
	return {"y": lvl, "flow": fl / float(cnt), "steep": stp, "shore": sho / float(cnt)}


# Shoreline contour tuning: the waterline is the 0.5 iso-line of the
# smoothed corner-wetness field (bilinear marching-squares over the wet
# cells), wobbled by world noise so no segment is grid-straight.
const SHORE_WOBBLE_SCALE := 17.0
const SHORE_WOBBLE_AMP := 2.4
const SHORE_SDF_SCALE := TILE * 0.85   # wetness units -> approx metres


## Smoothed wetness at a grid corner: the fraction of its four sharer cells
## that hold water, averaged with its four corner-neighbours — the 0.5
## contour of this field IS the continuous shoreline, whatever shape the
## water body is (channels, wide flooded lowlands, ponds alike).
static func _corner_wetf(cm: Dictionary, k: Vector2i) -> float:
	if not cm.has(k):
		return 0.0
	var w: float = 0.0
	for sh in cm[k]:
		if cm[k][sh].get("wet", false):
			w += 0.25
	return w


static func _corner_wetf_smooth(cm: Dictionary, k: Vector2i) -> float:
	# 3x3 gaussian over the corner lattice: the plain 5-point average left C1
	# breaks at cell borders — the waterline turned in SHARP ANGLES there
	# (owner). The wider kernel rounds the contour across cells.
	var acc: float = 4.0 * _corner_wetf(cm, k)
	acc += 2.0 * (_corner_wetf(cm, k + Vector2i(1, 0)) + _corner_wetf(cm, k + Vector2i(-1, 0))
		+ _corner_wetf(cm, k + Vector2i(0, 1)) + _corner_wetf(cm, k + Vector2i(0, -1)))
	acc += _corner_wetf(cm, k + Vector2i(1, 1)) + _corner_wetf(cm, k + Vector2i(1, -1)) \
		+ _corner_wetf(cm, k + Vector2i(-1, 1)) + _corner_wetf(cm, k + Vector2i(-1, -1))
	return acc / 16.0


## The rendered vertex grid for one cell of the sheet: SUBDIV² sub-quads as a
## triangle stream of {pos, cust}. Corner values from _corner, bilinearly
## interpolated (adjacent cells reproduce the exact shared edge values, so
## the sheet stays watertight). At SHORE cells (near-flush ground: hover rims
## and beach shelves) the grid is then capped by the continuous shoreline —
## the wobbled 0.5-contour of the corner-wetness field: sub-vertices outside
## it dive under the local ground along that CURVE, so the visible waterline
## is smooth and organic, never the cell grid (owner: "completely rectangular
## coastline... we want it nicely curved"), and banks quantized just under
## the level render as real shore water inside the line instead of filming
## over dry lawn. Ground clearly below the level is left alone — that water
## is genuinely submerged.
static func sheet_cell_grid(cell: Vector2i, field: Dictionary, cm: Dictionary,
		water: WaterPlan, region) -> Array:
	var e: Dictionary = field[cell]
	var own_level: float = e.level
	var keys: Array = [
		cell, cell + Vector2i(1, 0), cell + Vector2i(1, 1), cell + Vector2i(0, 1),
	]   # min corner, +x, +xz, +z — walk order around the quad
	var pos: Array = []
	var cust: Array = []
	var wets: Array = []
	for k in keys:
		var c: Dictionary = _corner(k, own_level, cm)
		pos.append(Vector3(
			(float(k.x) - 0.5) * TILE, c.y, (float(k.y) - 0.5) * TILE))
		# CUSTOM0 = (flow.x, shore proximity, flow.y, steepness).
		cust.append(Color(c.flow.x, c.shore, c.flow.y, c.steep))
		wets.append(_corner_wetf_smooth(cm, k))
	# Only shoreline cells pay for the contour: rims, and wet cells that
	# touch one. Ground checks are per-vertex against the REAL RENDERED
	# surface (TerrainSurfaceField — ramps included), never flat cell tops:
	# flat-top logic left edges hovering over ramped banks (owner: "water
	# stops before touching the ground").
	var contour: bool = (not e.wet) or e.get("shore", 0.0) > 0.0
	var out: Array = []
	for sz in SUBDIV:
		for sx in SUBDIV:
			var u0: float = float(sx) / float(SUBDIV)
			var u1: float = float(sx + 1) / float(SUBDIV)
			var v0: float = float(sz) / float(SUBDIV)
			var v1: float = float(sz + 1) / float(SUBDIV)
			var quad: Array = []
			for uv in [[u0, v0], [u0, v1], [u1, v1], [u1, v0]]:
				var p: Vector3 = _bilerp_pos(pos, uv[0], uv[1])
				var c: Color = _bilerp_cust(cust, uv[0], uv[1])
				if contour:
					var wf: float = _bilerp_gnd(wets, uv[0], uv[1])
					var wob: float = (Helper._value_noise01(
						Vector3(p.x, 0.0, p.z), water.world_seed + 913,
						SHORE_WOBBLE_SCALE) - 0.5) * 2.0 * SHORE_WOBBLE_AMP
					var s: float = (0.5 - wf) * SHORE_SDF_SCALE + wob
					if s > 0.0:
						var rg: float = TerrainSurfaceField.surface_y(region, p.x, p.z)
						# Rim cells always bury outside the waterline. WET
						# cells bury only where the rendered ground rises to
						# the surface (dive INTO the bank) — capping over
						# submerged ground dug a visible trough through open
						# water ("gap between the main water and the skirt").
						if not e.wet or rg >= own_level - 0.1:
							var cap: float = maxf(own_level - s * 3.2, rg - 0.35)
							p.y = minf(p.y, cap)
					if s > -1.2:
						# Waterline band: full shore — the foam lap line hugs
						# the curve (TIGHT: a wide band read as white blobs
						# over whole shelves) and the shader kills the swell
						# so the buried edge never bobs above its bank.
						c.g = maxf(c.g, 1.0 - maxf(0.0, -s) * 0.8)
				quad.append([p, c])
			# Sub-corners (0,0),(0,1),(1,1),(1,0); winding matches the +Y quad.
			for idx in [0, 1, 2, 0, 2, 3]:
				out.append({"pos": quad[idx][0], "cust": quad[idx][1]})
	return out


## Bilinear blend of the quad's corner positions ([min, +x, +xz, +z] order).
static func _bilerp_pos(pos: Array, u: float, v: float) -> Vector3:
	return (pos[0].lerp(pos[1], u)).lerp(pos[3].lerp(pos[2], u), v)


static func _bilerp_cust(cust: Array, u: float, v: float) -> Color:
	return (cust[0].lerp(cust[1], u)).lerp(cust[3].lerp(cust[2], u), v)


static func _bilerp_gnd(g: Array, u: float, v: float) -> float:
	return lerpf(lerpf(g[0], g[1], u), lerpf(g[3], g[2], u), v)


# --- plunge mist ------------------------------------------------

static var _mist_process: ParticleProcessMaterial = null
static var _mist_mesh: QuadMesh = null


## Shared soft-billboard mist resources (warmed on the main thread with the
## other water statics; the worker only reads them).
static func mist_resources() -> Array:
	if _mist_process == null:
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0.0, 1.0, 0.0)
		pm.spread = 32.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.8
		pm.gravity = Vector3(0.0, 0.35, 0.0)   # gentle updraft
		pm.damping_min = 0.4
		pm.damping_max = 0.7
		pm.scale_min = 1.0
		pm.scale_max = 2.2
		var sc := CurveTexture.new()
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.35))
		curve.add_point(Vector2(0.35, 1.0))
		curve.add_point(Vector2(1.0, 1.5))
		sc.curve = curve
		pm.scale_curve = sc
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
		grad.add_point(0.18, Color(1.0, 1.0, 1.0, 0.55))
		grad.set_color(grad.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = grad
		pm.color_ramp = gt
		_mist_process = pm
	if _mist_mesh == null:
		var mesh := QuadMesh.new()
		mesh.size = Vector2(2.4, 2.4)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
		mat.vertex_color_use_as_albedo = true
		mat.disable_receive_shadows = true
		mat.no_depth_test = false
		var rad := GradientTexture2D.new()
		rad.fill = GradientTexture2D.FILL_RADIAL
		rad.fill_from = Vector2(0.5, 0.5)
		rad.fill_to = Vector2(0.5, 0.0)
		var g2 := Gradient.new()
		g2.set_color(0, Color(1, 1, 1, 0.85))
		g2.add_point(0.55, Color(1, 1, 1, 0.28))
		g2.set_color(g2.get_point_count() - 1, Color(1, 1, 1, 0.0))
		rad.gradient = g2
		rad.width = 64
		rad.height = 64
		mat.albedo_texture = rad
		mesh.material = mat
		_mist_mesh = mesh
	return [_mist_process, _mist_mesh]


## Mist emitter for one waterfall's plunge line: a thin box across the fall's
## width at the water it lands in, puffing soft billboards that drift up and
## dissolve — the spray where the fall meets the pool.
static func _mist_node(r: Dictionary) -> GPUParticles3D:
	var res: Array = mist_resources()
	var rows: Dictionary = fall_rows(r)
	var mist := GPUParticles3D.new()
	mist.name = "PlungeMist"
	var half_w: float = rows.plunge_half_width
	mist.amount = clampi(int(half_w * 2.0), 16, 48)
	mist.lifetime = 2.2
	mist.preprocess = 2.2
	mist.randomness = 0.5
	mist.fixed_fps = 24
	mist.process_material = res[0].duplicate()
	(mist.process_material as ParticleProcessMaterial).emission_shape = \
		ParticleProcessMaterial.EMISSION_SHAPE_BOX
	(mist.process_material as ParticleProcessMaterial).emission_box_extents = \
		Vector3(half_w, 0.4, 1.5)
	mist.draw_pass_1 = res[1]
	mist.visibility_aabb = AABB(Vector3(-half_w - 6.0, -4.0, -8.0),
		Vector3(half_w * 2.0 + 12.0, 14.0, 16.0))
	var t: Vector2 = r.tangent
	var basis := Basis(
		Vector3(-t.y, 0.0, t.x),   # local X across the fall
		Vector3.UP,
		Vector3(t.x, 0.0, t.y))    # local Z downstream
	mist.transform = Transform3D(basis, rows.plunge + Vector3(0.0, 0.5, 0.0))
	return mist


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
