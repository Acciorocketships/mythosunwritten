# The continuous water surface: ONE height field w(x,z), discontinuous only
# at true waterfalls (bed drop > FALL_DROP_MIN between adjacent trace
# samples). Ponds are flat; river reaches slope monotonically between their
# anchors. This file is pure and deterministic — no rendering, no nodes.
class_name WaterField
extends Object

const TILE := 24.0
const FALL_DROP_MIN := 4.0    # the only fall threshold in the system
const SURFACE_RIDE := 2.2     # river surface height above the traced bed
const CLAIM_FEATHER := 8.0    # metres past the channel half-width a reach claims
const FLOOD_EXT := 24.0       # hard bound of the flooded-shelf extension
const FLOOD_DEPTH_MAX := 2.5  # flooded ground sits at most this far under the level
const EPS := 0.05

static var _profiles: Dictionary = {}   # trace.source_cell -> profile dict
# The streamer calls build_chunk (and therefore profile()) from a worker
# thread, and teleports can trigger a main-thread build concurrently — the
# same lazily-filled-static-Dictionary race that has crashed this codebase
# before (the foliage-cache incident). Guard every check-compute-store access.
static var _profiles_lock := Mutex.new()


## Everything the samplers need for one chunk, fetched once (bodies_near is
## too expensive per point). Also builds a 24m spatial bucket over river
## samples so level_at is O(nearby samples), not O(all samples).
## region is optional: when provided, level_at gains the flood extension
## (water reaches over ground that sits below its level — see level_at);
## null keeps the legacy hard-margin behaviour for existing callers.
static func ctx(water: WaterPlan, chunk: Vector2i, region = null) -> Dictionary:
	var centre := Vector2i(chunk.x * 8 + 4, chunk.y * 8 + 4)
	var bodies: Dictionary = water.bodies_near(centre, 8)
	var buckets: Dictionary = {}
	for ti in bodies.rivers.size():
		var tr: RiverTrace = bodies.rivers[ti]
		for si in tr.points.size():
			var cell := Vector2i(int(floor(tr.points[si].x / TILE)),
				int(floor(tr.points[si].y / TILE)))
			if not buckets.has(cell):
				buckets[cell] = []
			buckets[cell].append(Vector2i(ti, si))
	return {"water": water, "ponds": bodies.ponds, "rivers": bodies.rivers,
		"buckets": buckets, "region": region}


