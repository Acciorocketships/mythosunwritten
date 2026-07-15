extends GutTest

# r3-task-4/5 (plan docs/superpowers/plans/2026-07-10-water-continuous-surface.md,
# briefs .superpowers/sdd/r3-task-4-brief.md, r3-task-5-brief.md): WaterSkin
# welds a 2.0m interior lattice to a conforming boundary strip whose outer
# rim sits directly ON WaterContour's own smooth curves (Task 3) — this is
# the mesh that actually fixes the marching-squares corners
# test_water_contour.gd's own header documents (the old mesher's raw
# perimeter walk) — PLUS (Task 5) a meniscus rim that curls the strip's own
# curve edge down and outward into either a buried bank seal or a compact
# rounded drop edge. Task 4
# left the curve itself as the mesh's free edge ("no rim yet"); Task 5's rim
# heals that edge into interior geometry and TIGHTENS the invariant:
# test_free_edges_only_buried_rim_or_border's "accounted for" class is now
# outer-row(row5)-or-border, replacing Task 4's curve-or-border.

const SEED := 2697992464
const SITE_CHUNK := Vector2i(0, -6)


## Actual surface waves need several render vertices per wavelength. The old
## 3m lattice could not represent the approved 6-20m packets without reading
## as a faceted plane or aliasing back into contour lines.
func test_render_lattice_is_dense_enough_for_geometric_wavelets() -> void:
	assert_true(WaterSkin.STEP <= 2.0,
		"water render lattice is at most 2m (currently %.2fm)" % WaterSkin.STEP)

# --- Task 5 rim classification (mirrors WaterSkin's outer-row numeric
# structure, not its reach/pinch formula — see _on_rim_outer_row) ---
const RIM_MAX_REACH := WaterField.FILL_STEP \
	+ (WaterField.TILE * 0.5 - CliffDressing.PLACE) + 2.0
# A wall-turn miter may sit one 6m fill cell beyond a contour column, plus the
# independently-derived 1.5m KayKit recess and local curl slack. This bound is
# intentionally geometric, not copied from WaterSkin's miter limit.
const RIM_OUTER_Y_GATE := 0.60 # strictly between row4's -0.55 and row5's -0.65
const RIM_BURY_GATE := 0.25   # brief's own "test_rim_outer_row_is_buried ... >= 0.25"

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


## 192m streamer-chunk rect — MUST match WaterField.ctx's own
## `base := Vector2(chunk.x, chunk.y) * (TILE * 8.0)` convention exactly (the
## plan's erratum: Vector2i chunk args are 192m chunks, not 24m cells).
static func _rect(chunk: Vector2i) -> Rect2:
	return Rect2(Vector2(chunk) * (WaterField.TILE * 8.0), Vector2.ONE * WaterField.TILE * 8.0)


