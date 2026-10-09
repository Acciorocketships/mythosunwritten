class_name LandformFeatures
extends RefCounted

## Mid-scale structured landforms (owner review 2026-10-02: the first regime
## pass "reads as noise"; wanted basins with an island, three peaks joined by
## ridges, mesas with sheer cliffs, tall rolling hills).
##
## One candidate per CELL with its centre in [0.2, 0.8] of the cell; its kind is
## drawn from the archetype of the region at the centre
## (TerrainRegimeCatalog.FEATURES) and its shape from FEATURE_PARAMS. Every
## footprint radius is <= MAX_RADIUS (< 1.2 cells), so the 3x3 cells round a
## point hold every feature that reaches it, and each shape is exactly zero at
## its radius: the field is continuous. Raised parts of overlapping features
## merge by a 6-norm (zero-preserving smooth max: overlapping peaks become one
## massif with saddles); hollows merge the same way by depth.
## shape() works in a local frame: x along the feature, y across it.
## detail=false is the feature as rivers see it (the smooth field): sheer rims,
## tower and butte sides, escarpment faces and V crests are rounded into domes
## and shoulders, so the summit climb of WaterPlan converges on them instead of
## stalling where its 6 m gradient straddles a cliff edge.

## 256 m (owner review 2026-10-04: more medium-size features; was 320 m).
const CELL := 256.0
const MAX_RADIUS := 294.0
const NORM := 6.0
const ST := TerrainRegimeCatalog.STOREY
## No footprint comes closer than this to the world origin (spawn clearing).
const SPAWN_CLEAR_M := 200.0
const CACHE_LIMIT := 16384
## Exponent on the uniform draw of each feature's height scale.
const HEIGHT_SKEW := 2.0

static var _cache: Dictionary = {}   # seed -> {Vector3i(cell, table): value}
static var _keys: Array = []
static var _cursor := 0
static var _mutex := Mutex.new()

const _MAIN := 0
const _CHOSEN := 1
const _CANDIDATE := 2
const _LINKS := 3
const _DRAW := 4


static func clear_caches() -> void:
	_mutex.lock()
	_cache.clear()
	_keys.clear()
	_cursor = 0
	_mutex.unlock()


static func _hash(seed: int, cell: Vector2i, salt: int) -> float:
	return Helper._cell_hash01(seed + salt, cell.x, cell.y)


## Bounded, thread-safe memo of one per-cell table; values are pure functions
## of (seed, cell), so a race only computes one twice.
static func _memo(seed: int, cell: Vector2i, table: int, compute: Callable) -> Variant:
	var key := Vector3i(cell.x, cell.y, table)
	_mutex.lock()
	var cached = (_cache.get(seed, {}) as Dictionary).get(key)
	_mutex.unlock()
	if cached != null:
		return cached
	var value = compute.call()
	_mutex.lock()
	var per_seed: Dictionary = _cache.get(seed, {})
	if not per_seed.has(key):
		if _keys.size() == CACHE_LIMIT:
			var old: Array = _keys[_cursor]
			(_cache.get(old[0], {}) as Dictionary).erase(old[1])
			_keys[_cursor] = [seed, key]
			_cursor = (_cursor + 1) % CACHE_LIMIT
		else:
			_keys.append([seed, key])
		per_seed[key] = value
		_cache[seed] = per_seed
	value = per_seed[key]
	_mutex.unlock()
	return value


## The feature hosted by a cell, or {}; "links" lists the cells of the
## neighbouring features it is joined to (see _chosen).
static func candidate(seed: int, cell: Vector2i) -> Dictionary:
	return _memo(seed, cell, _CANDIDATE, func() -> Dictionary:
		var f := _main(seed, cell)
		if f.is_empty():
			return f
		var out := f.duplicate()
		var links: Array[Vector2i] = _chosen(seed, cell).duplicate()
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var other := cell + Vector2i(dx, dz)
				if other != cell and not links.has(other) and _chosen(seed, other).has(cell):
					links.append(other)
		out["links"] = links
		return out)


## The prevailing grain: ridges, valleys, scarps and elongated hills near p
## run along this angle (+- jitter), so neighbours line up into ranges and
## valley systems instead of pointing every way.
static func grain(seed: int, p: Vector2) -> float:
	return TAU * ReliefPrimitives.vnoise01(p.rotated(0.7), seed + 1620, 4000.0)


static func _main(seed: int, cell: Vector2i) -> Dictionary:
	return _memo(seed, cell, _MAIN, func() -> Dictionary: return _compute(seed, cell))