## Continuous, monotone level per trace sample + fall cut indices.
## levels[i] = min(levels[i-1], beds[i] + SURFACE_RIDE), anchored to the
## source pool at the top and the terminal pond at the bottom. Falls are
## detected over a short along-window (spec "Falls" bullet, docs/superpowers/
## specs/2026-07-09-water-boundary-mesh-design.md): a genuine cliff can
## descend over 2-3 samples (~12 m apart) without any single step exceeding
## FALL_DROP_MIN, so before committing the held level at sample i we also
## peek at sample i+1 (a ~24 m lookahead). If the held level clears either
## raw_i or raw_{i+1} by more than FALL_DROP_MIN, one cut is placed at the
## single step with the largest drop inside the held window; the samples
## between the anchor and that step are the lip (held at the anchor level),
## and scanning resumes just downstream of the cut with lvl = raw at the cut.
## Windows never overlap — once a cut is placed, the next window starts
## fresh from the sample after it.
static func profile(trace: RiverTrace) -> Dictionary:
	# Check-compute-store guarded end to end: the streamer's worker thread and
	# a teleport-triggered main-thread build can both call profile() for the
	# same trace at once. Profiles are small, so holding the lock across the
	# compute (not just the dictionary ops) costs nothing measurable.
	_profiles_lock.lock()
	if _profiles.has(trace.source_cell):
		var cached: Dictionary = _profiles[trace.source_cell]
		_profiles_lock.unlock()
		return cached
	var n: int = trace.points.size()
	var levels := PackedFloat32Array()
	levels.resize(n)
	var cuts := PackedInt32Array()
	var lvl: float = trace.beds[0] + SURFACE_RIDE
	if trace.source_pool != null:
		lvl = minf(lvl, trace.source_pool.surface_y())
	levels[0] = lvl
	var si: int = 1
	while si < n:
		var i: int = si
		var raw_i: float = trace.beds[i] + SURFACE_RIDE
		# Falls are strictly > FALL_DROP_MIN (4.0 m). An exact one-storey (4.0)
		# drop stays a slope by owner decision. The +0.01 guards float32
		# chained-subtraction noise so exact 4.0 drops never become falls.
		var drop_i: float = lvl - raw_i
		var drop_j: float = drop_i
		var j: int = i
		if i + 1 < n:
			var raw_next: float = trace.beds[i + 1] + SURFACE_RIDE
			var drop_next: float = lvl - raw_next
			if drop_next > drop_j:
				drop_j = drop_next
				j = i + 1
		if drop_i > FALL_DROP_MIN + 0.01 or drop_j > FALL_DROP_MIN + 0.01:
			# One of the two lookahead samples clears the threshold — place a
			# single cut at the step (within the anchor..j window) with the
			# largest drop measured from the held anchor level, holding the
			# lip level up to it. Measuring from the anchor (not step-to-step)
			# guarantees the recorded jump itself exceeds the threshold —
			# two sub-threshold single steps (e.g. 4.0 + 4.0) that only trip
			# the window *together* must still cut at the point that carries
			# the whole qualifying drop, not at whichever half-step is
			# nominally larger.
			var cut_at: int = i - 1
			var best_drop: float = drop_i
			for k in range(i + 1, j + 1):
				var raw_k: float = trace.beds[k] + SURFACE_RIDE
				var drop_k: float = lvl - raw_k
				if drop_k > best_drop:
					best_drop = drop_k
					cut_at = k - 1
			for fill in range(i, cut_at + 1):
				levels[fill] = lvl
			cuts.append(cut_at)
			var raw_after: float = trace.beds[cut_at + 1] + SURFACE_RIDE
			lvl = raw_after
			levels[cut_at + 1] = lvl
			si = cut_at + 2
			continue
		lvl = minf(lvl, raw_i)
		levels[i] = lvl
		si += 1
	if trace.pond != null:
		# Meet the pond surface continuously (or with a fall if the drop is big).
		var ps: float = trace.pond.surface_y()
		if levels[n - 1] - ps > FALL_DROP_MIN + 0.01:
			cuts.append(n - 1)
		else:
			# The trace must end exactly at the pond surface. Levels are already
			# monotone non-increasing, so pinning the last sample to ps preserves
			# monotonicity by itself UNLESS trailing samples dipped below ps
			# (water can't sit below the pond it feeds) — walk backward fixing
			# those up to ps.
			var i: int = n - 1
			while i >= 0 and levels[i] < ps:
				levels[i] = maxf(levels[i], ps)
				i -= 1
			levels[n - 1] = ps
			# Raising the tail up to ps can shrink the drop across the cut just
			# upstream of it (index i) below FALL_DROP_MIN — it's no longer a
			# real fall once the water below it was lifted to meet the pond.
			if i >= 0 and cuts.has(i) and levels[i] - levels[i + 1] <= FALL_DROP_MIN + 0.01:
				cuts.remove_at(cuts.find(i))
	var out := {"levels": levels, "cuts": cuts}
	_profiles[trace.source_cell] = out
	_profiles_lock.unlock()
	return out


## Surface height at p, or -INF when no pond/reach claims the point.
## Claimant = smallest signed margin (distance past the body's edge).
## FLOOD EXTENSION (only when the ctx carries a region): a candidate that
## fails the hard CLAIM_FEATHER margin still claims the point while the
## ground there sits below its level — water may not end mid-air over
## ground beneath its surface; it ends where the ground rises (a wall or a
## beach) or at the hard FLOOD_EXT bound. This restores the old system's
## flooded-shelf coverage on cliff terrain. Best-claimant selection stays
## smallest-margin-first. Flood covers SHALLOW shelves only (legacy
## FLOOD_MAX semantics): the ground must sit within FLOOD_DEPTH_MAX under
## the candidate's level — deep water exists only where the channel/pond
## carve contains it. Without the depth bound a high body's flood reaches
## over DEEP low ground toward a lower body, creating a bodiless level
## seam (an un-recorded jump in the lattice) between unrelated claimants.
static func level_at(c: Dictionary, p: Vector2) -> float:
	var region = c.get("region")
	var best_m: float = INF
	var best_lvl: float = -INF
	var gy: float = INF          # ground height, fetched lazily (flood test)
	var have_gy := false
	for pond: PondStamp in c.ponds:
		var m: float = (pond.footprint_t(p) - 1.0) * pond.radius
		if m >= best_m:
			continue
		var ok: bool = m < CLAIM_FEATHER
		var lvl: float = pond.surface_y()
		if not ok and region != null and m <= CLAIM_FEATHER + FLOOD_EXT:
			if not have_gy:
				gy = TerrainSurfaceField.surface_y(region, p.x, p.y)
				have_gy = true
			# Shallow shelves only: flooded ground rides just under the level.
			ok = gy < lvl - EPS and gy > lvl - FLOOD_DEPTH_MAX
		if ok:
			best_m = m
			best_lvl = lvl
	var cell := Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var b: Array = c.buckets.get(cell + Vector2i(dx, dz), [])
			for ref: Vector2i in b:
				var tr: RiverTrace = c.rivers[ref.x]
				var si: int = ref.y
				var d: float = p.distance_to(tr.points[si])
				var m: float = d - tr.widths[si]
				if m >= best_m:
					continue
				var ok: bool = m < CLAIM_FEATHER
				if not ok and (region == null or m > CLAIM_FEATHER + FLOOD_EXT):
					continue
				var lvl: float = _sample_level(tr, si, p)
				if not ok:
					if not have_gy:
						gy = TerrainSurfaceField.surface_y(region, p.x, p.y)
						have_gy = true
					# Shallow shelves only (see the flood note above).
					ok = gy < lvl - EPS and gy > lvl - FLOOD_DEPTH_MAX
				if ok:
					best_m = m
					best_lvl = lvl
	return best_lvl


