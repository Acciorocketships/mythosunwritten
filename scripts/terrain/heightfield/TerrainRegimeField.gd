class_name TerrainRegimeField
extends RefCounted

## Terrain regime layer (spec 2026-10-02 §3). Regions are jittered Voronoi cells
## (one site per REGION_CELL, offsets in [0.2, 0.8], 5x5 search: exact F1/F2).
## Each region holds one archetype from TerrainRegimeCatalog chosen with the
## visual-biome bias at its site, and sampled parameters. Relief cross-fades
## only inside a BAND_M border band (warped so borders never look straight);
## base elevation is a smootherstep-bilinear field on a BASE_NODE grid so
## regions with different base levels never meet at a wall.

const REGION_CELL := 640.0
const BAND_M := 120.0
const BORDER_WARP_M := 60.0
const BORDER_WARP_WL := 240.0
const BASE_NODE := 320.0
const MERGE_CHANCE := 0.2
## Regions whose site lies this close to the world origin are calm rolling
## downs (base <= 2 storeys, relief <= 1 storey) and never merge, so the spawn
## clearing opens onto gentle meadow on every seed. A point 452 m from the
## origin (the base nodes the spawn ring interpolates) always has its nearest
## site within this radius.
const SPAWN_CALM_M := 1200.0
const CACHE_LIMIT := 4096

static var _force: StringName = &""
static var _regions: Dictionary = {}     # seed -> {Vector2i: Dictionary}
static var _region_keys: Array = []
static var _region_cursor := 0
static var _nodes: Dictionary = {}       # seed -> {Vector2i: float}
static var _hoods: Dictionary = {}       # seed -> {Vector2i: PackedVector2Array}
static var _hood_keys: Array = []
static var _hood_cursor := 0
static var _node_keys: Array = []
static var _node_cursor := 0
static var _mutex := Mutex.new()


static func set_force_archetype(a: StringName) -> void:
	_force = a
	clear_caches()
	LandformSetpieces.clear_caches()
	LandformFeatures.clear_caches()


static func clear_caches() -> void:
	_mutex.lock()
	_regions.clear()
	_region_keys.clear()
	_region_cursor = 0
	_nodes.clear()
	_node_keys.clear()
	_node_cursor = 0
	_hoods.clear()
	_hood_keys.clear()
	_hood_cursor = 0
	_mutex.unlock()


static func site_of(seed: int, cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(
		0.2 + 0.6 * Helper._cell_hash01(seed + 1401, cell.x, cell.y),
		0.2 + 0.6 * Helper._cell_hash01(seed + 1402, cell.x, cell.y))) * REGION_CELL


## The region's own draw, before territory merging.
static func _own_region(seed: int, cell: Vector2i) -> Dictionary:
	var site := site_of(seed, cell)
	var calm := _force == &"" and site.length() < SPAWN_CALM_M
	var archetype := &"rolling_downs" if calm else _force
	if archetype == &"":
		var weights := Helper.biome_weights5(Vector3(site.x, 0.0, site.y), seed)
		archetype = TerrainRegimeCatalog.choose(weights, Helper._cell_hash01(seed + 1403, cell.x, cell.y),
			TerrainField.elevation01(seed, site))
	var scale := lerpf(0.6, 1.7, Helper._cell_hash01(seed + 1404, cell.x, cell.y))
	var params := TerrainRegimeCatalog.draw(seed, cell, 1410, TerrainRegimeCatalog.PARAMS[archetype], scale)
	if calm:
		params.base_level_st = minf(params.base_level_st, 2.0)
		params.relief_st = minf(params.relief_st, 1.0)
	return {
		"archetype": archetype, "params": params, "scale": scale, "site": site, "cell": cell,
		"calm": calm,
		"base_m": float(params.base_level_st) * TerrainRegimeCatalog.STOREY,
		"rot": Helper._cell_hash01(seed + 1405, cell.x, cell.y) * TAU,
		"salt": int(Helper._cell_hash01(seed + 1406, cell.x, cell.y) * 1000000.0),
	}


## Region record for a Voronoi cell. With MERGE_CHANCE a cell adopts the own
## draw of its west or north neighbour (never recursively), so some territories
## span two cells.
static func region(seed: int, cell: Vector2i) -> Dictionary:
	_mutex.lock()
	var per_seed: Dictionary = _regions.get(seed, {})
	var cached = per_seed.get(cell)
	_mutex.unlock()
	if cached != null:
		return cached
	var donor := cell
	if site_of(seed, cell).length() >= SPAWN_CALM_M \
			and Helper._cell_hash01(seed + 1407, cell.x, cell.y) < MERGE_CHANCE:
		donor += Vector2i(-1, 0) if Helper._cell_hash01(seed + 1408, cell.x, cell.y) < 0.5 else Vector2i(0, -1)
	var value := _own_region(seed, donor)
	_mutex.lock()
	per_seed = _regions.get(seed, {})
	cached = per_seed.get(cell)
	if cached == null:
		if _region_keys.size() == CACHE_LIMIT:
			var old: Array = _region_keys[_region_cursor]
			(_regions.get(old[0], {}) as Dictionary).erase(old[1])
			_region_keys[_region_cursor] = [seed, cell]
			_region_cursor = (_region_cursor + 1) % CACHE_LIMIT
		else:
			_region_keys.append([seed, cell])
		per_seed[cell] = value
		_regions[seed] = per_seed
		cached = value
	_mutex.unlock()
	return cached


