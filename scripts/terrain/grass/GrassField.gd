class_name GrassField
extends RefCounted

const TILE_WORLD := TerrainChunkMesher.TILE
## Collection 5 is a complete broad 311-blade patch rather than one small
## tuft. An 18×18 primary lattice closes saturated beds while the bake's broad
## root spread keeps neighbouring patches from reading as repeated clumps.
## Seventeen slots per side are 27.8% fewer candidates than the former 20×20
## field while the 3.11 m patch still overlaps its 1.41 m pitch by over 2×.
const SLOT_SIDE := 17
const SLOT_PITCH := TILE_WORLD / float(SLOT_SIDE)
const SLOT_COUNT := SLOT_SIDE * SLOT_SIDE
## Authored habitat values keep their biome meaning and true-zero clearings.
## This narrow threshold converts viable habitat into a visually closed carpet.
## Very weak habitat disappears instead of lingering as isolated repeated
## patches, while open marsh and every stronger biome reach saturation quickly.
const CARPET_EDGE_LOW := 0.20
const CARPET_EDGE_HIGH := 0.42
## Biome/canopy fields vary over 132–750 m. A canonical world-aligned 3 m
## projection keeps those smooth facts continuous while avoiding thousands of
## repeated noise/hash evaluations per 24 m tile. Terrain, water, shared land
## occupancy, and man-made clearance remain exact at every jittered anchor.
const FIELD_STEP := 3.0
const FIELD_SIDE := int(TILE_WORLD / FIELD_STEP) + 1
## The primary lattice measures projected XZ area. One independent supplemental
## lattice restores the exact extra surface area on slopes: A_surface/A_xz =
## 1 / normal.y. With the authored max grade this needs at most 41% more anchors.
const MAX_SLOPE_EXTRA := 1.0
## Collection 5 is a broad patch. Rejecting only its centre lets outer blades
## cover path geometry, so corridor qualification probes its conservative
## horizontal radius plus this small visual breathing margin.
const PATH_FOOTPRINT_CLEARANCE := 0.2
const FOOTPRINT_DIRECTIONS := [
	Vector2(1.0, 0.0), Vector2(-1.0, 0.0),
	Vector2(0.0, 1.0), Vector2(0.0, -1.0),
	Vector2(0.70710678, 0.70710678), Vector2(0.70710678, -0.70710678),
	Vector2(-0.70710678, 0.70710678), Vector2(-0.70710678, -0.70710678),
]
const CARDINALS := [Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)]
## Uniformly shrink a patch at any grass-bed edge. Ecological coverage supplies
## the general edge factor; exposed upper cliff lips supply the physical factor.
## The minimum wins, and inverse-area supplemental density keeps the smaller
## patches closed without distorting their authored proportions.
const CLIFF_TAPER_DISTANCE := 3.0
const COVERAGE_EDGE_MIN_SCALE := 0.55
const CLIFF_EDGE_MIN_SCALE := 0.55
## The upper lip has open space beyond it, so its last patch must fit on the
## walkable sheet. The lower side is not a grass-bed edge: its ordinary carpet
## meets the opaque rock face, which hides the part of a broad patch behind it.
## Treating both sides as edges creates a conspicuous bare band around cliffs.
## Only sub-10%-scale upper remnants are discarded.
const CLIFF_FOOTPRINT_MARGIN := 0.05
const CLIFF_MIN_VISIBLE_SCALE := 0.08
## Inverse-area compensation at a tapered edge and on a hill can otherwise grow
## without bound. Four total layers close the reviewed 55% edge patches while
## keeping slope/cliff junctions within a predictable visual and CPU budget.
const MAX_DENSITY_MULTIPLIER := 4.0
const SALT_TILE_X := 0x1F123BB5
const SALT_TILE_Z := 0x05491333
const SALT_SLOT := 0x6C8E9CF5
const SALT_JITTER_X := 0x243F6A88
const SALT_JITTER_Z := 0x13198A2E
const SALT_ELIGIBILITY := 0x1A2B3C4D
const SALT_YAW := 0x299F31D0
const SALT_SCALE := 0x082EFA98
const SALT_SWAY := 0x38D01377
const SALT_DROPOUT := 0x34E90C6C
const SALT_ASSET := 0x4A7484AA
const SALT_SLOPE_LAYER := 0x5A17C9E3

