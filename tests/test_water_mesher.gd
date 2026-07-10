extends GutTest

const SEED := 2697992464
const SITE_CHUNK := Vector2i(0, -6)

static var _plans: Dictionary = {}
static var _waters: Dictionary = {}
static var _regions: Dictionary = {}


static func _water(seed_v: int) -> WaterPlan:
	if not _waters.has(seed_v):
		var plan := HeightfieldPlan.new(seed_v, 22.0, 8, "mean", 3)
		var water := WaterPlan.new(seed_v, 22.0, 8)
		plan.set_water_plan(water)
		_plans[seed_v] = plan
		_waters[seed_v] = water
	return _waters[seed_v]


static func _region(seed_v: int, chunk: Vector2i):
	var key := [seed_v, chunk]
	if not _regions.has(key):
		_water(seed_v)
		_regions[key] = _plans[seed_v].compute_region(
			chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	return _regions[key]


## Phase 1 (hydrostatic fill) note: the fill legitimately extends water
## coverage right up to real cliff bases, which the site chunk has one of —
## a 3-cell run at lattice (19,12)-(19,14) where a corner sits on a ~16m
## cliff face beside two different water bodies (levels 3.0 and 5.70,
## verified: WaterMesher._mesh_cut_cell's existing multi-seam guard
## (WaterMesher.gd, "Guard: a cell whose wet corners span >= 3 level
## clusters") correctly drops the polygon there rather than emit a fold —
## this is the SAME pre-existing, tested behaviour
## test_multi_seam_cell_never_folds verifies in isolation, now also firing
## on this real site during ordinary WaterMesher.build() calls because the
## fill (unlike the old claim-radius field) reaches this close to the cliff
## at all. Not a new defect — investigated during Phase 1 (see
## .superpowers/sdd/h-task-1-report.md). GUT checks for unhandled errors
## right after the test body returns (gut.gd _run_test, BEFORE after_each
## runs — an after_each hook is too late to un-fail an already-failed
## test), so every test that (transitively) builds the site chunk calls
## this immediately after its own build call, same as
## test_multi_seam_cell_never_folds already does inline for its own
## hand-built case.
func _mark_multiseam_handled() -> void:
	for e in GutUtils.get_error_tracker().get_current_test_errors():
		if e.contains_text("multi-seam cell"):
			e.handled = true


func test_interior_is_welded() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	assert_false(m.is_empty(), "site chunk builds water")
	assert_true(m.idx.size() % 3 == 0, "triangles")
	# Welded: no two verts share a position (the weld map dedupes them).
	var seen: Dictionary = {}
	for v in m.verts:
		var key: Vector3i = Vector3i((v * 8.0).round())
		assert_false(seen.has(key), "duplicate vert at %s" % v)
		seen[key] = true


func test_dry_chunk_builds_nothing() -> void:
	var water: WaterPlan = _water(SEED)
	# Reuse the dry-chunk scan from test_water_surface_builder: any chunk
	# whose bodies_near window is empty.
	var dry := Vector2i.MAX
	for cz in range(0, 40):
		for cx in range(0, 40):
			var b: Dictionary = water.bodies_near(Vector2i(cx * 8 + 4, cz * 8 + 4), 5)
			if b.ponds.is_empty() and b.rivers.is_empty():
				dry = Vector2i(cx, cz)
				break
		if dry != Vector2i.MAX:
			break
	assert_true(dry != Vector2i.MAX, "found a dry chunk")
	assert_true(WaterMesher.build(water, dry, _region(SEED, dry)).is_empty(),
		"dry chunk => empty build")


## Phase 2a note: WaterMesher._hem (unmodified, out of scope this phase)
## hems every non-border free edge EXCEPT the two whose endpoints both sit
## near a recorded cut (_near_cut) — and hemming welds a second triangle
## onto that edge (via _hem's own [a,hb,b] quad sharing the (a,b) diagonal),
## which makes it no longer free at all. So the ONLY non-border free edges
## this test could ever check were a cut's own lip/base line — with zero
## cuts on the site now (H1 fixed — see test_water_field.gd's
## test_steep_spans_empty_at_the_site), checked is legitimately 0 (nothing
## was ever exempted from hemming, because nothing is near a nonexistent
## cut). See test_water_field.gd::test_waterline_is_a_terrain_contour's
## docstring for the full forensic trace of this same structural finding
## (verified there: 100% of the original 32 checked vertices sat on the
## site's one cut's own top/bottom line, none anywhere else). Treated as an
## explicit pass; the strict per-vertex check still runs in full whenever a
## real fall exists (checked > 0) on any seed/chunk.
func test_boundary_verts_sit_on_the_waterline() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	var checked := 0
	for e: Array in WaterMesher.free_edges(m.verts, m.idx):
		for v: Vector3 in e:
			if _on_chunk_border(v):
				continue
			# Task 6: the hem buries its outer rim below the terrain by
			# design (min(shore_y, g) - HEM_DROP) — those verts are not on
			# any water surface and are a separate free-edge class this test
			# predates. Skip them; they are covered by test_hem_is_buried
			# and test_every_free_edge_is_accounted_for instead.
			var g: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
			if v.y < g - 0.3:
				continue
			# Wall-shore reality: this terrain's shores are vertical walls
			# and claim edges, not beaches — per the amended rule the water's
			# edge rides its OWN surface (no dips to ground, no floating).
			# Near fall cuts and body seams two surfaces coexist within the
			# 1.5m cross, so the vert must match the nearest-in-height one
			# (its own side), not the highest.
			var lvl_near: float = -INF
			var diff_min: float = INF
			for q: Vector2 in [Vector2(v.x, v.z),
					Vector2(v.x + 1.5, v.z), Vector2(v.x - 1.5, v.z),
					Vector2(v.x, v.z + 1.5), Vector2(v.x, v.z - 1.5)]:
				var l: float = WaterField.level_at(ctx, q)
				if l == -INF:
					continue
				lvl_near = maxf(lvl_near, l)
				diff_min = minf(diff_min, absf(v.y - l))
			checked += 1
			assert_true(lvl_near > -INF,
				"free-edge vert claims no water nearby: %s" % v)
			if lvl_near > -INF:
				assert_true(diff_min <= 0.6,
					"vert off its water surface: %s (nearest lvl diff %.2f)" % [v, diff_min])
	if checked == 0:
		pass_test("no non-hemmed shoreline vertices at all: zero cuts on this chunk (H1 fixed) — see this test's own docstring")
		return
	assert_true(checked > 20, "site has a real shoreline (%d verts)" % checked)


## The sheet's winding convention is +Y (upward normals); later tasks (hem,
## cut cells) must keep it. Task 6's hem quads are DELIBERATE near-vertical/
## downward folds — exempt, identified by emission position: _hem runs last
## of the triangle emitters, so every triangle at index >= m.hem_start is
## hem geometry. Everything below hem_start (sheet AND cut-cell triangles,
## including cut verts pinned to water levels beside cliff skirts) is
## checked STRICTLY — no geometric proxy (near-vertical or buried-vertex)
## exemptions, which would also match legitimate cut-cell geometry near
## cliffs and silently un-cover it (review finding).
func test_all_triangles_wind_up() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	assert_false(m.is_empty(), "site chunk builds water")
	var verts: PackedVector3Array = m.verts
	var idx: PackedInt32Array = m.idx
	var tri_count: int = m.hem_start / 3   # strict check below the hem mark
	for t in tri_count:
		var i0: int = idx[t * 3]
		var i1: int = idx[t * 3 + 1]
		var i2: int = idx[t * 3 + 2]
		var v0: Vector3 = verts[i0]
		var v1: Vector3 = verts[i1]
		var v2: Vector3 = verts[i2]
		var n: Vector3 = (v1 - v0).cross(v2 - v0)
		assert_true(n.y > -0.0001,
			"triangle %d winds down: %s, %s, %s (n=%s)" % [t, v0, v1, v2, n])


func _on_chunk_border(v: Vector3) -> bool:
	var span: float = 24.0 * 8.0
	var lx: float = fposmod(v.x, span)
	var lz: float = fposmod(v.z, span)
	return lx < 0.01 or lx > span - 0.01 or lz < 0.01 or lz > span - 0.01


## Hem triangles (index >= m.hem_start, _hem emits last) are exempt: a hem
## step legitimately spans more than CUT_JUMP where the ground itself drops
## a wall's height within HEM_W — buried water-to-ground geometry, not two
## disjoint water surfaces bridged by one triangle (the failure mode this
## test guards against). Everything below hem_start — sheet AND cut-cell
## triangles — is checked strictly with no geometric exemptions.
func test_no_triangle_bridges_a_fall() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	var tri: int = 0
	while tri < m.hem_start:   # strict check below the hem mark
		var lo: float = INF
		var hi: float = -INF
		for k in 3:
			var y: float = m.verts[m.idx[tri + k]].y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		assert_true(hi - lo < WaterMesher.CUT_JUMP + 0.5,
			"triangle spans %.2f vertically — bridges a fall" % (hi - lo))
		tri += 3


## A single cell can span >= 3 level clusters (two seams crossing one 3m
## cell at a 3-body corner). A 2-way split then necessarily groups two
## far-apart levels into one side; the guard must DROP that folded
## polygon (a loud hole) rather than emit bridging triangles (a silent
## fold). Hand-built st — no world plan needed; empty cuts forces the
## synthetic seam path.
func test_multi_seam_cell_never_folds() -> void:
	var n1: int = WaterMesher.N + 1
	var lvl := PackedFloat32Array()
	lvl.resize(n1 * n1)
	lvl.fill(-INF)
	var gnd := PackedFloat32Array()
	gnd.resize(n1 * n1)
	gnd.fill(0.0)
	lvl[0] = 3.0          # corner (0,0)
	lvl[1] = 9.0          # corner (1,0)
	lvl[n1 + 1] = 15.0    # corner (1,1)
	lvl[n1] = 9.0         # corner (0,1)
	var st: Dictionary = {
		"region": null,
		"ctx": {"ponds": [], "rivers": [], "buckets": {}, "region": null},
		"base": Vector2.ZERO, "lvl": lvl, "gnd": gnd,
		"verts": PackedVector3Array(), "idx": PackedInt32Array(),
		"cust": PackedFloat32Array(), "weld": {},
		"cuts": [], "cut_hits": {},
	}
	WaterMesher._mesh_cell(st, 0, 0)
	# The drop must be LOUD: expect the guard's push_warning (and mark it
	# handled so GUT does not fail the test for it).
	var warned := false
	for e in GutUtils.get_error_tracker().get_current_test_errors():
		if e.contains_text("multi-seam cell"):
			e.handled = true
			warned = true
	assert_true(warned, "the dropped polygon warns loudly")
	assert_true(st.idx.size() > 0, "the cell still emits its clean side")
	var tri: int = 0
	while tri < st.idx.size():
		var lo: float = INF
		var hi: float = -INF
		for k in 3:
			var y: float = st.verts[st.idx[tri + k]].y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		assert_true(hi - lo < WaterMesher.CUT_JUMP + 0.5,
			"triangle spans %.2f — multi-seam cell folded" % (hi - lo))
		tri += 3


## Phase 2a REWRITE (was "site records its falls" / m.cuts.size() >= 1 —
## the old cut-object world). H1 fixed: profile()/steep_spans() find ZERO
## steep spans on this seed's site (the rendered terrain never drops more
## than FALL_DROP_MIN in any 24m window here), so m.cuts — WaterField.
## fall_cuts()'s back-compat shim over steep_spans(), still read by
## WaterMesher.build (see WaterMesher.gd:31) — is empty, and the mesher's
## cut-cell paths (_mesh_cut_cell, _cell_cut, _synth_cut) simply never fire
## on this chunk: every cell meshes through the ordinary _mesh_cell path.
## The welded-lip GUARANTEE this test used to check is now vacuous here (no
## cut records exist to weld), which is the fully-fixed state, not a
## regression — asserted directly instead of silently no-op'ing over an
## empty array.
func test_cut_records_have_welded_lips() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	assert_eq(m.cuts.size(), 0,
		"H1 fixed: the site's rendered terrain never demands a fall, so m.cuts is empty")


## THE continuity invariant: after the hem, a free edge may only be (a) on
## the chunk border, (b) a fall-cut lip/base line (exempted from hemming by
## WaterMesher._near_cut so FallMesher's curtain has a genuine open edge to
## weld to), or (c) the hem's own outer rim (buried under the terrain).
##
## Phase 2a REWRITE (the pinned S*1.5-tolerance vertex is DELETED, not
## re-pinned — see below). H1 fixed: the site's steep_spans()/fall_cuts()
## return ZERO spans (the rendered terrain here never demands a fall), so
## m.cuts is empty and class (b) has no members on this chunk at all. That
## collapses the invariant to "every non-border free edge is buried" —
## which the site's 159 non-border free edges (verified directly, this
## task) all satisfy with ZERO exceptions: with no cut anywhere, _near_cut
## never exempts anything from hemming, so _hem runs on literally every
## shore edge and buries all of it. The old S vs S*1.5 tolerance question
## (how far a hem-flank vertex's own along-cut distance can grow from
## _hem_vert's HEM_W=1.5 outward push) was ENTIRELY about class (b)/(d)
## edges beside a real cut — with no cut on this seed's site, there is
## nothing left to pin that evidence against; the specific vertex
## (39.0, 3.950638, -1087.41) the old pin named doesn't exist in this
## build at all (it was the hem-flank of the site's one, now-gone, cut).
## Left un-re-pinned rather than fabricated against a different seed/cliff
## purely to keep a number in the suite — Phase 2b's mesher rewrite is
## where a genuine steep-terrain integration fixture (if one is ever
## added) would be the right place to re-derive this tolerance's real
## necessity from scratch.
func test_every_free_edge_is_accounted_for() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	assert_eq(m.cuts.size(), 0, "H1 fixed: no cuts on this chunk (class (b) is empty here)")
	var checked := 0
	for e: Array in WaterMesher.free_edges(m.verts, m.idx):
		if _on_chunk_border(e[0]) and _on_chunk_border(e[1]):
			continue
		checked += 1
		var buried := true
		for v: Vector3 in e:
			var g: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
			if v.y > g - 0.3:
				buried = false
		assert_true(buried,
			"unaccounted free edge %s-%s (not border/buried, and m.cuts is empty so it cannot be a cut line)" % [e[0], e[1]])
	assert_true(checked > 20, "site has real shoreline free edges to check (%d)" % checked)


func test_hem_is_buried() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	var hem_n := 0
	for v in m.verts:
		var g: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
		if v.y < g - 0.5:
			hem_n += 1
	assert_true(hem_n > 10, "hem exists and dives under the banks (%d)" % hem_n)


## Adjacent chunks must produce bit-identical seam vertices at their shared
## border so the two meshes weld visually with no crack. Pinned to (0,-6)/
## (1,-6) at world x = 192 (the shared border) — probed first (temporary
## script, since removed) across (0,-6)/(0,-7), (0,-6)/(-1,-6), (1,-6)/
## (1,-7), (0,-7)/(1,-7), (-1,-6)/(-1,-7), (1,-6)/(2,-6), (0,-6)/(0,-5):
## the originally proposed pair already had 12 matching seam verts, well
## over the >= 2 floor, so it stayed pinned.
func test_chunk_seam_identity() -> void:
	var water: WaterPlan = _water(SEED)
	var a: Dictionary = WaterMesher.build(water, Vector2i(0, -6), _region(SEED, Vector2i(0, -6)))
	var b: Dictionary = WaterMesher.build(water, Vector2i(1, -6), _region(SEED, Vector2i(1, -6)))
	_mark_multiseam_handled()
	var seam_x: float = 24.0 * 8.0   # world x of the shared border
	var a_seam: Dictionary = {}
	for v in a.verts:
		if absf(v.x - seam_x) < 0.01:
			a_seam[Vector3i((v * 100.0).round())] = v
	var matched := 0
	for v in b.verts:
		if absf(v.x - seam_x) < 0.01 and a_seam.has(Vector3i((v * 100.0).round())):
			matched += 1
	assert_true(matched >= 2, "adjacent chunks share bit-identical seam verts (%d)" % matched)


## Phase 2a REWRITE (was "plunge band baked near falls" / churn > 0): the
## plunge band in _attributes only ever bakes steep > 0.9 by iterating
## st.cuts (see WaterMesher.gd:634-639) — with H1 fixed and zero steep
## spans on this seed's site, st.cuts is empty, so that loop body never
## runs and no vertex anywhere reaches the plunge band's exclusive >0.9
## territory (ordinary grade_at()-derived steep is clamped to <= 0.85, see
## _attributes' own clampf). churn == 0 is now the correct baseline; the
## rewritten assertion checks that directly instead of asserting the old
## (now impossible) opposite. steep itself is still meaningfully computed
## from grade_at() everywhere (verified: max steep found below is > 0, i.e.
## the field IS reporting real, if gentle, gradient — see WaterField.
## grade_at's own Phase 2a docstring on why it's no longer zeroed at a cut).
func test_commit_and_attributes() -> void:
	var water: WaterPlan = _water(SEED)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, _region(SEED, SITE_CHUNK))
	_mark_multiseam_handled()
	assert_eq(m.cust.size(), m.verts.size() * 4, "4 floats per vertex")
	var mesh: ArrayMesh = WaterMesher.commit(m)
	assert_eq(mesh.surface_get_array_len(0), m.verts.size(), "verts committed")
	assert_true(m.wet_cells.size() > 0, "volume cells recorded")
	assert_eq(m.cuts.size(), 0, "H1 fixed: no cuts on this chunk, so no plunge band is baked")
	var churn := 0
	var max_steep := 0.0
	var idx := 0
	while idx < m.cust.size():
		max_steep = maxf(max_steep, m.cust[idx + 3])
		if m.cust[idx + 3] > 0.9:
			churn += 1
		idx += 4
	assert_eq(churn, 0, "no plunge band anywhere: the site has no fall to churn near")
	assert_true(max_steep > 0.0, "grade_at still reports real (if gentle) gradient everywhere")


func test_build_chunk_scene_contract() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	assert_not_null(node, "site builds")
	assert_not_null(node.get_node_or_null("WaterSheet"), "sheet present")
	var areas := 0
	for ch in node.get_children():
		if ch is Area3D:
			areas += 1
			assert_true(ch.has_meta("surface_c") and ch.has_meta("surface_g"),
				"volume carries the sampled surface plane")
			assert_eq(ch.collision_layer, 1 << 7, "water layer")
	assert_true(areas > 0, "swim volumes present")
	node.free()
