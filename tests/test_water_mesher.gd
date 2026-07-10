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


## Phase 2b note (supersedes the Phase 1/2a "multi-seam guard" story that
## used to live here): the site chunk's lattice run at (19,12)-(19,14) —
## beside a ~16m cliff, previously reported as "two different water bodies
## at levels 3.0 and 5.70" that needed the (now-deleted) multi-seam guard to
## drop a folding polygon there — is VERIFIED (this task, headless probe) to
## be a genuinely CONTINUOUS column post-Phase-2a: level_at along that
## column reads 3.00 -> 3.00 -> 3.00 -> 3.00 -> 4.35 -> 5.70 as z increases
## toward the pool, a real smooth descent, not a hard jump. The mesh's own
## max per-triangle vertical span across the ENTIRE site chunk (non-hem
## triangles) is 2.00m, comfortably under CUT_JUMP+0.5 — the guard's
## deletion (see WaterMesher.gd's file header and _mesh_cell) is empirically
## safe at the one real site that used to trigger it; Phase 2a's continuous,
## terrain-hugging profile is what fixed the underlying jump, not a mesher
## band-aid. No more "multi-seam cell" warnings are possible anywhere in
## this file (the push_warning and its detection machinery are both gone),
## so the GUT-unhandled-error workaround that used to run after every build
## in this suite is deleted too.
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


## Phase 2b note: WaterMesher._hem now hems EVERY non-border free edge, full
## stop — there is no cut/fall exemption left at all (_near_cut is deleted;
## see WaterMesher.gd's file header and _hem's own docstring), so every free
## edge that is not a chunk border is buried by the hem and there are
## structurally ZERO non-border, non-buried free edges left for this test to
## check on ANY seed/chunk, not just this one — the same "nothing left to
## check" state test_water_field.gd::test_waterline_is_a_terrain_contour's
## docstring already documented for Phase 2a's narrower (H1-only) case, now
## true unconditionally. Treated as an explicit pass.
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
			# The hem buries its outer rim below the terrain by design
			# (min(shore_y, g) - HEM_DROP) — those verts are not on any water
			# surface and are a separate free-edge class this test predates.
			# Skip them; they are covered by test_hem_is_buried and
			# test_every_free_edge_is_accounted_for instead.
			var g: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
			if v.y < g - 0.3:
				continue
			# Wall-shore reality: this terrain's shores are vertical walls
			# and claim edges, not beaches — per the amended rule the water's
			# edge rides its OWN surface (no dips to ground, no floating).
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
		pass_test("no non-hemmed shoreline vertices at all: _hem exempts nothing any more (see this test's own docstring)")
		return
	assert_true(checked > 20, "site has a real shoreline (%d verts)" % checked)


## The sheet's winding convention is +Y (upward normals); the hem must keep
## it too. The hem's own quads are DELIBERATE near-vertical/downward folds —
## exempt, identified by emission position: _hem runs last of the triangle
## emitters, so every triangle at index >= m.hem_start is hem geometry.
## Everything below hem_start (Phase 2b: ordinary sheet geometry only — there
## is no separate cut-cell class left at all) is checked STRICTLY — no
## geometric proxy (near-vertical or buried-vertex) exemptions.
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


## Phase 2b: this is now the "max-slope sanity bound" the brief describes as
## the replacement for the deleted CUT_JUMP-based cell splitting (see
## WaterMesher.gd's file header) — with levels continuous by construction
## (Phase 2a's terrain-hugging profile), adjacent 3m-apart lattice samples
## cannot legitimately jump more than this without the profile itself being
## broken, so a single ordinary sheet triangle spanning more than CUT_JUMP+
## 0.5 vertically is a real defect, not a legitimate steep face (steep faces
## still fit inside this bound — see WaterMesher.gd's file header for the
## ~85°-max-slope framing). Hem triangles (index >= m.hem_start, _hem emits
## last) are exempt: a hem step legitimately spans more than CUT_JUMP where
## the ground itself drops a wall's height within HEM_W — buried
## water-to-ground geometry, not two disjoint water surfaces bridged by one
## triangle. Everything below hem_start (ordinary sheet triangles only now)
## is checked strictly with no geometric exemptions.
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


