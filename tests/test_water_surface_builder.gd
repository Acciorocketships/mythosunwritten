extends GutTest

# ------------------------------------------------------------
# WaterSurfaceBuilder — ribbon profile math + chunk node assembly
# ------------------------------------------------------------

const SEED := 991177

func _water() -> WaterPlan:
	return WaterPlan.new(SEED, 22.0, 8)

# The REAL rendered terrain for a chunk (clamped storeys, carve applied) — the
# water field reasons against this, never against raw-noise estimates.
# Plans/regions are cached per (seed, chunk) across tests: a fresh plan per
# call re-traces every overlapping river cold and the file times out.
static var _plan_cache: Dictionary = {}
static var _region_cache: Dictionary = {}

func _region(seed_v: int, chunk: Vector2i):
	var rk := [seed_v, chunk]
	if _region_cache.has(rk):
		return _region_cache[rk]
	if not _plan_cache.has(seed_v):
		var hp := HeightfieldPlan.new(seed_v, 22.0, 8, "mean", 3)
		hp.set_water_plan(WaterPlan.new(seed_v, 22.0, 8))
		_plan_cache[seed_v] = hp
	_region_cache[rk] = _plan_cache[seed_v].compute_region(chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	return _region_cache[rk]

func _a_river(plan: WaterPlan) -> RiverTrace:
	for sz in range(-4, 5):
		for sx in range(-4, 5):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz))
			if t != null and t.points.size() > 10:
				return t
	assert_true(false, "no river with >10 samples in the window")
	return null

func test_surface_profile_monotone_and_above_bed() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var prof: PackedFloat32Array = WaterSurfaceBuilder.surface_profile(river)
	assert_eq(prof.size(), river.points.size(), "one surface sample per polyline sample")
	for i in prof.size():
		assert_true(prof[i] >= river.beds[i] + 0.1,
			"surface stays above the bed (i=%d)" % i)
	for i in range(1, prof.size()):
		assert_true(prof[i] <= prof[i - 1] + 0.0001,
			"surface never flows uphill (i=%d)" % i)

func test_surface_profile_ends_at_terminal_pond_level() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = null
	for sz in range(-4, 5):
		for sx in range(-4, 5):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz))
			if t != null and t.pond != null and t.points.size() > 10:
				river = t
				break
		if river != null:
			break
	if river == null:
		pass_test("no ponded river in window on this seed")
		return
	var prof: PackedFloat32Array = WaterSurfaceBuilder.surface_profile(river)
	assert_almost_eq(prof[prof.size() - 1], river.pond.surface_y(), 0.6,
		"backwater reach flattens into the pond")

func test_build_chunk_makes_meshes_and_swim_volumes() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var mid: Vector2 = river.points[river.points.size() / 2]
	var chunk: Vector2i = Vector2i(int(floor(mid.x / 192.0)), int(floor(mid.y / 192.0)))
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(plan, chunk, _region(SEED, chunk))
	assert_not_null(node, "chunk containing a river builds a water node")
	var meshes: int = 0
	var areas: int = 0
	for c in node.get_children():
		if c is MeshInstance3D:
			meshes += 1
		if c is Area3D:
			areas += 1
			assert_true(c.has_meta("surface_y"), "swim volume carries surface_y")
			assert_eq(c.collision_layer, 1 << 7, "swim volume on the water layer")
	assert_true(meshes > 0, "water meshes present")
	assert_true(areas > 0, "swim volumes present")
	node.free()