## The 25 site positions of the 5x5 cells around cell c, row-major from
## c - (2, 2). Pure performance cache: hashing them costs most of a sample.
static func _neighbourhood(seed: int, c: Vector2i) -> PackedVector2Array:
	_mutex.lock()
	var cached = (_hoods.get(seed, {}) as Dictionary).get(c)
	_mutex.unlock()
	if cached != null:
		return cached
	var sites := PackedVector2Array()
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			sites.append(site_of(seed, c + Vector2i(dx, dz)))
	_mutex.lock()
	var per_seed: Dictionary = _hoods.get(seed, {})
	if not per_seed.has(c):
		if _hood_keys.size() == CACHE_LIMIT:
			var old: Array = _hood_keys[_hood_cursor]
			(_hoods.get(old[0], {}) as Dictionary).erase(old[1])
			_hood_keys[_hood_cursor] = [seed, c]
			_hood_cursor = (_hood_cursor + 1) % CACHE_LIMIT
		else:
			_hood_keys.append([seed, c])
		per_seed[c] = sites
		_hoods[seed] = per_seed
	_mutex.unlock()
	return sites


static func _cell_of(c: Vector2i, index: int) -> Vector2i:
	return c + Vector2i(index % 5 - 2, index / 5 - 2)


## Nearest and second-nearest sites around p: [cell1, d1, cell2, d2].
static func _nearest_two(seed: int, p: Vector2) -> Array:
	var c := Vector2i(floori(p.x / REGION_CELL), floori(p.y / REGION_CELL))
	var sites := _neighbourhood(seed, c)
	var d1 := INF
	var d2 := INF
	var i1 := 0
	var i2 := 0
	for i in sites.size():
		var d := p.distance_to(sites[i])
		if d < d1:
			d2 = d1
			i2 = i1
			d1 = d
			i1 = i
		elif d < d2:
			d2 = d
			i2 = i
	return [_cell_of(c, i1), d1, _cell_of(c, i2), d2]


static func region_at(seed: int, p: Vector2) -> Dictionary:
	return region(seed, _nearest_two(seed, p)[0])


## Regions blended at p: an Array of [region, weight] pairs, nearest first,
## weights summing to 1. Every site whose distance is within BAND_M of the
## nearest gets weight 1 - smootherstep((d - d1) / BAND_M) before
## normalization, so a weight is a continuous function of position even where
## two runner-up sites swap order. Outside every border band the result is the
## single nearest region with weight exactly 1.
static func sample(seed: int, p: Vector2) -> Array:
	var q := ReliefPrimitives.warp(p, seed + 1409, BORDER_WARP_M, BORDER_WARP_WL)
	var c := Vector2i(floori(q.x / REGION_CELL), floori(q.y / REGION_CELL))
	var sites := _neighbourhood(seed, c)
	var dists := PackedFloat64Array()
	dists.resize(sites.size())
	var d1 := INF
	var nearest := 0
	for i in sites.size():
		var d := q.distance_to(sites[i])
		dists[i] = d
		if d < d1:
			d1 = d
			nearest = i
	var out: Array = [[region(seed, _cell_of(c, nearest)), 1.0]]
	var total := 1.0
	for i in sites.size():
		if i == nearest or dists[i] - d1 >= BAND_M:
			continue
		var w := 1.0 - SlopeProfile.smootherstep((dists[i] - d1) / BAND_M)
		if w > 0.0:
			out.append([region(seed, _cell_of(c, i)), w])
			total += w
	if total > 1.0:
		for pair: Array in out:
			pair[1] = float(pair[1]) / total
	return out


static func _node_base(seed: int, node: Vector2i) -> float:
	_mutex.lock()
	var per_seed: Dictionary = _nodes.get(seed, {})
	var cached = per_seed.get(node)
	_mutex.unlock()
	if cached != null:
		return cached
	var value: float = region_at(seed, Vector2(node) * BASE_NODE).base_m
	_mutex.lock()
	per_seed = _nodes.get(seed, {})
	if not per_seed.has(node):
		if _node_keys.size() == CACHE_LIMIT * 4:
			var old: Array = _node_keys[_node_cursor]
			(_nodes.get(old[0], {}) as Dictionary).erase(old[1])
			_node_keys[_node_cursor] = [seed, node]
			_node_cursor = (_node_cursor + 1) % (CACHE_LIMIT * 4)
		else:
			_node_keys.append([seed, node])
		per_seed[node] = value
		_nodes[seed] = per_seed
	_mutex.unlock()
	return value


## Continental base elevation (m): smootherstep-bilinear over BASE_NODE nodes,
## each node holding the base level of the region containing it.
static func base_m(seed: int, p: Vector2) -> float:
	var q := p / BASE_NODE
	var c := Vector2i(floori(q.x), floori(q.y))
	var fx := SlopeProfile.smootherstep(q.x - c.x)
	var fz := SlopeProfile.smootherstep(q.y - c.y)
	var a := lerpf(_node_base(seed, c), _node_base(seed, c + Vector2i(1, 0)), fx)
	var b := lerpf(_node_base(seed, c + Vector2i(0, 1)), _node_base(seed, c + Vector2i(1, 1)), fx)
	return lerpf(a, b, fz)
