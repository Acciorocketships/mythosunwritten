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
const EPS := 0.05

static var _profiles: Dictionary = {}   # trace.source_cell -> profile dict


## Everything the samplers need for one chunk, fetched once (bodies_near is
## too expensive per point). Also builds a 24m spatial bucket over river
## samples so level_at is O(nearby samples), not O(all samples).
static func ctx(water: WaterPlan, chunk: Vector2i) -> Dictionary:
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
		"buckets": buckets}


## Continuous, monotone level per trace sample + fall cut indices.
## levels[i] = min(levels[i-1], beds[i] + SURFACE_RIDE), anchored to the
## source pool at the top and the terminal pond at the bottom; a cut is
## recorded wherever one step drops more than FALL_DROP_MIN (upstream holds
## its level to the lip; the jump IS the waterfall).
static func profile(trace: RiverTrace) -> Dictionary:
	if _profiles.has(trace.source_cell):
		return _profiles[trace.source_cell]
	var n: int = trace.points.size()
	var levels := PackedFloat32Array()
	levels.resize(n)
	var cuts := PackedInt32Array()
	var lvl: float = trace.beds[0] + SURFACE_RIDE
	if trace.source_pool != null:
		lvl = minf(lvl, trace.source_pool.surface_y())
	levels[0] = lvl
	for i in range(1, n):
		var raw: float = trace.beds[i] + SURFACE_RIDE
		# Falls are strictly > FALL_DROP_MIN (4.0 m). An exact one-storey (4.0)
		# drop stays a slope by owner decision. The +0.01 guards float32
		# chained-subtraction noise so exact 4.0 drops never become falls.
		if lvl - raw > FALL_DROP_MIN + 0.01:
			cuts.append(i - 1)
			lvl = raw
		else:
			lvl = minf(lvl, raw)
		levels[i] = lvl
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
	return out


## Surface height at p, or -INF when no pond/reach claims the point.
## Claimant = smallest signed margin (distance past the body's edge).
static func level_at(c: Dictionary, p: Vector2) -> float:
	var best_m: float = CLAIM_FEATHER
	var best_lvl: float = -INF
	for pond: PondStamp in c.ponds:
		var m: float = (pond.footprint_t(p) - 1.0) * pond.radius
		if m < best_m:
			best_m = m
			best_lvl = pond.surface_y()
	var cell := Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var b: Array = c.buckets.get(cell + Vector2i(dx, dz), [])
			for ref: Vector2i in b:
				var tr: RiverTrace = c.rivers[ref.x]
				var si: int = ref.y
				var d: float = p.distance_to(tr.points[si])
				var m: float = d - tr.widths[si]
				if m < best_m:
					best_m = m
					best_lvl = _sample_level(tr, si, p)
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