func test_sheet_quads_are_subdivided_for_shader_chop() -> void:
	# The shader displaces real chop waves (~14-26m wavelength); 24m cell
	# quads can't bend, so wet cells must emit a FULL SUBDIV x SUBDIV bilinear
	# grid. RIM (dry) cells are the exception: sub-quads whose ground dives
	# below the waterline are skipped — emitting them drapes a detached "water
	# skirt" down steps and channel walls — so rim cells may emit fewer, but
	# only whole sub-quads, and the mesh must be exactly the per-cell union.
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var chunk: Vector2i = _river_chunk(plan, river)
	var region = _region(SEED, chunk)
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(plan, chunk, region)
	assert_not_null(node, "river chunk builds")
	var mesh: Mesh = null
	for c in node.get_children():
		if c is MeshInstance3D:
			mesh = c.mesh
	assert_not_null(mesh, "water sheet mesh present")
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, chunk, region)
	var cm: Dictionary = WaterSurfaceBuilder.corner_map(field, region)
	var lo: Vector2i = Vector2i(chunk.x * 8, chunk.y * 8)
	var full: int = WaterSurfaceBuilder.SUBDIV * WaterSurfaceBuilder.SUBDIV * 6
	var expect: int = 0
	for cell in field:
		if cell.x < lo.x or cell.x >= lo.x + 8 or cell.y < lo.y or cell.y >= lo.y + 8:
			continue
		var g: Array = WaterSurfaceBuilder.sheet_cell_grid(cell, field, cm, plan, region)
		if field[cell].wet:
			assert_eq(g.size(), full, "wet cell %s emits the full grid" % cell)
		elif g.size() > full or g.size() % 6 != 0:
			fail_test("rim cell %s must emit whole sub-quads within the grid" % cell)
		expect += g.size()
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), expect, "sheet mesh is exactly the union of per-cell grids")
	node.free()

func test_build_chunk_returns_null_when_dry() -> void:
	var plan: WaterPlan = _water()
	# Scan for a chunk whose window has no bodies (seed-independent), then
	# assert the builder agrees. (The spawn chunk's corners poke past the dry
	# radius, so it is NOT guaranteed dry — don't hardcode it.)
	var dry: Vector2i = Vector2i.MAX
	for cz in range(0, 40):
		for cx in range(0, 40):
			var b: Dictionary = plan.bodies_near(Vector2i(cx * 8 + 4, cz * 8 + 4), 5)
			if b.ponds.is_empty() and b.rivers.is_empty():
				dry = Vector2i(cx, cz)
				break
		if dry != Vector2i.MAX:
			break
	assert_true(dry != Vector2i.MAX, "found a dry chunk in the scan band")
	assert_null(WaterSurfaceBuilder.new().build_chunk(plan, dry, _region(SEED, dry)), "dry chunk => no node")

# ------------------------------------------------------------
# Water field — the sheet reaches land at its own height
# ------------------------------------------------------------

func _river_chunk(plan: WaterPlan, river: RiverTrace) -> Vector2i:
	var mid: Vector2 = river.points[river.points.size() / 2]
	return Vector2i(int(floor(mid.x / 192.0)), int(floor(mid.y / 192.0)))

func test_field_rim_overshoots_every_wet_cell() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var chunk: Vector2i = _river_chunk(plan, river)
	var region = _region(SEED, chunk)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, chunk, region)
	assert_true(field.size() > 0, "river chunk has a water field")
	var lo: Vector2i = Vector2i(chunk.x * 8, chunk.y * 8)
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for cell in field:
		if not field[cell].wet:
			continue
		if cell.x < lo.x or cell.x >= lo.x + 8 or cell.y < lo.y or cell.y >= lo.y + 8:
			continue
		for d in dirs:
			var nb: Vector2i = cell + d
			if field.has(nb):
				continue
			# The only neighbours allowed OUTSIDE the sheet are genuine
			# DROP-OFFS (a lower reach owns that water; the wet cell's edge
			# there carries a curtain). Anything shallower — submerged
			# shelves and the near-flush band — must be wet or rim, or the
			# sheet gets missing tiles at the shore.
			var g: float = region.surface_height(nb.x, nb.y)
			assert_true(g < field[cell].level - 0.5,
				"neighbour %s of wet %s is in the sheet or is a drop-off" % [nb, cell])

func test_field_wet_cells_sit_below_their_level() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, _river_chunk(plan, river), _region(SEED, _river_chunk(plan, river)))
	var wet_seen: int = 0
	for cell in field:
		if not field[cell].wet:
			continue
		wet_seen += 1
		assert_true(field[cell].ground < field[cell].level,
			"wet cell %s ground sits below its water level" % cell)
	assert_true(wet_seen > 0, "field contains wet cells")

