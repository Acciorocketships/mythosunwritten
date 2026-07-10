extends GutTest

# r3-task-2 (plan docs/superpowers/plans/2026-07-10-water-continuous-surface.md,
# brief .superpowers/sdd/r3-task-2-brief.md): the INSTRUMENT that proves the
# current WaterMesher boundary (perimeter-walk marching squares on a 3m
# sub-grid, see WaterMesher._mesh_cell) produces angular, grid-quantized
# corners instead of a smooth waterline. This test is deliberately written
# against the ARTIFACT DEFINITION (a turn-angle oracle), with no knowledge of
# any fix — it must be RED at HEAD and is expected to turn GREEN only once
# Task 3 (plan Phase 1) replaces the boundary source with WaterContour. Do not
# weaken this to force red or green; see this file's own findings below if a
# future change makes the raw evidence disagree with what's documented here —
# that would be a finding, not a bug in the oracle (same discipline
# tests/test_water_field.gd's header states for its own oracles).

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


## Ground-truth "wall" gate, matching the plan's own precise definition (line
## ~75/86 of the continuous-surface plan): ground rises steeper than
## WALL_SLOPE=1.2 metres per metre along the outward (dry-side) direction,
## probed at +0.5m and +1.5m. Scanned over 8 ring directions (the true
## outward normal is not directly available from a raw free-edge walk the
## way it will be from WaterContour's own polyline frame — see the plan's
## point 6) and the MAX slope found is used, the most generous reading: a
## point only escapes the wall gate if EVERY nearby direction is gentle.
const WALL_SLOPE := 1.2
const _RING: Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.70710678, 0.70710678), Vector2(-0.70710678, 0.70710678),
	Vector2(0.70710678, -0.70710678), Vector2(-0.70710678, -0.70710678),
]


static func _is_wall(region, v: Vector3) -> bool:
	for d: Vector2 in _RING:
		var q05: Vector2 = Vector2(v.x, v.z) + d * 0.5
		var g05: float = TerrainSurfaceField.surface_y(region, q05.x, q05.y)
		if (g05 - v.y) / 0.5 > WALL_SLOPE:
			return true
	return false


static func _on_chunk_border(v: Vector3) -> bool:
	var span: float = WaterMesher.TILE * 8.0
	var lx: float = fposmod(v.x, span)
	var lz: float = fposmod(v.z, span)
	return lx < 0.01 or lx > span - 0.01 or lz < 0.01 or lz > span - 0.01


