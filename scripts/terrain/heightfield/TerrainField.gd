class_name TerrainField
extends RefCounted

## The natural terrain height in metres (spec 2026-10-02 §2, revised after the
## owner's first visual review):
##   H = base + continental + setpieces + features.raise - features.cut
##       + texture relief * (1 - 0.7 setpiece_mask)
## evaluated per blended regime (each applying its own storey-aligned terrace),
## summed with the regime weights from TerrainRegimeField.sample, then passed
## through a soft ceiling under REF_AMPLITUDE.
## - elevation: broad highlands and lowlands (0..ELEVATION_M) from a 4.5-9 km
##   noise: upland fronts rising over about 700 m, highland interiors swelling
##   higher, lowland basins dipping (owner review 2026-10-03); the noise is
##   shifted per seed so spawn lies on a lowland floor.
## - continental: a 1.3-2.6 km undulation (0..CONTINENTAL_M) on top of it.
## - features: LandformFeatures, the mid-scale structured landforms (hills,
##   peak clusters, ridges, mesas, basins with islands, valleys...).
## include_detail=false is the smooth field rivers trace: everything above
## except fine texture and terraces.

const REF_AMPLITUDE := TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE
const SETPIECE_RELIEF_SUPPRESSION := 0.7
const CONTINENTAL_M := 72.0
const ELEVATION_M := 320.0
## Heights above SOFT_CEILING approach REF_AMPLITUDE asymptotically.
const SOFT_CEILING := REF_AMPLITUDE - 16.0


## Broad highlands and lowlands in [0, 1] (before the spawn fade), from one
## slow noise n (owner review 2026-10-03, second pass):
## - the upland front, a rise of UPLAND of the layer over about 700 m where n
##   crosses 0.5 (`upland01`);
## - SWELL more toward the interior of a highland, where n keeps rising, so
##   highlands are not flat tables;
## - lowland floors at FLOOR, dipping to 0 in basins where n keeps falling.
const FLOOR := 0.15
const UPLAND := 0.65
const SWELL := 0.2
const FRONT_LO := 0.477
const FRONT_HI := 0.523

static func elevation01(seed: int, p: Vector2) -> float:
	return _elevation01_of(_elevation_noise(seed, p + _elevation_offset(seed)))


static func _elevation01_of(n: float) -> float:
	return FLOOR * (1.0 - smoothstep(0.46, 0.28, n)) + UPLAND * smoothstep(FRONT_LO, FRONT_HI, n) \
		+ SWELL * smoothstep(0.53, 0.72, n)


## The upland front alone: 0 in lowlands, 1 on highlands.
static func upland01(seed: int, p: Vector2) -> float:
	return smoothstep(FRONT_LO, FRONT_HI, _elevation_noise(seed, p + _elevation_offset(seed)))


static func _elevation_noise(seed: int, q: Vector2) -> float:
	# Rotated octaves and a 1.5 km warp hide the value-noise lattice (boxy,
	# axis-aligned plateau edges at this scale).
	var w := ReliefPrimitives.warp(q.rotated(0.45), seed + 1715, 1500.0, 5000.0)
	return 0.65 * ReliefPrimitives.vnoise01(w, seed + 1711, 9000.0) \
		+ 0.35 * ReliefPrimitives.vnoise01(w.rotated(1.3), seed + 1712, 4500.0)


static var _offsets: Dictionary = {}
static var _offset_mutex := Mutex.new()