## Edges used by exactly one triangle — ported verbatim from the old
## marching-squares mesher's own free_edges oracle pattern (now deleted,
## r3 Task 7), ARRAY-shaped so it works directly against WaterSkin's Mesh.ARRAY_MAX
## `arrays` output (ARRAY_VERTEX/ARRAY_INDEX) without needing WaterSkin to
## also expose a bespoke verts/idx dict shape.
static func _free_edges(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count: Dictionary = {}
	var tri: int = 0
	while tri < idx.size():
		for k in 3:
			var a: int = idx[tri + k]
			var b: int = idx[tri + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			count[key] = count.get(key, 0) + 1
		tri += 3
	var out: Array = []
	for key: Vector2i in count:
		if count[key] == 1:
			out.append([verts[key.x], verts[key.y]])
	return out


static func _on_chunk_border(v: Vector3, chunk: Vector2i) -> bool:
	var span: float = WaterField.TILE * 8.0
	var base: Vector2 = Vector2(chunk) * span
	var lx: float = v.x - base.x
	var lz: float = v.z - base.y
	return lx < 0.02 or lx > span - 0.02 or lz < 0.02 or lz > span - 0.02


## Nearest distance from p to ANY point on ANY curve in `curves` (brute
## force — test-side helper, not required to share WaterSkin's own
## presence-grid acceleration).
static func _dist_to_curves(curves: Array, p: Vector2) -> float:
	var best := INF
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		for i in pts.size():
			best = minf(best, pts[i].distance_to(p))
	return best


## Nearest curve point to p across every curve, returning both its distance
## and its own water level — the level is what _on_rim_outer_row needs (row5
## is defined relative to ITS OWN curve point's level, not a global constant).
static func _nearest_curve_pt(curves: Array, p: Vector2) -> Dictionary:
	var best := INF
	var best_level := 0.0
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		var levels: PackedFloat32Array = c.levels
		for i in pts.size():
			var d: float = pts[i].distance_to(p)
			if d < best:
				best = d
				best_level = levels[i]
	return {"dist": best, "level": best_level}


## True when v is a meniscus-rim OUTER (row5) vertex — Task 5's one allowed
## off-curve free-edge class. Deliberately does NOT reproduce WaterSkin's own
## reach/pinch/wall-blend formula (that would test the implementation against
## itself and could never catch a reach/pinch bug); instead it exploits the
## row definitions: row4 sits at L-0.55 and row5 at L-0.65. A y-gate strictly
## between them therefore admits row5 and ONLY row5, regardless of
## what reach WaterSkin chose at a wall-pinched, rising-overshot, or default
## point; RIM_MAX_REACH (one fill cell + the independently-derived KayKit
## recess + curl slack) scopes the search to "near some curve point" so an
## unrelated low-lying vertex elsewhere in the mesh (e.g. a different curve
## reach downstream at a lower level) can't false-positive.
static func _on_rim_outer_row(curves: Array, v: Vector3) -> bool:
	var p := Vector2(v.x, v.z)
	# At a corner, a buried vertex can be geometrically nearest to a different,
	# lower-level contour column than the one that emitted it. Requiring the
	# single nearest column therefore rejects a legitimate row5 edge. The
	# independent row definition is existential: it belongs to row5 when ANY
	# nearby contour column can account for both its reach and its burial.
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		var levels: PackedFloat32Array = c.levels
		for i in pts.size():
			if pts[i].distance_to(p) <= RIM_MAX_REACH \
				and v.y <= levels[i] - RIM_OUTER_Y_GATE:
				return true
	return false


## When the world-aligned interior ring lands exactly on a straight contour
## segment, the zipper has zero geometric width. Its independently sampled
## chain and the meniscus chain can have different collinear subdivisions,
## so the topology oracle sees free edges even though both chains occupy the
## same water-level line with no renderable hole. Admit only that exact
## geometric coincidence; even a 3cm separation remains a real failure.
static func _on_contour_surface(curves: Array, v: Vector3) -> bool:
	var p := Vector2(v.x, v.z)
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		var levels: PackedFloat32Array = c.levels
		var lim: int = pts.size() if c.closed else pts.size() - 1
		for i in lim:
			var j: int = (i + 1) % pts.size()
			var seg: Vector2 = pts[j] - pts[i]
			var len2: float = seg.length_squared()
			var t: float = clampf((p - pts[i]).dot(seg) / len2, 0.0, 1.0) \
				if len2 > 0.000001 else 0.0
			if p.distance_to(pts[i] + seg * t) <= 0.02 \
					and absf(v.y - lerpf(levels[i], levels[j], t)) <= 0.08:
				return true
	return false


## --- Task 6 (flow frames + real normals) test helpers ---

## Brute-force point-to-trace-polyline distance, and its min over every trace
## in ctx.rivers — deliberately independent of WaterSkin's own projection
## code (_project_on_trace/_flow_frame_at), so a river/pond-mode test built
## on this cannot validate the implementation against itself (same discipline
## _on_rim_outer_row's own docstring documents for the Task 5 rim tests).
static func _dist_point_to_trace(tr: RiverTrace, p: Vector2) -> float:
	var pts: PackedVector2Array = tr.points
	var n: int = pts.size()
	var best := INF
	for i in n - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg: Vector2 = b - a
		var seg_len2: float = seg.length_squared()
		var t: float = clampf((p - a).dot(seg) / seg_len2, 0.0, 1.0) if seg_len2 > 0.000001 else 0.0
		best = minf(best, p.distance_to(a + seg * t))
	return best


static func _dist_to_rivers(ctx: Dictionary, p: Vector2) -> float:
	var best := INF
	for tr: RiverTrace in ctx.rivers:
		best = minf(best, _dist_point_to_trace(tr, p))
	return best


## Linear scan for a welded vertex at `target` within `tol` — the same
## pattern test_rim_welds_to_strip already uses inline, factored out so the
## Task 6 tests can look up a specific curve point's own baked vertex (and
## read back its CUSTOM0/normal) without re-deriving WaterSkin's own weld key.
static func _find_vertex(verts: PackedVector3Array, target: Vector3, tol: float) -> int:
	for i in verts.size():
		if verts[i].distance_to(target) <= tol:
			return i
	return -1


## Structurally locates curve point (p, nrm2d)'s own row2 rim vertex — WITHOUT
## reproducing WaterSkin's own reach/wall-blend formula (same discipline
## _on_rim_outer_row already documents). rows2..5 are the rim vertices sitting
## on p's own outward-normal COLUMN (cross ~ 0) beyond the crest; row2 is the
## INNER
## one — the smaller outward offset (including the deliberately smoothed
## transition toward a neighbouring recessed wall). So "the near-column
## vertex with the smallest positive along"
## is row2, structurally, regardless of its Y.
## Locating by column POSITION is stable across bank and drop profiles and stays
## non-circular (it reads only the structural "row2 is the inner outer-column
## vertex," never WaterSkin's reach or Y formula). The one point the callers
## use it on has the outer rows well separated, so "smallest along" is
## unambiguously row2; a tie is broken toward the HIGHER vertex (row2 always
## sits above later curl rows).
static func _find_row2_vertex(verts: PackedVector3Array, p: Vector2, nrm2d: Vector2) -> int:
	var perp := Vector2(-nrm2d.y, nrm2d.x)
	var best_i: int = -1
	for i in verts.size():
		var v: Vector3 = verts[i]
		var off: Vector2 = Vector2(v.x, v.z) - p
		if absf(off.dot(perp)) > 0.05:
			continue
		var reach: float = off.dot(nrm2d)
		if reach < 0.15 or reach > 1.9:
			continue
		if best_i < 0:
			best_i = i
			continue
		var best_reach: float = (Vector2(verts[best_i].x, verts[best_i].z) - p).dot(nrm2d)
		if reach < best_reach - 0.02:
			best_i = i                        # clearly the inner (row2) vertex
		elif reach <= best_reach + 0.02 and v.y > verts[best_i].y:
			best_i = i                        # a tie: row2 sits above later curl rows
	return best_i


static func _column_diagnostic(verts: PackedVector3Array, p: Vector2,
		nrm2d: Vector2, level: float) -> Array[String]:
	var perp := Vector2(-nrm2d.y, nrm2d.x)
	var out: Array[String] = []
	for v: Vector3 in verts:
		var off: Vector2 = Vector2(v.x, v.z) - p
		if off.length() > 2.0 or absf(off.dot(perp)) > 0.12:
			continue
		out.append("along=%.3f cross=%.3f y=%.3f" % [
			off.dot(nrm2d), off.dot(perp), v.y - level])
		if out.size() >= 20:
			break
	return out


## Max outward reach (distance along the curve's own outward normal n̂, PAST
## the waterline point p) among any mesh vertex whose xz sits in p's own
## normal COLUMN — i.e. offset-from-p projects almost entirely onto n̂ with
## near-zero cross (tangential) component. r3-task-14: used to measure how
## far the rim's outer rows (rows2..5 — whichever reaches furthest) extend
## into the bank, WITHOUT reproducing WaterSkin's own reach/rising-blend
## formula (same "don't test the implementation against itself" discipline
## _find_row2_vertex/_on_rim_outer_row already document above): all curl rows
## sit EXACTLY on this column by construction (p + reach*n̂ has a
## cross component of precisely zero, up to float weld quantization), so
## whichever row WaterSkin chose to push furthest out is exactly what this
## finds — a fix that overshoots XZ shows up here regardless of whatever Y
## value or curl-normal angle it also happens to use. cross_tol=0.02 is
## comfortably above WELD_XZ_Q's own 1cm quantization noise and comfortably
## below the ~1.5m curve-point spacing that separates this column from its
## neighbours' own rim columns (verified structurally: two adjacent curve
## points 1.5m apart, each with up to a ~0.55m reach, cannot cross-contaminate
## a 0.02m-wide column centred on either one — see WaterContour.SPACING).
## reach_cap bounds the scan to a small neighbourhood of p (comfortably above
## an ordinary measured recessed-wall column; turn miters are raster-tested
## at their literal world pin instead)
## so a coincidental far-away alignment could never false-positive.
static func _max_outward_reach(verts: PackedVector3Array, p: Vector2, nrm2d: Vector2, cross_tol: float) -> float:
	var perp := Vector2(-nrm2d.y, nrm2d.x)
	var reach_cap := 5.0
	var best := -INF
	for v: Vector3 in verts:
		var off: Vector2 = Vector2(v.x, v.z) - p
		if off.length() > reach_cap:
			continue
		var along: float = off.dot(nrm2d)
		var cross: float = off.dot(perp)
		if absf(cross) > cross_tol:
			continue
		best = maxf(best, along)
	return best


## Finds the first point outside a wet contour where the rendered bank rises
## to the contour's own level.  This is intentionally test-side sampling of
## TerrainSurfaceField, not WaterSkin's rim formula: it measures the physical
## contact the visible water surface has to reach.
static func _bank_contact_distance(region, p: Vector2, nrm: Vector2, level: float) -> float:
	var step := 0.02
	var d := 0.0
	while d <= 3.0:
		var q: Vector2 = p + nrm * d
		if TerrainSurfaceField.surface_y(region, q.x, q.y) >= level:
			return d
		d += step
	return INF


## Returns the nearest contour sample to a reported world-space failure pin.
## The test deliberately discovers the sample instead of copying a production
## curve index, so contour reshaping cannot make the pin silently inspect an
## unrelated old index.
static func _nearest_curve_sample(curves: Array, hint: Vector2) -> Dictionary:
	var out := {"distance": INF}
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		for i in pts.size():
			var d: float = pts[i].distance_to(hint)
			if d < out.distance:
				out = {
					"distance": d,
					"point": pts[i],
					"normal": c.normals[i],
					"level": c.levels[i],
				}
	return out


## Independent geometric classification for the rim after wall contacts may
## extend farther than the old 2m strip inset. A true rim vertex lies on the
## outward (dry) side of its nearest contour frame; an interior/strip vertex
## lies on or toward the wet side. This keeps the chute falsifier checking
## surface bridges without mistaking intentionally buried under-wall rim faces
## for exposed water merely because their new physical wall reach exceeds
## WaterSkin.INSET.
static func _on_curve_outward_side(curves: Array, p: Vector2) -> bool:
	var nearest: Dictionary = _nearest_curve_sample(curves, p)
	if nearest.distance == INF:
		return false
	return (p - Vector2(nearest.point)).dot(Vector2(nearest.normal)) >= -0.05


## Returns the highest water-skin intersection over p in XZ.  This is an
## independent point-in-triangle query over the emitted arrays, used to tell
## a genuine mesh hole from terrain merely visible through transparent water.
static func _skin_y_at(arrays: Array, p: Vector2) -> float:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var best := -INF
	for ti in range(0, idx.size(), 3):
		var a: Vector3 = verts[idx[ti]]
		var b: Vector3 = verts[idx[ti + 1]]
		var c: Vector3 = verts[idx[ti + 2]]
		var av := Vector2(a.x, a.z)
		var bv := Vector2(b.x, b.z)
		var cv := Vector2(c.x, c.z)
		var v0: Vector2 = bv - av
		var v1: Vector2 = cv - av
		var v2: Vector2 = p - av
		var den: float = v0.x * v1.y - v1.x * v0.y
		if absf(den) < 0.000001:
			continue
		var u: float = (v2.x * v1.y - v1.x * v2.y) / den
		var v: float = (v0.x * v2.y - v2.x * v0.y) / den
		if u < -0.001 or v < -0.001 or u + v > 1.001:
			continue
		best = maxf(best, a.y + u * (b.y - a.y) + v * (c.y - a.y))
	return best


## A redundant coplanar zipper flap can retain a topological free edge at a
## contour/lattice turn while the canonical sheet underneath covers both
## sides. That is not a render hole. Probe independently off the edge on
## both sides; a true crack has no above-bed skin on one of them.
static func _edge_is_surface_covered(arrays: Array, a: Vector3, b: Vector3) -> bool:
	var av := Vector2(a.x, a.z)
	var bv := Vector2(b.x, b.z)
	var edge: Vector2 = bv - av
	if edge.length_squared() <= 0.000001:
		return true
	var side: Vector2 = Vector2(-edge.y, edge.x).normalized() * 0.06
	var mid: Vector2 = (av + bv) * 0.5
	var expected: float = (a.y + b.y) * 0.5
	return _skin_y_at(arrays, mid + side) >= expected - 0.10 \
		and _skin_y_at(arrays, mid - side) >= expected - 0.10


## Regression pins for the owner's 2026-07-13 screenshots at cells (3,-47),
## (5,-49), and (1,-46).  Every legitimate WaterSkin edge is local:
## interior diagonals are STEP*sqrt(2), a boundary-ring point is at most
## INSET+STEP*1.5 from its contour, and rim edges are shorter still.  An XZ
## edge over 6.6m therefore cannot represent water; it is a zipper jump
## between disconnected shoreline components, which renders as the giant
## cliff-corner fans in the screenshots.
func test_reported_corner_sites_have_no_nonlocal_water_triangles() -> void:
	var offender_lines: Array[String] = []
	var worst := 0.0
	for chunk: Vector2i in [Vector2i(0, -6), Vector2i(0, -7)]:
		var water: WaterPlan = _water(SEED)
		var skin: Dictionary = WaterSkin.build(water, chunk, _region(SEED, chunk))
		assert_false(skin.is_empty(), "reported chunk %s builds water" % chunk)
		if skin.is_empty():
			continue
		var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = skin.arrays[Mesh.ARRAY_INDEX]
		for ti in range(0, idx.size(), 3):
			for k in 3:
				var a: Vector3 = verts[idx[ti + k]]
				var b: Vector3 = verts[idx[ti + (k + 1) % 3]]
				var span: float = Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
				worst = maxf(worst, span)
				if span > 6.6 and offender_lines.size() < 12:
					var tv: Array[Vector3] = [
						verts[idx[ti]], verts[idx[ti + 1]], verts[idx[ti + 2]]]
					offender_lines.append("chunk %s tri %d: %.2fm %s -> %s; triangle=%s" % [
						chunk, ti / 3, span, a, b, str(tv)])
	print("MEAS reported corner triangle maximum XZ edge: %.3fm; offenders=%s" % [
		worst, str(offender_lines)])
	assert_true(offender_lines.is_empty(),
		"reported cliff-corner water contains non-local fan triangles: %s" % str(offender_lines))


## Exact 2026-07-13 19:29 chute view: player (52.2,8,-1091.6), crosshair
## (52.4,8.2,-1091.9).  The yellow ownership capture proves the broad face
## cutting through the green tongue is WaterSkin's boundary/interior sheet,
## not translucent terrain seen through valid water.  Edge-length tests are
## insufficient: subdividing an invalid bridge produces short invalid faces.
## Sample every local-scale face that reaches the interior ring (shore_dist
## >= INSET) and require its whole area to remain in wet field territory and
## above the rendered bed. Wall-contact rims can now legitimately extend past
## INSET beneath recessed rock, so meniscus-only faces are excluded by an
## independent nearest-contour outward-side test rather than by distance alone.
func test_reported_chute_faces_never_bridge_dry_ground_or_underrun_the_bed() -> void:
	var chunk := Vector2i(0, -6)
	var region = _region(SEED, chunk)
	var ctx: Dictionary = WaterField.ctx(_water(SEED), chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(chunk))
	var skin: Dictionary = WaterSkin.build(_water(SEED), chunk, region)
	assert_false(skin.is_empty(), "exact chute chunk builds water")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = skin.arrays[Mesh.ARRAY_INDEX]
	var custom0: PackedFloat32Array = skin.arrays[Mesh.ARRAY_CUSTOM0]
	var pin := Vector2(52.2, -1091.6)
	var checked := 0
	var offenders: Array[String] = []
	var bary: Array[Vector3] = [
		Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0),
		Vector3(0.5, 0.25, 0.25), Vector3(0.25, 0.5, 0.25),
		Vector3(0.25, 0.25, 0.5),
	]
	for ti in range(0, idx.size(), 3):
		var ids: Array[int] = [idx[ti], idx[ti + 1], idx[ti + 2]]
		var a: Vector3 = verts[ids[0]]
		var b: Vector3 = verts[ids[1]]
		var c: Vector3 = verts[ids[2]]
		var center := (Vector2(a.x, a.z) + Vector2(b.x, b.z) + Vector2(c.x, c.z)) / 3.0
		if center.distance_to(pin) > 15.0:
			continue
		var max_shore := maxf(custom0[ids[0] * 4 + 3],
			maxf(custom0[ids[1] * 4 + 3], custom0[ids[2] * 4 + 3]))
		var meniscus_only := true
		for id: int in ids:
			var vp: Vector3 = verts[id]
			if not _on_curve_outward_side(curves, Vector2(vp.x, vp.z)):
				meniscus_only = false
				break
		if max_shore < WaterSkin.INSET - 0.05 or meniscus_only:
			continue   # the meniscus is intentionally outside/buried
		for w: Vector3 in bary:
			var p3: Vector3 = a * w.x + b * w.y + c * w.z
			var p := Vector2(p3.x, p3.z)
			var level: float = WaterField.level_at(ctx, p)
			var ground: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
			checked += 1
			if level == -INF or level <= ground + 0.02 or p3.y < ground + 0.02:
				if offenders.size() < 20:
					offenders.append("tri=%d p=%s mesh_y=%.3f field=%.3f ground=%.3f shore=%.2f" % [
						ti / 3, p, p3.y, level, ground, max_shore])
	print("MEAS exact chute face samples checked=%d invalid=%d %s" % [
		checked, offenders.size(), str(offenders)])
	assert_true(checked > 100, "exact chute neighbourhood exercises real strip/interior faces")
	assert_true(offenders.is_empty(),
		"water faces near the exact chute view never bridge dry terrain or pass below the riverbed: %s" % str(offenders))


## Exact 19:28 long-bank view: the terrain cell is 24m wide but KayKit's
## visible cliff wall/lip origin is at +/-10.5m, 1.5m inside the true cell
## boundary.  Reaching merely 0.3-0.6m past WaterContour can therefore still
## leave the owner's visible slot.  At the wall point nearest the literal F3
## pin, require the emitted rim to reach that independently-derived visual
## face inset.
func test_reported_exact_bank_rim_reaches_recessed_cliff_face() -> void:
	var chunk := Vector2i(0, -6)
	var region = _region(SEED, chunk)
	var ctx: Dictionary = WaterField.ctx(_water(SEED), chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(chunk))
	var hint := Vector2(60.0, -1130.3)
	var sample: Dictionary = _nearest_curve_sample(curves, hint)
	assert_true(sample.distance < 5.0,
		"a contour sample exists at the exact long-bank wall (nearest %.2fm)" % sample.distance)
	if sample.distance >= 5.0:
		return
	var skin: Dictionary = WaterSkin.build(_water(SEED), chunk, region)
	assert_false(skin.is_empty(), "exact long-bank chunk builds water")
	if skin.is_empty():
		return
	var reach: float = _max_outward_reach(skin.arrays[Mesh.ARRAY_VERTEX],
		sample.point, sample.normal, 0.02)
	var visible_face_inset: float = WaterField.TILE * 0.5 - CliffDressing.PLACE
	print("MEAS exact bank contour=%s normal=%s distance=%.3f rim_reach=%.3f visual_face_inset=%.3f" % [
		sample.point, sample.normal, sample.distance, reach, visible_face_inset])
	assert_true(reach >= visible_face_inset,
		"water rim reaches the recessed KayKit cliff face: %.3fm >= %.3fm" % [
			reach, visible_face_inset])


## Exact 19:30 corner view: the dark triangular wedge is centred on the
## already-pinned diagonal saddle cell (129..132, -1164..-1161).  Topological
## free-edge checks can pass when two separately hemmed components simply
## fail to cover the wet region between them.  Rasterize an independent
## point-in-triangle oracle over the local field: every sample with >=8cm of
## static water must have rendered skin above its bed.
func test_reported_exact_corner_wet_region_has_connected_skin_coverage() -> void:
	var chunk := Vector2i(0, -7)
	var region = _region(SEED, chunk)
	var ctx: Dictionary = WaterField.ctx(_water(SEED), chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(chunk))
	var skin: Dictionary = WaterSkin.build(_water(SEED), chunk, region)
	assert_false(skin.is_empty(), "exact corner chunk builds water")
	if skin.is_empty():
		return
	var wet_checked := 0
	var offenders: Array[String] = []
	var step := 0.20
	var x := 127.0
	while x <= 135.0:
		var z := -1167.0
		while z <= -1158.0:
			var p := Vector2(x, z)
			var ground: float = TerrainSurfaceField.surface_y(region, x, z)
			var level: float = WaterField.level_at(ctx, p)
			if level != -INF and level - ground >= 0.08:
				wet_checked += 1
				var skin_y: float = _skin_y_at(skin.arrays, p)
				if skin_y == -INF or skin_y < ground + 0.02:
					if offenders.size() < 24:
						offenders.append("p=%s ground=%.3f level=%.3f skin=%.3f" % [
							p, ground, level, skin_y])
			z += step
		x += step
	print("MEAS exact corner wet samples=%d uncovered/under-bed=%d %s" % [
		wet_checked, offenders.size(), str(offenders)])
	assert_true(wet_checked > 40, "exact corner neighbourhood contains a real wet region")
	assert_true(offenders.is_empty(),
		"the exact touching-corner wet region is continuously covered above its bed: %s" % str(offenders))

	# Screen-space rays through the exact ReviewCam frame separated the real
	# mechanisms. The low probe is river and must be covered. The upper probe
	# is the precision-pinned high side of the cliff and must STAY dry; the
	# connection is closed by extending the meniscus under the recessed KayKit
	# wall, not by incorrectly flooding the cliff top. The flat-yellow
	# ownership rerender confirms that this removes the visible wedge.
	var low_probe := Vector2(131.1227, -1161.356)
	var low_ground: float = TerrainSurfaceField.surface_y(region, low_probe.x, low_probe.y)
	var low_level: float = WaterField.level_at(ctx, low_probe)
	var low_skin: float = _skin_y_at(skin.arrays, low_probe)
	print("MEAS exact corner low screen probe p=%s ground=%.3f level=%.3f skin=%.3f" % [
		low_probe, low_ground, low_level, low_skin])
	assert_true(low_level - low_ground >= 0.08,
		"exact lower corner probe is real river")
	assert_true(low_skin != -INF and low_skin >= low_ground + 0.02,
		"exact lower corner probe has above-bed rendered skin")

	var high_probe := Vector2(131.99, -1164.368)
	var high_ground: float = TerrainSurfaceField.surface_y(region, high_probe.x, high_probe.y)
	var high_level: float = WaterField.level_at(ctx, high_probe)
	assert_true(high_level < high_ground,
		"exact upper corner probe remains dry cliff top instead of being flooded")
	var corner_sample: Dictionary = _nearest_curve_sample(curves, high_probe)
	assert_true(corner_sample.distance < 4.0,
		"a contour sample exists beside the exact dry corner tip")
	if corner_sample.distance < 4.0:
		var corner_reach: float = _max_outward_reach(
			skin.arrays[Mesh.ARRAY_VERTEX], corner_sample.point, corner_sample.normal, 0.05)
		var visible_face_inset: float = WaterField.TILE * 0.5 - CliffDressing.PLACE
		print("MEAS exact corner contour=%s normal=%s distance=%.3f rim_reach=%.3f visual_face_inset=%.3f" % [
			corner_sample.point, corner_sample.normal, corner_sample.distance,
			corner_reach, visible_face_inset])
		assert_true(corner_reach >= visible_face_inset,
			"corner meniscus reaches beneath the recessed cliff face: %.3fm >= %.3fm" % [
				corner_reach, visible_face_inset])


## Exact 2026-07-14 16:45 view: player (180.9,4,-1184.4), crosshair
## (180.6,4.2,-1184.7). The matched screen ray through the visible triangular
## notch lands on the low apron at this world point, behind the x=181.3 cliff
## face. It must be covered at the neighbouring river level; covering it by
## flooding the y=4 cliff top would be the wrong fix.
func test_reported_corner_181_inner_apron_stays_water_covered() -> void:
	var chunk := Vector2i(0, -7)
	var region = _region(SEED, chunk)
	var ctx: Dictionary = WaterField.ctx(_water(SEED), chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(chunk))
	var skin: Dictionary = WaterSkin.build(_water(SEED), chunk, region)
	# Intersect the failing screen ray with y=3, the neighbouring water body,
	# rather than reusing its later collision with the apron at y=0.
	var pin := Vector2(178.8354, -1186.913)
	var ground: float = TerrainSurfaceField.surface_y(region, pin.x, pin.y)
	var level: float = WaterField.level_at(ctx, pin)
	var skin_y: float = _skin_y_at(skin.arrays, pin)
	var nearest: Dictionary = _nearest_curve_sample(curves, pin)
	print("MEAS exact corner-181 apron p=%s ground=%.3f field=%.3f skin=%.3f nearest=%s n=%s level=%.3f dist=%.3f" % [
		pin, ground, level, skin_y, nearest.point, nearest.normal,
		nearest.level, nearest.distance])
	assert_true(level - ground >= 0.08,
		"the exposed inner apron remains part of the continuous river field")
	assert_true(skin_y >= float(nearest.level) - 0.10,
		"top water contact covers the inner apron at river level (skin %.3f, water %.3f)" % [
			skin_y, float(nearest.level)])


## The matched-angle render still exposed a dark triangular shard after the
## oversized face was subdivided.  The long-standing free-edge test only
## covered SITE_CHUNK (0,-6), while the reported touching-corner frame is in
## its southern neighbour (0,-7).  Apply the same independent topological
## oracle to the actual failing chunk. A non-border free edge is accounted for
## only when it belongs to the buried outer rim, exactly coincides with the
## zero-width contour zipper, or has independently sampled surface coverage on
## both sides. Anything else is a visible hole in the sheet.
func test_reported_corner_chunk_has_no_visible_free_edge_holes() -> void:
	var chunk := Vector2i(0, -7)
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, chunk)
	var ctx: Dictionary = WaterField.ctx(water, chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(chunk))
	var skin: Dictionary = WaterSkin.build(water, chunk, region)
	assert_false(skin.is_empty(), "reported corner chunk builds water")
	if skin.is_empty():
		return
	var offenders: Array[String] = []
	var checked := 0
	for edge: Array in _free_edges(skin.arrays):
		var a: Vector3 = edge[0]
		var b: Vector3 = edge[1]
		if _on_chunk_border(a, chunk) and _on_chunk_border(b, chunk):
			continue
		checked += 1
		var a_ok: bool = _on_chunk_border(a, chunk) or _on_rim_outer_row(curves, a) \
			or _on_contour_surface(curves, a)
		var b_ok: bool = _on_chunk_border(b, chunk) or _on_rim_outer_row(curves, b) \
			or _on_contour_surface(curves, b)
		if not (a_ok and b_ok) and not _edge_is_surface_covered(skin.arrays, a, b) \
				and offenders.size() < 20:
			offenders.append("%s -> %s" % [a, b])
	print("MEAS reported corner chunk free edges: %d checked, %d visible-hole offenders: %s" % [
		checked, offenders.size(), str(offenders)])
	assert_true(offenders.is_empty(),
		"reported corner chunk contains visible free-edge holes: %s" % str(offenders))


