class_name LandformSetpieces
extends RefCounted

## Sparse, individually placed landforms (spec 2026-10-02 §6). One candidate per
## CELL; its kind is drawn from the region archetype's set-piece densities.
## Matern-II priority over the 5x5 neighbouring cells rejects every candidate
## whose footprint meets a higher-priority one, so admitted footprints never
## overlap and composition is a plain sum (no averaging of shapes). Footprint
## radius <= MAX_RADIUS keeps both the 5x5 rejection and the 3x3 evaluation
## exact. Shapes are in a local frame: x along the piece, y across it.

const CELL := 512.0
const MAX_RADIUS := 480.0
const FEATHER := 48.0
const ST := TerrainRegimeCatalog.STOREY
const CACHE_LIMIT := 4096
## No set-piece footprint comes closer than this to the world origin.
const SPAWN_CLEAR_M := 400.0

static var _candidates: Dictionary = {}   # seed -> {cell: Dictionary}
static var _admitted: Dictionary = {}
static var _keys: Array = []
static var _cursor := 0
static var _mutex := Mutex.new()


static func clear_caches() -> void:
	_mutex.lock()
	_candidates.clear()
	_admitted.clear()
	_keys.clear()
	_cursor = 0
	_mutex.unlock()


static func _cached(store: Dictionary, seed: int, cell: Vector2i):
	_mutex.lock()
	var value = (store.get(seed, {}) as Dictionary).get(cell)
	_mutex.unlock()
	return value


static func _store(store: Dictionary, seed: int, cell: Vector2i, value: Dictionary) -> Dictionary:
	_mutex.lock()
	var per_seed: Dictionary = store.get(seed, {})
	var existing = per_seed.get(cell)
	if existing != null:
		_mutex.unlock()
		return existing
	if _keys.size() == CACHE_LIMIT:
		var old: Array = _keys[_cursor]
		(_candidates.get(old[0], {}) as Dictionary).erase(old[1])
		(_admitted.get(old[0], {}) as Dictionary).erase(old[1])
		_keys[_cursor] = [seed, cell]
		_cursor = (_cursor + 1) % CACHE_LIMIT
	else:
		_keys.append([seed, cell])
	per_seed[cell] = value
	store[seed] = per_seed
	_mutex.unlock()
	return value


static func _candidate(seed: int, cell: Vector2i) -> Dictionary:
	var cached = _cached(_candidates, seed, cell)
	if cached != null:
		return cached
	var pos := (Vector2(cell) + Vector2(
		0.15 + 0.7 * Helper._cell_hash01(seed + 1501, cell.x, cell.y),
		0.15 + 0.7 * Helper._cell_hash01(seed + 1502, cell.x, cell.y))) * CELL
	var densities: Dictionary = TerrainRegimeCatalog.SETPIECE_DENSITY[TerrainRegimeField.region_at(seed, pos).archetype]
	var u := Helper._cell_hash01(seed + 1503, cell.x, cell.y)
	var kind: StringName = &""
	for k: StringName in densities:
		u -= float(densities[k])
		if u < 0.0:
			kind = k
			break
	var value := {}
	if kind != &"":
		var params := TerrainRegimeCatalog.draw(seed, cell, 1510, TerrainRegimeCatalog.SETPIECE_PARAMS[kind], 1.0)
		value = {"kind": kind, "pos": pos, "params": params, "cell": cell,
			"rot": Helper._cell_hash01(seed + 1504, cell.x, cell.y) * TAU,
			"priority": Helper._cell_hash01(seed + 1505, cell.x, cell.y),
			"radius": footprint_radius(kind, params)}
		if pos.length() - float(value.radius) < SPAWN_CLEAR_M:
			value = {}
	return _store(_candidates, seed, cell, value)


static func _outranks(a: Dictionary, b: Dictionary) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.cell.x < b.cell.x or (a.cell.x == b.cell.x and a.cell.y < b.cell.y)


static func admitted(seed: int, cell: Vector2i) -> Dictionary:
	var cached = _cached(_admitted, seed, cell)
	if cached != null:
		return cached
	var c := _candidate(seed, cell)
	var value := c
	if not c.is_empty():
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				if dx == 0 and dz == 0:
					continue
				var o := _candidate(seed, cell + Vector2i(dx, dz))
				if not o.is_empty() and _outranks(o, c) \
						and c.pos.distance_to(o.pos) < c.radius + o.radius:
					value = {}
	return _store(_admitted, seed, cell, value)


## (delta metres, mask) at p from the one admitted set piece covering it.
static func sample(seed: int, p: Vector2) -> Vector2:
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var a := admitted(seed, c + Vector2i(dx, dz))
			if a.is_empty() or p.distance_to(a.pos) >= a.radius:
				continue
			return shape(a.kind, a.params, (p - a.pos).rotated(-a.rot), a.priority * TAU)
	return Vector2.ZERO


