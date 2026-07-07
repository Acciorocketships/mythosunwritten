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
	# quads can't bend, so every cell must emit a SUBDIV x SUBDIV bilinear grid.
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var chunk: Vector2i = _river_chunk(plan, river)
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(plan, chunk, _region(SEED, chunk))
	assert_not_null(node, "river chunk builds")
	var mesh: Mesh = null
	for c in node.get_children():
		if c is MeshInstance3D:
			mesh = c.mesh
	assert_not_null(mesh, "water sheet mesh present")
	var field: Dictionary = WaterSurfaceBuilder.compute_field(plan, chunk, _region(SEED, chunk))
	var lo: Vector2i = Vector2i(chunk.x * 8, chunk.y * 8)
	var quads: int = 0
	for cell in field:
		if cell.x >= lo.x and cell.x < lo.x + 8 and cell.y >= lo.y and cell.y < lo.y + 8:
			quads += 1
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), quads * WaterSurfaceBuilder.SUBDIV * WaterSurfaceBuilder.SUBDIV * 6,
		"every cell quad is a SUBDIV x SUBDIV bilinear grid")
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
			# DROP-OFFS (a lower reach owns that water). Anything shallower —
			# including the just-under-level band — must be wet or rim, or
			# the sheet gets missing tiles at the shore.
			var g: float = region.surface_height(nb.x, nb.y)
			assert_true(g < field[cell].level - WaterSurfaceBuilder.FLOOD_MIN_DEPTH,
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
		for cell in field:
			var e: Dictionary = field[cell]
			if e.wet:
				wet_seen += 1
			var real: float = region.surface_height(cell.x, cell.y)
			assert_true(e.level - real <= WaterSurfaceBuilder.SHELF_DEPTH + 0.01,
				"%s cell %s floats %.1fm over the rendered terrain (level %.1f, real %.1f)" % [
					"wet" if e.wet else "rim", cell, e.level - real, e.level, real])
	assert_gt(wet_seen, 0, "the cascade chunks still hold water")

func test_corner_dips_into_the_lip_at_drop_offs() -> void:
	# A corner with a MISSING member (sharer cell absent from the field — a
	# genuine drop-off with no water below) must sink under the counted
	# members' own ground so the sheet edge dives into the lip terrain instead
	# of hanging in mid-air over the lower terrain (owner: "floating water").
	var wet_a: Dictionary = {"level": 12.8, "flow": Vector2.ZERO, "steep": 0.0, "wet": true, "ground": 12.0}
	var wet_b: Dictionary = {"level": 12.8, "flow": Vector2.ZERO, "steep": 0.0, "wet": true, "ground": 11.6}
	var k := Vector2i(5, 5)
	# Full corner (4 members): no dip — interior corners stay at the level.
	var full: Dictionary = {k: [wet_a, wet_b, wet_a, wet_b]}
	assert_almost_eq(WaterSurfaceBuilder._corner(k, 12.8, full).y, 12.8, 0.001,
		"interior corner averages to the level")
	# Missing members (drop-off beyond): dip under the lowest counted ground.
	var edge: Dictionary = {k: [wet_a, wet_b]}
	assert_true(WaterSurfaceBuilder._corner(k, 12.8, edge).y <= 11.6 - 0.07,
		"drop-off corner dives under the counted members' own ground")
	# Dry (rim) member keeps the shore dip: just under the bank ground.
	var rim: Dictionary = {"level": 12.8, "flow": Vector2.ZERO, "steep": 0.0, "wet": false, "ground": 12.6}
	var shore: Dictionary = {k: [wet_a, wet_a, wet_b, rim]}
	assert_almost_eq(WaterSurfaceBuilder._corner(k, 12.8, shore).y, 12.6 - 0.08, 0.001,
		"shore corner sinks just under the lowest adjacent bank ground")

func test_waterfall_is_a_thick_horizontal_exit_parabola_with_splash() -> void:
	# Owner round 2: "the water should exit the top travelling horizontally,
	# then curve down" (C1 with the flat sheet) and "they need some depth" —
	# the fall is a slab: front parabola x = reach·t, y = top − h·t², a back
	# sheet offset along the curve normal, and a splash apron (UV.y > 1)
	# riding just above the lower surface.
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: Dictionary = {"mid": Vector2(0.0, 0.0), "tangent": Vector2(1.0, 0.0),
		"half_width": 12.0, "top": 10.0, "bottom": 2.0}
	WaterSurfaceBuilder._ribbon_mesh(st, r)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var top: float = 10.0 + 0.15
	var bottom: float = 2.0 - 0.6
	var h: float = top - bottom
	var reach: float = clampf(h * WaterSurfaceBuilder.FALL_REACH,
		WaterSurfaceBuilder.FALL_REACH_MIN, WaterSurfaceBuilder.FALL_REACH_MAX)
	var thick: float = clampf(h * 0.10, 0.4, 1.2)

	# Front sheet ON the parabola: one vertex per row at (reach·t, top − h·t²).
	var rows: int = WaterSurfaceBuilder.FALL_ROWS
	for i in rows + 1:
		var t: float = float(i) / float(rows)
		var found: bool = false
		for j in verts.size():
			if absf(verts[j].x - reach * t) < 0.001 \
					and absf(verts[j].y - (top - h * t * t)) < 0.001:
				found = true
				break
		assert_true(found, "front row t=%.2f sits on the parabola" % t)
	# HORIZONTAL exit: the first arc chord leaves the lip nearly flat (C1
	# with the sheet above), far from the old 45°+ plunge.
	var dx: float = reach / float(rows)
	var dy: float = h / float(rows * rows)
	assert_true(rad_to_deg(atan(dy / dx)) < 30.0,
		"first chord leaves the lip near-horizontal (%.1f°)" % rad_to_deg(atan(dy / dx)))
	# DEPTH: a back sheet hangs thick-below the crest and thick-behind the
	# plunge (offset along the curve normal).
	var crest_back: bool = false
	var plunge_nrm: Vector2 = Vector2(2.0 * h, reach).normalized()
	var plunge_back: bool = false
	for j in verts.size():
		if absf(verts[j].x) < 0.001 and absf(verts[j].y - (top - thick)) < 0.001:
			crest_back = true
		if absf(verts[j].x - (reach - plunge_nrm.x * thick)) < 0.001 \
				and absf(verts[j].y - (bottom - plunge_nrm.y * thick)) < 0.001:
			plunge_back = true
	assert_true(crest_back, "back sheet gives the crest vertical thickness")
	assert_true(plunge_back, "back sheet gives the plunge upstream thickness")
	# Splash apron past uv.y = 1, above the lower surface, downstream.
	var seen_apron: bool = false
	for i in verts.size():
		if uvs[i].y > 1.0:
			seen_apron = true
			assert_true(verts[i].y >= 2.6,
				"apron rides above the lower water surface (y=%.2f)" % verts[i].y)
			assert_true(verts[i].x > reach - 0.5, "apron spreads downstream of the plunge")
	assert_true(seen_apron, "mesh carries a splash apron past uv.y = 1")

func test_every_sheet_split_gets_a_waterfall_curtain() -> void:
	# Owner: "where there is a drop, we should also work on waterfalls." The
	# sheet deliberately splits between adjacent wet cells whose levels differ
	# by more than BRIDGE_MAX; a curtain must fill EXACTLY each such gap —
	# same data source, so splits and curtains can never disagree.
	var water := WaterPlan.new(OWNER_SEED, 22.0, 8)
	var total := 0
	for chunk in [Vector2i(-1, -6), Vector2i(0, -6)]:
		var field: Dictionary = WaterSurfaceBuilder.compute_field(
			water, chunk, _region(OWNER_SEED, chunk))
		var ribbons: Array = WaterSurfaceBuilder.compute_ribbons(field, chunk)
		var lo := Vector2i(chunk.x * 8, chunk.y * 8)
		var gaps := 0
		for cell: Vector2i in field:
			if not field[cell].wet:
				continue
			if cell.x < lo.x or cell.x >= lo.x + 8 or cell.y < lo.y or cell.y >= lo.y + 8:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cell + d
				if field.has(nb) and field[nb].wet \
						and field[cell].level - field[nb].level > WaterSurfaceBuilder.BRIDGE_MAX:
					gaps += 1
		assert_eq(ribbons.size(), gaps, "one curtain per wet-wet sheet split in the chunk")
		for r in ribbons:
			total += 1
			assert_gt(r.top - r.bottom, WaterSurfaceBuilder.BRIDGE_MAX - 0.7,
				"a curtain spans its drop (top %.1f bottom %.1f)" % [r.top, r.bottom])
	assert_gt(total, 0, "the cascade chunks carry waterfall curtains")

func test_ribbons_are_deterministic_and_chunk_owned() -> void:
	var water := WaterPlan.new(OWNER_SEED, 22.0, 8)
	var chunk := Vector2i(-1, -6)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(water, chunk, _region(OWNER_SEED, chunk))
	var a: Array = WaterSurfaceBuilder.compute_ribbons(field, chunk)
	var b: Array = WaterSurfaceBuilder.compute_ribbons(field, chunk)
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
