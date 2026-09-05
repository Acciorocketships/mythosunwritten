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
var _collar_cells: int
var _uniform := true


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


func surface_y(point: Vector2, natural_height: float) -> float:
	if not bounds.has_point(point):
		return natural_height
	var local := point - _origin
	var cell := Vector2i(roundi(local.x / _targets.pitch),
		roundi(local.y / _targets.pitch))
	var weight := 1.0 - TerrainSurfaceField.transition_weight(_claim_distance(local))
	if weight <= 0.0:
		return natural_height
	var target := _targets.fallback if _uniform else (
		_sample(_targets, _target_cache, cell, local) if _claims.has(cell)
		else _collar_height(local, cell))
	return lerpf(natural_height, target, weight)


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
		var height := _sample(_targets, _target_cache, key, boundary)
		if distance < 0.000001:
			return height
		var w := (1.0 - TerrainSurfaceField.transition_weight(distance)) / (distance * distance)
		weighted += height * w
		total += w
	return weighted / total if total > 0.0 else _targets.fallback


## Exact distance to the union of construction cells, not a second smooth
## interpolation of already-smoothed 3 m weights. The latter stopped the slope
## at every fine-cell centre and produced visible corrugations. Finite buckets
## keep the query local; inside the plateau the answer is a single lookup.
func _claim_distance(local: Vector2) -> float:
	var pitch := _targets.pitch
	var cell := Vector2i(roundi(local.x / pitch), roundi(local.y / pitch))
	if _claims.has(cell):
		return 0.0
	var distance := TRANSITION_WIDTH
	for key: Vector2i in _nearby(cell):
		var delta := (local - Vector2(key) * pitch).abs() - Vector2.ONE * pitch * 0.5
		distance = minf(distance, delta.max(Vector2.ZERO).length())
	return distance


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
			var distance := _claim_distance(part.get_center())
			# Distance to a closed union is 1-Lipschitz. This interval remains
			# conservative even when its nearest owner changes inside the box.
			var radius := part.size.length() * 0.5
			interval.x = minf(interval.x, 1.0 - TerrainSurfaceField.transition_weight(distance + radius))
			interval.y = maxf(interval.y, 1.0 - TerrainSurfaceField.transition_weight(maxf(0, distance - radius)))
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
	return TerrainGradePatch.new(stable_id, claims, _origin, pitch)


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