func test_shore_adjacent_wet_cells_carry_almost_no_flow() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, _river_chunk(plan, river), _region(SEED, _river_chunk(plan, river)))
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var shore_seen: int = 0
	for cell in field:
		if not field[cell].wet:
			continue
		var at_shore: bool = false
		for d in dirs:
			var nb: Vector2i = cell + d
			if not field.has(nb) or not field[nb].wet:
				at_shore = true
				break
		if at_shore:
			shore_seen += 1
			assert_true(field[cell].flow.length() <= 0.55,
				"shore cell %s flow damped (waterline vertices reach zero via rim corners)" % cell)
	assert_true(shore_seen > 0, "field has shore-adjacent wet cells")

func test_rim_cells_carry_zero_flow() -> void:
	# The rim IS the no-flux boundary: corner averaging blends these zeros
	# into the waterline vertices.
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, _river_chunk(plan, river), _region(SEED, _river_chunk(plan, river)))
	for cell in field:
		if not field[cell].wet:
			assert_eq(field[cell].flow, Vector2.ZERO, "rim cell %s is still water" % cell)

func test_river_channel_actually_flows() -> void:
	# Regression: heavy shore damping froze whole narrow rivers (every cell of
	# a 1-3 cell channel is shore-adjacent). The channel must keep real flow.
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, _river_chunk(plan, river), _region(SEED, _river_chunk(plan, river)))
	var max_flow: float = 0.0
	for cell in field:
		if field[cell].wet:
			max_flow = maxf(max_flow, field[cell].flow.length())
	assert_true(max_flow >= 0.35,
		"a river chunk keeps visible flow (max %.2f)" % max_flow)

func test_wet_cells_are_anchored_no_floating_tiles() -> void:
	# Regression: river surfaces ride 0.8m above their floor storey, so bare
	# level tests marked same-storey terraces "submerged" — floating square
	# water tiles on dry land. Every wet cell is either carved (part of the
	# network's bed) or holds water within a shelf of its REAL ground; depth
	# alone anchors nothing (a dry terrace under an upstream level is not water).
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, _river_chunk(plan, river), _region(SEED, _river_chunk(plan, river)))
	for cell in field:
		if not field[cell].wet:
			continue
		var carved: bool = plan.carve_at_cell(cell.x, cell.y) > 0.05
		var shallow: bool = field[cell].level - field[cell].ground <= WaterSurfaceBuilder.SHELF_DEPTH + 0.01
		assert_true(carved or shallow,
			"wet cell %s is anchored (carved or within a shelf of real ground)" % cell)

func test_pond_owns_its_surface_level() -> void:
	# Regression: a river's higher upstream profile leaked into pond
	# footprints via nearest-sample lookup, hovering raised sheets over lakes.
	var plan: WaterPlan = _water()
	var river: RiverTrace = null
	for sz in range(-4, 5):
		for sx in range(-4, 5):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz))
			if t != null and t.pond != null:
				river = t
				break
		if river != null:
			break
	if river == null:
		pass_test("no ponded river on this seed window")
		return
	var pond: PondStamp = river.pond
	var cc: Vector2i = Vector2i(roundi(pond.center.x / 24.0), roundi(pond.center.y / 24.0))
	var chunk: Vector2i = Vector2i(int(floor(pond.center.x / 192.0)), int(floor(pond.center.y / 192.0)))
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, chunk, _region(SEED, chunk))
	var checked: int = 0
	for cell in field:
		var p: Vector2 = Vector2(cell.x * 24.0, cell.y * 24.0)
		if pond.footprint_t(p) < 0.9:
			checked += 1
			assert_true(field[cell].level <= pond.surface_y() + 0.001,
				"cell %s inside the pond never exceeds the pond level" % cell)
	assert_true(checked > 0, "pond chunk has in-footprint cells")

# ------------------------------------------------------------
# Floating-sheet regression (owner, seed 2697992464): water hung in mid-air
# over dry terraces beside steep reaches at cells (-3,-42) and (-1,-43).
# ------------------------------------------------------------

const OWNER_SEED := 2697992464