## Exact 2026-07-13 22:00 normal-corner view. The literal next screen ray after
## the old water endpoint hits this recessed wall point. Mere triangle coverage
## is insufficient: the previous fix reached it only with the bottom curl at
## y=2.515 while the adjacent body is y=3.0, leaving the same visible downward
## notch. Require the TOP contact surface to stay within 10cm of the nearest
## contour level until it meets the wall. The point and tolerance come from the
## matched camera/terrain, not from WaterSkin's row/reach implementation.
func test_reported_normal_corner_rim_reaches_recessed_turn() -> void:
	var chunk := Vector2i(0, -7)
	var region = _region(SEED, chunk)
	var ctx: Dictionary = WaterField.ctx(_water(SEED), chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(chunk))
	var skin: Dictionary = WaterSkin.build(_water(SEED), chunk, region)
	# The first pin is the literal straight-wall ray from the matched camera.
	# The second is the actual KayKit corner: cell (6,-51)'s centre plus the
	# independently defined 10.5m dressing placement on both axes. The old
	# one-pin test passed while this real corner still visibly descended.
	var pins: Array[Vector2] = [
		Vector2(154.28436, -1212.0),
		Vector2(6.0 * WaterField.TILE + CliffDressing.PLACE,
			-51.0 * WaterField.TILE + CliffDressing.PLACE),
	]
	for pin: Vector2 in pins:
		var ground: float = TerrainSurfaceField.surface_y(region, pin.x, pin.y)
		var level: float = WaterField.level_at(ctx, pin)
		var skin_y: float = _skin_y_at(skin.arrays, pin)
		var nearest: Dictionary = _nearest_curve_sample(curves, pin)
		var to_gap: Vector2 = pin - nearest.point
		print("MEAS exact normal-corner shelf p=%s ground=%.3f field=%.3f skin=%.3f nearest=%s n=%s dist=%.3f along=%.3f cross=%.3f" % [
			pin, ground, level, skin_y, nearest.point, nearest.normal,
			nearest.distance, to_gap.dot(nearest.normal),
			absf(to_gap.dot(Vector2(-nearest.normal.y, nearest.normal.x)))])
		assert_true(skin_y >= float(nearest.level) - 0.10,
			"water stays level through the literal recessed corner instead of reaching it only with a downward curl at %s (skin %.3f, water %.3f)" % [
				pin, skin_y, float(nearest.level)])


## In the same exact view, an unbounded water edge ends over a terrain drop.
## The old safety clamp sends row2 directly from the 4cm crest to the landing
## ground, creating the sharp vertical polygon the owner marked.  A rounded,
## substance-like edge must contain a visible shoulder and a lower curl within
## the first 0.8m of its own outward-normal column; neither assertion copies
## WaterSkin's row count, reach constants, or production branch condition.
func test_reported_unbounded_edge_has_a_rounded_vertical_cross_section() -> void:
	var chunk := Vector2i(0, -7)
	var region = _region(SEED, chunk)
	var ctx: Dictionary = WaterField.ctx(_water(SEED), chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(chunk))
	var skin: Dictionary = WaterSkin.build(_water(SEED), chunk, region)
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var hint := Vector2(151.0, -1213.6)
	var sample := {"drop": -INF}
	for c: Dictionary in curves:
		for i in c.pts.size():
			var p: Vector2 = c.pts[i]
			if p.distance_to(hint) > 30.0:
				continue
			var nrm: Vector2 = c.normals[i]
			var q: Vector2 = p + nrm * 0.45
			var far_q: Vector2 = p + nrm * WaterSkin.WALL_CONTACT_SCAN_MAX
			var drop: float = c.levels[i] - TerrainSurfaceField.surface_y(region, q.x, q.y)
			# A low near probe followed by sustained high ground inside the
			# signed-depth cell is a recessed bank, not an unbounded edge. The
			# compact-lobe oracle must select a column that remains genuinely free.
			if TerrainSurfaceField.surface_y(region, far_q.x, far_q.y) \
					> c.levels[i] + 0.05:
				continue
			if drop > sample.drop:
				sample = {"drop": drop, "point": p, "normal": nrm,
					"level": c.levels[i]}
	assert_true(sample.drop > 1.0,
		"the exact view contains a genuinely unbounded/drop shore (drop %.3f)" % sample.drop)
	if sample.drop <= 1.0:
		return
	var perp := Vector2(-sample.normal.y, sample.normal.x)
	var shoulder := false
	var lower_curl := false
	var column: Array[String] = []
	for v: Vector3 in verts:
		var off: Vector2 = Vector2(v.x, v.z) - sample.point
		var reach: float = off.dot(sample.normal)
		if reach < 0.0 or reach > 0.8 or absf(off.dot(perp)) > 0.04:
			continue
		var rel_y: float = v.y - sample.level
		column.append("(r=%.3f,y=%.3f)" % [reach, rel_y])
		if reach >= 0.20 and rel_y <= 0.06 and rel_y >= -0.30:
			shoulder = true
		if reach >= 0.30 and rel_y < -0.30 and rel_y >= -0.85:
			lower_curl = true
	print("MEAS exact unbounded-edge sample p=%s n=%s drop=%.3f column=%s" % [
		sample.point, sample.normal, sample.drop, str(column)])
	assert_true(shoulder,
		"unbounded edge has a visible rounded shoulder instead of jumping straight to landing ground")
	assert_true(lower_curl,
		"unbounded edge curls down by a finite body thickness before its terminal edge")


