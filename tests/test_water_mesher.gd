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


func test_interior_is_welded() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
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


func test_boundary_verts_sit_on_the_waterline() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
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


func test_cut_records_have_welded_lips() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	assert_true(m.cuts.size() >= 1, "site records its falls")
	var vset: Dictionary = {}
	for v in m.verts:
		vset[v] = true
	for rec: Dictionary in m.cuts:
		assert_true(rec.lip.size() >= 2, "lip is a polyline")
		for v: Vector3 in rec.lip:
			assert_true(vset.has(v), "lip vert %s is bit-equal to a sheet vert" % v)
		for v: Vector3 in rec.base:
			assert_true(vset.has(v), "base vert %s is bit-equal to a sheet vert" % v)


func test_every_free_edge_is_accounted_for() -> void:
	# THE continuity invariant: after the hem, a free edge may only be
	# (a) on the chunk border, (b) a fall-cut lip/base line, or
	# (c) the hem's outer rim, buried under the terrain.
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	for e: Array in WaterMesher.free_edges(m.verts, m.idx):
		if _on_chunk_border(e[0]) and _on_chunk_border(e[1]):
			continue
		var buried := true
		var on_cut := true
		for v: Vector3 in e:
			var g: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
			if v.y > g - 0.3:
				buried = false
			var near := false
			for rec: Dictionary in m.cuts:
				var p2 := Vector2(v.x, v.z)
				if absf((p2 - rec.cut.p).dot(rec.cut.dir)) < WaterMesher.S \
						and absf((p2 - rec.cut.p).dot(rec.cut.across)) < rec.cut.half + WaterMesher.S:
					near = true
			if not near:
				on_cut = false
		assert_true(buried or on_cut,
			"unaccounted free edge %s-%s (not border/cut/buried)" % [e[0], e[1]])


func test_hem_is_buried() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
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


func test_commit_and_attributes() -> void:
	var water: WaterPlan = _water(SEED)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, _region(SEED, SITE_CHUNK))
	assert_eq(m.cust.size(), m.verts.size() * 4, "4 floats per vertex")
	var mesh: ArrayMesh = WaterMesher.commit(m)
	assert_eq(mesh.surface_get_array_len(0), m.verts.size(), "verts committed")
	assert_true(m.wet_cells.size() > 0, "volume cells recorded")
	var churn := 0
	var idx := 0
	while idx < m.cust.size():
		if m.cust[idx + 3] > 0.9:
			churn += 1
		idx += 4
	assert_true(churn > 0, "plunge band baked near falls")


func test_build_chunk_scene_contract() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
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
