extends GutTest

# ------------------------------------------------------------
# Water visual invariants on the owner's pinned review seed — no floating
# water, crests flush with their waterfall slabs, every big drop curtained,
# hover-rim films buried outside the continuous shoreline, ogee plunge.
# Encodes the round-3 review fixes (2026-07-07): these are the geometric
# definitions of "solved" for the five annotated screenshots.
# ------------------------------------------------------------

const SEED := 2697992464
const TILE := 24.0
const BRIDGE := 2.5          # = WaterSurfaceBuilder.BRIDGE_MAX
# Chunks covering the owner's five annotated spots (S1/S4/S5, S3, S2).
const CHUNKS := [Vector2i(0, -6), Vector2i(-1, -6), Vector2i(-1, -5)]

# Plans/regions/fields cached per (seed, chunk) across tests: fresh plans
# re-trace every overlapping river cold and the file times out.
static var _plan_cache: Dictionary = {}
static var _region_cache: Dictionary = {}
static var _field_cache: Dictionary = {}


func _plan(seed_v: int) -> HeightfieldPlan:
	if not _plan_cache.has(seed_v):
		var hp := HeightfieldPlan.new(seed_v, 22.0, 8, "mean", 3)
		hp.set_water_plan(WaterPlan.new(seed_v, 22.0, 8))
		_plan_cache[seed_v] = hp
	return _plan_cache[seed_v]


func _water(seed_v: int) -> WaterPlan:
	return _plan(seed_v)._water_plan


