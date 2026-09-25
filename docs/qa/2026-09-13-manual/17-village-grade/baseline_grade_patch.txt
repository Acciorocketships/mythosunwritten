class_name TerrainGradePatch
extends RefCounted

## A sealed edit of the ground heightfield on an authored construction lattice.
## Target heights use TerrainSurfaceField's shared centre/edge/corner controls;
## the finite collar uses its normal, world-sized slope profile once. No mesh,
## ramp, or collision is stored here.
## The natural field remains the planning input; this patch is composed before
## the final terrain is sampled by rendering, collision, and ground dressing.
const TRANSITION_WIDTH := TerrainSurfaceField.HALF

class Controls extends RefCounted:
	var values: Dictionary
	var source_values: Dictionary
	var search_radius := 0
	var pitch: float
	var fallback: float
	func _init(p_values: Dictionary, p_pitch: float, p_fallback: float) -> void:
		source_values = p_values
		values = p_values.duplicate()
		pitch = p_pitch
		fallback = p_fallback
	func terrain_tile_size() -> float:
		return pitch
	func storey_at(_x: int, _z: int) -> int:
		return 0
	func surface_height(x: int, z: int) -> float:
		var cell := Vector2i(x,z)
		if values.has(cell):
			return float(values[cell])
		# Stable nearest-source extrapolation for the boundary controls only.
		# Ghost controls are memoized on demand; unused house proposals no longer
		# allocate the entire village's expanded collar.
		for radius in range(1, search_radius + 1):
			for dz in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if maxi(absi(dx), absi(dz)) != radius:
						continue
					var key := cell + Vector2i(dx,dz)
					if source_values.has(key):
						values[cell] = source_values[key]
						return float(values[cell])
		values[cell] = fallback
		return fallback
	func is_carved(_x: int, _z: int) -> bool:
		return false

var stable_id: StringName
var bounds: Rect2
var _origin: Vector2
var _claims: Dictionary
var _targets: Controls
var _target_cache: Dictionary = {}
var _nearby_claims: Dictionary = {}
var _collar_rectangles_by_cell: Dictionary = {}
var _collar_rectangles: Array[Rect2] = []
var _nearby_collar_rectangles: Dictionary = {}
var _collar_cells: int
var _uniform := true
var _continuous_source: TerrainGradePatch
var _continuous_cells: Dictionary = {}
var _continuous_datum := 0.0
const SURFACE_CACHE_LIMIT := 32768
var _surface_cache: Dictionary = {}


## Road reservations inherit an already reconstructed continuous field. Their
## centre samples are planning facts, not new plateau controls for that field.
func with_continuous_extension(heights: Dictionary, datum: float) -> TerrainGradePatch:
	var result := TerrainGradePatch.new(stable_id, heights, _origin, _targets.pitch)
	result._continuous_source = self
	result._continuous_cells = heights.duplicate()
	result._continuous_datum = datum
	return result


## New foundation pads own fixed heights; previously reserved street cells
## retain their continuous source instead of baking that slope a second time.
func with_fixed_extension(heights: Dictionary) -> TerrainGradePatch:
	var result := TerrainGradePatch.new(stable_id, heights, _origin, _targets.pitch)
	result._continuous_source = self
	for cell: Vector2i in heights:
		if _claims.has(cell) and float(_claims[cell]) == float(heights[cell]):
			result._continuous_cells[cell] = true
	result._continuous_datum = _targets.fallback
	return result


func _init(id: StringName, heights: Dictionary, origin: Vector2,
		pitch: float) -> void:
	assert(not heights.is_empty() and pitch > 0.0 and not id.is_empty())
	stable_id = id
	_origin = origin
	_claims = heights.duplicate()
	var ordered: Array[Vector2i] = []
	ordered.assign(heights.keys())
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	_collar_cells = ceili(TRANSITION_WIDTH / pitch) + 1
	var minimum := INF
	var maximum := -INF
	for cell: Vector2i in ordered:
		minimum = minf(minimum, float(heights[cell]))
		maximum = maxf(maximum, float(heights[cell]))
	_uniform = minimum == maximum
	_targets = Controls.new(heights, pitch, minimum)
	_targets.search_radius = _collar_cells
	var lo := ordered[0]
	var hi := lo
	for cell: Vector2i in ordered:
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	bounds = Rect2(origin + Vector2(lo) * pitch,
		Vector2(hi - lo) * pitch).grow(TRANSITION_WIDTH + pitch * 0.5)
	_build_collar_rectangles(ordered)