## The visible shoreline must be one continuous rounded surface.  The old
## rim starts with row0 and row1 at identical XZ and different Y, producing a
## literal vertical water stitch before its outward repair rows.  That stitch
## is the detached-looking seam/skirt in the owner's (61.5,-1118.1) and
## (34.0,-1108.9) frames.  Falsify it directly near those exact pins: no
## water triangle may contain a short vertical-only shoreline edge.
func test_reported_bank_sites_have_no_vertical_repair_skirt_seam() -> void:
	var chunk := Vector2i(0, -6)
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, chunk)
	var ctx: Dictionary = WaterField.ctx(water, chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(chunk))
	var skin: Dictionary = WaterSkin.build(water, chunk, region)
	assert_false(skin.is_empty(), "reported bank chunk builds water")
	if skin.is_empty():
		return
	var hints: Array[Vector2] = [Vector2(61.5, -1118.1), Vector2(34.0, -1108.9)]
	for hint: Vector2 in hints:
		var sample: Dictionary = _nearest_curve_sample(curves, hint)
		assert_true(sample.distance < 18.0,
			"a shoreline contour exists near reported pin %s (nearest %.2fm)" % [hint, sample.distance])
		if sample.distance >= 18.0:
			continue
		var contact: float = _bank_contact_distance(region, sample.point, sample.normal, sample.level)
		print("MEAS bank pin %s -> contour %s (dist %.2f), normal=%s, level=%.3f, bank contact=%.3fm" % [
			hint, sample.point, sample.distance, sample.normal, sample.level, contact])

	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = skin.arrays[Mesh.ARRAY_INDEX]
	var seam_edges: Dictionary = {}
	for ti in range(0, idx.size(), 3):
		for k in 3:
			var a: Vector3 = verts[idx[ti + k]]
			var b: Vector3 = verts[idx[ti + (k + 1) % 3]]
			var axz := Vector2(a.x, a.z)
			var bxz := Vector2(b.x, b.z)
			var near_pin := false
			for hint: Vector2 in hints:
				if ((axz + bxz) * 0.5).distance_to(hint) < 18.0:
					near_pin = true
					break
			if not near_pin:
				continue
			var horizontal: float = axz.distance_to(bxz)
			var vertical: float = absf(a.y - b.y)
			if horizontal < 0.005 and vertical > 0.015:
				var key := "%s -> %s" % [a, b]
				seam_edges[key] = true
	print("MEAS vertical repair-skirt seams near reported pins: %d" % seam_edges.size())
	assert_true(seam_edges.is_empty(),
		"reported bank water still begins with a vertical repair-skirt seam: %s" % str(seam_edges.keys().slice(0, 12)))


## Pixel-to-world probes through the owner's (33.9,8.0,-1108.5) view pin
## the long green wedge to these two points on the rendered slope.  The
## desired river is continuous here, so each point must be statically wet
## AND covered by the emitted skin.  This distinguishes a dry field claim
## from a skin triangulation hole before either system is changed.
func test_reported_green_wedge_is_wet_and_skin_covered() -> void:
	var chunk := Vector2i(0, -6)
	var region = _region(SEED, chunk)
	var ctx: Dictionary = WaterField.ctx(_water(SEED), chunk, region)
	var skin: Dictionary = WaterSkin.build(_water(SEED), chunk, region)
	var probes: Array[Vector2] = [Vector2(49.91661, -1106.483), Vector2(56.12246, -1106.213)]
	for p: Vector2 in probes:
		var ground: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
		var level: float = WaterField.level_at(ctx, p)
		var skin_y: float = _skin_y_at(skin.arrays, p)
		var depth: float = level - ground if level != -INF else -INF
		print("MEAS reported green wedge p=%s ground=%.3f field=%.3f depth=%.3f skin=%.3f" % [
			p, ground, level, depth, skin_y])
		assert_true(level != -INF and depth >= 0.25,
			"reported river wedge point %s has at least 25cm static depth (%.3f)" % [p, depth])
		assert_true(skin_y != -INF,
			"reported river wedge point %s is covered by a water-skin triangle" % p)
		assert_true(skin_y != -INF and skin_y - ground >= 0.25,
			"rendered skin at reported wedge point %s has at least 25cm bed clearance (%.3f)" % [
				p, skin_y - ground])


## Paired renders from the owner's (33.9,8.0,-1108.5) angle show the green
## polygon changing outline with time: it is not a fixed contour corner, but
## shallow terrain being uncovered by the geometric swell.  The five-sine
## shared dynamic spectrum has WaterSkin's conservative downward bound. COLOR.r is the
## mesh-baked amplitude scale; after applying that worst trough, every
## statically visible wet vertex must retain 2cm of cover over the rendered
## terrain.  Before the fix ARRAY_COLOR is absent, so the diagnostic falls
## back to the shipped shore-distance fade and exposes the real failure.
func test_reported_shallow_water_cannot_dry_at_swell_trough() -> void:
	const SWELL_TROUGH_BOUND := WaterSkin.SWELL_TROUGH_BOUND
	const COVER := 0.02
	var offenders: Array[String] = []
	var checked := 0
	var constrained := 0
	var has_baked_scale := true
	var has_sampler_scale := true
	for chunk: Vector2i in [Vector2i(0, -6), Vector2i(0, -7)]:
		var region = _region(SEED, chunk)
		var skin: Dictionary = WaterSkin.build(_water(SEED), chunk, region)
		assert_false(skin.is_empty(), "reported chunk %s builds water" % chunk)
		if skin.is_empty():
			continue
		var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
		var custom0: PackedFloat32Array = skin.arrays[Mesh.ARRAY_CUSTOM0]
		var colors := PackedColorArray()
		if skin.arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
			colors = skin.arrays[Mesh.ARRAY_COLOR]
		if colors.size() != verts.size():
			has_baked_scale = false
		if not skin.sampler.has_method("wave_scale_at"):
			has_sampler_scale = false
		for vi in verts.size():
			var v: Vector3 = verts[vi]
			var ground: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
			var clearance: float = v.y - ground
			if clearance < COVER:
				continue # intentionally buried rim rows are not visible surface
			checked += 1
			var scale: float
			if colors.size() == verts.size():
				scale = colors[vi].r
			else:
				var shore_t: float = clampf(custom0[vi * 4 + 3] / 4.0, 0.0, 1.0)
				scale = shore_t * shore_t * (3.0 - 2.0 * shore_t)
			if scale < 0.999:
				constrained += 1
			var trough_y: float = v.y - SWELL_TROUGH_BOUND * scale
			if trough_y < ground + COVER - 0.0001 and offenders.size() < 20:
				offenders.append("chunk=%s p=(%.2f,%.2f) depth=%.3f scale=%.3f trough_gap=%.3f" % [
					chunk, v.x, v.z, clearance, scale, trough_y - ground])
	print("MEAS reported swell clearance: checked=%d constrained=%d baked_scale=%s offenders=%s" % [
		checked, constrained, has_baked_scale, str(offenders)])
	assert_true(has_baked_scale, "WaterSkin bakes one depth-limited swell scale per vertex")
	assert_true(has_sampler_scale,
		"the frozen WaterSampler exposes the same scale so character buoyancy can mirror the GPU surface")
	assert_true(checked > 100, "reported chunks exercise a substantial visible water surface")
	assert_true(constrained > 0, "shallow reported water actually receives depth limiting")
	assert_true(offenders.is_empty(),
		"worst swell trough can still expose terrain in reported water: %s" % str(offenders))


## test_skin_builds_on_site_chunk — non-empty, indexed, welded-shape output.
## r3 Task 7: the old marching-squares mesher this test used to print a
## tri-count comparison against (the Task 11 perf-budget baseline) is
## deleted along with the rest of its class this task — the comparison print
## goes with it; the skin's own tri/vert/timing numbers are still printed
## standalone for continuity with that baseline's own MEAS line format.
func test_skin_builds_on_site_chunk() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var t0: int = Time.get_ticks_usec()
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	var skin_us: int = Time.get_ticks_usec() - t0
	assert_false(skin.is_empty(), "site chunk builds a skin (real water present)")
	if skin.is_empty():
		return
	assert_true(skin.has("arrays") and skin.has("triggers") and skin.has("sampler"),
		"skin dict carries the documented arrays/triggers/sampler keys")
	var arrays: Array = skin.arrays
	assert_eq(arrays.size(), Mesh.ARRAY_MAX, "Mesh.ARRAY_MAX-shaped arrays")
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert_true(verts.size() > 0, "non-empty vertex buffer")
	assert_true(idx.size() > 0, "non-empty index buffer")
	assert_true(idx.size() % 3 == 0, "indices form whole triangles")
	for i in idx:
		assert_true(i >= 0 and i < verts.size(), "index %d in range [0,%d)" % [i, verts.size()])
	# Welded: no two verts share a position at the skin's documented 1/64m
	# world-space precision.
	var seen: Dictionary = {}
	var dup_ct := 0
	for v: Vector3 in verts:
		var key := Vector3i(roundi(v.x * 64.0), roundi(v.y * 64.0), roundi(v.z * 64.0))
		if seen.has(key):
			dup_ct += 1
		seen[key] = true
	assert_eq(dup_ct, 0, "no duplicate-position verts survive the weld")
	var custom1: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	assert_eq(custom1.size(), verts.size() * 4,
		"CUSTOM1 stores velocity/vorticity/compression for every water vertex")
	var moving_vertices := 0
	var max_sampler_error := 0.0
	for vi in verts.size():
		var baked := Vector2(custom1[vi * 4], custom1[vi * 4 + 1])
		if baked.length() < 0.2:
			continue
		moving_vertices += 1
		var v: Vector3 = verts[vi]
		var sampled: Vector2 = skin.sampler.velocity_at(Vector2(v.x, v.z))
		max_sampler_error = maxf(max_sampler_error, baked.distance_to(sampled))
	assert_true(moving_vertices > 100,
		"the real flat river reach bakes a readable nonzero current")
	assert_true(max_sampler_error < 0.01,
		"mesh and CPU sampler share one current field (max error %.5f)" % max_sampler_error)

	var skin_tris: int = idx.size() / 3
	print("MEAS test_skin_builds_on_site_chunk: skin=%d tris (%d verts, %.2fms)" % [
		skin_tris, verts.size(), skin_us / 1000.0])


func test_current_field_is_bit_identical_across_chunk_border() -> void:
	var north := WaterSkin.build(_water(SEED), Vector2i(0, -6),
		_region(SEED, Vector2i(0, -6)))
	var south := WaterSkin.build(_water(SEED), Vector2i(0, -7),
		_region(SEED, Vector2i(0, -7)))
	assert_false(north.is_empty() or south.is_empty(),
		"both reported neighbouring chunks carry water")
	if north.is_empty() or south.is_empty():
		return
	var common_wet := 0
	var worst := 0.0
	for x in range(0, 193, 3):
		var p := Vector2(float(x), -1152.0)
		if is_nan(north.sampler.level_at(p)) or is_nan(south.sampler.level_at(p)):
			continue
		common_wet += 1
		worst = maxf(worst, north.sampler.velocity_at(p).distance_to(
			south.sampler.velocity_at(p)))
	assert_true(common_wet > 4, "shared border exercises a real wet reach")
	assert_true(worst < 0.0001,
		"two-cell halo produces a welded current border (worst %.7f)" % worst)


## test_free_edges_only_buried_rim_or_border (r3-task-5-brief.md's own name —
## the FINAL form of the free-edge invariant): now that the meniscus rim
## exists, Task 4's old "on a curve" class is GONE — the rim's row0-row1 band
## covers every curve-chain edge the strip used to leave free (see
## WaterSkin._rim's own docstring on this exact healing mechanism), so a
## surviving non-border free edge may only lie on the rim's own OUTER row
## (row5; _on_rim_outer_row), either buried under a bank or completing a
## compact rounded drop lobe. Ports the free-edge-walker convention from
## test_water_mesher.gd (test_every_free_edge_is_accounted_for), same as
## Task 4's version, with the accounted-for class swapped.
func test_free_edges_only_buried_rim_or_border() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var free: Array = _free_edges(skin.arrays)
	var checked := 0
	var offenders: Array = []
	for e: Array in free:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var a_border: bool = _on_chunk_border(a, SITE_CHUNK)
		var b_border: bool = _on_chunk_border(b, SITE_CHUNK)
		if a_border and b_border:
			continue
		checked += 1
		var a_ok: bool = a_border or _on_rim_outer_row(curves, a)
		var b_ok: bool = b_border or _on_rim_outer_row(curves, b)
		if not (a_ok and b_ok):
			if offenders.size() < 30:
				var mid := Vector2(a.x + b.x, a.z + b.z) * 0.5
				offenders.append("%s-%s (curve_dist=%.2f mid_level=%.3f)" % [
					a, b, _dist_to_curves(curves, mid), WaterField.level_at(ctx, mid)])
	print("MEAS test_free_edges_only_buried_rim_or_border: %d non-border-pair free edges checked, %d offenders" % [
		checked, offenders.size()])
	assert_true(checked > 5, "site has real boundary free edges to check (%d)" % checked)
	assert_true(offenders.is_empty(),
		"every non-border free edge lies on the meniscus rim's buried outer row: %s" % str(offenders))


