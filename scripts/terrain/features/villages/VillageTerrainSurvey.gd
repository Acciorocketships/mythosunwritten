class_name VillageTerrainSurvey
extends RefCounted

## Pure deterministic discovery of compact terrain-supported urban perches.
## The survey never edits terrain, allocates server-backed resources, or makes
## final building decisions. Its sorted output is the canonical input to the
## massing solver; bounded structural variants expand only after this terrain
## result set is sealed, so variant count cannot perturb perch discovery.
const GRID_STEP := 3.0
const DEFAULT_SEARCH_RADIUS := 42.0
const NEIGHBOURHOOD_RADIUS := 24.0
const FLOOR_GUARD := 0.05
const NATURAL_RELIEF_MAX := 1.0
const MAX_RETAINED_RELIEF := 5.95
const MIN_RETAINED_SUPPORT_RATIO := 0.30
const SUPPORT_CONTACT_EPS := 0.65
const CLIFF_EXPOSURE_DROP := 2.0
const EXPOSURE_PROBE_DISTANCE := 1.5
const MIN_USEFUL_VERTICAL_SPAN := 4.0
const IDEAL_VERTICAL_SPAN := 8.0
const MAX_USEFUL_VERTICAL_SPAN := 12.0
const DEFAULT_RESULT_LIMIT := 128


static func discover(terrain: VillageTerrainView,
		arrival: Vector2, half_extents: Vector2,
		primary_axis: Vector2 = Vector2.RIGHT,
		search_radius: float = DEFAULT_SEARCH_RADIUS,
		result_limit: int = DEFAULT_RESULT_LIMIT,
		minimum_radius: float = 0.0
		) -> Array[VillageTerrainPerch]:
	assert(terrain != null)
	assert(arrival.is_finite() and half_extents.is_finite())
	assert(half_extents.x > 0.0 and half_extents.y > 0.0)
	assert(primary_axis.is_normalized())
	assert(is_finite(search_radius) and search_radius >= GRID_STEP)
	assert(is_finite(minimum_radius) and minimum_radius >= 0.0 \
		and minimum_radius <= search_radius)
	assert(result_limit > 0)
	var out: Array[VillageTerrainPerch] = []
	var envelope_radius := search_radius + half_extents.length()
	var survey_region := terrain.region_covering(Rect2(arrival \
		- Vector2.ONE * envelope_radius,
		Vector2.ONE * envelope_radius * 2.0))
	var water_proved_dry := terrain.proves_planning_dry(arrival,
		envelope_radius)
	var steps := floori(search_radius / GRID_STEP)
	for z_index in range(-steps, steps + 1):
		for x_index in range(-steps, steps + 1):
			var lattice := Vector2i(x_index, z_index)
			var local := Vector2(lattice) * GRID_STEP
			if local.length() > search_radius + 0.001 \
					or local.length() < minimum_radius - 0.001:
				continue
			var anchor := arrival + primary_axis * local.x \
				+ Vector2(-primary_axis.y, primary_axis.x) * local.y
			for orientation_index in 2:
				var axis := primary_axis.rotated(float(orientation_index) * PI * 0.5)
				var yaw := atan2(-axis.y, axis.x)
				var candidate := _evaluate(terrain, survey_region,
					water_proved_dry,
					arrival, lattice,
					orientation_index, anchor, yaw, half_extents)
				if candidate != null:
					out.append(candidate)
	_populate_neighbourhoods(out)
	out.sort_custom(_less)
	if out.size() > result_limit:
		out.resize(result_limit)
	return out