func surface_y(point: Vector2, natural_height: float) -> float:
	if not bounds.has_point(point):
		return natural_height
	if _surface_cache.has(point):
		var cached: PackedFloat64Array = _surface_cache[point]
		return lerpf(natural_height,cached[0],cached[1])
	if _surface_cache.size() >= SURFACE_CACHE_LIMIT:
		_surface_cache.clear()
	var local := point - _origin
	var cell := Vector2i(roundi(local.x / _targets.pitch),
		roundi(local.y / _targets.pitch))
	var weight := _collar_weight(local,cell)
	if weight <= 0.0:
		_surface_cache[point] = PackedFloat64Array([0.0,0.0])
		return natural_height
	var target := _target_at(local,cell) if _claims.has(cell) else (
		_continuous_source.surface_y(point,_continuous_datum)
		if _continuous_source != null and _continuous_cells.size() == _claims.size()
		else (_targets.fallback if _uniform and _continuous_source == null
		else _collar_height(local,cell)))
	# Cache only the immutable target/weight, never the caller's natural height.
	# Neighboring mesh triangles, collision and nested grade fields revisit the
	# same world coordinates; eviction cannot change their sampled surface.
	_surface_cache[point] = PackedFloat64Array([target,weight])
	return lerpf(natural_height, target, weight)


func _target_at(local: Vector2, cell: Vector2i) -> float:
	if _continuous_source != null and _continuous_cells.has(cell):
		return _continuous_source.surface_y(_origin+local,_continuous_datum)
	return _targets.fallback if _uniform else _sample(_targets,_target_cache,cell,local)


## Extend actual boundary values, not the identity of the nearest building.
## Nearest-owner switching made ghost ridges halfway between unequal pads.
## Compact inverse-distance weights meet the boundary exactly and blend all
## nearby constraints continuously. The boundary values themselves still come
## from the one terrain centre/edge/corner kernel.
func _collar_height(local: Vector2, cell: Vector2i) -> float:
	var weighted := 0.0
	var total := 0.0
	var half := Vector2.ONE * _targets.pitch * 0.5
	for key: Vector2i in _nearby(cell):
		var centre := Vector2(key) * _targets.pitch
		var boundary := local.clamp(centre - half, centre + half)
		var distance := local.distance_to(boundary)
		if distance >= TRANSITION_WIDTH:
			continue
		var height := _target_at(boundary,key)
		if distance < 0.000001:
			return height
		var w := (1.0 - TerrainSurfaceField.transition_weight(distance)) / (distance * distance)
		weighted += height * w
		total += w
	return weighted / total if total > 0.0 else _targets.fallback


## Cover the claim union with its maximal axis-aligned rectangles. Every
## rectangle is a convex distance field; their compact weights can form a C1
## union instead of switching nearest owners at a concave medial axis. Maximal
## rectangles are determined by the outline, not arbitrary row partitions, so
## a long straight pad retains one 12 m profile across construction-cell seams.
func _build_collar_rectangles(ordered: Array[Vector2i]) -> void:
	var rows: Dictionary={}
	for cell: Vector2i in ordered:
		if not rows.has(cell.y): rows[cell.y]=[]
		var runs: Array=rows[cell.y]
		if not runs.is_empty() and runs[-1].y==cell.x-1:
			runs[-1]=Vector2i(runs[-1].x,cell.x)
		else: runs.append(Vector2i(cell.x,cell.x))
	var rectangles: Array[Rect2]=[]
	for top: int in rows:
		var common: Array=rows[top].duplicate()
		var bottom := top
		while rows.has(bottom) and not common.is_empty():
			if bottom>top: common=_intersect_runs(common,rows[bottom])
			for run: Vector2i in common:
				if _row_contains(rows.get(top-1,[]),run) or _row_contains(rows.get(bottom+1,[]),run): continue
				var index := rectangles.size()
				rectangles.append(Rect2(Vector2(run.x,top)*_targets.pitch-Vector2.ONE*_targets.pitch*0.5,
					Vector2(run.y-run.x+1,bottom-top+1)*_targets.pitch))
				for z in range(top,bottom+1):
					for x in range(run.x,run.y+1):
						var key:=Vector2i(x,z)
						if not _collar_rectangles_by_cell.has(key): _collar_rectangles_by_cell[key]=[]
						_collar_rectangles_by_cell[key].append(index)
			bottom+=1
	_collar_rectangles.assign(rectangles)