static func parent_chunk(tile: Vector2i) -> Vector2i:
	var origin := Vector2(tile) * TILE_WORLD
	return WorldFieldBlockCache.key_of(origin)

static func tile_of(world_xz: Vector2) -> Vector2i:
	return Vector2i(floori(world_xz.x / TILE_WORLD), floori(world_xz.y / TILE_WORLD))

static func compute(program: GrassProgram, world_seed: int, tile: Vector2i,
		region: HeightfieldRegion, water: WaterFieldContext,
		paths: PathContext = null) -> GrassPayload:
	assert(program != null and region != null and water != null)
	var payload := GrassPayload.new()
	payload.tile = tile
	var tile_identity := _tile_identity(world_seed, program.grass_seed_version, tile)
	var asset_id := _choose_asset(program.variant_asset_ids,
		_roll(tile_identity, SALT_ASSET))
	var candidates := {asset_id: []}
	var origin := Vector2(tile) * TILE_WORLD
	var tile_fields := _bake_tile_fields(program, origin, world_seed)
	var surface_cache: Dictionary = {}
	var cliff_edge_cache: Dictionary = {}
	var asset: Dictionary = program.assets[asset_id]
	var maximum_slope_extra := minf(MAX_SLOPE_EXTRA,
		sqrt(1.0 + program.max_grade * program.max_grade) - 1.0)
	var has_coverage_edge := _tile_has_coverage_edge(tile_fields)
	var has_cliff_edge := _tile_has_cliff_lip(
		region, origin, cliff_edge_cache)
	var minimum_tile_scale := 1.0
	if has_coverage_edge:
		minimum_tile_scale = COVERAGE_EDGE_MIN_SCALE
	if has_cliff_edge:
		minimum_tile_scale = minf(minimum_tile_scale, CLIFF_EDGE_MIN_SCALE)
	var layer_count := 1 + ceili(_density_extra(
		minimum_tile_scale, maximum_slope_extra))
	for layer in layer_count:
		for slot_index in SLOT_COUNT:
			var sx := slot_index % SLOT_SIDE
			var sz := slot_index / SLOT_SIDE
			var identity := Helper._mix64(tile_identity \
				^ Helper._mix64(slot_index ^ SALT_SLOT))
			identity = _layer_identity(identity, layer)
			var anchor := origin + Vector2(
				(float(sx) + _roll(identity, SALT_JITTER_X)) * SLOT_PITCH,
				(float(sz) + _roll(identity, SALT_JITTER_Z)) * SLOT_PITCH)
			var field_sample := _sample_tile_fields(tile_fields, anchor - origin)
			var eligibility := _roll(identity, SALT_ELIGIBILITY)
			var preliminary_coverage: float = field_sample.coverage
			var preliminary_habitat := preliminary_coverage \
				* float(field_sample.land_occupancy)
			var preliminary_carpet := carpet_coverage(preliminary_habitat)
			var scale := lerpf(program.scale_range.x, program.scale_range.y,
				_roll(identity, SALT_SCALE))
			var footprint_radius := float(asset.footprint_radius) * scale
			var physical_edge_scale := _cliff_scale(region, anchor, footprint_radius,
				cliff_edge_cache)
			var preliminary_edge_scale := minf(physical_edge_scale,
				_coverage_edge_scale(preliminary_carpet))
			var maximum_extra := _density_extra(preliminary_edge_scale,
				maximum_slope_extra)
			var maximum_weight := 1.0 if layer == 0 \
				else _supplement_weight(maximum_extra, layer)
			if maximum_weight <= 0.0 or eligibility >= \
					preliminary_carpet * maximum_weight:
				continue
			# Evaluate exact shared land occupancy only for a candidate which can
			# survive its monotone upper bound. Applying the carpet curve after the
			# product preserves true shared clearings instead of filling them back in.
			var habitat := preliminary_coverage \
				* DressingEcology.land_occupancy01(anchor, world_seed)
			var coverage := carpet_coverage(habitat)
			if eligibility >= coverage * maximum_weight:
				continue
			var surface := _qualified_surface(program, anchor, region, water, paths,
				footprint_radius, surface_cache, cliff_edge_cache,
				physical_edge_scale)
			if surface.is_empty():
				continue
			var edge_scale := minf(float(surface.physical_edge_scale),
				_coverage_edge_scale(coverage))
			var actual_extra := _density_extra(edge_scale,
				float(surface.area_extra))
			var actual_weight := 1.0 if layer == 0 \
				else _supplement_weight(actual_extra, layer)
			if actual_weight <= 0.0 or eligibility >= coverage * actual_weight:
				continue
			var yaw := _roll(identity, SALT_YAW) * TAU
			var orientation := _surface_basis(surface.normal) * Basis(Vector3.UP, yaw)
			var final_scale := scale * edge_scale
			var basis := Basis(orientation.x * final_scale,
				orientation.y * final_scale, orientation.z * final_scale)
			var placement := Transform3D(basis,
				Vector3(anchor.x, surface.y, anchor.y))
			var final_transform: Transform3D = placement * asset.piece_transform
			(candidates[asset_id] as Array).append({
				"key": Helper._mix64(identity ^ SALT_DROPOUT),
				"slot": layer * SLOT_COUNT + slot_index,
				"transform": final_transform,
				"color": field_sample.tint,
				"sway": _roll(identity, SALT_SWAY) * TAU,
				"bounds": placement * (asset.descriptor_aabb as AABB),
				"height": (asset.descriptor_aabb as AABB).size.y * final_scale,
			})
	for batch_asset_id: StringName in candidates:
		var batch_candidates: Array = candidates[batch_asset_id]
		if batch_candidates.is_empty():
			continue
		batch_candidates.sort_custom(_candidate_less)
		var buffer := PackedFloat32Array()
		buffer.resize(batch_candidates.size() * GrassPayload.FLOATS_PER_INSTANCE)
		var bounds: AABB
		var has_bounds := false
		var max_height := 0.0
		for index in batch_candidates.size():
			var candidate: Dictionary = batch_candidates[index]
			_write_instance(buffer, index, candidate.transform, candidate.color,
				candidate.sway, float(index) / float(batch_candidates.size()))
			var candidate_bounds: AABB = candidate.bounds
			bounds = candidate_bounds if not has_bounds else bounds.merge(candidate_bounds)
			has_bounds = true
			max_height = maxf(max_height, candidate.height)
		payload.batches[batch_asset_id] = {
			"buffer": buffer,
			"count": batch_candidates.size(),
			"aabb": bounds,
			"max_height": max_height,
		}
		payload.instance_count += batch_candidates.size()
	assert(payload.validate())
	return payload