static func discover_corridor(terrain: VillageTerrainView,
		survey_origin: Vector2, arrival: Vector2, half_extents: Vector2,
		forward_axis: Vector2, maximum_forward: float,
		corridor_half_width: float, minimum_arrival_radius: float,
		maximum_arrival_radius: float,
		result_limit: int = DEFAULT_RESULT_LIMIT,
		frontage_clearance: float = -1.0
		) -> Array[VillageTerrainPerch]:
	## Deterministic oriented survey whose spatial qualification precedes terrain
	## ranking and the bounded result cap. Producers that need a branch/corridor
	## must use this instead of globally sampling a disc and filtering its capped
	## winners afterwards: in an irregular biome the global winners may all lie
	## outside the only region that can participate in the topology.
	assert(terrain != null)
	assert(survey_origin.is_finite() and arrival.is_finite())
	assert(half_extents.is_finite() and half_extents.x > 0.0 \
		and half_extents.y > 0.0)
	assert(forward_axis.is_normalized())
	assert(is_finite(maximum_forward) and maximum_forward >= GRID_STEP)
	assert(is_finite(corridor_half_width) and corridor_half_width >= 0.0)
	assert(is_finite(minimum_arrival_radius) \
		and is_finite(maximum_arrival_radius) \
		and minimum_arrival_radius >= 0.0 \
		and maximum_arrival_radius >= minimum_arrival_radius)
	assert(result_limit > 0)
	assert(is_finite(frontage_clearance) and frontage_clearance >= -1.0)
	var envelope_radius := maximum_forward + corridor_half_width \
		+ half_extents.length()
	var survey_region := terrain.region_covering(Rect2(survey_origin \
		- Vector2.ONE * envelope_radius,
		Vector2.ONE * envelope_radius * 2.0))
	var water_proved_dry := terrain.proves_planning_dry(survey_origin,
		envelope_radius)
	var side := Vector2(-forward_axis.y, forward_axis.x)
	var forward_steps := ceili(maximum_forward / GRID_STEP)
	var side_steps := ceili(corridor_half_width / GRID_STEP)
	var out: Array[VillageTerrainPerch] = []
	for forward_index in range(1, forward_steps + 1):
		for side_index in range(-side_steps, side_steps + 1):
			var side_distance := float(side_index) * GRID_STEP
			if absf(side_distance) > corridor_half_width + 0.001:
				continue
			var lattice := Vector2i(forward_index, side_index)
			for orientation_index in 2:
				var axis := forward_axis.rotated(
					float(orientation_index) * PI * 0.5)
				var yaw := atan2(-axis.y, axis.x)
				var forward_distance := float(forward_index) * GRID_STEP
				if frontage_clearance >= 0.0:
					# Keep a measured rectangular support on the same lattice as
					# the street edge. Even- and odd-cell footprints require
					# different centre phases; deriving the first centre from the
					# orientation's support radius avoids rounding either family
					# to a remote grid line.
					var axes := _axes(yaw)
					var support_radius := absf(forward_axis.dot(axes[0])) \
						* half_extents.x \
						+ absf(forward_axis.dot(axes[1])) * half_extents.y
					forward_distance = frontage_clearance + support_radius \
						+ float(forward_index - 1) * GRID_STEP
				if forward_distance > maximum_forward + 0.001:
					continue
				var anchor := survey_origin + forward_axis * forward_distance \
					+ side * side_distance
				var arrival_radius := anchor.distance_to(arrival)
				if arrival_radius < minimum_arrival_radius - 0.001 \
						or arrival_radius > maximum_arrival_radius + 0.001:
					continue
				var candidate := _evaluate(terrain, survey_region,
					water_proved_dry, survey_origin, lattice,
					orientation_index, anchor, yaw, half_extents)
				if candidate != null:
					out.append(candidate)
	_populate_neighbourhoods(out)
	out.sort_custom(_less)
	if out.size() > result_limit:
		out.resize(result_limit)
	return out


static func expand_structural_variants(
		base_perches: Array[VillageTerrainPerch], datum_y: float,
		profile: VillageVerticalProfile, maximum_band: int
		) -> Array[VillageTerrainPerch]:
	assert(is_finite(datum_y) and profile != null and profile.is_valid())
	assert(maximum_band >= 0)
	var out: Array[VillageTerrainPerch] = []
	for base: VillageTerrainPerch in base_perches:
		base.architectural_band = profile.band_for_floor(base.floor_y, datum_y)
		out.append(base)
		for band_index in range(1, maximum_band + 1):
			var target_y := profile.floor_for_band(datum_y, band_index)
			if target_y < base.floor_y + FLOOR_GUARD:
				continue
			out.append(_terrace_variant(base, target_y, band_index))
	return out