func test_sheet_never_floats_over_the_rendered_terrain() -> void:
	# Owner screenshots: sheets hovered over terraces at the cascades in these
	# chunks — rim cells trusted a raw-noise ground estimate storeys above the
	# CLAMPED terrain, and drop-lip cells took the upstream reach's level over
	# a floor that had already fallen away. Every field cell (wet or rim) —
	# POND CELLS INCLUDED (a healthy bowl floor quantizes exactly 3.0m under
	# the surface; clamp-sunk bowl cells must drop out, not hover) — must hold
	# its water within SHELF_DEPTH of the real rendered ground.
	var water := WaterPlan.new(OWNER_SEED, 22.0, 8)
	var wet_seen := 0
	for chunk in [Vector2i(-1, -6), Vector2i(0, -6)]:
		var region = _region(OWNER_SEED, chunk)
		var field: Dictionary = WaterSurfaceBuilder.compute_field(water, chunk, region)
		var bodies: Dictionary = water.bodies_near(
			Vector2i(chunk.x * 8 + 4, chunk.y * 8 + 4), 5 + WaterSurfaceBuilder.FIELD_MARGIN)
		for cell in field:
			var e: Dictionary = field[cell]
			if e.wet:
				wet_seen += 1
			# Pond INTERIORS are exempt: a clamp-sunk cell deep inside the
			# footprint is deep lake (dropping it opened see-through holes);
			# only the rim band must stay floor-consistent.
			var interior := false
			var p := Vector2(float(cell.x) * 24.0, float(cell.y) * 24.0)
			for pond in bodies.ponds:
				if pond.footprint_t(p) < 0.75:
					interior = true
					break
			if interior:
				continue
			var real: float = region.surface_height(cell.x, cell.y)
			assert_true(e.level - real <= WaterSurfaceBuilder.SHELF_DEPTH + 0.01,
				"%s cell %s floats %.1fm over the rendered terrain (level %.1f, real %.1f)" % [
					"wet" if e.wet else "rim", cell, e.level - real, e.level, real])
	assert_gt(wet_seen, 0, "the cascade chunks still hold water")

func test_corner_crest_shore_and_bury_rules() -> void:
	# New round-3 corner semantics: interior corners average to the level;
	# corners over a CURTAINED drop (a wet member cardinal to lower water or
	# to a low missing cell) snap EXACTLY to the level so the slab lip always
	# meets the sheet; shallow lower terrain with no curtain buries the edge
	# under itself; rim members keep the shore dip.
	var wet_a: Dictionary = {"level": 12.8, "flow": Vector2.ZERO, "steep": 0.0, "wet": true, "ground": 12.0}
	var wet_b: Dictionary = {"level": 12.8, "flow": Vector2.ZERO, "steep": 0.0, "wet": true, "ground": 11.6}
	var k := Vector2i(5, 5)
	var sh := [k + Vector2i(-1, -1), k + Vector2i(0, -1), k + Vector2i(-1, 0), k]
	# Full compatible corner: averages to the level.
	var full: Dictionary = {k: {sh[0]: wet_a, sh[1]: wet_b, sh[2]: wet_a, sh[3]: wet_b}}
	assert_almost_eq(WaterSurfaceBuilder._corner(k, 12.8, full).y, 12.8, 0.001,
		"interior corner averages to the level")
	# Lower WATER cardinal to a wet member: crest — snaps to the level.
	var low_wet: Dictionary = {"level": 6.0, "flow": Vector2.ZERO, "steep": 0.0, "wet": true, "ground": 5.0}
	var crest: Dictionary = {k: {sh[0]: wet_a, sh[1]: low_wet, sh[2]: wet_a, sh[3]: wet_b}}
	assert_almost_eq(WaterSurfaceBuilder._corner(k, 12.8, crest).y, 12.8, 0.001,
		"curtained crest corner stays exactly at the pool level")
	assert_almost_eq(WaterSurfaceBuilder._corner(k, 12.8, crest).shore, 1.0, 0.001,
		"crest corner is full shore (swell-killed, foam-fed)")
	# Missing cell with ground FAR below, cardinal to a wet member: also a
	# curtained drop (compute_ribbons hangs a dry curtain there) — level.
	var low_missing: Dictionary = {"level": -INF, "wet": false, "missing": true,
		"ground": 4.0, "flow": Vector2.ZERO, "steep": 0.0, "shore": 0.0}
	var weir: Dictionary = {k: {sh[0]: wet_a, sh[1]: low_missing, sh[2]: wet_a, sh[3]: wet_b}}
	assert_almost_eq(WaterSurfaceBuilder._corner(k, 12.8, weir).y, 12.8, 0.001,
		"weir crest corner stays at the pool level over the dry drop")
	# Missing cell just under the level (no curtain — drop within BRIDGE_MAX):
	# bury under that ground.
	var shallow_missing: Dictionary = {"level": -INF, "wet": false, "missing": true,
		"ground": 11.4, "flow": Vector2.ZERO, "steep": 0.0, "shore": 0.0}
	var pocket: Dictionary = {k: {sh[0]: wet_a, sh[1]: shallow_missing, sh[2]: wet_a, sh[3]: wet_b}}
	assert_true(WaterSurfaceBuilder._corner(k, 12.8, pocket).y <= 11.4 - 0.07,
		"uncurtained shallow drop buries the edge under the lower ground")
	# Dry (rim) member keeps the shore dip: just under the bank ground.
	var rim: Dictionary = {"level": 12.8, "flow": Vector2.ZERO, "steep": 0.0, "wet": false, "ground": 12.6}
	var shore: Dictionary = {k: {sh[0]: wet_a, sh[1]: wet_a, sh[2]: wet_b, sh[3]: rim}}
	assert_almost_eq(WaterSurfaceBuilder._corner(k, 12.8, shore).y, 12.6 - 0.08, 0.001,
		"shore corner sinks just under the lowest adjacent bank ground")