## A basin gives way to a raised neighbour whose core it would overlap: cut
## into a hill or ridge, it left only a stranded crest stub (owner review
## 2026-10-04, with basins in most archetypes), so basins lie in the gaps
## between raised landforms. Valleys still cross them as passes (net). Raised draws never depend on
## neighbours, so this reads each neighbour's own draw without recursion.
static func _compute(seed: int, cell: Vector2i) -> Dictionary:
	var f := _draw(seed, cell)
	if f.is_empty() or f.kind != &"basin":
		return f
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if dx == 0 and dz == 0:
				continue
			var g := _draw(seed, cell + Vector2i(dx, dz))
			if not g.is_empty() and g.kind in _RAISED \
					and f.pos.distance_to(g.pos) < 0.5 * (f.radius + g.radius):
				return {}
	return f


static func _draw(seed: int, cell: Vector2i) -> Dictionary:
	return _memo(seed, cell, _DRAW, func() -> Dictionary: return _draw_raw(seed, cell))


static func _draw_raw(seed: int, cell: Vector2i) -> Dictionary:
	var pos := (Vector2(cell) + Vector2(0.2 + 0.6 * _hash(seed, cell, 1601),
		0.2 + 0.6 * _hash(seed, cell, 1602))) * CELL
	var region := TerrainRegimeField.region_at(seed, pos)
	var table: Dictionary = TerrainRegimeCatalog.FEATURES[region.archetype]
	if _hash(seed, cell, 1603) >= float(table.density):
		return {}
	var kinds: Dictionary = table.kinds
	var u := _hash(seed, cell, 1604)
	var kind: StringName = kinds.keys()[kinds.size() - 1]
	for k: StringName in kinds:
		u -= float(kinds[k])
		if u < 0.0:
			kind = k
			break
	var params := TerrainRegimeCatalog.draw(seed, cell, 1610, TerrainRegimeCatalog.FEATURE_PARAMS[kind], 1.0)
	var range_: Array = table.height_scale
	# Skewed toward the low end: most features keep a moderate height and a
	# few stand far taller (owner review 2026-10-04).
	var scale := lerpf(float(range_[0]), float(range_[1]), pow(_hash(seed, cell, 1605), HEIGHT_SKEW))
	for name: String in params:
		if name.ends_with("_st"):
			params[name] = float(params[name]) * scale
	var radius := footprint_radius(kind, params)
	if pos.length() - radius < SPAWN_CLEAR_M:
		return {}
	var salt := int(_hash(seed, cell, 1607) * 1000000.0)
	if kind in [&"hill", &"mesa", &"basin"]:
		params["_blob"] = blob_components(params, salt)
	var rot := grain(seed, pos) + (_hash(seed, cell, 1606) - 0.5) * 0.7
	return {"kind": kind, "pos": pos, "params": params, "radius": radius, "cell": cell,
		"rot": rot, "salt": salt}


## (raise m, cut m) at p from every feature and link reaching it.
static func sample(seed: int, p: Vector2, detail: bool = true) -> Vector2:
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var raise := 0.0
	var cut := 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cell := c + Vector2i(dx, dz)
			var f := _main(seed, cell)
			if not f.is_empty() and p.distance_to(f.pos) < f.radius:
				var v := shape(f.kind, f.params, (p - f.pos).rotated(-f.rot), f.salt, detail)
				raise = _union(raise, v.x)
				cut = _union(cut, v.y)
			for link: Dictionary in _links_owned(seed, cell):
				if p.distance_to(link.pos) < link.radius:
					var h := link_shape(link, p, detail)
					if link.raise:
						raise = _union(raise, h)
					else:
						cut = _union(cut, h)
	return Vector2(raise, cut)


## Net height of a sample (raise, cut): a valley or basin crossing a raised
## landform taller than a few storeys breaches it as a pass (a quarter of its
## depth over 12 m of raise) instead of cutting a gap that strands a stub
## (owner review 2026-10-03: no lone bumps).
static func net(v: Vector2) -> float:
	return v.x - v.y * (1.0 - 0.75 * smoothstep(0.0, 12.0, v.x))


## Zero-preserving smooth max of two non-negative heights.
static func _union(a: float, b: float) -> float:
	if a <= 0.0:
		return maxf(b, 0.0)
	if b <= 0.0:
		return a
	return pow(pow(a, NORM) + pow(b, NORM), 1.0 / NORM)