static func setpieces_in_rect(seed: int, rect: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lo := Vector2i(floori(rect.position.x / CELL) - 1, floori(rect.position.y / CELL) - 1)
	var hi := Vector2i(floori(rect.end.x / CELL) + 1, floori(rect.end.y / CELL) + 1)
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var a := admitted(seed, Vector2i(x, z))
			if not a.is_empty() and rect.grow(a.radius).has_point(a.pos):
				out.append(a)
	return out


static func footprint_radius(kind: StringName, q: Dictionary) -> float:
	match kind:
		&"escarpment", &"big_ridge", &"hanging_valley":
			return q.length_m * 0.5 + FEATHER * 0.5
		&"amphitheatre":
			return q.radius_m * 1.35 + FEATHER
		&"mesa":
			return q.radius_m + FEATHER
		&"cleft":
			return maxf(q.length_m * 0.5, q.slot_m * 0.5 + q.shoulder_m + FEATHER) + FEATHER * 0.5
	return 0.0


## Envelope reaching exactly 0 at the footprint radius.
static func _envelope(r: float, radius: float) -> float:
	return 1.0 - smoothstep(radius - FEATHER, radius, r)


## Fade to 0 over the last 2 FEATHER of a half-length.
static func _along(u: float, half: float) -> float:
	return 1.0 - smoothstep(half - 2.0 * FEATHER, half, absf(u))


static func shape(kind: StringName, q: Dictionary, local: Vector2, phase: float) -> Vector2:
	var env := _envelope(local.length(), footprint_radius(kind, q))
	var delta := 0.0
	var mask := 0.0
	match kind:
		&"escarpment":
			var half: float = q.length_m * 0.5
			var v: float = local.y + sin(local.x / q.length_m * TAU * 1.5 + phase) * q.face_m * 1.5
			var step: float = smoothstep(-q.face_m * 0.5, q.face_m * 0.5, v)
			var across: float = 1.0 - smoothstep(q.back_m * 0.5, q.back_m, absf(local.y))
			var along := _along(local.x, half)
			delta = (step - 0.5) * q.rise_st * ST * across * along
			mask = across * along
		&"amphitheatre":
			var r := local.length()
			var radius: float = q.radius_m
			var ring := exp(-pow((r - radius) / (0.25 * radius), 2.0))
			var mouth := smoothstep(-0.2, 0.5, local.x / maxf(r, 1.0))
			delta = q.wall_st * ST * ring * (1.0 - 0.9 * mouth)
			mask = 1.0 - smoothstep(radius, radius * 1.35, r)
		&"mesa":
			var r := local.length()
			delta = q.height_st * ST * (1.0 - smoothstep(q.radius_m - q.face_m, q.radius_m, r))
			mask = 1.0 - smoothstep(q.radius_m, q.radius_m + FEATHER, r)
		&"big_ridge":
			var across: float = exp(-pow(local.y / q.half_width_m, 2.0))
			var saddle: float = 1.0 - q.pass_frac * exp(-pow(local.x / (0.12 * q.length_m), 2.0))
			var along: float = _along(local.x, q.length_m * 0.5)
			delta = q.height_st * ST * across * saddle * along
			mask = smoothstep(0.0, 0.3, across) * along
		&"cleft":
			var a: float = absf(local.y + sin(local.x / q.length_m * TAU + phase) * q.slot_m)
			var inner: float = q.slot_m * 0.5
			var outer: float = inner + q.shoulder_m
			var shoulders := smoothstep(inner, inner + 16.0, a) * (1.0 - smoothstep(outer, outer + FEATHER, a))
			var along: float = _along(local.x, q.length_m * 0.5)
			delta = q.shoulder_st * ST * shoulders * along
			mask = (1.0 - smoothstep(outer, outer + FEATHER, a)) * along
		&"hanging_valley":
			var half: float = q.length_m * 0.5
			var along := _along(local.x, half)
			var trunk: float = (1.0 - smoothstep(q.trunk_half_m, q.trunk_half_m + 32.0, absf(local.y))) * along
			var trib: float = (1.0 - smoothstep(q.trib_half_m, q.trib_half_m + 24.0, absf(local.x))) \
				* smoothstep(q.trunk_half_m, q.trunk_half_m + 8.0, local.y) * _along(local.y, half)
			var trib_depth: float = maxf(q.trunk_st - q.lip_st, 1.0)
			delta = -q.trunk_st * ST * trunk - trib_depth * ST * trib * (1.0 - trunk)
			mask = maxf(trunk, trib)
	return Vector2(delta * env, clampf(mask, 0.0, 1.0) * env)