## Every row5 vertex on a real bank must remain at least 0.25m under local
## ground. At a genuine terrain drop there is no bank to bury into, so row5
## instead completes the finite rounded lobe at about L-0.65. Iterating actual
## free-edge endpoints isolates row5 from the band-interior rows and keeps
## this oracle independent of the production reach/branch formulas.
func test_rim_outer_row_is_buried_or_rounded_over_drop() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var seen: Dictionary = {}
	var checked := 0
	var offenders: Array = []
	var rounded := 0
	for e: Array in _free_edges(skin.arrays):
		for v: Vector3 in [e[0], e[1]]:
			var key: Vector3i = Vector3i((v * 64.0).round())
			if seen.has(key):
				continue
			seen[key] = true
			if _on_chunk_border(v, SITE_CHUNK) or not _on_rim_outer_row(curves, v):
				continue
			checked += 1
			var g: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
			var buried: float = g - v.y
			if buried >= RIM_BURY_GATE:
				continue
			var near: Dictionary = _nearest_curve_pt(curves, Vector2(v.x, v.z))
			var rel_y: float = v.y - near.level
			var is_drop_lobe: bool = g <= near.level - 0.8 \
				and rel_y <= -0.40 and rel_y >= -0.70
			if is_drop_lobe:
				rounded += 1
			elif offenders.size() < 10:
				offenders.append("%s buried=%.3f ground=%.3f nearest=%s rel_y=%.3f" % [
					v, buried, g, near, rel_y])
	print("MEAS rim outer row: %d verts checked, %d rounded drop lobes, %d offenders" % [
		checked, rounded, offenders.size()])
	assert_true(checked > 5, "site has real rim outer-row free-edge verts to check (%d)" % checked)
	assert_true(offenders.is_empty(),
		"every rim outer edge is buried by bank terrain or is a finite rounded drop lobe: %s" % str(offenders))


## test_rim_welds_to_strip (brief's own name) — row0 (the rim's innermost
## row, reused from _boundary_strip's own curve_vi — see WaterSkin._rim's
## docstring) never duplicates the strip's own vertex: exactly one mesh
## vertex exists at each curve point's own (p, level) position. This is the
## externally-observable proxy for "row0 index == strip index" (the weld
## dict's own semantics make index equality automatic once the position+level
## key matches, per _weld_vert; what could actually go WRONG — and what this
## test actually catches — is a stray near-duplicate from an off-by-epsilon
## position or level mismatch between the two call sites).
func test_rim_welds_to_strip() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	# Tight on purpose: row1 sits exactly RIM_ROW1_BULGE=0.04 ABOVE row0 at the
	# SAME xz (the brief's own hairline meniscus-crest lip — r3 Task 14
	# changed this from a 0.02 DIP below to a 0.04 BULGE above, only widening
	# the real neighbour distance this guards against) — a tolerance at or
	# above that gap double-counts row1 as a "hit" for row0's own target
	# (caught directly pre-Task-14: 10 offenders each reporting hits=2 at
	# exactly the then-0.02 boundary before this was tightened). 0.005 sits
	# safely below that real intentional neighbour and comfortably above
	# float weld noise.
	var tol := 0.005
	var checked := 0
	var offenders: Array = []
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		var levels: PackedFloat32Array = c.levels
		for i in pts.size():
			var target := Vector3(pts[i].x, levels[i], pts[i].y)
			var hits := 0
			for v: Vector3 in verts:
				if v.distance_to(target) <= tol:
					hits += 1
			checked += 1
			if hits != 1 and offenders.size() < 10:
				offenders.append("%s hits=%d" % [target, hits])
	print("MEAS test_rim_welds_to_strip: %d curve points checked, %d offenders" % [checked, offenders.size()])
	assert_true(checked > 5, "site has real curve points to check (%d)" % checked)
	assert_true(offenders.is_empty(),
		"every curve point has exactly one welded vertex (row0 reuses the strip's own index): %s" % str(offenders))