func test_waterfall_is_a_thick_ogee_slab_with_submerged_runout() -> void:
	# Round 3 shape + round 9 welding: the fall's columns leave the SHEET'S OWN
	# drooped edge vertices, drop, then FLATTEN back to horizontal right at the
	# lower surface (ogee — owner: "a smooth curve back up to connect with the
	# water at the bottom"), ending in a flat submerged runout. Built against
	# the real pinned-seed field (the welded mesh needs the sheet context).
	var water := WaterPlan.new(OWNER_SEED, 22.0, 8)
	var chunk := Vector2i(0, -6)
	var region = _region(OWNER_SEED, chunk)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(water, chunk, region)
	var cm: Dictionary = WaterSurfaceBuilder.corner_map(field, region)
	var ribbons: Array = WaterSurfaceBuilder.compute_ribbons(field, chunk, region)
	assert_true(ribbons.size() > 0, "pinned chunk has at least one fall")
	if ribbons.is_empty():
		return
	var r: Dictionary = ribbons[0]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	WaterSurfaceBuilder._ribbon_mesh(st, r, field, cm, water, region)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var mid3 := Vector3(r.mid.x, 0.0, r.mid.y)
	var tan3 := Vector3(r.tangent.x, 0.0, r.tangent.y)
	# The slab never rises above the upstream surface it pours from…
	var y_max: float = -INF
	var y_min: float = INF
	var along_lo: float = INF
	var along_hi: float = -INF
	for v in verts:
		y_max = maxf(y_max, v.y)
		y_min = minf(y_min, v.y)
		var along: float = (v - mid3).dot(tan3)
		along_lo = minf(along_lo, along)
		along_hi = maxf(along_hi, along)
	assert_true(y_max <= r.top + 0.001, "slab crest never pokes above the pool surface")
	# …starts upstream of the lip (overlap row embedded under the sheet)…
	assert_true(along_lo <= -WaterSurfaceBuilder.FALL_OVERLAP + 0.2,
		"slab overlaps upstream under the sheet (along_min %.2f)" % along_lo)
	# …reaches below the lower surface (submerged runout, no painted apron
	# hovering above the pool)…
	assert_true(y_min <= r.bottom - 0.05, "runout submerges under the plunge pool")
	assert_true(along_hi >= 3.0, "runout carries downstream past the plunge")
	# …and the LAST front chord is near-horizontal (C1 into the pool).
	var rows: Dictionary = WaterSurfaceBuilder.fall_rows(r)
	var fr: Array = rows.front
	var runout_start: int = fr.size() - 3   # last curve row before the runout
	var a: Array = fr[runout_start - 1]
	var b: Array = fr[runout_start]
	var slope: float = absf(b[1] - a[1]) / maxf(a[0].distance_to(b[0]), 0.001)
	assert_true(slope <= 0.35, "plunge entry is near-horizontal (slope %.2f)" % slope)
	# uv.y stays within the curtain band (no churn apron past ~1.1).
	var uv_max: float = 0.0
	for uv in uvs:
		uv_max = maxf(uv_max, uv.y)
	assert_true(uv_max <= 1.15, "no painted churn apron band (uv_max %.2f)" % uv_max)