static func features_in_rect(seed: int, rect: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lo := Vector2i(floori(rect.position.x / CELL) - 1, floori(rect.position.y / CELL) - 1)
	var hi := Vector2i(floori(rect.end.x / CELL) + 1, floori(rect.end.y / CELL) + 1)
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var f := candidate(seed, Vector2i(x, z))
			if not f.is_empty() and rect.grow(f.radius).has_point(f.pos):
				out.append(f)
	return out


static func footprint_radius(kind: StringName, q: Dictionary) -> float:
	match kind:
		&"hill", &"peak_cluster", &"butte_group", &"tower_cluster", &"basin":
			return q.radius_m
		&"ridge", &"valley":
			return q.half_length_m
		&"mesa":
			return q.radius_m + 64.0
		&"escarpment":
			return maxf(q.half_length_m, q.back_m + 24.0)
		&"amphitheatre":
			return q.radius_m * 1.4
	return 0.0


## Smooth fade to exactly zero over the outer rim of a footprint.
static func _envelope(r: float, radius: float) -> float:
	return 1.0 - smoothstep(radius - minf(60.0, 0.3 * radius), radius, r)


## A smooth per-feature value in [0, 1] varying with direction (organic outlines).
static func _lobes(local: Vector2, salt: int) -> float:
	var dir := local.normalized() if local.length_squared() > 1e-6 else Vector2.RIGHT
	# Low frequency round the circle (about four swells): at 2.5 the outline
	# zigzagged every ~25 degrees and broke amphitheatre walls into beads.
	return ReliefPrimitives.vnoise01(dir * 0.65, salt, 1.0)


static func _h(salt: int, i: int, k: int) -> float:
	return Helper._cell_hash01(salt + k, i, 0)


const PROFILE_DOME := 0
const PROFILE_PLATEAU := 2
const BLOB_STRIDE := 6

## The blob of a hill/mesa/basin (owner review 2026-10-03: circles read
## as artificial): a core ellipse and 0-2 satellite ellipses, each with its own
## centre, semi-axes, rotation and relative height, all inside 0.92 of the
## radius. Flat array [cx, cy, a, b, rot, rel] per component; cached in the
## feature's params at creation (computed on the fly for synthetic params).
static func _components(q: Dictionary, salt: int) -> PackedFloat64Array:
	var cached = q.get("_blob")
	if cached != null:
		return cached
	return blob_components(q, salt)


static func blob_components(q: Dictionary, salt: int) -> PackedFloat64Array:
	var radius: float = q.radius_m
	var sat_lo := 0.7
	var sat_hi := 0.9
	if q.has("peaks") or q.has("spread"):
		sat_lo = 0.4
		sat_hi = 0.7
	var out := PackedFloat64Array()
	# 1-3 ellipses in all (owner, 2026-10-03). A lone core is never near-round.
	var satellites := int(_h(salt, 0, 46) * 2.999)
	var core_a := radius * (0.6 + 0.18 * _h(salt, 0, 41))
	var core_aspect := (0.5 + 0.3 * _h(salt, 0, 44)) if satellites == 0 else (0.5 + 0.45 * _h(salt, 0, 44))
	if q.has("depth_st"):
		# Basins are troughs and lake hollows along the grain, never round
		# craters (owner review 2026-10-03).
		core_aspect = 0.35 + 0.25 * _h(salt, 0, 44)
	out.append_array([(_h(salt, 0, 42) - 0.5) * 0.16 * radius, (_h(salt, 0, 43) - 0.5) * 0.16 * radius,
		core_a, core_a * core_aspect, (_h(salt, 0, 45) - 0.5) * 0.6, 1.0])
	# Satellites are lobes grown off the core's ends (either end, a little to
	# one side), never separate bumps beside it (owner review 2026-10-03).
	var core_rot := out[4]
	var first_end := 1.0 if _h(salt, 1, 48) < 0.5 else -1.0
	for i in range(1, satellites + 1):
		var end := (first_end if i == 1 else -first_end) * (0.5 + 0.3 * _h(salt, i, 47)) * core_a
		var at := Vector2(out[0], out[1]) + Vector2(end, (_h(salt, i, 52) - 0.5) * 0.5 * core_a * core_aspect).rotated(core_rot)
		var dist := at.length()
		var a := maxf(0.1 * radius, minf(radius * (0.28 + 0.22 * _h(salt, i, 49)), 0.92 * radius - dist))
		out.append_array([at.x, at.y, a, a * (0.4 + 0.5 * _h(salt, i, 50)), _h(salt, i, 53) * TAU,
			lerpf(sat_lo, sat_hi, _h(salt, i, 54))])
	return out


## Light domain warp so blob outlines are never clean conics.
static func _warp(q: Dictionary, local: Vector2, salt: int) -> Vector2:
	var wl: float = 0.4 * q.radius_m
	return local + Vector2(ReliefPrimitives.vnoise(local, salt + 61, wl),
		ReliefPrimitives.vnoise(local, salt + 62, wl)) * 0.18 * q.radius_m


## Normalised elliptical distance of a warped point to component k (1 at its outline).
static func _component_t(c: PackedFloat64Array, k: int, w: Vector2) -> float:
	var i := k * BLOB_STRIDE
	var d := (w - Vector2(c[i], c[i + 1])).rotated(-c[i + 4])
	return Vector2(d.x / c[i + 2], d.y / c[i + 3]).length()


## Height fraction (0..1) of the blob: max over components of rel * profile.
static func _blob_height(q: Dictionary, local: Vector2, salt: int, profile: int, detail: bool) -> float:
	var c := _components(q, salt)
	var w := _warp(q, local, salt)
	var best := 0.0
	for k in c.size() / BLOB_STRIDE:
		var t := _component_t(c, k, w)
		if t >= 1.0:
			continue
		var v := 0.0
		match profile:
			PROFILE_DOME:
				v = pow(1.0 - t * t, 2.0)
			PROFILE_PLATEAU:
				var b: float = c[k * BLOB_STRIDE + 3]
				var rim := 6.0 / b if detail else 0.6
				v = 1.0 - smoothstep(1.0 - rim, 1.0, t)
		best = maxf(best, v * c[k * BLOB_STRIDE + 5])
	return best


## The blob's normalised distance: the minimum over its components (union).
static func _blob_t(q: Dictionary, local: Vector2, salt: int) -> float:
	var c := _components(q, salt)
	var w := _warp(q, local, salt)
	var best := INF
	for k in c.size() / BLOB_STRIDE:
		best = minf(best, _component_t(c, k, w))
	return best


## A planar tilt: one flank up to 30% taller than the other.
static func _tilt(q: Dictionary, local: Vector2, salt: int) -> float:
	var dir := Vector2.from_angle(_h(salt, 0, 55) * TAU)
	var amount := 0.3 * _h(salt, 0, 56)
	return 1.0 + amount * clampf(local.dot(dir) / q.radius_m, -1.0, 1.0)


## Summit positions of a peak cluster (local frame).
static func cluster_summits(q: Dictionary, salt: int) -> Array[Vector2]:
	var n := clampi(roundi(q.peaks), 2, 4)
	var base := _h(salt, 0, 11) * TAU
	var out: Array[Vector2] = []
	for i in n:
		var angle: float = base + i * TAU / n + (_h(salt, i, 12) - 0.5) * 0.5
		out.append(Vector2.from_angle(angle) * q.spread * q.radius_m)
	return out


## (raise, cut) in metres of one feature at a local position.
static func shape(kind: StringName, q: Dictionary, local: Vector2, salt: int, detail: bool = true) -> Vector2:
	var r := local.length()
	var raise := 0.0
	var cut := 0.0
	match kind:
		&"hill":
			raise = q.height_st * ST * _blob_height(q, local, salt, PROFILE_DOME, detail) * _tilt(q, local, salt)
		&"peak_cluster":
			raise = _cluster(q, local, salt, detail)
		&"ridge":
			raise = _ridge(q, local, salt, detail)
		&"mesa":
			raise = _mesa(q, local, salt, detail)
		&"butte_group":
			raise = _scatter(q, local, salt, q.buttes, q.butte_radius_m, 0.6, true, detail)
		&"tower_cluster":
			raise = _scatter(q, local, salt, q.towers, q.tower_radius_m, 0.55, false, detail)
		&"basin":
			# The bowl and its rim follow the blob outline (t = 1); the depth
			# tilts across the basin.
			var t := _blob_t(q, local, salt)
			var depth: float = q.depth_st * ST
			cut = depth * (1.0 - smoothstep(q.floor, 0.95, t)) * _tilt(q, local, salt)
			# A low lip on one side only: a full raised ring read as a crater.
			var lip := Vector2.from_angle(_h(salt, 0, 59) * TAU)
			var side := smoothstep(-0.2, 0.8, local.normalized().dot(lip)) if local.length_squared() > 1.0 else 0.0
			raise = q.rim_st * ST * exp(-pow((t - 1.0) / 0.12, 2.0)) * side
			if q.island >= 0.7:
				# The island stands island_st above the surrounding ground: an
				# elliptical sheer-sided mesa or rounded hill, by the feature's hash.
				var ir: float = q.island_radius * q.floor * q.radius_m
				# Off-centre along the basin's long axis: a central peak reads as a crater.
				var off: Vector2 = Vector2((0.3 + 0.25 * _h(salt, 0, 58)) * (1.0 if _h(salt, 0, 57) < 0.5 else -1.0) * q.floor * q.radius_m, 0.0)
				var e := (local - off).rotated(-_h(salt, 0, 51) * TAU)
				var ti := Vector2(e.x / ir, e.y / (ir * (0.55 + 0.4 * _h(salt, 0, 52)))).length()
				var profile := 1.0 - smoothstep(0.85, 1.0, ti) if detail and salt % 2 == 0 \
					else pow(maxf(0.0, 1.0 - ti * ti), 1.5)
				raise = maxf(raise, (depth + q.island_st * ST) * profile)
		&"valley":
			var half: float = q.half_length_m
			var shift: float = 0.7 * q.floor_half_m * sin(local.x / half * PI)
			var along := 1.0 - smoothstep(0.65 * half, half, absf(local.x))
			var across := 1.0 - smoothstep(q.floor_half_m, q.floor_half_m + q.side_m, absf(local.y - shift))
			cut = q.depth_st * ST * along * across
		&"escarpment":
			var half: float = q.half_length_m
			var wob: float = q.face_m * 1.5 * sin(local.x / half * PI * 1.5 + float(salt % 7))
			var face: float = q.face_m * (1.0 if detail else 6.0)
			var step := smoothstep(-face * 0.5, face * 0.5, local.y + wob)
			var back := 1.0 - smoothstep(q.back_m * 0.6, q.back_m, local.y)
			var along := 1.0 - smoothstep(0.7 * half, half, absf(local.x))
			raise = q.rise_st * ST * step * back * along
		&"amphitheatre":
			# A horseshoe cut into rising ground, longer across than deep, open
			# over well over half its circle (a near-closed ring read as a crater).
			var e := Vector2(local.x * 1.35, local.y)
			var re := e.length()
			var radius: float = q.radius_m * (0.8 + 0.4 * _lobes(local, salt))
			var ring := exp(-pow((re - radius) / (q.thickness * q.radius_m), 2.0))
			var mouth := smoothstep(-0.55, 0.05, local.x / maxf(r, 1.0))
			raise = q.wall_st * ST * ring * (1.0 - 0.9 * mouth)
	var env := _envelope(r, footprint_radius(kind, q))
	return Vector2(maxf(raise, 0.0) * env, maxf(cut, 0.0) * env)


## Maps t in [0, 1] onto [0, 1] with zero slope at 0 (a rounded tip of radius e).
static func _round01(t: float, e: float) -> float:
	return (sqrt(t * t + e * e) - e) / (sqrt(1.0 + e * e) - e)


static func _cluster(q: Dictionary, local: Vector2, salt: int, detail: bool) -> float:
	var height: float = q.height_st * ST
	var summits := cluster_summits(q, salt)
	var heights: Array[float] = []
	for i in summits.size():
		heights.append(height * (1.0 if i == 0 else 0.75 + 0.25 * _h(salt, i, 13)))
	var cone_r: float = 0.55 * q.radius_m
	var best := 0.0
	for i in summits.size():
		var d := local.distance_to(summits[i])
		if d < cone_r:
			var t := d / cone_r if detail else _round01(d / cone_r, 0.25)
			best = maxf(best, heights[i] * pow(1.0 - t, 1.5))
	var width: float = 0.22 * q.radius_m
	var pairs := summits.size() if summits.size() > 2 else 1
	for i in pairs:
		var a := summits[i]
		var b := summits[(i + 1) % summits.size()]
		var ab := b - a
		var t := clampf((local - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := local.distance_to(a + ab * t)
		if d < width:
			var crest: float = lerpf(heights[i], heights[(i + 1) % summits.size()], t) \
				* (1.0 - (1.0 - q.saddle) * sin(PI * t))
			var w := d / width if detail else _round01(d / width, 0.3)
			best = maxf(best, crest * pow(1.0 - w, 1.4))
	# A broad shoulder so the cluster stands on one massif.
	var apron := 0.25 * height * pow(maxf(0.0, 1.0 - local.length() / q.radius_m), 2.0)
	return maxf(best, apron)


static func _ridge(q: Dictionary, local: Vector2, salt: int, detail: bool) -> float:
	var half: float = q.half_length_m
	var u := local.x
	var v: float = local.y + (1.0 if salt % 2 == 0 else -1.0) * 0.6 * q.half_width_m * sin(u / half * PI * 1.3)
	var along := 1.0 - smoothstep(0.7 * half, half, absf(u))
	var pass_u: float = q.pass_at * half
	var gap: float = 1.0 - q.pass_depth * exp(-pow((u - pass_u) / (0.18 * half), 2.0))
	var crest: float = q.height_st * ST * along * gap * (0.85 + 0.15 * cos(u / half * PI))
	var t: float = minf(absf(v) / q.half_width_m, 1.0)
	var across := 1.0 - (t if detail else _round01(t, 0.3))
	return crest * pow(across, 1.3)


static func _mesa(q: Dictionary, local: Vector2, salt: int, detail: bool) -> float:
	var height: float = q.height_st * ST
	var top := height * _blob_height(q, local, salt, PROFILE_PLATEAU, detail)
	# Apron: a low talus skirt just outside the cliff (the blob outline).
	var t := _blob_t(q, local, salt)
	var apron: float = q.apron * height * (1.0 - smoothstep(1.0, 1.0 + 40.0 / (0.6 * q.radius_m), t))
	var h := maxf(top, apron)
	if q.tier >= 0.5:
		# A second tier toward one end of the core lobe, at half its size (a
		# concentric tier read as a crater rim).
		var c := _components(q, salt)
		var d := (local - Vector2(c[0], c[1])).rotated(-c[4]) - Vector2((0.3 if salt % 3 == 0 else -0.3) * c[2], 0.0)
		var tt := Vector2(d.x / (0.5 * c[2]), d.y / (0.5 * c[3])).length()
		var rim := 5.0 if detail else 0.8 * 0.5 * c[3]
		h += q.tier_st * ST * (1.0 - smoothstep(1.0 - rim / (0.5 * c[3]), 1.0, tt))
	return h


## Flat-topped buttes (sharp; domes in the smooth field) or rounded karst
## towers (steep sides; domes in the smooth field) strung along the grain on a
## shared bench, the remnant of the plateau they were cut from (owner review
## 2026-10-03: lone pimples read as a lunar landscape).
static func _scatter(q: Dictionary, local: Vector2, salt: int, count: float, each_r: float,
		reach: float, flat: bool, detail: bool = true) -> float:
	var height: float = q.height_st * ST
	var long: float = reach * q.radius_m
	var e0 := local / Vector2(long + each_r, 0.35 * long + 1.2 * each_r)
	e0 += Vector2(ReliefPrimitives.vnoise(local, salt + 63, 0.5 * long), ReliefPrimitives.vnoise(local, salt + 64, 0.5 * long)) * 0.15
	var bench_t := e0.length()
	# Buttes stand on a flat bench with a sharp edge (a plateau remnant);
	# karst towers rise from a rounded swell (a flat-edged ring read as a crater).
	var bench_lo := (0.7 if detail else 0.4) if flat else 0.0
	var best: float = q.plinth * height * (1.0 - smoothstep(bench_lo, 1.0, bench_t))
	for i in clampi(roundi(count), 1, 8):
		var at := Vector2((_h(salt, i, 21) - 0.5) * 2.0 * long, (_h(salt, i, 22) - 0.5) * 0.6 * long)
		var radius := each_r * (0.75 + 0.5 * _h(salt, i, 23))
		var hi := height * (0.7 + 0.3 * _h(salt, i, 24))
		var e := (local - at).rotated(-_h(salt, i, 25) * TAU)
		var t := Vector2(e.x, e.y / (0.55 + 0.45 * _h(salt, i, 26))).length() / radius
		var h: float
		if not detail:
			h = hi * pow(maxf(0.0, 1.0 - t * t), 2.0)
		elif flat:
			var top := hi * (1.0 - smoothstep(1.0 - 5.0 / radius, 1.0, t))
			var apron := 0.2 * hi * (1.0 - smoothstep(1.0, 1.0 + 20.0 / radius, t))
			h = maxf(top, apron)
		else:
			h = hi * (1.0 - smoothstep(0.45, 1.0, t))
		best = maxf(best, h)
	return best


# --- Links (owner review 2026-10-03: features should "connect to other
# things"). Each raised feature (hill, ridge, peak cluster, mesa, butte group,
# tower cluster) may join its best-placed raised neighbour in the 8 cells round
# it by a saddle ridge, or a flat bench between plateau forms; each valley or
# basin may join a neighbouring one by a channel. "Best placed" prefers short
# links along the grain, so linked features run into ranges and valley chains.
# A link is owned by the cell holding its midpoint and its footprint radius is
# at most LINK_MAX_RADIUS (< one cell), so the 3x3 cells round a point still
# hold every link that reaches it.

const LINK_MAX_RADIUS := 240.0
const LINK_FIRST := 0.95
const LINK_SECOND := 0.6
const _RAISED := [&"hill", &"ridge", &"peak_cluster", &"mesa", &"butte_group", &"tower_cluster"]
const _HOLLOW := [&"valley", &"basin"]
const _BENCHED := [&"mesa", &"butte_group", &"tower_cluster"]


static func _link_class(kind: StringName) -> int:
	if kind in _RAISED:
		return 1
	if kind in _HOLLOW:
		return -1
	return 0


## Where a link leaves feature f toward a point: on a ridge crest or valley
## floor line, else part way out from the centre.
static func _endpoint(f: Dictionary, toward: Vector2) -> Vector2:
	var q: Dictionary = f.params
	var dir := Vector2.from_angle(f.rot)
	match f.kind:
		&"ridge":
			var half: float = q.half_length_m
			var u := clampf((toward - f.pos).dot(dir), -0.6 * half, 0.6 * half)
			var v: float = -(1.0 if int(f.salt) % 2 == 0 else -1.0) * 0.6 * q.half_width_m * sin(u / half * PI * 1.3)
			return f.pos + Vector2(u, v).rotated(f.rot)
		&"valley":
			var half: float = q.half_length_m
			var u := clampf((toward - f.pos).dot(dir), -0.55 * half, 0.55 * half)
			return f.pos + Vector2(u, 0.7 * q.floor_half_m * sin(u / half * PI)).rotated(f.rot)
	# From inside the high (or deep) core, so the link rises out of it.
	return f.pos + (toward - f.pos).normalized() * 0.15 * q.radius_m


## Height (raised) or depth (hollow) a link carries from f, before its fraction.
static func _top(f: Dictionary) -> float:
	var q: Dictionary = f.params
	if f.kind in _HOLLOW:
		return q.depth_st * ST
	if f.kind in [&"butte_group", &"tower_cluster"]:
		return q.plinth * q.height_st * ST
	return q.height_st * ST


static func _link_width(f: Dictionary) -> float:
	var q: Dictionary = f.params
	match f.kind:
		&"ridge":
			return 0.9 * q.half_width_m
		&"valley":
			return q.floor_half_m + 0.6 * q.side_m
		&"basin":
			return clampf(0.2 * q.radius_m, 35.0, 80.0)
	return clampf(0.28 * q.radius_m, 50.0, 100.0)


## The link between two features (in canonical cell order), or {} when it
## would not fit (too long) or is not needed (the features already touch).
static func _link_geometry(seed: int, fa: Dictionary, fb: Dictionary) -> Dictionary:
	var ca: Vector2i = fa.cell
	var cb: Vector2i = fb.cell
	if cb.x < ca.x or (cb.x == ca.x and cb.y < ca.y):
		var t := fa
		fa = fb
		fb = t
	ca = fa.cell
	cb = fb.cell
	var a := _endpoint(fa, fb.pos)
	var b := _endpoint(fb, fa.pos)
	var length := a.distance_to(b)
	if length < 24.0:
		return {}
	var salt := int(Helper._cell_hash01(seed + 1630 + cb.x * 7919 + cb.y * 104729, ca.x, ca.y) * 1000000.0)
	var wa := _link_width(fa)
	var wb := _link_width(fb)
	var amp := (_h(salt, 0, 3) - 0.5) * 0.3 * length
	var radius := 0.5 * length + maxf(wa, wb) + absf(amp)
	if radius > LINK_MAX_RADIUS:
		return {}
	var raised := _link_class(fa.kind) > 0
	var bench: bool = raised and fa.kind in _BENCHED and fb.kind in _BENCHED
	var frac := 0.45 + 0.2 * _h(salt, 0, 1)
	var ha := frac * _top(fa)
	var hb := frac * _top(fb)
	if bench:
		ha = 0.55 * minf(_top(fa), _top(fb))
		hb = ha
	return {"pos": (a + b) * 0.5, "a": a, "b": b, "radius": radius, "raise": raised, "bench": bench,
		"ha": ha, "hb": hb, "wa": wa, "wb": wb, "sag": 0.15 + 0.25 * _h(salt, 0, 2), "amp": amp}


## The neighbour cells this cell's feature reaches out to (at most two).
static func _chosen(seed: int, cell: Vector2i) -> Array[Vector2i]:
	return _memo(seed, cell, _CHOSEN, func() -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		var f := _main(seed, cell)
		if f.is_empty() or _link_class(f.kind) == 0:
			return out
		var g := grain(seed, f.pos)
		var options: Array = []
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var other := cell + Vector2i(dx, dz)
				var o := _main(seed, other)
				if other == cell or o.is_empty() or _link_class(o.kind) != _link_class(f.kind):
					continue
				if _link_geometry(seed, f, o).is_empty():
					continue
				var to: Vector2 = o.pos - f.pos
				options.append([to.length() * (1.0 + 0.7 * absf(sin(to.angle() - g))), other])
		options.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		if options.size() > 0 and _hash(seed, cell, 1631) < LINK_FIRST:
			out.append(options[0][1])
		if options.size() > 1 and _hash(seed, cell, 1632) < LINK_SECOND:
			out.append(options[1][1])
		return out)


## Links whose midpoint lies in this cell.
static func _links_owned(seed: int, cell: Vector2i) -> Array:
	return _memo(seed, cell, _LINKS, func() -> Array:
		var out: Array = []
		var seen := {}
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var ca := cell + Vector2i(dx, dz)
				for cb: Vector2i in _chosen(seed, ca):
					var key := Vector4i(ca.x, ca.y, cb.x, cb.y)
					if ca.x > cb.x or (ca.x == cb.x and ca.y > cb.y):
						key = Vector4i(cb.x, cb.y, ca.x, ca.y)
					if seen.has(key):
						continue
					seen[key] = true
					var link := _link_geometry(seed, _main(seed, ca), _main(seed, cb))
					if not link.is_empty() and Vector2i(floori(link.pos.x / CELL), floori(link.pos.y / CELL)) == cell:
						out.append(link)
		return out)


## Height (raised link) or depth (hollow link) in metres at world p: a
## meandering capsule from a to b. Raised: a saddle ridge sagging between its
## ends, or a flat bench between plateau forms; hollow: a channel.
static func link_shape(link: Dictionary, p: Vector2, detail: bool = true) -> float:
	var ab: Vector2 = link.b - link.a
	var length := ab.length()
	var dir := ab / length
	var rel: Vector2 = p - link.a
	var u := rel.dot(dir)
	var t := clampf(u / length, 0.0, 1.0)
	var v: float = rel.dot(dir.orthogonal()) - link.amp * sin(PI * t)
	var du := -u if u < 0.0 else maxf(0.0, u - length)
	var d := sqrt(du * du + v * v)
	var w: float = lerpf(link.wa, link.wb, t)
	if d >= w:
		return 0.0
	var x := d / w
	var level: float = lerpf(link.ha, link.hb, t)
	if not link.raise:
		return level * (1.0 - 0.25 * sin(PI * t)) * (1.0 - smoothstep(0.35, 1.0, x))
	if link.bench:
		return level * (1.0 - smoothstep(0.75 if detail else 0.3, 1.0, x))
	return level * (1.0 - link.sag * sin(PI * t)) * pow(1.0 - (x if detail else _round01(x, 0.3)), 1.3)


## Battle-scale relief carried by the smooth river field as well as the detailed
## terrain. Connected crests make three summits and two passes; divided hollows
## retain a cross-valley bridge and offset high ground. This tier adds local
## decisions without shrinking the continental/mountain features.
const LOCAL_CELL := 192.0
const LOCAL_RADIUS := 148.0
const LOCAL_HEIGHT_MIN := 16.0
const LOCAL_HEIGHT_MAX := 32.0
const _LOCAL := 5
const LOCAL_CREST_HEIGHTS := [.84, 1.0, .9]

static func local_candidate(seed_value: int, cell: Vector2i) -> Dictionary:
	return _memo(seed_value, cell, _LOCAL,
		func() -> Dictionary: return _local_draw(seed_value, cell))


static func _local_draw(seed_value: int, cell: Vector2i) -> Dictionary:
	var h := func(salt: int) -> float: return Helper._cell_hash01(seed_value + salt, cell.x, cell.y)
	if h.call(2310) > .82:
		return {}
	var pos: Vector2 = (Vector2(cell) + Vector2(.25 + .5 * h.call(2311),
		.25 + .5 * h.call(2312))) * LOCAL_CELL
	if pos.length() - LOCAL_RADIUS < SPAWN_CLEAR_M:
		return {}
	var bend: float = (h.call(2316) - .5) * 48
	return {
		"nodes": PackedVector2Array([Vector2(-64, -bend * .4), Vector2(0, bend), Vector2(64, -bend * .6)]),
		"pos": pos, "angle": grain(seed_value, pos) + (h.call(2313) - .5) * .8,
		"height": lerpf(LOCAL_HEIGHT_MIN, LOCAL_HEIGHT_MAX, h.call(2314)),
		"hollow": h.call(2315) < .4, "offset": (h.call(2317) - .5) * 35,
	}


static func _local_dome(p: Vector2, a: float, b: float) -> float:
	var t := Vector2(p.x / a, p.y / b).length_squared()
	return pow(maxf(0, 1 - t), 2)


static func local_shape(f: Dictionary, p: Vector2) -> float:
	var q: Vector2 = (p - f.pos).rotated(-f.angle)
	if q.length() >= LOCAL_RADIUS:
		return 0
	if f.hollow:
		# A connected hollow interrupted by a cross-valley bridge and two
		# offset remnants. All margins have zero height and slope.
		var bowl := _local_dome(q, 132, 78)
		var bridge := 1 - smoothstep(9, 27, absf(q.x - f.offset))
		var island := maxf(_local_dome(q - Vector2(-48, 27), 27, 23),
			_local_dome(q - Vector2(49, -26), 30, 24))
		return -f.height * bowl * (1 - maxf(bridge, island))
	var nodes: PackedVector2Array = f.nodes
	var heights: Array = LOCAL_CREST_HEIGHTS
	var result := 0.0
	for i in 3:
		result = maxf(result, heights[i] * _local_dome(q - nodes[i], 50, 43))
	for i in 2:
		var a := nodes[i]
		var b := nodes[i + 1]
		var axis := b - a
		var t := clampf((q - a).dot(axis) / axis.length_squared(), 0, 1)
		var distance := q.distance_to(a + axis * t)
		var crest := lerpf(heights[i], heights[i + 1], t) * (1 - .42 * sin(PI * t) * sin(PI * t))
		result = maxf(result, crest * pow(maxf(0, 1 - pow(distance / 43, 2)), 2))
	return f.height * result


static func local_relief(seed_value: int, p: Vector2) -> float:
	var cell := Vector2i((p / LOCAL_CELL).floor())
	var raised := 0.0
	var cut := 0.0
	for z in range(-1, 2):
		for x in range(-1, 2):
			var f := local_candidate(seed_value, cell + Vector2i(x, z))
			if f.is_empty():
				continue
			var value := local_shape(f, p)
			raised = _union(raised, maxf(0, value))
			cut = _union(cut, maxf(0, -value))
	return raised - cut