func _region(seed_v: int, chunk: Vector2i):
	var rk := [seed_v, chunk]
	if not _region_cache.has(rk):
		_region_cache[rk] = _plan(seed_v).compute_region(chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	return _region_cache[rk]


func _field(seed_v: int, chunk: Vector2i) -> Dictionary:
	var rk := [seed_v, chunk]
	if not _field_cache.has(rk):
		_field_cache[rk] = WaterSurfaceBuilder.compute_field(
			_water(seed_v), chunk, _region(seed_v, chunk))
	return _field_cache[rk]


func _interior(cell: Vector2i, chunk: Vector2i) -> bool:
	return cell.x >= chunk.x * 8 and cell.x < chunk.x * 8 + 8 \
		and cell.y >= chunk.y * 8 and cell.y < chunk.y * 8 + 8


## Corner keys shared by cell and its cardinal neighbour cell+d.
func _edge_corners(cell: Vector2i, d: Vector2i) -> Array:
	if d == Vector2i(1, 0):
		return [cell + Vector2i(1, 0), cell + Vector2i(1, 1)]
	if d == Vector2i(-1, 0):
		return [cell, cell + Vector2i(0, 1)]
	if d == Vector2i(0, 1):
		return [cell + Vector2i(0, 1), cell + Vector2i(1, 1)]
	return [cell, cell + Vector2i(1, 0)]


# ------------------------------------------------------------
# Crest flushness: every wet-to-wet waterfall's upstream sheet edge sits
# EXACTLY at the upper level, and the slab's top matches it — the slab lip
# can never poke above (or float off) the water it pours out of (S5).
# ------------------------------------------------------------
func test_crest_corners_flush_with_slab_top() -> void:
	var checked := 0
	for chunk: Vector2i in CHUNKS:
		var field: Dictionary = _field(SEED, chunk)
		if field.is_empty():
			continue
		var region = _region(SEED, chunk)
		var cm: Dictionary = WaterSurfaceBuilder.corner_map(field, region)
		for r in WaterSurfaceBuilder.compute_ribbons(field, chunk, region):
			var d := Vector2i(int(r.tangent.x), int(r.tangent.y))
			var upper := Vector2i(
				roundi(r.mid.x / TILE - r.tangent.x * 0.5),
				roundi(r.mid.y / TILE - r.tangent.y * 0.5))
			if not field.has(upper):
				continue
			var lvl: float = field[upper].level
			assert_almost_eq(r.top, lvl, 0.05,
				"slab top rides the upstream surface (ribbon at %s)" % str(r.mid))
			for k in _edge_corners(upper, d):
				var c: Dictionary = WaterSurfaceBuilder._corner(k, lvl, cm)
				assert_almost_eq(c.y, lvl, 0.05,
					"crest corner %s stays at the pool level %0.2f" % [str(k), lvl])
				checked += 1
	assert_true(checked > 0, "found at least one curtained crest to check")


# ------------------------------------------------------------
# Every big drop off a wet cell is curtained — including drops onto DRY or
# missing ground (weir edges, dropped cells): the sheet must never end in
# mid-air over lower terrain with nothing covering the face (S1/S2/S3).
# ------------------------------------------------------------
func test_every_big_drop_edge_has_a_curtain() -> void:
	for chunk: Vector2i in CHUNKS:
		var field: Dictionary = _field(SEED, chunk)
		if field.is_empty():
			continue
		var region = _region(SEED, chunk)
		var ribbons: Array = WaterSurfaceBuilder.compute_ribbons(field, chunk, region)
		var covered: Dictionary = {}
		for r in ribbons:
			covered[Vector2(r.mid)] = true
		for cell: Vector2i in field:
			if not field[cell].wet or not _interior(cell, chunk):
				continue
			var lvl: float = field[cell].level
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cell + d
				var other: float
				if field.has(nb):
					other = field[nb].level if field[nb].wet else field[nb].ground
				else:
					other = region.surface_height(nb.x, nb.y)
				if lvl - other <= BRIDGE:
					continue
				var mid := Vector2(
					(float(cell.x) + float(d.x) * 0.5) * TILE,
					(float(cell.y) + float(d.y) * 0.5) * TILE)
				assert_true(covered.has(mid),
					"drop edge at %s (lvl %.2f over %.2f) carries a curtain" % [str(mid), lvl, other])


# ------------------------------------------------------------
# No hanging corners: a sheet corner bordering terrain the water does NOT
# continue onto must be buried under that terrain — unless a curtain at that
# corner covers the face (the floating edge fins of S1/S3).
# ------------------------------------------------------------
func test_no_uncurtained_hanging_corners() -> void:
	var checked := 0
	for chunk: Vector2i in CHUNKS:
		var field: Dictionary = _field(SEED, chunk)
		if field.is_empty():
			continue
		var region = _region(SEED, chunk)
		var cm: Dictionary = WaterSurfaceBuilder.corner_map(field, region)
		var curtain_corners: Dictionary = {}
		for r in WaterSurfaceBuilder.compute_ribbons(field, chunk, region):
			var d := Vector2i(int(r.tangent.x), int(r.tangent.y))
			var upper := Vector2i(
				roundi(r.mid.x / TILE - r.tangent.x * 0.5),
				roundi(r.mid.y / TILE - r.tangent.y * 0.5))
			for k in _edge_corners(upper, d):
				curtain_corners[k] = true
		for cell: Vector2i in field:
			if not field[cell].wet or not _interior(cell, chunk):
				continue
			var lvl: float = field[cell].level
			for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var k: Vector2i = cell + off
				var lows: Array = []
				for sh in [k + Vector2i(-1, -1), k + Vector2i(0, -1), k + Vector2i(-1, 0), k]:
					if field.has(sh):
						if absf(field[sh].level - lvl) > BRIDGE and field[sh].level < lvl:
							lows.append(field[sh].ground)
					else:
						lows.append(region.surface_height(sh.x, sh.y))
				if lows.is_empty():
					continue
				var low_min: float = lows.min()
				if lvl - low_min <= BRIDGE:
					continue
				if curtain_corners.has(k):
					continue
				checked += 1
				var c: Dictionary = WaterSurfaceBuilder._corner(k, lvl, cm)
				assert_true(c.y <= low_min - 0.04,
					"uncurtained corner %s of cell %s buries under the drop (y %.2f vs ground %.2f)"
					% [str(k), str(cell), c.y, low_min])
	if checked == 0:
		pass_test("every drop corner in the tested chunks is curtain-covered")


# ------------------------------------------------------------
# Hover-rim films: a rim cell whose ground sits UNDER the water level renders
# as real shore water only inside the continuous waterline (shore_sdf < 0);
# outside it every sub-vertex hides below the grass — the 24m film of water
# hovering over dry lawn (S1 "floating water", S2 "extra section") is gone.
# ------------------------------------------------------------
func test_hover_rims_buried_outside_the_waterline() -> void:
	var water: WaterPlan = _water(SEED)
	var found := 0
	for chunk: Vector2i in CHUNKS:
		var field: Dictionary = _field(SEED, chunk)
		if field.is_empty():
			continue
		var region = _region(SEED, chunk)
		var cm: Dictionary = WaterSurfaceBuilder.corner_map(field, region)
		for cell: Vector2i in field:
			if not _interior(cell, chunk):
				continue
			var e: Dictionary = field[cell]
			if e.wet or e.level <= e.ground + 0.02:
				continue   # rising-bank rim: sheet dives into the wall, fine
			found += 1
			var verts: Array = WaterSurfaceBuilder.sheet_cell_grid(cell, field, cm, water, region)
			var y_min: float = INF
			var above := 0
			for v in verts:
				y_min = minf(y_min, v.pos.y)
				assert_true(v.pos.y <= e.level + 0.02,
					"rim water at %s never rises above its level" % str(v.pos))
				if v.pos.y > e.ground - 0.05:
					above += 1
			# The old bug rendered the ENTIRE 24m rim quad at the level, a
			# film hovering over dry lawn. Now only the shore-water margin
			# near the waterline contour may stand above the grass; the rest
			# of the cell buries.
			assert_true(y_min <= e.ground - 0.2,
				"hover rim %s dives under its grass somewhere (min y %.2f, ground %.2f)"
				% [str(cell), y_min, e.ground])
			assert_true(above <= verts.size() * 7 / 10,
				"hover rim %s is not a full-cell film (%d/%d verts above grass)"
				% [str(cell), above, verts.size()])
	if found == 0:
		pass_test("no hover rims in the tested chunks")


# ------------------------------------------------------------
# Submerged shelves KEEP their water: a wet cell whose ground sits clearly
# under the level (flooded shelf) must still render surface at the level —
# the shoreline contour cap may only bury banks and near-flush hover bands,
# never open water (that would re-open the see-under gaps).
# ------------------------------------------------------------
func test_submerged_shelves_keep_their_water() -> void:
	var water: WaterPlan = _water(SEED)
	var found := 0
	for chunk: Vector2i in CHUNKS:
		var field: Dictionary = _field(SEED, chunk)
		if field.is_empty():
			continue
		var region = _region(SEED, chunk)
		var cm: Dictionary = WaterSurfaceBuilder.corner_map(field, region)
		for cell: Vector2i in field:
			if not _interior(cell, chunk):
				continue
			var e: Dictionary = field[cell]
			if not e.wet or e.level - e.ground < 1.2:
				continue
			found += 1
			var y_max: float = -INF
			for v in WaterSurfaceBuilder.sheet_cell_grid(cell, field, cm, water, region):
				y_max = maxf(y_max, v.pos.y)
			# (Corners shared with a higher compatible reach may average the
			# sheet ABOVE this cell's own level — that is the watertight
			# slope between reaches, not an error.)
			assert_true(y_max >= e.level - 0.6,
				"submerged cell %s still shows water near its level (max y %.2f, level %.2f)"
				% [str(cell), y_max, e.level])
	assert_true(found > 0, "found submerged wet cells to check")


# ------------------------------------------------------------
# Waterfall centreline: horizontal exit at the crest, an upstream overlap row
# embedded under the upper sheet, and an ogee plunge that flattens back to
# horizontal just under the lower surface (S4's ugly angle), ending in a
# submerged runout — never a steep chord stabbing into the pool.
# ------------------------------------------------------------
func test_fall_rows_ogee_profile() -> void:
	var r := {"mid": Vector2(0.0, 0.0), "tangent": Vector2(0.0, -1.0),
		"half_width": 12.0, "top": 9.0, "bottom": 4.55, "kind": "wet"}
	var rows: Dictionary = WaterSurfaceBuilder.fall_rows(r)
	var front: Array = rows.front
	assert_true(front.size() >= 8, "enough rows to read as a smooth curve")
	# Overlap row: starts upstream of the crest, just under the sheet.
	var head: Array = front[0]
	assert_true(head[0].y > 0.5, "first row sits upstream of the lip (overlap)")
	assert_true(head[1] < r.top and head[1] > r.top - 0.5,
		"overlap row embeds just under the upstream sheet")
	# Monotone advance; monotone descent from the crest on (the overlap row
	# deliberately rises INTO the lip from under the upstream sheet).
	for i in range(1, front.size()):
		assert_true(front[i][0].y <= front[i - 1][0].y + 0.0001,
			"rows only ever advance downstream (row %d)" % i)
	for i in range(2, front.size()):
		assert_true(front[i][1] <= front[i - 1][1] + 0.0001,
			"rows only ever descend past the crest (row %d)" % i)
	# Crest exit near-horizontal; plunge entry near-horizontal; ends at bottom.
	var c0: Array = front[1]
	var c1: Array = front[2]
	var exit_slope: float = absf(c1[1] - c0[1]) / maxf(c0[0].distance_to(c1[0]), 0.001)
	assert_true(exit_slope <= 0.8, "water leaves the lip flat-ish (slope %.2f)" % exit_slope)
	var e0: Array = front[front.size() - 2]
	var e1: Array = front[front.size() - 1]
	var entry_slope: float = absf(e1[1] - e0[1]) / maxf(e0[0].distance_to(e1[0]), 0.001)
	assert_true(entry_slope <= 0.35,
		"curve flattens back up into the lower water (slope %.2f)" % entry_slope)
	assert_almost_eq(front[front.size() - 1][1], r.bottom, 0.30,
		"curve ends at the plunge surface, C1 into the pool")


# ------------------------------------------------------------
# Water only stops by touching ground (round-4 rule 3): every outer-ring
# sub-vertex of the sheet — the rows of rim cells facing cells OUTSIDE the
# field — must sit under the REAL RENDERED terrain at that exact point
# (TerrainSurfaceField.surface_y — ramps included). Flat cell-top logic left
# edges hovering over ramped banks ("water stops before touching the
# ground", "water mysteriously missing").
# ------------------------------------------------------------
func test_outer_ring_buried_under_rendered_ground() -> void:
	var water: WaterPlan = _water(SEED)
	var checked := 0
	for chunk: Vector2i in CHUNKS:
		var field: Dictionary = _field(SEED, chunk)
		if field.is_empty():
			continue
		var region = _region(SEED, chunk)
		var cm: Dictionary = WaterSurfaceBuilder.corner_map(field, region)
		for cell: Vector2i in field:
			if field[cell].wet or not _interior(cell, chunk):
				continue
			var open: Array = []
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not field.has(cell + d):
					open.append(d)
			if open.is_empty():
				continue
			for v in WaterSurfaceBuilder.sheet_cell_grid(cell, field, cm, water, region):
				var lx: float = v.pos.x - (float(cell.x) - 0.5) * TILE
				var lz: float = v.pos.z - (float(cell.y) - 0.5) * TILE
				var on_open := false
				for d in open:
					if (d.x == 1 and lx > TILE - 0.01) or (d.x == -1 and lx < 0.01) \
							or (d.y == 1 and lz > TILE - 0.01) or (d.y == -1 and lz < 0.01):
						on_open = true
						break
				if not on_open:
					continue
				checked += 1
				var rg: float = TerrainSurfaceField.surface_y(region, v.pos.x, v.pos.z)
				assert_true(v.pos.y <= rg - 0.02,
					"outer-ring vertex at %s buried under the rendered ground (y %.2f, ground %.2f)"
					% [str(v.pos), v.pos.y, rg])
	assert_true(checked > 0, "found outer-ring vertices to check")


# ------------------------------------------------------------
# The shoreline cap must never dig a trough through open water (round-4:
# "small gap between the main water and the skirt water"): on WET shore
# cells, sub-vertices over SUBMERGED rendered ground stay at the surface.
# ------------------------------------------------------------
func test_wet_shores_never_trough() -> void:
	var water: WaterPlan = _water(SEED)
	var checked := 0
	for chunk: Vector2i in CHUNKS:
		var field: Dictionary = _field(SEED, chunk)
		if field.is_empty():
			continue
		var region = _region(SEED, chunk)
		var cm: Dictionary = WaterSurfaceBuilder.corner_map(field, region)
		for cell: Vector2i in field:
			var e: Dictionary = field[cell]
			if not e.wet or not _interior(cell, chunk):
				continue
			if e.get("shore", 0.0) <= 0.0:
				continue   # only shore cells run the contour cap
			# Sloping reaches legitimately tilt the sheet below the cell's own
			# level (corner averaging with the downstream neighbour). The BUG
			# is the CAP digging below the corner-bilinear surface over
			# submerged ground — so the floor is the lowest corner anchor.
			var floor_y: float = INF
			for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				floor_y = minf(floor_y,
					WaterSurfaceBuilder._corner(cell + off, e.level, cm).y)
			for v in WaterSurfaceBuilder.sheet_cell_grid(cell, field, cm, water, region):
				var rg: float = TerrainSurfaceField.surface_y(region, v.pos.x, v.pos.z)
				if rg < e.level - 0.3:
					checked += 1
					assert_true(v.pos.y >= floor_y - 0.03,
						"no cap trough through open water at %s (y %.2f, corner floor %.2f, ground %.2f)"
						% [str(v.pos), v.pos.y, floor_y, rg])
	if checked == 0:
		pass_test("no submerged wet-shore vertices in the tested chunks")


# ------------------------------------------------------------
# Crest cells are swell-damped (round-4: "water not blending into
# waterfall"): the sheet next to a static waterfall slab must barely move,
# or the full-amplitude swell hinges against the pinned crest edge and opens
# a slit. Both sides of every split carry high baked shore.
# ------------------------------------------------------------
func test_crest_cells_are_swell_damped() -> void:
	var checked := 0
	for chunk: Vector2i in CHUNKS:
		var field: Dictionary = _field(SEED, chunk)
		if field.is_empty():
			continue
		for cell: Vector2i in field:
			if not field[cell].wet:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cell + d
				if field.has(nb) and field[nb].wet \
						and absf(field[cell].level - field[nb].level) > BRIDGE:
					checked += 1
					assert_true(field[cell].get("shore", 0.0) >= 0.65,
						"crest-side cell %s is swell-damped (shore %.2f)"
						% [str(cell), field[cell].get("shore", 0.0)])
					break
	assert_true(checked > 0, "found crest cells to check")


# ------------------------------------------------------------
# Pond interiors never drop out: a clamp-sunk cell fully inside a pond
# footprint is deep lake, not a hole you can see the bed through (S2 gap).
# ------------------------------------------------------------
func test_pond_interiors_have_no_holes() -> void:
	var water: WaterPlan = _water(SEED)
	var checked := 0
	for chunk: Vector2i in CHUNKS:
		var field: Dictionary = _field(SEED, chunk)
		var bodies: Dictionary = water.bodies_near(
			Vector2i(chunk.x * 8 + 4, chunk.y * 8 + 4), 5)
		for pond in bodies.ponds:
			for dz in 8:
				for dx in 8:
					var cell := Vector2i(chunk.x * 8 + dx, chunk.y * 8 + dz)
					var p := Vector2(float(cell.x) * TILE, float(cell.y) * TILE)
					if pond.footprint_t(p) >= 0.7:
						continue
					checked += 1
					assert_true(field.has(cell) and field[cell].wet,
						"pond-interior cell %s is wet (no see-through hole)" % str(cell))
	if checked == 0:
		pass_test("no pond interiors inside the tested chunks")