static func carpet_coverage(habitat: float) -> float:
	return smoothstep(CARPET_EDGE_LOW, CARPET_EDGE_HIGH,
		clampf(habitat, 0.0, 1.0))

static func _coverage_edge_scale(coverage: float) -> float:
	return lerpf(COVERAGE_EDGE_MIN_SCALE, 1.0,
		smoothstep(0.0, 1.0, clampf(coverage, 0.0, 1.0)))

static func _density_extra(edge_scale: float, surface_area_extra: float) -> float:
	var multiplier := (1.0 + surface_area_extra) / (edge_scale * edge_scale)
	return minf(multiplier, MAX_DENSITY_MULTIPLIER) - 1.0

static func _supplement_weight(total_extra: float, layer: int) -> float:
	assert(layer > 0)
	return clampf(total_extra - float(layer - 1), 0.0, 1.0)

static func _layer_identity(base_identity: int, layer: int) -> int:
	if layer == 0:
		return base_identity
	if layer == 1:
		# Preserve the already-landed slope supplement's identities.
		return Helper._mix64(base_identity ^ SALT_SLOPE_LAYER)
	return Helper._mix64(base_identity \
		^ Helper._mix64(SALT_SLOPE_LAYER ^ layer))

static func _bake_tile_fields(program: GrassProgram, origin: Vector2,
		world_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var canopy_hash := DressingCompiler.stable_id_hash(GrassProgram.CANOPY_CHANNEL)
	for z in FIELD_SIDE:
		for x in FIELD_SIDE:
			var point := origin + Vector2(float(x), float(z)) * FIELD_STEP
			var weights: Dictionary = Helper.biome_weights5(
				Vector3(point.x, 0.0, point.y), world_seed)
			var biome_base := _biome_dot(program.coverage_by_biome, weights)
			var canopy_coverage := _biome_dot(GrassProgram.CANOPY_COVERAGE, weights)
			var canopy_field := DressingEcology.habitat01(point, world_seed,
				canopy_hash, GrassProgram.CANOPY_SCALE)
			var canopy_opening := DressingEcology.suitability(canopy_field,
				canopy_coverage, DressingHabitatLayer.Preference.EXTERIOR,
				GrassProgram.CANOPY_SOFTNESS)
			out.append({
				"coverage": clampf(biome_base * canopy_opening, 0.0, 1.0),
				"land_occupancy": DressingEcology.land_occupancy01(
					point, world_seed),
				"tint": BiomeRegistry.ground_tint_at(
					Vector3(point.x, 0.0, point.y), world_seed),
			})
	return out

static func _sample_tile_fields(values: Array[Dictionary],
		local: Vector2) -> Dictionary:
	var grid := local / FIELD_STEP
	var x0 := clampi(floori(grid.x), 0, FIELD_SIDE - 2)
	var z0 := clampi(floori(grid.y), 0, FIELD_SIDE - 2)
	var tx := clampf(grid.x - float(x0), 0.0, 1.0)
	var tz := clampf(grid.y - float(z0), 0.0, 1.0)
	var a: Dictionary = values[z0 * FIELD_SIDE + x0]
	var b: Dictionary = values[z0 * FIELD_SIDE + x0 + 1]
	var c: Dictionary = values[(z0 + 1) * FIELD_SIDE + x0]
	var d: Dictionary = values[(z0 + 1) * FIELD_SIDE + x0 + 1]
	return {
		"coverage": lerpf(lerpf(float(a.coverage), float(b.coverage), tx),
			lerpf(float(c.coverage), float(d.coverage), tx), tz),
		"land_occupancy": lerpf(lerpf(float(a.land_occupancy),
			float(b.land_occupancy), tx), lerpf(float(c.land_occupancy),
			float(d.land_occupancy), tx), tz),
		"tint": (a.tint as Color).lerp(b.tint, tx).lerp(
			(c.tint as Color).lerp(d.tint, tx), tz),
	}

static func _qualified_surface(program: GrassProgram, anchor: Vector2,
		region: HeightfieldRegion, water: WaterFieldContext,
		paths: PathContext, footprint_radius: float,
		surface_cache: Dictionary = {}, cliff_edge_cache: Dictionary = {},
		known_physical_edge_scale: float = -1.0) -> Dictionary:
	assert(water.covers(anchor), "Grass water context must cover every tile anchor")
	if paths != null:
		if paths.clearance_at(anchor) < GrassProgram.FEATURE_CLEARANCE:
			return {}
		if _footprint_overlaps_corridor(paths, anchor,
				footprint_radius + PATH_FOOTPRINT_CLEARANCE):
			return {}
	# Signed shoreline distance is negative on wet ground, so this one canonical
	# query replaces a redundant wet() + shore_distance_at() pair.
	if water.shore_distance_at(anchor) < program.shore_clearance:
		return {}
	var gradient := _surface_gradient(region, anchor, surface_cache,
		cliff_edge_cache)
	if gradient.length() > program.max_grade:
		return {}
	var normal := Vector3(-gradient.x, 1.0, -gradient.y).normalized()
	var physical_edge_scale := known_physical_edge_scale if \
		known_physical_edge_scale >= 0.0 else _cliff_scale(
			region, anchor, footprint_radius, cliff_edge_cache)
	if physical_edge_scale < CLIFF_MIN_VISIBLE_SCALE:
		return {}
	return {
		"y": _surface_y(region, surface_cache, anchor.x, anchor.y),
		"normal": normal,
		"area_extra": minf(MAX_SLOPE_EXTRA, 1.0 / normal.y - 1.0),
		"physical_edge_scale": physical_edge_scale,
	}

static func _surface_basis(normal: Vector3) -> Basis:
	var tangent_x := (Vector3.RIGHT - normal * normal.x).normalized()
	var tangent_z := tangent_x.cross(normal).normalized()
	return Basis(tangent_x, normal, tangent_z)

static func _footprint_overlaps_corridor(paths: PathContext,
		anchor: Vector2, radius: float) -> bool:
	if not paths.has_corridors():
		return false
	if paths.corridor_at(anchor):
		return true
	for direction: Vector2 in FOOTPRINT_DIRECTIONS:
		if paths.corridor_at(anchor + direction * radius):
			return true
	return false

static func _cliff_scale(region: HeightfieldRegion,
		anchor: Vector2, footprint_radius: float,
		edge_cache: Dictionary = {}) -> float:
	var cell := Vector2i(roundi(anchor.x / TerrainSurfaceField.TILE),
		roundi(anchor.y / TerrainSurfaceField.TILE))
	var local := anchor - Vector2(cell) * TerrainSurfaceField.TILE
	var high_edge_distance := INF
	var low_edge_distance := INF
	var masks := _cliff_masks(region, cell, edge_cache)
	var boundary_mask := masks.x
	var high_mask := masks.y
	for index in CARDINALS.size():
		if (boundary_mask & (1 << index)) == 0:
			continue
		var direction: Vector2i = CARDINALS[index]
		var centre_distance := TerrainSurfaceField.HALF \
			- local.dot(Vector2(direction))
		if (high_mask & (1 << index)) != 0:
			high_edge_distance = minf(high_edge_distance, centre_distance)
		else:
			low_edge_distance = minf(low_edge_distance, centre_distance)
	var edge_distance := minf(high_edge_distance, low_edge_distance)
	if is_inf(edge_distance):
		return 1.0
	var footprint_clearance := maxf(0.0, edge_distance - footprint_radius)
	var minimum_scale := CLIFF_EDGE_MIN_SCALE if \
		high_edge_distance <= low_edge_distance else 1.0
	var taper_scale := lerpf(minimum_scale, 1.0,
		smoothstep(0.0, CLIFF_TAPER_DISTANCE, footprint_clearance))
	var contained_scale := 1.0 if is_inf(high_edge_distance) else clampf(
		(high_edge_distance - CLIFF_FOOTPRINT_MARGIN) / footprint_radius, 0.0, 1.0)
	return minf(taper_scale, contained_scale)

static func _tile_has_coverage_edge(tile_fields: Array[Dictionary]) -> bool:
	var has_grass := false
	var has_less_than_full := false
	for sample: Dictionary in tile_fields:
		var projected := carpet_coverage(float(sample.coverage) \
			* float(sample.land_occupancy))
		has_grass = has_grass or projected > 0.0
		has_less_than_full = has_less_than_full or projected < 0.999
	return has_grass and has_less_than_full

static func _tile_has_cliff_lip(region: HeightfieldRegion, origin: Vector2,
		edge_cache: Dictionary) -> bool:
	var first := Vector2i(roundi(origin.x / TerrainSurfaceField.TILE),
		roundi(origin.y / TerrainSurfaceField.TILE))
	var last_point := origin + Vector2.ONE * (TILE_WORLD - 0.001)
	var last := Vector2i(roundi(last_point.x / TerrainSurfaceField.TILE),
		roundi(last_point.y / TerrainSurfaceField.TILE))
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if _cliff_masks(region, Vector2i(x, z), edge_cache).y != 0:
				return true
	return false

## Returns (symmetric boundary mask, high-side mask). Both sides need one-sided
## gradient sampling at the discontinuity. Only the exposed owner tapers and
## needs footprint containment; lower-side blades terminate against the wall.
static func _cliff_masks(region: HeightfieldRegion, cell: Vector2i,
		edge_cache: Dictionary) -> Vector2i:
	if edge_cache.has(cell):
		return edge_cache[cell] as Vector2i
	var boundary_mask := 0
	var high_mask := 0
	for index in CARDINALS.size():
		var direction: Vector2i = CARDINALS[index]
		var high_here := TerrainSurfaceField.is_exposed_edge(
			region, cell.x, cell.y, direction)
		var high_there := TerrainSurfaceField.is_exposed_edge(region,
			cell.x + direction.x, cell.y + direction.y, -direction)
		if high_here or high_there:
			boundary_mask |= 1 << index
		if high_here:
			high_mask |= 1 << index
	var masks := Vector2i(boundary_mask, high_mask)
	edge_cache[cell] = masks
	return masks

## A centred derivative crossing a vertical discontinuity falsely classifies a
## metre-wide strip as over-grade. At a cliff boundary, use the sample on the
## anchor's own side instead. Ordinary walkable seams retain the centred
## derivative, including their shared smootherstep slope.
static func _surface_gradient(region: HeightfieldRegion, anchor: Vector2,
		surface_cache: Dictionary, edge_cache: Dictionary = {}) -> Vector2:
	var step := DressingCompiler.SURFACE_STENCIL
	var cell := Vector2i(roundi(anchor.x / TerrainSurfaceField.TILE),
		roundi(anchor.y / TerrainSurfaceField.TILE))
	var local := anchor - Vector2(cell) * TerrainSurfaceField.TILE
	var boundary_mask := _cliff_masks(region, cell, edge_cache).x
	var centre := _surface_y(region, surface_cache, anchor.x, anchor.y)
	var left_crosses := (boundary_mask & (1 << 1)) != 0 \
		and local.x - step < -TerrainSurfaceField.HALF
	var right_crosses := (boundary_mask & (1 << 0)) != 0 \
		and local.x + step > TerrainSurfaceField.HALF
	var back_crosses := (boundary_mask & (1 << 3)) != 0 \
		and local.y - step < -TerrainSurfaceField.HALF
	var front_crosses := (boundary_mask & (1 << 2)) != 0 \
		and local.y + step > TerrainSurfaceField.HALF
	var gradient_x: float
	if left_crosses:
		gradient_x = (_surface_y(region, surface_cache,
			anchor.x + step, anchor.y) - centre) / step
	elif right_crosses:
		gradient_x = (centre - _surface_y(region, surface_cache,
			anchor.x - step, anchor.y)) / step
	else:
		gradient_x = (_surface_y(region, surface_cache,
			anchor.x + step, anchor.y) - _surface_y(region, surface_cache,
			anchor.x - step, anchor.y)) / (2.0 * step)
	var gradient_z: float
	if back_crosses:
		gradient_z = (_surface_y(region, surface_cache,
			anchor.x, anchor.y + step) - centre) / step
	elif front_crosses:
		gradient_z = (centre - _surface_y(region, surface_cache,
			anchor.x, anchor.y - step)) / step
	else:
		gradient_z = (_surface_y(region, surface_cache,
			anchor.x, anchor.y + step) - _surface_y(region, surface_cache,
			anchor.x, anchor.y - step)) / (2.0 * step)
	return Vector2(gradient_x, gradient_z)

static func _surface_y(region: HeightfieldRegion, cache: Dictionary,
		x: float, z: float) -> float:
	var cell := Vector2i(roundi(x / TerrainSurfaceField.TILE),
		roundi(z / TerrainSurfaceField.TILE))
	if not cache.has(cell):
		cache[cell] = TerrainSurfaceField.bake_cell(region, cell.x, cell.y)
	return TerrainSurfaceField.sample_baked(cache[cell], cell.x, cell.y, x, z)

static func _biome_dot(values: PackedFloat32Array, weights: Dictionary) -> float:
	var total := 0.0
	var biome_ids := BiomeRegistry.biome_ids()
	for index in biome_ids.size():
		total += values[index] * float(weights[biome_ids[index]])
	return total

static func _choose_asset(ids: Array[StringName], roll: float) -> StringName:
	return ids[mini(int(floor(roll * ids.size())), ids.size() - 1)]

static func _tile_identity(world_seed: int, seed_version: int,
		tile: Vector2i) -> int:
	return Helper._mix64(world_seed ^ Helper._mix64(seed_version) \
		^ Helper._mix64(tile.x ^ SALT_TILE_X) \
		^ Helper._mix64(tile.y ^ SALT_TILE_Z))

static func _roll(identity: int, salt: int) -> float:
	return Helper._hash01(Helper._mix64(identity ^ salt))

static func _candidate_less(a: Dictionary, b: Dictionary) -> bool:
	return a.key < b.key or (a.key == b.key and a.slot < b.slot)

static func _write_instance(buffer: PackedFloat32Array, index: int,
		transform: Transform3D, color: Color, sway: float, rank: float) -> void:
	var offset := index * GrassPayload.FLOATS_PER_INSTANCE
	var basis := transform.basis
	buffer[offset + 0] = basis.x.x
	buffer[offset + 1] = basis.y.x
	buffer[offset + 2] = basis.z.x
	buffer[offset + 3] = transform.origin.x
	buffer[offset + 4] = basis.x.y
	buffer[offset + 5] = basis.y.y
	buffer[offset + 6] = basis.z.y
	buffer[offset + 7] = transform.origin.y
	buffer[offset + 8] = basis.x.z
	buffer[offset + 9] = basis.y.z
	buffer[offset + 10] = basis.z.z
	buffer[offset + 11] = transform.origin.z
	buffer[offset + 12] = color.r
	buffer[offset + 13] = color.g
	buffer[offset + 14] = color.b
	buffer[offset + 15] = color.a
	buffer[offset + 16] = sway
	buffer[offset + 17] = rank
	buffer[offset + 18] = 0.0
	buffer[offset + 19] = 0.0