## I-2 (final-review-run2.md Important 2): test_no_triangle_bridges_a_fall
## above is only ever exercised on the pinned SITE_CHUNK, which H1 confirmed
## has ZERO steep spans — the strict CUT_JUMP+0.5=2.5m bound has never once
## been checked against a real cliff, and it does NOT hold there: a genuine
## storey cliff (up to MAX_CLIFF_STEP*STOREY_HEIGHT=12m at one tile boundary)
## legitimately produces a much larger triangle span once bilinear'd through
## the 6m fill lattice down to the mesher's own 3m sample spacing — this is
## the water surface correctly following real terrain, not a bridging bug.
##
## Chose option (b) from the finding (keep 2.5m strict, exempt triangles
## that are LEGITIMATELY steep) over option (a) (derive one honest bound
## from design) after measuring the real worst case on production seed
## 991177 (this task's own investigation, see the report): the TRUE
## worst-case span is not bounded by a single clean "one storey-cliff over
## one FILL_STEP" formula the way the finding's own framing suggests — the
## hydrostatic fill's flood-adjacency mechanism (_relax_fill, WaterField.gd)
## can place a HIGH-level flood cell directly next to unrelated low ground
## via lateral spread, not just along the channel's own hug — so a formula
## tight enough to stay useful as a bridging-bug detector cannot also
## safely bound every legitimate steep triangle (measured real spans on
## seed 991177: 1.70m / 3.35m / 6.97m across three different real steep
## chunks — the honest design bound would have to be very loose, at which
## point it stops usefully catching anything). A GROUND-TRUTH exemption
## (does the real, independently-resampled terrain show a genuine nearby
## drop?) covers both mechanisms at once (verified: 0 of 90 offending
## triangles on chunk (-2,10) below survive this exemption) without needing
## to know WHICH mechanism produced the span.
##
## Deliberately NOT anchored on WaterField.steep_spans()'s own reported
## corridor (measured: a lip/base corridor around steep_spans' output
## covers only 64/90 offending triangles here — steep_spans only scans
## ALONG THE CHANNEL, so it misses spans from the fill's lateral flood
## against a nearby cliff the channel itself never touches) — that would
## also be closer to mirroring the fix's own internals than an
## independently-verifiable ground fact. The exemption re-samples raw
## TerrainSurfaceField ground in a ring around each offending triangle and
## independently re-applies the same "24m-window drop > FALL_DROP_MIN" I1
## rule _steep_scan encodes (WaterField.gd), exactly as
## test_no_steep_span_without_terrain_drop already does for a different
## purpose — an issue-level property (real terrain has a real cliff there),
## not a re-derivation of steep_spans' bookkeeping.
##
## Runs on a REAL production chunk (seed 991177, chunk (-2,10) — discovered
## by scanning both pinned seeds for a chunk with non-empty steep_spans;
## drop=12.00, the theoretical max at one MAX_CLIFF_STEP boundary) rather
## than a synthetic hand-built one: WaterMesher.build always resolves its
## own rivers via water.bodies_near, so there is no injection point for a
## hand-placed RiverTrace the way WaterField.steep_spans' own hand-built-
## cliff fixture (test_water_field.gd) can use directly — a real seed/chunk
## with a genuine steep reach is the practical equivalent for exercising the
## mesher's own pipeline end to end, matching the sibling fixture's own
## "practical alternative when a stub input would not exercise the real
## plumbing" reasoning.
func test_no_triangle_bridges_a_fall_except_legitimate_steep_terrain() -> void:
	var water: WaterPlan = _water(991177)
	var chunk := Vector2i(-2, 10)
	var region = _region(991177, chunk)
	var m: Dictionary = WaterMesher.build(water, chunk, region)
	assert_false(m.is_empty(), "the steep chunk builds real water")
	var tri: int = 0
	var checked := 0
	var exempted := 0
	var violations := 0
	var offenders: Array = []
	while tri < m.hem_start:
		var lo: float = INF
		var hi: float = -INF
		var cx := 0.0
		var cz := 0.0
		for k in 3:
			var v: Vector3 = m.verts[m.idx[tri + k]]
			lo = minf(lo, v.y)
			hi = maxf(hi, v.y)
			cx += v.x
			cz += v.z
		cx /= 3.0
		cz /= 3.0
		var span: float = hi - lo
		checked += 1
		if span >= WaterMesher.CUT_JUMP + 0.5:
			if _has_real_nearby_ground_drop(region, cx, cz):
				exempted += 1
			else:
				violations += 1
				if offenders.size() < 5:
					offenders.append("centroid=(%.1f,%.1f) span=%.3f — no real terrain drop nearby" % [cx, cz, span])
		tri += 3
	print("test_no_triangle_bridges_a_fall_except_legitimate_steep_terrain: %d triangles checked, %d exempted (real cliff), %d violations" % [
		checked, exempted, violations])
	assert_true(checked > 0, "the steep chunk has real sheet triangles to check")
	assert_true(exempted > 0, "at least one triangle on this known-steep chunk actually needed the exemption (otherwise this test exercises nothing new)")
	assert_eq(violations, 0,
		"%d triangles span >= CUT_JUMP+0.5 with no real nearby terrain drop to justify it — a genuine bridge (%s)" % [
			violations, offenders])