## test_interior_rides_field — 50 random KEPT interior LATTICE verts (not
## boundary-strip verts, which ride the smoothed curve/interpolated strip
## instead) must equal WaterField.level_at within 0.03m. The long-edge strip
## splitter can add non-lattice boundary vertices more than 1.5m from a curve,
## so distance alone is no longer a valid interior classifier. Requiring the
## world-aligned 3m lattice is the direct structural property named here.
func test_interior_rides_field() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var interior: Array = []
	for v: Vector3 in verts:
		var on_lattice: bool = absf(v.x / WaterSkin.STEP - roundf(v.x / WaterSkin.STEP)) < 0.0001 \
			and absf(v.z / WaterSkin.STEP - roundf(v.z / WaterSkin.STEP)) < 0.0001
		if on_lattice and _dist_to_curves(curves, Vector2(v.x, v.z)) >= 1.5:
			interior.append(v)
	print("MEAS test_interior_rides_field: %d/%d verts classified interior" % [interior.size(), verts.size()])
	assert_true(interior.size() >= 50, "at least 50 interior verts exist to sample (%d)" % interior.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var checked := 0
	var max_err := 0.0
	var offenders: Array = []
	for _i in 50:
		if interior.is_empty():
			break
		var v: Vector3 = interior[rng.randi_range(0, interior.size() - 1)]
		var truth: float = WaterField.level_at(ctx, Vector2(v.x, v.z))
		var err: float = absf(v.y - truth)
		checked += 1
		max_err = maxf(max_err, err)
		if err >= 0.03 and offenders.size() < 10:
			offenders.append("%s baked=%.4f truth=%.4f err=%.4f" % [v, v.y, truth, err])
	print("MEAS test_interior_rides_field: checked %d, max_err=%.5f (threshold 0.03)" % [checked, max_err])
	assert_eq(checked, 50, "50 interior verts sampled")
	assert_true(max_err < 0.03, "every sampled interior vert rides level_at within 0.03m: %s" % str(offenders))


## test_skin_handles_closed_and_border_exit_curves — the isolated-pond chunk
## (-4,-18) (test_water_contour.gd's own verified closed-curve site) is the
## structural complement to SITE_CHUNK: one CLOSED curve (the pond bowl —
## exercises the zip's A-wrap and the closed-annulus closing triangle) plus
## one open HORSESHOE curve whose both endpoints exit through the same chunk
## border (a wet inlet continuing into the neighbour chunk — exercises the
## border-row edge-ring rules). Development caught three real defects here
## that SITE_CHUNK's three open border-to-border curves structurally cannot
## reproduce (an out-of-bounds A-read at the closed wrap, a missing annulus
## closing triangle, and a ring-chain fold from over-approximated edge-ring
## membership at the border exit — this task's report has the traces); this
## test pins all three.
func test_skin_handles_closed_and_border_exit_curves() -> void:
	var pond_chunk := Vector2i(-4, -18)
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, pond_chunk)
	var ctx: Dictionary = WaterField.ctx(water, pond_chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(pond_chunk))
	var has_closed := false
	for c: Dictionary in curves:
		if c.closed:
			has_closed = true
	assert_true(has_closed, "the pond chunk still carries a closed curve (site precondition)")
	var skin: Dictionary = WaterSkin.build(water, pond_chunk, region)
	assert_false(skin.is_empty(), "pond chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var seen: Dictionary = {}
	var dup_ct := 0
	for v: Vector3 in verts:
		var key: Vector3i = Vector3i((v * 64.0).round())
		if seen.has(key):
			dup_ct += 1
		seen[key] = true
	assert_eq(dup_ct, 0, "no duplicate-position verts on the pond chunk")
	var checked := 0
	var offenders: Array = []
	for e: Array in _free_edges(skin.arrays):
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		if _on_chunk_border(a, pond_chunk) and _on_chunk_border(b, pond_chunk):
			continue
		checked += 1
		# Tightened per Task 5 (test_free_edges_only_buried_rim_or_border's own
		# class): the rim heals every curve-level free edge Task 4 left behind,
		# so a surviving non-border free edge must lie on the rim's buried
		# outer row instead of merely "near a curve point."
		var a_ok: bool = _on_chunk_border(a, pond_chunk) or _on_rim_outer_row(curves, a)
		var b_ok: bool = _on_chunk_border(b, pond_chunk) or _on_rim_outer_row(curves, b)
		if not (a_ok and b_ok) and offenders.size() < 10:
			offenders.append("%s near=%s ok=%s - %s near=%s ok=%s" % [
				a, _nearest_curve_pt(curves, Vector2(a.x, a.z)), a_ok,
				b, _nearest_curve_pt(curves, Vector2(b.x, b.z)), b_ok])
	print("MEAS test_skin_handles_closed_and_border_exit_curves: %d free edges checked, %d offenders" % [
		checked, offenders.size()])
	assert_true(checked > 5, "pond chunk has real boundary free edges to check (%d)" % checked)
	assert_true(offenders.is_empty(),
		"closed + border-exit curves stitch watertight: %s" % str(offenders))


func test_dry_chunk_builds_nothing() -> void:
	var water: WaterPlan = _water(SEED)
	# Same dry-chunk scan test_water_mesher.gd's own test_dry_chunk_builds_nothing uses.
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
	assert_true(WaterSkin.build(water, dry, _region(SEED, dry)).is_empty(),
		"dry chunk => empty build")


## Shared walker for test_s_is_continuous_along_river: reads curve c's own
## welded row0 vertices over curve indices [lo..hi], walking hi -> lo (this
## curve's index order runs upstream, so the reversed walk reads downstream /
## s-INcreasing, matching the brief's "strictly increasing" wording), and
## asserts per step: s strictly increases AND |Δs − spatial step| < 0.5 (the
## brief's own tolerance).
func _assert_s_window(skin: Dictionary, c: Dictionary, lo: int, hi: int, label: String) -> void:
	var pts: PackedVector2Array = c.pts
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var cust: PackedFloat32Array = skin.arrays[Mesh.ARRAY_CUSTOM0]
	var s_vals: Array = []
	var walk_pts: Array = []
	for i in range(hi, lo - 1, -1):
		var target := Vector3(pts[i].x, c.levels[i], pts[i].y)
		var vi: int = _find_vertex(verts, target, 0.01)
		assert_true(vi >= 0, "%s: curve point %d has a welded mesh vertex" % [label, i])
		if vi < 0:
			return
		s_vals.append(cust[vi * 4 + 0])
		walk_pts.append(pts[i])
	var checked := 0
	var worst := 0.0
	var offenders: Array = []
	for k in range(0, s_vals.size() - 1):
		var d_space: float = walk_pts[k].distance_to(walk_pts[k + 1])
		var d_s: float = s_vals[k + 1] - s_vals[k]
		checked += 1
		worst = maxf(worst, absf(d_s - d_space))
		if d_s <= 0.0:
			offenders.append("%s k=%d s not strictly increasing: %.4f -> %.4f" % [label, k, s_vals[k], s_vals[k + 1]])
		elif absf(d_s - d_space) >= 0.5:
			offenders.append("%s k=%d |Δs(%.4f) - step(%.4f)|=%.4f >= 0.5" % [label, k, d_s, d_space, absf(d_s - d_space)])
	print("MEAS test_s_is_continuous_along_river[%s]: %d steps checked, worst |Δs-step|=%.4f, %d offenders" % [
		label, checked, worst, offenders.size()])
	assert_eq(checked, hi - lo, "%s: %d consecutive steps checked" % [label, hi - lo])
	assert_true(offenders.is_empty(),
		"%s: s strictly increases and tracks the real spatial step along the river: %s" % [label, str(offenders)])


## test_s_is_continuous_along_river (brief's own name) — CUSTOM0.x (arc
## length s) walked along 30 consecutive points of a REAL river shoreline
## curve (row0 vertices — see WaterSkin._rim's own docstring on why row0 IS
## the strip's welded vertex) must strictly increase, with each step's own
## |Δs| tracking the vertices' real-world spacing within 0.5m — s
## approximates true arc length, so a baked value that drifts from the
## actual distance walked would misdrive Task 8's travelling-wave phase (the
## Task 6 reviewer quantified it: a 1.0m per-step shortfall is ~109° of phase
## error on the λ≈3.3m river train and ~185° on the λ≈1.8m crossed train — a
## third to half a wave cycle of crests bunching at one shoreline spot).
## SITE_CHUNK's curve[0] runs from a river reach into its own terminal lake
## (verified this task: dist-to-nearest-trace ranges 0.76m at pts[0] out to
## 32.98m by pts[142] — see r3-task-6-report.md); pts[0..36] sits in the
## river-close end (all <18m from a real trace, checked below as a site
## precondition independent of WaterSkin's own bake).
## TWO windows assert, per the Task 6 review verdict (r3-task-6-report.md,
## "Fix: bend s-compression"):
##   - pts[0..30], the BEND stretch: pts[4..8] sweeps past a ~6.2° bend in
##     the claimed trace's polyline (trace ti=1, sample 9) from ~9m offset.
##     Nearest-point projection stalls at a polyline corner (the whole
##     outside wedge of angular width θ projects onto the corner vertex, so
##     s stops advancing for d·θ ≈ 0.96m of shoreline walk) — this window
##     was RED against the un-blended Task 6 projection (worst
##     |Δs−step|=1.008, transcript in the report) and is the regression pin
##     for WaterSkin._project_on_trace's segment-tie blend, which spreads
##     that geometric arc-length deficit over the tie band instead of
##     concentrating it in one step.
##   - pts[6..36], the CLEAN stretch (no wedge transition mid-window): pins
##     that the blend does not degrade ordinary shoreline tracking.
## This curve's OWN point order runs upstream (index increasing = toward the
## source, s DEcreasing) — _assert_s_window walks each window in the opposite
## (index-decreasing, s-increasing) direction; the underlying data is
## identical either way.
func test_s_is_continuous_along_river() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	assert_true(curves.size() > 0, "site chunk has curves")
	if curves.is_empty():
		return
	var c: Dictionary = curves[0]
	var pts: PackedVector2Array = c.pts
	assert_true(pts.size() >= 37, "curve[0] has >=37 points to walk pts[0..36] (%d)" % pts.size())
	if pts.size() < 37:
		return
	for i in range(0, 37):
		assert_true(_dist_to_rivers(ctx, pts[i]) < 18.0,
			"pts[%d] sits within the brief's own river gate (site precondition)" % i)
	_assert_s_window(skin, c, 0, 30, "bend pts[0..30]")
	_assert_s_window(skin, c, 6, 36, "clean pts[6..36]")


## test_slope_is_continuous (brief's own name) — CUSTOM0.z (profile slope)
## between ADJACENT points of the same river window test_s_is_continuous_
## along_river uses (pts[6..36] — see that test's own docstring for why the
## window starts at 6, not 0) must never jump by >=0.15 — the brief's own
## literal tolerance for its "central-difference prof at the projected
## segment, sampled continuously" rule (see WaterSkin._project_on_trace's own
## docstring): a real jump there would show up as a visible pop in the Task 8
## wave-train amplitude (A ≈ base*(1+k_slope*slope)), which is keyed directly
## off this lane.
func test_slope_is_continuous() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	assert_true(curves.size() > 0, "site chunk has curves")
	if curves.is_empty():
		return
	var c: Dictionary = curves[0]
	var pts: PackedVector2Array = c.pts
	assert_true(pts.size() >= 37, "curve[0] has >=37 points to walk pts[6..36] (%d)" % pts.size())
	if pts.size() < 37:
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var cust: PackedFloat32Array = skin.arrays[Mesh.ARRAY_CUSTOM0]
	var slopes: Array = []
	for i in range(36, 5, -1):
		var target := Vector3(pts[i].x, c.levels[i], pts[i].y)
		var vi: int = _find_vertex(verts, target, 0.01)
		assert_true(vi >= 0, "curve point %d has a welded mesh vertex" % i)
		if vi < 0:
			return
		slopes.append(cust[vi * 4 + 2])
	var checked := 0
	var offenders: Array = []
	for k in range(0, 30):
		var d_slope: float = absf(slopes[k + 1] - slopes[k])
		checked += 1
		if d_slope >= 0.15:
			offenders.append("k=%d |Δslope|=%.4f >= 0.15 (%.4f -> %.4f)" % [k, d_slope, slopes[k], slopes[k + 1]])
	print("MEAS test_slope_is_continuous: %d adjacent pairs checked, %d offenders" % [checked, offenders.size()])
	assert_true(checked == 30, "30 adjacent pairs checked")
	assert_true(offenders.is_empty(), "slope never jumps by >=0.15 between adjacent river verts: %s" % str(offenders))


## test_pond_frames_are_calm (brief's own name) — lake verts get slope==0 and
## d==0 (brief's literal pond/lake rule: "no trace within 18m"; s==0 is also
## checked here since WaterSkin's pond branch returns all three as one hard
## early-return, per _flow_frame_at's own docstring). Pond chunk (-4,-18) is
## NOT uniformly far from every river — it carries a real feeding inlet
## (verified this task: curve[1]'s own dist-to-nearest-trace ranges from
## 0.38m up to 36.09m across its 124 points, see r3-task-6-report.md) — so
## this test scopes to the verified-calm stretch of the pond's own closed
## curve (pts[39..78], all independently confirmed >=18m from every trace
## below) rather than every vertex in the chunk, which would wrongly include
## the inlet's own river-engaged points.
func test_pond_frames_are_calm() -> void:
	var pond_chunk := Vector2i(-4, -18)
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, pond_chunk)
	var ctx: Dictionary = WaterField.ctx(water, pond_chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(pond_chunk))
	var closed_curve: Dictionary = {}
	for c: Dictionary in curves:
		if c.closed:
			closed_curve = c
			break
	assert_true(not closed_curve.is_empty(), "pond chunk has a closed (pond bowl) curve (site precondition)")
	if closed_curve.is_empty():
		return
	var pts: PackedVector2Array = closed_curve.pts
	# Select the calm window DYNAMICALLY: every pond curve point genuinely
	# >= 18m from any river (the "river gate" — a pond point nearer than that
	# legitimately picks up a river flow frame, so it is not calm). r3 Task
	# 12b: this was a hard-coded pts[39..78] window, which the smooth-descent
	# level change (DESCENT_CLAMP 0.05 -> 0.10) reshaped the pond contour out
	# from under — the fixed indices drifted toward a river and the precondition
	# broke, though the property under test never changed. Selecting by the
	# actual far-from-river condition (independent of the flow-frame bake this
	# asserts on, so not circular) makes the test robust to contour reshaping.
	var calm_idx: Array = []
	for i in pts.size():
		if _dist_to_rivers(ctx, pts[i]) >= 18.0:
			calm_idx.append(i)
	# The continuous channel carve legitimately shifts the closed shoreline by
	# about one resampled point at this fixture. Sixteen independent points is
	# still a substantial calm arc and keeps the precondition from becoming a
	# brittle contour-size snapshot.
	assert_true(calm_idx.size() >= 16,
		"pond curve has a real calm window (>= 16 points >= 18m from any river): %d" % calm_idx.size())
	if calm_idx.size() < 16:
		return
	var skin: Dictionary = WaterSkin.build(water, pond_chunk, region)
	assert_false(skin.is_empty(), "pond chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var cust: PackedFloat32Array = skin.arrays[Mesh.ARRAY_CUSTOM0]
	var checked := 0
	var offenders: Array = []
	for i: int in calm_idx:
		var target := Vector3(pts[i].x, closed_curve.levels[i], pts[i].y)
		var vi: int = _find_vertex(verts, target, 0.01)
		assert_true(vi >= 0, "curve point %d has a welded mesh vertex" % i)
		if vi < 0:
			continue
		checked += 1
		var s_v: float = cust[vi * 4 + 0]
		var d_v: float = cust[vi * 4 + 1]
		var slope_v: float = cust[vi * 4 + 2]
		if s_v != 0.0 or d_v != 0.0 or slope_v != 0.0:
			if offenders.size() < 10:
				offenders.append("%s s=%.4f d=%.4f slope=%.4f" % [target, s_v, d_v, slope_v])
	print("MEAS test_pond_frames_are_calm: %d calm-window curve points checked, %d offenders" % [checked, offenders.size()])
	assert_true(checked >= 16, "at least 16 calm-window points had welded verts to check (%d)" % checked)
	assert_true(offenders.is_empty(), "every calm-window pond vert has s==0, d==0, slope==0: %s" % str(offenders))


## test_rim_normals_curl_outward (controller brief's own name) — two
## independent checks of the controller addition (real vertex normals,
## replacing the Task 4-5 blanket Vector3.UP):
##   1. At a non-wall rim point, row0's normal is near-UP (the meniscus crest
##      reads as flat water) and row2's normal has a positive outward (n̂)
##      component (the visible curl) — WaterSkin._curl_normal's own contract.
##      Located structurally (_find_row2_vertex — does NOT reproduce
##      WaterSkin's own reach/wall-blend formula, same discipline
##      _on_rim_outer_row already documents) on the pond chunk's own closed
##      curve, whose 2 non-wall points were verified this task (see
##      r3-task-6-report.md).
##   2. On SITE_CHUNK, at least one interior-classified vertex (>=1.5m from
##      any curve point, mirrors test_interior_rides_field's own classifier)
##      whose surface genuinely slopes (an INDEPENDENT, test-side central
##      difference of WaterField.level_at at +-1.5m — the same formula the
##      brief prescribes for _interior_normal, so this is a wiring/weld-
##      average check, not a reach/pinch-style tautology guard) has a baked
##      normal that measurably deviates from UP.
func test_rim_normals_curl_outward() -> void:
	var water: WaterPlan = _water(SEED)
	var pond_chunk := Vector2i(-4, -18)
	var region = _region(SEED, pond_chunk)
	var ctx: Dictionary = WaterField.ctx(water, pond_chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(pond_chunk))
	var found := false
	var p := Vector2.ZERO
	var nrm2d := Vector2.ZERO
	var lvl := 0.0
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		for i in pts.size():
			var q: Vector2 = pts[i] + c.normals[i] * WaterSkin.RIM_WALL_REACH
			var g: float = TerrainSurfaceField.surface_y(region, q.x, q.y)
			if g > c.levels[i] + WaterSkin.RISE_MARGIN:
				continue
			p = pts[i]
			nrm2d = c.normals[i]
			lvl = c.levels[i]
			found = true
			break
		if found:
			break
	assert_true(found, "pond chunk has a non-wall curve point (site precondition)")
	if not found:
		return
	var skin: Dictionary = WaterSkin.build(water, pond_chunk, region)
	assert_false(skin.is_empty(), "pond chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = skin.arrays[Mesh.ARRAY_NORMAL]
	assert_eq(norms.size(), verts.size(), "one normal per vertex")
	var vi0: int = _find_vertex(verts, Vector3(p.x, lvl, p.y), 0.01)
	var vi2: int = _find_row2_vertex(verts, p, nrm2d)   # located by column position (clamp-stable); the curl NORMAL it reads is set independently of row2's clamped Y
	assert_true(vi0 >= 0, "row0 vertex found at the non-wall point")
	assert_true(vi2 >= 0, "row2 vertex found at the non-wall point")
	if vi2 < 0:
		print("MEAS missing pond row2 column: %s" % str(
			_column_diagnostic(verts, p, nrm2d, lvl)))
	if vi0 < 0 or vi2 < 0:
		return
	var n0: Vector3 = norms[vi0]
	var n2: Vector3 = norms[vi2]
	var outward3 := Vector3(nrm2d.x, 0.0, nrm2d.y)
	print("MEAS test_rim_normals_curl_outward: non-wall pt=%s row0.normal=%s (dot_up=%.4f) row2.normal=%s (outward_comp=%.4f)" % [
		p, n0, n0.dot(Vector3.UP), n2, n2.dot(outward3)])
	assert_true(n0.dot(Vector3.UP) > 0.9, "row0's normal is near-UP at a non-wall point: %s" % n0)
	assert_true(n2.dot(outward3) > 0.0, "row2's normal has a positive outward component at a non-wall point: %s" % n2)

	# Part 2: interior normals deviate from UP where the surface slopes.
	var region2 = _region(SEED, SITE_CHUNK)
	var ctx2: Dictionary = WaterField.ctx(water, SITE_CHUNK, region2)
	var curves2: Array = WaterContour.curves(ctx2, _rect(SITE_CHUNK))
	var skin2: Dictionary = WaterSkin.build(water, SITE_CHUNK, region2)
	assert_false(skin2.is_empty(), "site chunk builds a skin")
	if skin2.is_empty():
		return
	var verts2: PackedVector3Array = skin2.arrays[Mesh.ARRAY_VERTEX]
	var norms2: PackedVector3Array = skin2.arrays[Mesh.ARRAY_NORMAL]
	var e := 1.5
	var sloped_found := 0
	var offenders2: Array = []
	var sample_line := ""
	for vi in verts2.size():
		var v: Vector3 = verts2[vi]
		var p2 := Vector2(v.x, v.z)
		# Wall menisci can now extend several metres through measured recessed
		# cliff contacts.
		# Exclude the full independently bounded rim envelope; otherwise those
		# intentionally UP-normal wall columns are misclassified as interior.
		if _dist_to_curves(curves2, p2) < RIM_MAX_REACH:
			continue
		var hx1: float = WaterField.level_at(ctx2, p2 + Vector2(e, 0.0))
		var hx0: float = WaterField.level_at(ctx2, p2 - Vector2(e, 0.0))
		var hz1: float = WaterField.level_at(ctx2, p2 + Vector2(0.0, e))
		var hz0: float = WaterField.level_at(ctx2, p2 - Vector2(0.0, e))
		var dhdx := 0.0
		var dhdz := 0.0
		if hx1 > -INF and hx0 > -INF:
			dhdx = (hx1 - hx0) / (2.0 * e)
		if hz1 > -INF and hz0 > -INF:
			dhdz = (hz1 - hz0) / (2.0 * e)
		var slope_mag: float = sqrt(dhdx * dhdx + dhdz * dhdz)
		if slope_mag <= 0.1:
			continue
		sloped_found += 1
		var dot_up: float = norms2[vi].dot(Vector3.UP)
		if sloped_found == 1:
			sample_line = "%s slope_mag=%.4f normal=%s dot_up=%.4f" % [v, slope_mag, norms2[vi], dot_up]
		if dot_up > 0.999 and offenders2.size() < 10:
			offenders2.append("%s slope_mag=%.4f dot_up=%.4f" % [v, slope_mag, dot_up])
	print("MEAS test_rim_normals_curl_outward: interior sloped verts found=%d, sample: %s" % [sloped_found, sample_line])
	assert_true(sloped_found > 0, "site has at least one interior vertex with a real (>0.1) surface slope")
	assert_true(offenders2.is_empty(),
		"every sloped interior vertex's normal measurably deviates from UP: %s" % str(offenders2))


## test_wall_rim_reaches_the_face (r3-task-14-brief.md, UPGRADED round-5
## addendum — the BINDING version; the original walls-only wording earlier in
## that same file is superseded) — at a genuinely RISING wall reach near the
## owner's own R5-B frame (player (129.6,4.0,-1166.1) crosshair
## (129.7,4.2,-1165.8); owner complaint: "water still not going all the way
## up to the edges of the terrain," a visible slot between the sheet and the
## bank), the rim's own outer-row verts must reach the visible wall at
## TILE/2-CliffDressing.PLACE = 1.5m PAST the heightfield waterline. Earlier
## 0.3-0.6m overshoot values still left the owner's visible slot because the
## KayKit wall itself is recessed from the cell boundary.
## Site precondition scanned directly against WaterContour's own curve
## output (own ground probe at 1.0m along n̂, comparing against the curve's
## own baked level) — NOT via WaterSkin's own _rising_flags — so confirming
## "this is really a rising bank, not a drop" is not circular with the fix
## under test. Reach is measured via
## _max_outward_reach, which (per its own docstring) also does not reproduce
## WaterSkin's own reach/rising-blend formula, and is unaffected by this
## task's OTHER change (the row1/row2 meniscus bulge) since it locates
## vertices purely by xz column, never by y.
func test_wall_rim_reaches_the_face() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	assert_true(curves.size() > 0, "site chunk has curves")
	if curves.is_empty():
		return

	# Nearest WALL-flagged curve point to the R5-B owner frame's own wall
	# reach — scanned directly rather than hard-coding an index, so this
	# survives future curve reshaping (same discipline
	# test_pond_frames_are_calm's own "select the calm window DYNAMICALLY"
	# note documents for the identical reason).
	var hint := Vector2(129.6, -1138.5)
	var best_p := Vector2.ZERO
	var best_nrm := Vector2.ZERO
	var best_lvl := 0.0
	var best_d := INF
	var found := false
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		var wall: PackedByteArray = c.wall
		for i in pts.size():
			if wall[i] != 1:
				continue
			var d: float = pts[i].distance_to(hint)
			if d < best_d:
				best_d = d
				best_p = pts[i]
				best_nrm = c.normals[i]
				best_lvl = c.levels[i]
				found = true
	assert_true(found, "SITE_CHUNK has a wall-flagged curve point near the R5-B frame (site precondition)")
	if not found:
		return
	assert_true(best_d < 5.0,
		"the nearest wall point sits close to the R5-B frame's own wall reach (dist=%.2f)" % best_d)

	# Confirm it is a genuinely RISING bank (not a drop) — independent ground
	# probe at the brief's own ~1m distance, comparing against the curve's
	# OWN baked water level.
	var probe_pt: Vector2 = best_p + best_nrm * 1.0
	var g_probe: float = TerrainSurfaceField.surface_y(region, probe_pt.x, probe_pt.y)
	print("MEAS test_wall_rim_reaches_the_face: wall pt=%s nrm=%s level=%.3f ground@1m=%.3f" % [
		best_p, best_nrm, best_lvl, g_probe])
	assert_true(g_probe > best_lvl,
		"site precondition: ground genuinely RISES above the waterline within 1m along +n̂ (ground=%.2f > level=%.2f) — a rising bank, not a drop" % [g_probe, best_lvl])

	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var reach: float = _max_outward_reach(verts, best_p, best_nrm, 0.02)
	var visible_face_inset: float = WaterField.TILE * 0.5 - CliffDressing.PLACE
	print("MEAS test_wall_rim_reaches_the_face: max outward reach=%.4f (visible face inset=%.4f)" % [
		reach, visible_face_inset])
	assert_true(reach >= visible_face_inset,
		"the rim reaches the recessed wall face at %s (measured %.4f >= %.4f) — no visible slot" % [
			best_p, reach, visible_face_inset])

	# Free-edge invariant unaffected by the overshoot — same class, same
	# assertion shape as test_free_edges_only_buried_rim_or_border, re-run
	# here against SITE_CHUNK's own build so this test is a self-contained
	# regression pin even if that test is ever run in isolation elsewhere.
	var free: Array = _free_edges(skin.arrays)
	var checked := 0
	var offenders: Array = []
	for e: Array in free:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var a_border: bool = _on_chunk_border(a, SITE_CHUNK)
		var b_border: bool = _on_chunk_border(b, SITE_CHUNK)
		if a_border and b_border:
			continue
		checked += 1
		var a_ok: bool = a_border or _on_rim_outer_row(curves, a)
		var b_ok: bool = b_border or _on_rim_outer_row(curves, b)
		if not (a_ok and b_ok) and offenders.size() < 10:
			offenders.append("%s-%s" % [a, b])
	print("MEAS test_wall_rim_reaches_the_face: free-edge invariant re-check: %d checked, %d offenders" % [
		checked, offenders.size()])
	assert_true(offenders.is_empty(),
		"the overshoot does not break the buried-rim free-edge invariant: %s" % str(offenders))


## Complement of test_wall_rim_reaches_the_face: find a genuinely unbounded
## column whose ground drops inside 0.35m and is still low at the 1.5m wall
## reach. Its row2 must be the compact rounded shoulder (about 0.30m outward,
## 0.06m down), never the long recessed-wall skirt. Both terrain probes and
## the row lookup are test-side, independent of WaterSkin's branch condition.
func test_drop_rim_is_a_compact_rounded_lobe() -> void:
	var pond_chunk := Vector2i(-4, -18)
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, pond_chunk)
	var ctx: Dictionary = WaterField.ctx(water, pond_chunk, region)
	var curves: Array = WaterContour.curves(ctx, _rect(pond_chunk))
	assert_true(curves.size() > 0, "pond chunk has curves")
	if curves.is_empty():
		return

	# Scan for a true free edge: low ground both near the crest and at the full
	# recessed-wall distance. A local dip followed by rock at 1.5m is a bank
	# contact and intentionally takes the longer profile.
	var probe_reach := 0.35
	var drop_margin := 0.15
	var dp := Vector2.ZERO
	var dnrm := Vector2.ZERO
	var dlvl := 0.0
	var dground := 0.0
	var found := false
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		for i in pts.size():
			var pp: Vector2 = pts[i]
			var nn: Vector2 = c.normals[i]
			var ll: float = c.levels[i]
			var land: Vector2 = pp + nn * probe_reach
			var g: float = TerrainSurfaceField.surface_y(region, land.x, land.y)
			var far: Vector2 = pp + nn * WaterSkin.RIM_WALL_REACH
			var gfar: float = TerrainSurfaceField.surface_y(region, far.x, far.y)
			if g < ll - drop_margin and gfar <= ll + WaterSkin.RISE_MARGIN:
				dp = pp
				dnrm = nn
				dlvl = ll
				dground = g
				found = true
				break
		if found:
			break
	assert_true(found, "pond chunk has a non-wall drop-off shore point (ground drops >%.2fm below level within %.2fm) — the site precondition" % [drop_margin, probe_reach])
	if not found:
		return
	print("MEAS test_drop_rim_is_a_compact_rounded_lobe: drop pt=%s nrm=%s level=%.3f ground@%.2f=%.3f (drops %.3fm)" % [
		dp, dnrm, dlvl, probe_reach, dground, dlvl - dground])

	var skin: Dictionary = WaterSkin.build(water, pond_chunk, region)
	assert_false(skin.is_empty(), "pond chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var vi2: int = _find_row2_vertex(verts, dp, dnrm)
	assert_true(vi2 >= 0, "row2 vertex located in the drop point's own normal column")
	if vi2 < 0:
		print("MEAS missing drop row2 column: %s" % str(
			_column_diagnostic(verts, dp, dnrm, dlvl)))
	if vi2 < 0:
		return
	var row2: Vector3 = verts[vi2]
	var g_row2: float = TerrainSurfaceField.surface_y(region, row2.x, row2.z)
	var reach: float = (Vector2(row2.x, row2.z) - dp).dot(dnrm)
	var rel_y: float = row2.y - dlvl
	print("MEAS test_drop_rim_is_a_compact_rounded_lobe: row2=%s ground=%.3f reach=%.3f rel_y=%.3f" % [
		row2, g_row2, reach, rel_y])
	assert_true(reach >= 0.20 and reach <= 0.70,
		"drop shoulder stays a compact edge, not a horizontal film (reach %.3f)" % reach)
	assert_true(rel_y <= 0.06 and rel_y >= -0.30,
		"drop shoulder begins with a finite rounded descent (relative y %.3f)" % rel_y)


## --- r3 Task 7 (triggers + sampler; the old marching-squares mesher's own
## test suite is deleted) — two tests ported here per the task brief: this
## one verbatim (build_chunk's own contract is unchanged by this task), the
## other (below) retargeted from a per-24m-CELL swim-volume gate to the
## equivalent per-24m-TILE trigger gate. ---

## test_no_waterfall_nodes (ported verbatim from the deleted mesher suite) —
## falls are not a separate swept mesh with its own MeshInstance3D:
## build_chunk emits exactly one "WaterSheet" node and never a "Waterfalls"
## node, on ANY chunk (steep terrain included) — the falling look is a
## shader blend on the one sheet material, not additional geometry. Checked
## on the site chunk AND structurally by asserting build_chunk's own source
## has no code path that could ever add a second MeshInstance3D.
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


## test_no_trigger_where_unswimmably_steep — the swim-STEEP no-volume rule,
## retargeted from the deleted mesher's own per-24m-CELL swim-cell gate
## (test_no_volume_on_steep_water, formerly in the swim-volumes suite) to
## WaterSkin._triggers' own per-24m-TILE gate: a tile whose max |grade_at|
## exceeds STEEP_UNSWIMMABLE gets no trigger box at all — same 0.45 constant,
## same rationale comment (see WaterSkin.STEEP_UNSWIMMABLE's own docstring),
## just ported from "cell" to "tile" vocabulary (both are the same 24m
## magic number under a new name).
##
## Same fixture shape as the original: a real RiverTrace whose bed drops
## 12.0 over one 3m segment (grade 4.0, far past the 0.45 gate), claimed via
## ctx.buckets so WaterField.grade_at has a real trace to read from rather
## than a stubbed number. `_triggers` is called directly on a hand-built
## minimal `st` (only the three keys it actually reads: verts/region/ctx) —
## there is no curve/contour injection point for a synthetic steep
## RiverTrace the way a full WaterSkin.build() pass would need one, mirroring
## the original test's own "call the private function directly on a
## hand-built st" pattern.
##
## Anti-vacuity (new — the original test had no equivalent, since its own
## single fixture WAS the whole check): a SECOND, calm control tile 100m
## away (no trace nearby, grade_at reads 0) proves the gate is selective —
## it must still emit a trigger there, not swallow every tile indiscriminately.
func test_no_trigger_where_unswimmably_steep() -> void:
	var water := WaterPlan.new(1, 22.0, 8)
	var tr := RiverTrace.new()
	tr.source_cell = Vector2i(997, 997)
	tr.priority = 1
	tr.points = PackedVector2Array([Vector2(1.5, 1.5), Vector2(4.5, 1.5)])
	tr.beds = PackedFloat32Array([9.0, -3.0])
	tr.widths = PackedFloat32Array([3.0, 3.0])
	tr.joined = false
	tr.source_pool = null
	tr.pond = null
	# A real (if trivially flat, storey-0-everywhere) HeightfieldRegion —
	# TerrainSurfaceField.surface_y needs a real region object, not null
	# (unlike WaterField.grade_at, which tolerates a null region gracefully
	# via profile()'s own region-optional fallback).
	var region := HeightfieldRegion.new({}, {})
	var ctx: Dictionary = {"water": water, "ponds": [], "rivers": [tr],
		"buckets": {Vector2i(0, 0): [Vector2i(0, 0), Vector2i(0, 1)]}, "region": region}
	assert_true(absf(WaterField.grade_at(ctx, Vector2(1.5, 1.5))) > WaterSkin.STEEP_UNSWIMMABLE,
		"sanity: this fixture's own grade genuinely exceeds the gate")
	var verts := PackedVector3Array([
		Vector3(1.5, 9.0, 1.5), Vector3(4.5, 9.0, 1.5),        # steep tile (0,0)
		Vector3(101.5, 3.0, 1.5), Vector3(104.5, 3.0, 1.5),    # calm control tile (4,0) — no trace nearby
	])
	var st: Dictionary = {"verts": verts, "region": region, "ctx": ctx}
	var triggers: Array = WaterSkin._triggers(st)
	var by_cell: Dictionary = {}
	for t: Dictionary in triggers:
		var cell := Vector2i(int(t.rect.position.x / WaterSkin.TILE), int(t.rect.position.y / WaterSkin.TILE))
		by_cell[cell] = t
	print("MEAS test_no_trigger_where_unswimmably_steep: %d tiles emitted (of 2 candidate tiles)" % triggers.size())
	assert_false(by_cell.has(Vector2i(0, 0)),
		"steep tile (grade 4.0 >> 0.45) gets no trigger box at all")
	assert_true(by_cell.has(Vector2i(4, 0)),
		"calm control tile still gets a trigger — the gate is selective, not indiscriminate")

	# --- r3 Task 12b: the level-SPREAD reconciliation this stanza used to pin
	# (Task 7 "Defect B" + Task 9's sub-tile fallback) is RETIRED — see
	# WaterSkin.STEEP_UNSWIMMABLE's own neighbouring docstring and
	# r3-task-12b-report.md for the full proof. That mechanism existed to
	# catch a cascade-step tile carrying fill water at an UPSTREAM reach's
	# flat level over a downstream face — a shape only possible under the OLD
	# stepped profile model (one flat level per reach, hard cuts at trace
	# samples). r3 Task 12/12a's smooth monotone descent
	# (WaterField._dense_span_curve) removes that flat shelf structurally:
	# THIS EXACT site's own chute span (trace source_cell (0,-2)) resolves to
	# a two-anchor curve with ZERO interior sill knots (r3-task-12a-
	# report.md's own knot list) — there is no flat plateau anywhere along it
	# for a phantom reading to stand on. Measured directly
	# The segment-capsule fill now evaluates the continuous profile at the
	# closest longitudinal position instead of letting overlapping seed discs
	# pull this point to an arbitrary shelf. The chute remains grade-legal
	# (0.2333, below STEEP_UNSWIMMABLE), so it gets a REAL trigger. With the
	# requested deeper river bathymetry this old "film" pin is now legitimately
	# swim-deep; the anti-regression that matters is sampler == local FIELD,
	# while the synthetic fall tile above still proves truly steep water gets
	# no trigger at all.
	var site_water: WaterPlan = _water(SEED)
	var site_region = _region(SEED, SITE_CHUNK)
	var site_ctx: Dictionary = WaterField.ctx(site_water, SITE_CHUNK, site_region)
	var site_skin: Dictionary = WaterSkin.build(site_water, SITE_CHUNK, site_region)
	assert_false(site_skin.is_empty(), "site chunk builds (precondition)")
	var film := Vector2(53.0, -1083.9)
	# Historically labelled "the 5.7 plunge pool centre" (the OLD stepped
	# model's own flat reach value here) — controller addition 3's own pin.
	var pool_centre := Vector2(56.0, -1101.0)
	var film_covered := false
	var pool_covered := false
	var site_tiles := 0
	for t: Dictionary in site_skin.triggers:
		site_tiles += 1
		var rect: Rect2 = t.rect
		if rect.has_point(film):
			film_covered = true
		if rect.has_point(pool_centre):
			pool_covered = true
	print("MEAS test_no_trigger_where_unswimmably_steep: site chunk emits %d tiles; film covered=%s, pool centre covered=%s" % [
		site_tiles, film_covered, pool_covered])
	assert_true(site_tiles > 0, "site chunk still emits real triggers (the gate is not suppressing everything)")
	assert_true(film_covered,
		"the I1 chute tile now gets a real trigger (grade-legal at 0.2333, no spread gate left to suppress it) — the smooth ramp carries genuine, honest shallow water here, not a phantom reading")
	assert_true(pool_covered, "the historical '5.7' plunge pool centre (56,-1101) still gets a real trigger")

	# Direct phantom-depth pin (r3 Task 12b, the anti-regression that
	# actually matters now that trigger COVERAGE alone can no longer prove
	# anything about phantom depth): the sampler baked into this trigger must
	# read the FIELD's own LOCAL value at the film point, within 0.3 — never
	# a stale or upstream one. Measured: sampler and field agree EXACTLY here
	# (WaterSampler.build bakes a direct snapshot of WaterField.level_at),
	# comfortably inside the bound.
	var sampler: WaterSampler = site_skin.sampler
	var s_lvl: float = sampler.level_at(film)
	var f_lvl: float = WaterField.level_at(site_ctx, film)
	assert_false(is_nan(s_lvl), "sampler answers at the I1 film point (it is covered)")
	print("MEAS test_no_trigger_where_unswimmably_steep: I1 film phantom-depth pin: sampler=%.4f field=%.4f |diff|=%.4f (bound 0.3)" % [
		s_lvl, f_lvl, absf(s_lvl - f_lvl)])
	assert_true(absf(s_lvl - f_lvl) <= 0.3,
		"the sampler's own level at the old I1 film pin tracks WaterField.level_at's local continuous ramp within 0.3")

	# Replicate character.gd's STATIC depth math at the former film pin.  It
	# is now an ordinary deepened river reach, so swimming and wading are both
	# expected; the steep synthetic tile above remains triggerless.
	var film_g: float = TerrainSurfaceField.surface_y(site_region, film.x, film.y)
	var probe_y: float = film_g + 0.3
	var best_depth := -INF
	for t: Dictionary in site_skin.triggers:
		if not t.rect.has_point(film):
			continue
		if probe_y < float(t.bottom) or probe_y > float(t.top):
			continue
		var lvl: float = sampler.level_at(film)
		if not is_nan(lvl):
			best_depth = maxf(best_depth, lvl - film_g)
	var in_water: bool = best_depth > 0.8
	var wading: bool = best_depth > 0.05
	print("MEAS test_no_trigger_where_unswimmably_steep: I1 film character-math: depth=%.4f in_water=%s wading=%s" % [
		best_depth, in_water, wading])
	assert_true(in_water, "deepened legal river reach is swim-deep (%.4f > 0.8)" % best_depth)
	assert_true(wading, "swimming remains a deeper case of wading (%.4f > 0.05)" % best_depth)


## test_legal_sloped_reach_keeps_its_trigger — RENAMED + RETARGETED r3 Task
## 12b (was test_sub_tile_reconciliation_keeps_a_legal_sloped_reach, r3 Task
## 9's controller addition 2: "add a synthetic-or-real test for a
## sloped-but-legal reach tile"). The risk that test guarded against — the
## OLD whole-tile level-SPREAD fast path (TRIGGER_LEVEL_SPREAD_MAX)
## over-suppressing a legal, sustained slope, "rescued" by falling through to
## _sub_tile_triggers — no longer exists: the ENTIRE level-spread mechanism
## (TRIGGER_LEVEL_SPREAD_MAX/TRIGGER_SUB_TILE_SPREAD_MAX,
## _tile_level_spread/_level_spread_over, _sub_tile_triggers) is DELETED (r3
## Task 12b — see WaterSkin.STEEP_UNSWIMMABLE's own neighbouring docstring
## and r3-task-12b-report.md for the full proof). A legal grade=0.2 reach no
## longer risks whole-tile suppression AT ALL — there is nothing left to
## reconcile at sub-tile resolution; STEEP_UNSWIMMABLE (0.45) is the only
## remaining exclusion, and 0.2 sits nowhere near it. This test is KEPT,
## repointed at the new, simpler invariant: the SAME fixture (grade 0.2,
## inside the historical (0.083, 0.333] legal band STEEP_UNSWIMMABLE's own
## derivation still documents) gets exactly ONE 24m trigger covering its
## whole footprint — a real regression pin against a future
## re-introduction of level-spread-style over-suppression, not a new
## invariant invented for this task.
##
## Hand-builds a FILL lattice directly (WaterField.FILL_M/FILL_STEP, the same
## shape ctx() itself builds) rather than a RiverTrace + profile(): a
## profile()-derived synthetic trace hits real, unrelated quirks of the
## NO-FILL nearest-claimant fallback (_channel_membership_level's own
## nearest-SAMPLE-then-single-segment-lerp rule, which is not smooth at a
## sample switch and goes flat past the last sample's own capture zone —
## verified directly while designing this fixture, see r3-task-9-report.md)
## that have nothing to do with what this test checks — kept unchanged from
## the original fixture design.
func test_legal_sloped_reach_keeps_its_trigger() -> void:
	var region := HeightfieldRegion.new({}, {})
	var m1: int = WaterField.FILL_M + 1
	var levels := PackedFloat32Array()
	levels.resize(m1 * m1)
	var top_level := 10.0
	var grade := 0.2
	assert_true(grade > 0.083 and grade <= 0.333,
		"sanity: this fixture's own grade sits in the historical (0.083,0.333] legal band")
	for j in m1:
		for i in m1:
			levels[j * m1 + i] = top_level - grade * float(j) * WaterField.FILL_STEP
	var fill_base := Vector2(0.0, 0.0)
	var ctx: Dictionary = {"ponds": [], "rivers": [], "buckets": {}, "region": region,
		"fill_base": fill_base, "fill": {"levels": levels}}

	var verts := PackedVector3Array()
	for zz in [1.0, 4.0, 7.0, 10.0, 13.0, 16.0, 19.0, 22.0]:
		for xx in [13.0, 15.0]:
			verts.append(Vector3(xx, WaterField.level_at(ctx, Vector2(xx, zz)), zz))
	var st: Dictionary = {"verts": verts, "region": region, "ctx": ctx}
	var triggers: Array = WaterSkin._triggers(st)
	print("MEAS test_legal_sloped_reach_keeps_its_trigger: %d trigger(s) emitted (expect 1 — whole-tile coverage, no sub-tile splitting left to reconcile)" % triggers.size())
	assert_eq(triggers.size(), 1, "the legal sloped reach gets exactly one whole-tile trigger — grade 0.2 is nowhere near STEEP_UNSWIMMABLE(0.45)")
	# 60+ points: walk the whole reach densely and confirm every point along
	# it is covered by the trigger (trivial once triggers.size()==1 spans the
	# fixture's own tile, but kept as an explicit end-to-end regression pin,
	# same density as the parity test's own sloped-reach class).
	var checked := 0
	var offenders: Array = []
	for i in range(0, 61):
		var zz2: float = 0.2 + (23.6 * float(i) / 60.0)   # z in (0, 23.8), inset from both tile edges
		var p := Vector2(14.0, zz2)
		checked += 1
		var covered := false
		for t: Dictionary in triggers:
			if t.rect.has_point(p):
				covered = true
				break
		if not covered and offenders.size() < 10:
			offenders.append(str(p))
	print("MEAS test_legal_sloped_reach_keeps_its_trigger: %d points walked along the reach, %d offenders" % [checked, offenders.size()])
	assert_eq(checked, 61, "61 points walked (>=60 per the parity test's own per-class density)")
	assert_true(offenders.is_empty(), "every point along the legal sloped reach is covered by the trigger: %s" % str(offenders))
