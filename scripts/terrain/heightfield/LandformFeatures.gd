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

const CELL := 320.0
const MAX_RADIUS := 368.0
const NORM := 6.0
const ST := TerrainRegimeCatalog.STOREY
## No footprint comes closer than this to the world origin (spawn clearing).
const SPAWN_CLEAR_M := 300.0
const CACHE_LIMIT := 8192

static var _cache: Dictionary = {}   # seed -> {cell: Dictionary}
static var _keys: Array = []
static var _cursor := 0
static var _mutex := Mutex.new()


static func clear_caches() -> void:
	_mutex.lock()
	_cache.clear()
	_keys.clear()
	_cursor = 0
	_mutex.unlock()


static func _hash(seed: int, cell: Vector2i, salt: int) -> float:
	return Helper._cell_hash01(seed + salt, cell.x, cell.y)


## The feature hosted by a cell, or {} if none.
static func candidate(seed: int, cell: Vector2i) -> Dictionary:
	_mutex.lock()
	var cached = (_cache.get(seed, {}) as Dictionary).get(cell)
	_mutex.unlock()
	if cached != null:
		return cached
	var value := _compute(seed, cell)
	_mutex.lock()
	var per_seed: Dictionary = _cache.get(seed, {})
	if not per_seed.has(cell):
		if _keys.size() == CACHE_LIMIT:
			var old: Array = _keys[_cursor]
			(_cache.get(old[0], {}) as Dictionary).erase(old[1])
			_keys[_cursor] = [seed, cell]
			_cursor = (_cursor + 1) % CACHE_LIMIT
		else:
			_keys.append([seed, cell])
		per_seed[cell] = value
		_cache[seed] = per_seed
	value = per_seed[cell]
	_mutex.unlock()
	return value


static func _compute(seed: int, cell: Vector2i) -> Dictionary:
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
	var scale := lerpf(float(range_[0]), float(range_[1]), _hash(seed, cell, 1605))
	if region.get("calm", false):
		scale *= 0.6
	for name: String in params:
		if name.ends_with("_st"):
			params[name] = float(params[name]) * scale
	var radius := footprint_radius(kind, params)
	if pos.length() - radius < SPAWN_CLEAR_M:
		return {}
	return {"kind": kind, "pos": pos, "params": params, "radius": radius, "cell": cell,
		"rot": _hash(seed, cell, 1606) * TAU, "salt": int(_hash(seed, cell, 1607) * 1000000.0)}


## (raise m, cut m) at p from every feature reaching it.
static func sample(seed: int, p: Vector2, detail: bool = true) -> Vector2:
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var raise := 0.0
	var cut := 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var f := candidate(seed, c + Vector2i(dx, dz))
			if f.is_empty() or p.distance_to(f.pos) >= f.radius:
				continue
			var v := shape(f.kind, f.params, (p - f.pos).rotated(-f.rot), f.salt, detail)
			raise = _union(raise, v.x)
			cut = _union(cut, v.y)
	return Vector2(raise, cut)


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
		&"hill", &"peak", &"peak_cluster", &"butte_group", &"tower_cluster", &"basin":
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
	return ReliefPrimitives.vnoise01(dir * 2.5, salt, 1.0)


static func _h(salt: int, i: int, k: int) -> float:
	return Helper._cell_hash01(salt + k, i, 0)


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
			var lq := Vector2(local.x, local.y / q.aspect)
			var t: float = lq.length() / (q.radius_m * (0.85 + 0.15 * _lobes(local, salt)))
			if t < 1.0:
				raise = q.height_st * ST * pow(1.0 - t * t, 2.0)
		&"peak":
			var t: float = r / (q.radius_m * (0.85 + 0.15 * _lobes(local, salt)))
			if t < 1.0:
				# Rounded summit, normalised so the profile still ends at exactly t = 1.
				var ts: float = (sqrt(t * t + 0.0025) - 0.05) / (sqrt(1.0025) - 0.05)
				var spur := 1.0 + 0.18 * (_lobes(local * 3.0, salt + 1) - 0.5) * 4.0 * t * (1.0 - t)
				raise = q.height_st * ST * pow(1.0 - clampf(ts, 0.0, 1.0), 1.7) * spur
		&"peak_cluster":
			raise = _cluster(q, local, salt, detail)
		&"ridge":
			raise = _ridge(q, local, salt, detail)
		&"mesa":
			raise = _mesa(q, local, salt, detail)
		&"butte_group":
			raise = _scatter(q, local, salt, q.buttes, q.butte_radius_m, 0.6, true, detail)
		&"tower_cluster":
			raise = _scatter(q, local, salt, q.towers, q.tower_radius_m, 0.65, false, detail)
		&"basin":
			var rw: float = r / (0.88 + 0.12 * _lobes(local, salt))
			var depth: float = q.depth_st * ST
			var floor_r: float = q.floor * q.radius_m
			cut = depth * (1.0 - smoothstep(floor_r, 0.88 * q.radius_m, rw))
			raise = q.rim_st * ST * exp(-pow((rw - 0.9 * q.radius_m) / (0.08 * q.radius_m), 2.0))
			if q.island >= 0.4:
				# The island stands island_st above the surrounding ground: a
				# sheer-sided mesa or a rounded hill, by the feature's hash.
				var ir: float = q.island_radius * floor_r
				var t := r / ir
				var profile := 1.0 - smoothstep(0.85, 1.0, t) if detail and salt % 2 == 0 \
					else pow(maxf(0.0, 1.0 - t * t), 1.5)
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
			var radius: float = q.radius_m
			var ring := exp(-pow((r - radius) / (q.thickness * radius), 2.0))
			var mouth := smoothstep(-0.2, 0.5, local.x / maxf(r, 1.0))
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
	var r := local.length()
	var height: float = q.height_st * ST
	var edge: float = q.radius_m * (1.0 - q.wobble * _lobes(local, salt))
	var rim := 6.0 if detail else 0.6 * edge
	var top := height * (1.0 - smoothstep(edge - rim, edge, r))
	var apron: float = q.apron * height * (1.0 - smoothstep(edge, edge + 40.0, r))
	var h := maxf(top, apron)
	if q.tier >= 0.5:
		var tier_edge := 0.5 * edge
		h += q.tier_st * ST * (1.0 - smoothstep(tier_edge - (5.0 if detail else 0.8 * tier_edge), tier_edge, r))
	return h


## Small flat-topped buttes (sharp; domes in the smooth field) or rounded karst
## towers (steep sides; domes in the smooth field) scattered in a disc.
static func _scatter(q: Dictionary, local: Vector2, salt: int, count: float, each_r: float,
		reach: float, flat: bool, detail: bool = true) -> float:
	var height: float = q.height_st * ST
	var best := 0.0
	for i in clampi(roundi(count), 1, 8):
		var at: Vector2 = Vector2.from_angle(_h(salt, i, 21) * TAU) * sqrt(_h(salt, i, 22)) * reach * q.radius_m
		var radius := each_r * (0.75 + 0.5 * _h(salt, i, 23))
		var hi := height * (0.7 + 0.3 * _h(salt, i, 24))
		var t := local.distance_to(at) / radius
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