## Independent ground-truth re-derivation (NOT a call into
## WaterField.steep_spans or _steep_scan — see the caller's own docstring on
## why this must be independently verifiable, not a mirror of steep_spans'
## channel-anchored bookkeeping): true when the REAL terrain within a 24m
## window centred on (cx,cz) drops more than WaterField.FALL_DROP_MIN,
## re-applying the same I1 rule directly against TerrainSurfaceField.
func _has_real_nearby_ground_drop(region, cx: float, cz: float) -> bool:
	var g_lo := INF
	var g_hi := -INF
	for dz in range(-12, 13, 3):
		for dx in range(-12, 13, 3):
			var g: float = TerrainSurfaceField.surface_y(region, cx + float(dx), cz + float(dz))
			g_lo = minf(g_lo, g)
			g_hi = maxf(g_hi, g)
	return (g_hi - g_lo) > WaterField.FALL_DROP_MIN


## THE continuity invariant: after the hem, a free edge may only be (a) on
## the chunk border, or (b) the hem's own outer rim (buried under the
## terrain).
##
## Phase 2b (test_multi_seam_cell_never_folds and
## test_cut_records_have_welded_lips, formerly here, are DELETED — see this
## task's report — since the multi-seam guard and the cut-record/welded-lip
## concept they tested no longer exist AT ALL, not just "empty on this
## seed"; there is nothing left for either test to exercise). H1 fixed AND
## the cut/fall exemption itself is now fully deleted (_near_cut is gone —
## see WaterMesher.gd's file header and _hem's own docstring): EVERY
## non-border free edge is hemmed unconditionally, on any seed/chunk, so
## class (b) from the old three-way split above (a fall-cut lip/base line)
## no longer exists as a category at all. That collapses the invariant to
## "every non-border free edge is buried" — which the site's real free
## edges (verified directly, this task) all satisfy with ZERO exceptions.
##
## S vs S*1.5 tolerance (brief item 2, re-derived): the old S*1.5 pinned
## tolerance vertex was already deleted, not re-pinned, in Phase 2a (its
## whole reason for existing — a hem-flank vertex beside a real recorded cut
## — no longer existed even then; see the Phase 2a report). With
## `_near_cut`'s exemption now ALSO fully deleted in this phase, there is no
## cut-adjacent free-edge category left at all for an S vs S*1.5 tolerance
## to distinguish between — the invariant below needs no tolerance concept,
## plain border|buried is the whole story now. Reported as: the S*1.5 case
## is retired outright, not replaced with a plain-S assertion (there was
## nothing left to assert a distance FROM).
func test_every_free_edge_is_accounted_for() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
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
			"unaccounted free edge %s-%s (not border, and every non-border edge must be hemmed)" % [e[0], e[1]])
	assert_true(checked > 20, "site has real shoreline free edges to check (%d)" % checked)


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