static func best_core(perches: Array[VillageTerrainPerch]
		) -> VillageTerrainPerch:
	return null if perches.is_empty() else perches[0]


static func _evaluate(terrain: VillageTerrainView,
		region: HeightfieldRegion, water_proved_dry: bool, arrival: Vector2,
		lattice: Vector2i, orientation_index: int, anchor: Vector2,
		yaw: float, half_extents: Vector2) -> VillageTerrainPerch:
	var axes := _axes(yaw)
	var right: Vector2 = axes[0]
	var forward: Vector2 = axes[1]
	var samples := _footprint_samples(anchor, half_extents, right, forward)
	for point: Vector2 in samples:
		if not water_proved_dry and terrain.may_be_wet(point):
			return null
	var bounds := _bounds(anchor, half_extents, right, forward)
	var extrema := TerrainSurfaceField.height_bounds(region, bounds)
	var relief := extrema.y - extrema.x
	if relief > MAX_RETAINED_RELIEF + 0.001:
		return null
	var floor_y := extrema.y + FLOOR_GUARD
	var supported := 0
	for point: Vector2 in samples:
		if floor_y - TerrainSurfaceField.surface_y(region,
				point.x, point.y) <= SUPPORT_CONTACT_EPS + FLOOR_GUARD:
			supported += 1
	var support_ratio := float(supported) / float(samples.size())
	var exposed_edge_mask := _exposed_edges(region, anchor, half_extents,
		right, forward, floor_y)
	var support_kind := VillageTerrainPerch.SupportKind.NATURAL
	if relief > NATURAL_RELIEF_MAX + 0.001:
		if support_ratio < MIN_RETAINED_SUPPORT_RATIO:
			return null
		support_kind = VillageTerrainPerch.SupportKind.RETAINED
	var key := StringName("%d:%d:%d" % [lattice.x, lattice.y,
		orientation_index])
	var perch := VillageTerrainPerch.new(key, lattice, orientation_index,
		anchor, yaw, half_extents, floor_y, extrema.x, extrema.y,
		support_ratio, exposed_edge_mask, support_kind,
		anchor.distance_to(arrival))
	assert(perch.is_valid())
	return perch


static func _terrace_variant(base: VillageTerrainPerch,
		target_y: float, band_index: int) -> VillageTerrainPerch:
	assert(band_index > 0 and target_y >= base.floor_y)
	var lift := target_y - base.floor_y
	var raised := VillageTerrainPerch.new(
		StringName("%s:b%d" % [String(base.candidate_key), band_index]),
		base.lattice_offset, base.orientation_index, base.anchor, base.yaw,
		base.half_extents, target_y, base.minimum_y,
		base.maximum_y, base.support_ratio, base.exposed_edge_mask,
		VillageTerrainPerch.SupportKind.RETAINED,
		base.distance_from_arrival, lift)
	raised.architectural_band = band_index
	raised.neighbour_count = base.neighbour_count
	raised.vertical_span = base.vertical_span
	raised.elevation_band_count = base.elevation_band_count
	raised.useful_relief_score = maxf(0.0, base.useful_relief_score \
		- (0.12 if base.is_naturally_supported() else 0.0))
	assert(raised.is_valid())
	return raised