func test_every_sheet_split_gets_a_waterfall_curtain() -> void:
	# Owner: "where there is a drop, we should also work on waterfalls." The
	# sheet deliberately splits between adjacent wet cells whose levels differ
	# by more than BRIDGE_MAX; a curtain must fill EXACTLY each such gap —
	# same data source, so splits and curtains can never disagree.
	var water := WaterPlan.new(OWNER_SEED, 22.0, 8)
	var total := 0
	for chunk in [Vector2i(-1, -6), Vector2i(0, -6)]:
		var region = _region(OWNER_SEED, chunk)
		var field: Dictionary = WaterSurfaceBuilder.compute_field(water, chunk, region)
		var ribbons: Array = WaterSurfaceBuilder.compute_ribbons(field, chunk, region)
		var covered: Dictionary = {}
		for r in ribbons:
			covered[r.mid] = true
		var lo := Vector2i(chunk.x * 8, chunk.y * 8)
		for cell: Vector2i in field:
			if not field[cell].wet:
				continue
			if cell.x < lo.x or cell.x >= lo.x + 8 or cell.y < lo.y or cell.y >= lo.y + 8:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cell + d
				if field.has(nb) and field[nb].wet \
						and field[cell].level - field[nb].level > WaterSurfaceBuilder.BRIDGE_MAX:
					var mid := Vector2((float(cell.x) + float(d.x) * 0.5) * 24.0,
							(float(cell.y) + float(d.y) * 0.5) * 24.0)
					assert_true(covered.has(mid),
						"wet-wet sheet split at %s carries a curtain" % str(mid))
		for r in ribbons:
			total += 1
			assert_gt(r.top - r.bottom, WaterSurfaceBuilder.BRIDGE_MAX - 0.7,
				"a curtain spans its drop (top %.1f bottom %.1f)" % [r.top, r.bottom])
	assert_gt(total, 0, "the cascade chunks carry waterfall curtains")

func test_ribbons_are_deterministic_and_chunk_owned() -> void:
	var water := WaterPlan.new(OWNER_SEED, 22.0, 8)
	var chunk := Vector2i(-1, -6)
	var region = _region(OWNER_SEED, chunk)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(water, chunk, region)
	var a: Array = WaterSurfaceBuilder.compute_ribbons(field, chunk, region)
	var b: Array = WaterSurfaceBuilder.compute_ribbons(field, chunk, region)
	assert_eq(a.size(), b.size(), "pure function of (field, chunk)")
	for i in a.size():
		assert_eq(a[i].mid, b[i].mid, "ribbon %d midpoint stable" % i)
	# A curtain's HIGHER cell sits inside the owning chunk — the neighbour's
	# field marks the same boundary but its higher cell is then in the margin.
	var lo := Vector2i(chunk.x * 8, chunk.y * 8)
	for r in a:
		var hi_cell := Vector2i(roundi((r.mid.x - r.tangent.x * 12.0) / 24.0),
				roundi((r.mid.y - r.tangent.y * 12.0) / 24.0))
		assert_true(hi_cell.x >= lo.x and hi_cell.x < lo.x + 8 \
				and hi_cell.y >= lo.y and hi_cell.y < lo.y + 8,
			"curtain %s owned via its higher cell %s" % [r.mid, hi_cell])