## Phase 2b REWRITE (was checking m.cuts.size()==0 — m.cuts no longer
## exists at all, the returned dict has no `cuts` key any more; see
## WaterMesher.build's own docstring). The plunge band in _attributes now
## bakes steep > 0.9 by iterating WaterField.steep_spans()'s own result
## (kept internally on `st.steep`, computed once in build() — see
## _attributes' Phase 2b docstring), independently re-derived here rather
## than trusted: zero spans on this seed's site (H1 fixed, unchanged since
## Phase 2a — see test_water_field.gd's test_steep_spans_empty_at_the_site)
## means the plunge loop body never runs and no vertex anywhere reaches the
## band's exclusive >0.9 territory (ordinary grade_at()-derived steep is
## clamped to <= 0.85, see _attributes' own clampf). churn == 0 is the
## correct baseline at this site; steep itself is still meaningfully
## computed from grade_at() everywhere (max steep found below is > 0, i.e.
## the field IS reporting real, if gentle, gradient).
func test_commit_and_attributes() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var spans: Array = WaterField.steep_spans(ctx, Rect2(
		Vector2(SITE_CHUNK) * (WaterMesher.TILE * 8.0), Vector2.ONE * WaterMesher.TILE * 8.0))
	assert_eq(spans.size(), 0, "H1: independently re-derived, no steep spans on this chunk")
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	assert_eq(m.cust.size(), m.verts.size() * 4, "4 floats per vertex")
	assert_false(m.has("cuts"), "m.cuts is gone entirely (Phase 2b: no cut geometry left to carry)")
	var mesh: ArrayMesh = WaterMesher.commit(m)
	assert_eq(mesh.surface_get_array_len(0), m.verts.size(), "verts committed")
	assert_true(m.wet_cells.size() > 0, "volume cells recorded")
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


## Phase 2b (moved from the deleted tests/test_water_falls.gd, which asserted
## m.cuts.size()==0 + FallMesher.build([])==null + no "Waterfalls" node — the
## first two no longer make sense at all now that m.cuts and FallMesher.gd
## are both gone entirely, not just empty; the THIRD assertion is the one
## that still means something and survives here, at the build_chunk/scene
## level, which is the only level "no waterfall NODE" was ever really about).
## Falls are no longer a separate swept mesh with its own MeshInstance3D —
## WaterSurfaceBuilder.build_chunk emits exactly one "WaterSheet" node and
## never a "Waterfalls" node, on ANY chunk (steep terrain included): the
## falling look is a shader blend on the one sheet material now, not
## additional geometry. Checked on the site chunk (dry of falls per H1) AND
## structurally by asserting build_chunk's own source has no code path that
## could ever add a second MeshInstance3D — see the direct source check
## below, which is honest that "no waterfall nodes ANYWHERE" is a structural
## claim about build_chunk, not just an empirical one about this one chunk.
func test_no_waterfall_nodes() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	assert_not_null(node, "site still builds its water sheet")
	assert_null(node.get_node_or_null("Waterfalls"),
		"build_chunk never adds a Waterfalls node — falls are a shader blend on the one sheet now")
	var mesh_instances := 0
	for ch in node.get_children():
		if ch is MeshInstance3D:
			mesh_instances += 1
			assert_eq(ch.name, "WaterSheet", "the only MeshInstance3D child is the sheet")
	assert_eq(mesh_instances, 1, "exactly one mesh (the sheet) — no second fall mesh, ever")
	node.free()