static func _row_contains(runs: Array, interval: Vector2i) -> bool:
	for run: Vector2i in runs:
		if run.x<=interval.x and run.y>=interval.y: return true
	return false


static func _intersect_runs(first: Array, second: Array) -> Array:
	var result: Array=[]
	for a: Vector2i in first:
		for b: Vector2i in second:
			var lo:=maxi(a.x,b.x)
			var hi:=mini(a.y,b.y)
			if lo<=hi: result.append(Vector2i(lo,hi))
	return result


func _rectangle_distances(local: Vector2, cell: Vector2i) -> Dictionary:
	if not _nearby_collar_rectangles.has(cell):
		var nearby: Dictionary = {}
		for key: Vector2i in _nearby(cell):
			for index: int in _collar_rectangles_by_cell.get(key, []): nearby[index] = true
		_nearby_collar_rectangles[cell] = nearby.keys()
	var distances: Dictionary = {}
	for index: int in _nearby_collar_rectangles[cell]:
		var area: Rect2 = _collar_rectangles[index]
		var nearest := local.clamp(area.position, area.end)
		distances[index] = local.distance_to(nearest)
	return distances


func _collar_weight(local: Vector2, cell: Vector2i) -> float:
	if _claims.has(cell):
		return 1.0
	var remaining := 1.0
	for distance: float in _rectangle_distances(local,cell).values():
		remaining *= TerrainSurfaceField.transition_weight(distance)
	return 1.0-remaining


func _nearby(cell: Vector2i) -> Array:
	if not _nearby_claims.has(cell):
		var keys: Array[Vector2i] = []
		for z in range(-_collar_cells, _collar_cells + 1):
			for x in range(-_collar_cells, _collar_cells + 1):
				var key := cell + Vector2i(x,z)
				if _claims.has(key):
					keys.append(key)
		_nearby_claims[cell] = keys
	return _nearby_claims[cell]


func _weight_bounds(area: Rect2) -> Vector2:
	var half := _targets.pitch * 0.5
	var lo := Vector2i(floori(area.position.x / _targets.pitch + 0.5),
		floori(area.position.y / _targets.pitch + 0.5))
	var hi := Vector2i(ceili(area.end.x / _targets.pitch + 0.5) - 1,
		ceili(area.end.y / _targets.pitch + 0.5) - 1)
	var interval := Vector2(1, 0)
	for z in range(lo.y, maxi(lo.y, hi.y) + 1):
		for x in range(lo.x, maxi(lo.x, hi.x) + 1):
			var cell := Vector2i(x,z)
			if _claims.has(cell):
				interval.y = 1.0
				continue
			var part := area.intersection(Rect2(Vector2(cell) * _targets.pitch - Vector2.ONE * half,
				Vector2.ONE * _targets.pitch))
			# Each convex-boundary distance is 1-Lipschitz. The smooth union is
			# monotone in every input, so composing their intervals is conservative.
			var radius := part.size.length() * 0.5
			var remaining_lo := 1.0
			var remaining_hi := 1.0
			for distance: float in _rectangle_distances(part.get_center(),cell).values():
				remaining_lo *= TerrainSurfaceField.transition_weight(maxf(0,distance-radius))
				remaining_hi *= TerrainSurfaceField.transition_weight(distance+radius)
			interval.x=minf(interval.x,1.0-remaining_hi)
			interval.y=maxf(interval.y,1.0-remaining_lo)
	return interval


## Seal complete neighbouring foundation pads into the same lattice before
## publishing any terrain chunk. These are planning constraints, not meshes or
## post-stream edits. The lower pad controls the shared transition to a higher
## town band, exactly as ordinary terrain does.
func with_foundation_pads(pads: Array[Dictionary], preserve_claims := false) -> TerrainGradePatch:
	var claims := _claims.duplicate()
	var pitch := _targets.pitch
	for pad: Dictionary in pads:
		var area: Rect2 = pad.area
		var lo := Vector2i(floori((area.position.x - _origin.x) / pitch - 0.5),
			floori((area.position.y - _origin.y) / pitch - 0.5))
		var hi := Vector2i(ceili((area.end.x - _origin.x) / pitch + 0.5),
			ceili((area.end.y - _origin.y) / pitch + 0.5))
		for z in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var key := Vector2i(x, z)
				if preserve_claims and claims.has(key) \
						and not is_equal_approx(float(claims[key]), float(pad.height)):
					return null # A later parcel may not invalidate sealed ground.
				claims[key] = minf(float(claims.get(key, pad.height)), float(pad.height))
	return with_fixed_extension(claims) if _continuous_source != null \
		else TerrainGradePatch.new(stable_id, claims, _origin, pitch)