## Shift of the elevation noise that puts spawn naturally on a lowland floor:
## the first of a fixed sequence of hashed offsets whose layer stays at the
## lowland floor (no upland front, no basin) within 1.5 km of the origin; a
## basin drew rivers into spawn (2026-10-04). Pure function of the seed; cached.
static func _elevation_offset(seed: int) -> Vector2:
	_offset_mutex.lock()
	var cached = _offsets.get(seed)
	_offset_mutex.unlock()
	if cached != null:
		return cached
	var best := Vector2.ZERO
	var best_e := INF
	for k in 64:
		var off := Vector2(Helper._cell_hash01(seed + 1713, k, 0) - 0.5,
			Helper._cell_hash01(seed + 1714, k, 0) - 0.5) * 40000.0
		var e := 0.0
		for d in [Vector2.ZERO, Vector2(1500, 0), Vector2(-1500, 0), Vector2(0, 1500), Vector2(0, -1500)]:
			e = maxf(e, absf(_elevation01_of(_elevation_noise(seed, off + d)) - FLOOR))
		if e < best_e:
			best_e = e
			best = off
		if e < 0.03:
			break
	_offset_mutex.lock()
	_offsets[seed] = best
	_offset_mutex.unlock()
	return best


## Not faded round spawn: fading to zero dug a bowl rivers ended in, and
## easing to the origin's own value raised a plateau when the origin sat on a
## high (2026-10-04). _elevation_offset already puts spawn on a lowland floor.
static func elevation_m(seed: int, p: Vector2) -> float:
	return ELEVATION_M * elevation01(seed, p)


## A 1.3-2.6 km undulation (gentle: about two degrees); not faded round spawn
## (see elevation_m).
static func continental_m(seed: int, p: Vector2) -> float:
	var n := 0.65 * ReliefPrimitives.vnoise01(p, seed + 1701, 2600.0) \
		+ 0.35 * ReliefPrimitives.vnoise01(p.rotated(0.9), seed + 1702, 1300.0)
	return CONTINENTAL_M * smoothstep(0.2, 0.8, n)


static var _spawn_levels: Dictionary = {}

## The spawn clearing's level: the mean smooth field on a ring 240 m out,
## where HeightfieldPlan's clearing ends, but never below the median ground
## 400 m out (hills round spawn must not leave it in a hollow that collects
## water). Pure function of the seed; cached.
static func spawn_level_m(seed: int) -> float:
	_offset_mutex.lock()
	var cached = _spawn_levels.get(seed)
	_offset_mutex.unlock()
	if cached != null:
		return cached
	var sum := 0.0
	for k in 16:
		sum += height_m(Vector2.from_angle(k * TAU / 16.0) * 240.0, seed, false)
	var ring: Array[float] = []
	for k in 32:
		ring.append(height_m(Vector2.from_angle(k * TAU / 32.0) * 400.0, seed, false))
	ring.sort()
	var level := maxf(sum / 16.0, ring[16])
	_offset_mutex.lock()
	_spawn_levels[seed] = level
	_offset_mutex.unlock()
	return level


static func height_m(p: Vector2, seed: int, include_detail: bool) -> float:
	var sp := LandformSetpieces.sample(seed, p)
	var f := LandformFeatures.sample(seed, p, include_detail)
	var h := TerrainRegimeField.base_m(seed, p) + elevation_m(seed, p) + continental_m(seed, p) \
		+ sp.x + LandformFeatures.net(f) + LandformFeatures.local_relief(seed,p)
	var keep := 1.0 - SETPIECE_RELIEF_SUPPRESSION * sp.y
	var out := 0.0
	for pair: Array in TerrainRegimeField.sample(seed, p):
		var region: Dictionary = pair[0]
		var hr := h + RegimeRelief.relief_m(region, p, include_detail) * keep
		out += float(pair[1]) * (_terraced(hr, RegimeRelief.terrace_of(region)) if include_detail else hr)
	return soft_ceiling(out)


static func soft_ceiling(h: float) -> float:
	if h <= SOFT_CEILING:
		return h
	var room := REF_AMPLITUDE - SOFT_CEILING
	return SOFT_CEILING + room * tanh((h - SOFT_CEILING) / room)


static func _terraced(h: float, t: Vector2) -> float:
	return h if t.x <= 0.0 else ReliefPrimitives.terrace(h, t.x, t.y)