static func _populate_neighbourhoods(
		perches: Array[VillageTerrainPerch]) -> void:
	var buckets: Dictionary = {}
	for perch: VillageTerrainPerch in perches:
		var key := _bucket_key(perch.anchor)
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(perch)
	for perch: VillageTerrainPerch in perches:
		var minimum := perch.floor_y
		var maximum := perch.floor_y
		var bands: Dictionary = {}
		var anchors: Dictionary = {}
		var centre_bucket := _bucket_key(perch.anchor)
		for bucket_z in range(centre_bucket.y - 1, centre_bucket.y + 2):
			for bucket_x in range(centre_bucket.x - 1, centre_bucket.x + 2):
				var bucket: Array = buckets.get(Vector2i(bucket_x, bucket_z), [])
				for value: Variant in bucket:
					var other := value as VillageTerrainPerch
					if perch.anchor.distance_squared_to(other.anchor) \
							> NEIGHBOURHOOD_RADIUS * NEIGHBOURHOOD_RADIUS \
							+ 0.001:
						continue
					var anchor_key := Vector2i(roundi(other.anchor.x * 1000.0),
						roundi(other.anchor.y * 1000.0))
					if anchors.has(anchor_key):
						continue
					anchors[anchor_key] = true
					minimum = minf(minimum, other.floor_y)
					maximum = maxf(maximum, other.floor_y)
					bands[roundi(other.floor_y / HeightfieldPlan.LEVEL_HEIGHT)] = true
		perch.neighbour_count = anchors.size()
		perch.vertical_span = maximum - minimum
		perch.elevation_band_count = bands.size()
		var span_score := clampf(perch.vertical_span \
			/ IDEAL_VERTICAL_SPAN, 0.0, 1.0)
		if perch.vertical_span > MAX_USEFUL_VERTICAL_SPAN:
			span_score -= clampf((perch.vertical_span - MAX_USEFUL_VERTICAL_SPAN)
				/ IDEAL_VERTICAL_SPAN, 0.0, 1.0)
		if perch.vertical_span < MIN_USEFUL_VERTICAL_SPAN:
			span_score *= perch.vertical_span / MIN_USEFUL_VERTICAL_SPAN
		var density_score := clampf(float(perch.neighbour_count) / 12.0,
			0.0, 1.0)
		var natural_bonus := 0.12 if perch.is_naturally_supported() else 0.0
		perch.useful_relief_score = span_score * 0.62 \
			+ density_score * 0.26 + natural_bonus


static func _bucket_key(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / NEIGHBOURHOOD_RADIUS),
		floori(point.y / NEIGHBOURHOOD_RADIUS))


static func _less(a: VillageTerrainPerch, b: VillageTerrainPerch) -> bool:
	if a.useful_relief_score != b.useful_relief_score:
		return a.useful_relief_score > b.useful_relief_score
	if a.support_kind != b.support_kind:
		return a.support_kind < b.support_kind
	if a.relief != b.relief:
		return a.relief < b.relief
	if a.distance_from_arrival != b.distance_from_arrival:
		return a.distance_from_arrival < b.distance_from_arrival
	return String(a.candidate_key) < String(b.candidate_key)


static func _axes(yaw: float) -> Array[Vector2]:
	return [Vector2(cos(yaw), -sin(yaw)),
		Vector2(sin(yaw), cos(yaw))]


static func _bounds(anchor: Vector2, half_extents: Vector2,
		right: Vector2, forward: Vector2) -> Rect2:
	var aabb_half := right.abs() * half_extents.x \
		+ forward.abs() * half_extents.y
	return Rect2(anchor - aabb_half, aabb_half * 2.0)


static func _footprint_samples(anchor: Vector2, half_extents: Vector2,
		right: Vector2, forward: Vector2) -> Array[Vector2]:
	return [
		anchor,
		anchor - right * half_extents.x - forward * half_extents.y,
		anchor + right * half_extents.x - forward * half_extents.y,
		anchor - right * half_extents.x + forward * half_extents.y,
		anchor + right * half_extents.x + forward * half_extents.y,
		anchor - right * half_extents.x,
		anchor + right * half_extents.x,
		anchor - forward * half_extents.y,
		anchor + forward * half_extents.y,
	]


static func _exposed_edges(region: HeightfieldRegion, anchor: Vector2,
		half_extents: Vector2, right: Vector2, forward: Vector2,
		floor_y: float) -> int:
	var mask := 0
	var directions: Array[Vector2] = [right, -right, forward, -forward]
	var reaches: Array[float] = [half_extents.x, half_extents.x,
		half_extents.y, half_extents.y]
	for index in directions.size():
		var point := anchor + directions[index] \
			* (reaches[index] + EXPOSURE_PROBE_DISTANCE)
		if floor_y - TerrainSurfaceField.surface_y(region,
				point.x, point.y) >= CLIFF_EXPOSURE_DROP:
			mask |= 1 << index
	return mask