## Interval composition is conservative even where the fine grading controls
## cross a coarse natural quadrant. On a construction plateau weight is exactly
## one, so distant natural heights cannot inflate a foundation's support bounds.
func height_bounds(footprint: Rect2, natural: Vector2) -> Vector2:
	if not bounds.intersects(footprint, true):
		return natural
	var local := Rect2(footprint.position - _origin, footprint.size)
	var weights := _weight_bounds(local)
	if weights.y <= 0.0:
		return natural
	# Only the claimed plateau is evaluated directly on the control lattice.
	# The collar is a convex boundary blend, not the ghost lattice: bounding
	# those unused ghost quadrants was both misleading and expensive.
	var targets := Vector2(_targets.fallback, _targets.fallback) if _uniform else (
		_control_bounds(_targets, _target_cache, local) if weights.x == 1.0
		else _collar_target_bounds(local))
	if _continuous_source != null:
		# Inherited curves can have extrema between this reservation's lattice
		# corners. Ask their original field for its conservative interval.
		var inherited_area := footprint if _continuous_cells.size() == _claims.size() \
			else footprint.grow(TRANSITION_WIDTH + _targets.pitch * 2.0)
		var inherited := _continuous_source.height_bounds(inherited_area,
			Vector2(_continuous_datum,_continuous_datum))
		if _continuous_cells.size() == _claims.size():
			targets = inherited
		else:
			targets = Vector2(minf(targets.x,inherited.x),maxf(targets.y,inherited.y))
	var interval := Vector2(INF, -INF)
	for n: float in [natural.x, natural.y]:
		for t: float in [targets.x, targets.y]:
			for w: float in [weights.x, weights.y]:
				var value := lerpf(n, t, w)
				interval.x = minf(interval.x, value)
				interval.y = maxf(interval.y, value)
	return interval


func _collar_target_bounds(area: Rect2) -> Vector2:
	# Every projected boundary control is a convex combination of source
	# heights no farther than two pitches from its owning claim. Bound those
	# sources directly instead of baking hundreds of unused collar quadrants
	# for every proposed building survey.
	var halo := area.grow(TRANSITION_WIDTH + 2.0 * _targets.pitch)
	var result := Vector2(INF,-INF)
	for cell: Vector2i in _claims:
		if halo.has_point(Vector2(cell) * _targets.pitch):
			var height := float(_claims[cell])
			result.x = minf(result.x,height)
			result.y = maxf(result.y,height)
	return result if result.x <= result.y else Vector2(_targets.fallback,_targets.fallback)


## The controls have no cliffs. Each half-cell patch is bilinear in monotone
## coordinates, so only the clipped corners are extrema. Reuse the same baked
## controls as point sampling instead of reclassifying each corner on every
## foundation candidate during the bounded outskirts search.
static func _control_bounds(controls: Controls, cache: Dictionary,
		area: Rect2) -> Vector2:
	var half := controls.pitch * 0.5
	var xs: Array[float] = [area.position.x, area.end.x]
	var zs: Array[float] = [area.position.y, area.end.y]
	for x in range(ceili(area.position.x / half), floori(area.end.x / half) + 1):
		xs.append(x * half)
	for z in range(ceili(area.position.y / half), floori(area.end.y / half) + 1):
		zs.append(z * half)
	var interval := Vector2(INF, -INF)
	for z: float in zs:
		for x: float in xs:
			var value := _sample(controls, cache, Vector2i(roundi(x / controls.pitch),
				roundi(z / controls.pitch)), Vector2(x, z))
			interval.x = minf(interval.x, value)
			interval.y = maxf(interval.y, value)
	return interval


static func _sample(controls: Controls, cache: Dictionary, cell: Vector2i,
		point: Vector2) -> float:
	if not cache.has(cell):
		cache[cell] = TerrainSurfaceField.bake_cell(controls, cell.x, cell.y)
	return TerrainSurfaceField.sample_baked(cache[cell], cell.x, cell.y,
		point.x, point.y, controls)