## Level near sample si, projected onto the adjacent segment; across a cut
## the side of the cut plane decides which level applies (the jump line).
static func _sample_level(tr: RiverTrace, si: int, p: Vector2) -> float:
	var prof: Dictionary = profile(tr)
	var j: int = mini(si + 1, tr.points.size() - 1)
	if j == si:
		return prof.levels[si]
	if prof.cuts.has(si):
		var mid: Vector2 = (tr.points[si] + tr.points[j]) * 0.5
		var dirv: Vector2 = (tr.points[j] - tr.points[si]).normalized()
		return prof.levels[j] if (p - mid).dot(dirv) > 0.0 else prof.levels[si]
	var seg: Vector2 = tr.points[j] - tr.points[si]
	var t: float = clampf((p - tr.points[si]).dot(seg) / seg.length_squared(), 0.0, 1.0)
	return lerpf(prof.levels[si], prof.levels[j], t)


static func wet(c: Dictionary, region, p: Vector2) -> bool:
	var lvl: float = level_at(c, p)
	return lvl > -INF and lvl > TerrainSurfaceField.surface_y(region, p.x, p.y) + EPS


## Nearest-claimant helper shared by flow/grade: returns
## [trace, sample_i, margin] or [] when a pond wins / nothing claims.
static func _claim(c: Dictionary, p: Vector2) -> Array:
	var best_m: float = CLAIM_FEATHER
	var best: Array = []
	for pond: PondStamp in c.ponds:
		var m: float = (pond.footprint_t(p) - 1.0) * pond.radius
		if m < best_m:
			best_m = m
			best = []          # pond claims: still water
	var cell := Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for ref: Vector2i in c.buckets.get(cell + Vector2i(dx, dz), []):
				var tr: RiverTrace = c.rivers[ref.x]
				var m: float = p.distance_to(tr.points[ref.y]) - tr.widths[ref.y]
				if m < best_m:
					best_m = m
					best = [tr, ref.y]
	return best


static func flow_at(c: Dictionary, p: Vector2) -> Vector2:
	var cl: Array = _claim(c, p)
	if cl.is_empty():
		return Vector2.ZERO
	var tr: RiverTrace = cl[0]
	var si: int = cl[1]
	var j: int = mini(si + 1, tr.points.size() - 1)
	if j == si:
		return Vector2.ZERO
	# Fade to zero at the channel edge (shore water is calm).
	var edge: float = clampf(1.0 - p.distance_to(tr.points[si]) / maxf(tr.widths[si], 1.0), 0.0, 1.0)
	return (tr.points[j] - tr.points[si]).normalized() * edge


static func grade_at(c: Dictionary, p: Vector2) -> float:
	var cl: Array = _claim(c, p)
	if cl.is_empty():
		return 0.0
	var tr: RiverTrace = cl[0]
	var si: int = cl[1]
	var prof: Dictionary = profile(tr)
	var j: int = mini(si + 1, tr.points.size() - 1)
	if j == si or prof.cuts.has(si):
		return 0.0
	var run: float = tr.points[si].distance_to(tr.points[j])
	return (prof.levels[si] - prof.levels[j]) / maxf(run, 0.001)


## Fall cut segments whose midpoint lies inside rect (grown by one tile so
## chunk-border cuts appear for both neighbouring chunks).
static func fall_cuts(c: Dictionary, rect: Rect2) -> Array:
	var out: Array = []
	var grown: Rect2 = rect.grow(TILE)
	for tr: RiverTrace in c.rivers:
		var prof: Dictionary = profile(tr)
		for ci in prof.cuts:
			var j: int = mini(ci + 1, tr.points.size() - 1)
			var mid: Vector2 = (tr.points[ci] + tr.points[j]) * 0.5
			if not grown.has_point(mid):
				continue
			var dirv: Vector2 = (tr.points[j] - tr.points[ci]).normalized()
			out.append({"p": mid, "dir": dirv,
				"across": Vector2(-dirv.y, dirv.x),
				"half": tr.widths[ci] + CLAIM_FEATHER,
				"top": prof.levels[ci], "bottom": prof.levels[j]})
	return out