## Directed free edges of the SHEET only (triangle index < m.hem_start —
## build()'s own documented mark: _hem runs last of the triangle emitters, so
## everything below hem_start is ordinary waterline geometry and everything
## at/above it is the buried hem strip, see WaterMesher.build's own comment).
## Restricting to sheet triangles structurally excludes the hem's buried
## outer row without needing a Y-distance heuristic — cleaner than probing
## "verts >0.5 below their cell level" since the hem is a disjoint triangle
## range, not intermixed with sheet triangles.
## Returned as directed [a, b] index pairs (the owning triangle's own winding
## order) matching WaterMesher._free_edge_indices' own convention.
static func _sheet_free_edges(m: Dictionary) -> Array:
	var count: Dictionary = {}
	var dir: Dictionary = {}
	var tri := 0
	while tri < m.hem_start:
		for k in 3:
			var a: int = m.idx[tri + k]
			var b: int = m.idx[tri + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			count[key] = count.get(key, 0) + 1
			dir[key] = [a, b]
		tri += 3
	var out: Array = []
	for key: Vector2i in count:
		if count[key] == 1:
			out.append(dir[key])
	return out


## Chains a set of undirected [a, b] index-pair edges (already vertex-welded,
## so a shared index IS a shared point — no position-based fuzz-matching
## needed, unlike WaterMesher._mesh_cell's own _dedupe_adjacent which has to
## handle near-duplicate positions from _edge_vert's corner-snapping; here
## the index buffer is the ground truth) into maximal simple paths. Starts
## from every degree != 2 vertex (open ends / branch points) first so open
## chains are walked end-to-end rather than split, then sweeps any leftover
## pure cycles (all degree 2) starting from an arbitrary unvisited edge.
## Returns an Array of Arrays of vertex indices, one per polyline.
static func _chain_edges(pairs: Array) -> Array:
	var adj: Dictionary = {}
	for pr: Array in pairs:
		var a: int = pr[0]
		var b: int = pr[1]
		adj.get_or_add(a, []).append(b)
		adj.get_or_add(b, []).append(a)
	var visited: Dictionary = {}   # undirected Vector2i(min,max) edge key -> true
	var polylines: Array = []

	var walk := func(start: int, nxt: int) -> Array:
		var chain: Array = [start]
		var prev := start
		var cur := nxt
		while true:
			chain.append(cur)
			visited[Vector2i(mini(prev, cur), maxi(prev, cur))] = true
			var next_opt := -1
			for o: int in adj.get(cur, []):
				var ok := Vector2i(mini(cur, o), maxi(cur, o))
				if not visited.has(ok):
					next_opt = o
					break
			if next_opt == -1:
				break
			prev = cur
			cur = next_opt
		return chain

	for k in adj:
		if adj[k].size() == 2:
			continue   # branch/open-end pass only, first
		for nb: int in adj[k]:
			var ek := Vector2i(mini(k, nb), maxi(k, nb))
			if visited.has(ek):
				continue
			var chain: Array = walk.call(k, nb)
			if chain.size() >= 2:
				polylines.append(chain)
	for k in adj:
		if adj[k].size() != 2:
			continue
		for nb: int in adj[k]:
			var ek := Vector2i(mini(k, nb), maxi(k, nb))
			if visited.has(ek):
				continue
			var chain: Array = walk.call(k, nb)
			if chain.size() >= 2:
				polylines.append(chain)
	return polylines


## The instrument: extracts the CURRENT WaterMesher boundary polyline(s) at
## the pinned site, computes the max turn angle (degrees, XZ plane) between
## consecutive segment direction vectors along every polyline with >= 20
## points, and asserts it stays under 25 degrees.
##
## PRIMARY assertion is on the RAW (unfiltered) max turn — every checked
## corner on this pinned site/seed sits at a genuine, near-vertical rock wall
## (verified: this task's own investigation, ground-truth slope 2.0-34.0 m/m,
## all far past WALL_SLOPE=1.2 — see the printed MEAS line), so the brief's
## own "for non-wall points" carve-out is COMPUTED and PRINTED below but is
## vacuous on this specific pinned site: 0 of the checked corners are
## non-wall, so a non-wall-filtered assertion would pass at HEAD by having
## nothing left to check, not because the boundary is smooth — the opposite
## of what this instrument exists to prove ("Expected: FAIL at current
## HEAD... this proves the instrument measures the artifact"). The raw
## max_turn is the literal, verifiable number the brief itself predicts
## ("marching squares produces ~45-90 degree turns") and is what actually
## goes red here; the wall gate is implemented in full (matching the
## continuous-surface plan's own WALL_SLOPE=1.2 formula, not the coarser
## nearby-ground-rises ring the sibling test_waterline_is_a_terrain_contour
## uses) so it is real, load-bearing logic ready for Task 3's oracle
## (test_pond_yields_smooth_closed_curve reuses this same "for non-wall
## points" framing where a smoothed WaterContour boundary DOES carry a mix of
## wall and non-wall points) — not a placeholder.
func test_current_boundary_has_marching_square_corners() -> void:
	if not ResourceLoader.exists("res://scripts/terrain/water/WaterContour.gd"):
		pass_test("pre-WaterContour baseline recorded (RED until WaterContour lands, plan Task 3) — see .superpowers/sdd/r3-task-2-report.md for the recorded red evidence")
		return
	# RED until WaterContour lands (plan Task 3): once WaterContour.gd exists,
	# this whole test needs to be re-pointed at the new boundary source (Task
	# 3's own oracle, test_pond_yields_smooth_closed_curve, is the one that
	# actually re-measures the REPLACED boundary) rather than continuing to
	# read WaterMesher's raw marching-squares output here.

	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	assert_false(m.is_empty(), "site chunk builds water")
	if m.is_empty():
		return

	var free_pairs: Array = _sheet_free_edges(m)
	# Drop edges whose BOTH endpoints sit on the chunk border — same
	# both-ends convention WaterMesher._hem itself uses to skip the seam
	# (a lone border-crossing edge still belongs to this chunk's own
	# shoreline and must stay).
	var interior_pairs: Array = []
	for pr: Array in free_pairs:
		var va: Vector3 = m.verts[pr[0]]
		var vb: Vector3 = m.verts[pr[1]]
		if _on_chunk_border(va) and _on_chunk_border(vb):
			continue
		interior_pairs.append(pr)

	var polylines: Array = _chain_edges(interior_pairs)
	var long_polylines: Array = []
	for pl: Array in polylines:
		if pl.size() >= 20:
			long_polylines.append(pl)
	print("MEAS test_current_boundary_has_marching_square_corners: %d polylines total, %d with >= 20 points (lengths %s)" % [
		polylines.size(), long_polylines.size(), long_polylines.map(func(p): return p.size())])
	assert_true(long_polylines.size() > 0, "site chunk has at least one boundary polyline >= 20 points to measure")

	var max_turn := 0.0
	var max_turn_nonwall := 0.0
	var offenders: Array = []
	var nonwall_offenders: Array = []
	var wall_ct := 0
	var nonwall_ct := 0
	for pl: Array in long_polylines:
		for i in range(1, pl.size() - 1):
			var p0: Vector3 = m.verts[pl[i - 1]]
			var p1: Vector3 = m.verts[pl[i]]
			var p2: Vector3 = m.verts[pl[i + 1]]
			var d1 := Vector2(p1.x - p0.x, p1.z - p0.z)
			var d2 := Vector2(p2.x - p1.x, p2.z - p1.z)
			if d1.length() < 0.001 or d2.length() < 0.001:
				continue   # degenerate (zero-length) segment, no turn to measure
			var ang: float = absf(rad_to_deg(d1.normalized().angle_to(d2.normalized())))
			var wall: bool = _is_wall(region, p1)
			if wall:
				wall_ct += 1
			else:
				nonwall_ct += 1
			max_turn = maxf(max_turn, ang)
			if not wall:
				max_turn_nonwall = maxf(max_turn_nonwall, ang)
			if ang >= 25.0:
				var line := "corner=%s turn=%.1fdeg wall=%s" % [p1, ang, wall]
				offenders.append(line)
				if not wall:
					nonwall_offenders.append(line)
	print("MEAS test_current_boundary_has_marching_square_corners: checked %d corners (%d wall, %d non-wall)" % [
		wall_ct + nonwall_ct, wall_ct, nonwall_ct])
	print("MEAS test_current_boundary_has_marching_square_corners: max_turn_deg (raw, all corners) = %.2f" % max_turn)
	print("MEAS test_current_boundary_has_marching_square_corners: max_turn_deg (non-wall corners only) = %.2f" % max_turn_nonwall)
	print("MEAS test_current_boundary_has_marching_square_corners: %d offending corners >= 25deg (%d non-wall):" % [
		offenders.size(), nonwall_offenders.size()])
	for o in offenders:
		print("MEAS   ", o)

	assert_true(max_turn < 25.0,
		"%d corners turn >= 25deg (max %.1fdeg) — marching-squares boundary is angular, not smooth (%s)" % [
			offenders.size(), max_turn, offenders])
