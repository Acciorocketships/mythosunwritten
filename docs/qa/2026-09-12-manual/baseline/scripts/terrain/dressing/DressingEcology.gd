class_name DressingEcology
extends RefCounted

const MICRO_SALT := 0x6A09E667
const COMMUNITY_X_SALT := 0x510E527F
const COMMUNITY_Z_SALT := 0x9B05688C
const COMMUNITY_VALUE_SALT := 0x1F83D9AB
const CLEARING_SALT := 0x5BE0CD19
const PATH_X_SALT := 0xC1059ED8
const PATH_Z_SALT := 0x367CD507
const CLEARING_SCALE := 228.0
const CLEARING_COVERAGE := 0.84
const CLEARING_SOFTNESS := 0.05
const PATH_SCALE := 144.0
const PATH_HALF_WIDTH := 3.0
const PATH_FEATHER := 4.0

## A shared two-scale latent field: broad patches with enough smaller structure
## to avoid featureless blobs. It remains a pure function of world position.
static func habitat01(point: Vector2, world_seed: int,
		channel_hash: int, scale: float) -> float:
	var pos := Vector3(point.x, 0.0, point.y)
	var macro := Helper._value_noise01(pos, world_seed ^ channel_hash, scale)
	var micro := Helper._value_noise01(pos,
		world_seed ^ channel_hash ^ MICRO_SALT, scale * 0.37)
	return 0.72 * macro + 0.28 * micro

## Coverage controls genuine negative space. INTERIOR occupies the high side,
## EXTERIOR the complementary clearing, and EDGE a finite ecotone band.
static func suitability(value: float, coverage: float,
		preference: int, softness: float) -> float:
	coverage = clampf(coverage, 0.0, 1.0)
	softness = clampf(softness, 0.001, 0.49)
	if preference == DressingHabitatLayer.Preference.INTERIOR:
		if coverage <= 0.0:
			return 0.0
		if coverage >= 1.0:
			return 1.0
		var threshold := 1.0 - coverage
		return smoothstep(threshold - softness, threshold + softness, value)
	if preference == DressingHabitatLayer.Preference.EXTERIOR:
		if coverage <= 0.0:
			return 1.0
		if coverage >= 1.0:
			return 0.0
		var threshold := 1.0 - coverage
		return 1.0 - smoothstep(threshold - softness, threshold + softness, value)
	if coverage <= 0.0 or coverage >= 1.0:
		return 0.0
	var distance := absf(value - (1.0 - coverage))
	return 1.0 - smoothstep(softness, softness * 2.0, distance)

## Irregular jittered-Voronoi communities. Every point in a community shares
## one uniform roll, so nearby variants form species neighbourhoods instead of
## confetti while boundaries remain non-grid-aligned.
static func community_roll(point: Vector2, world_seed: int,
		channel_hash: int, scale: float) -> float:
	assert(scale > 0.0)
	var base := Vector2i(floori(point.x / scale), floori(point.y / scale))
	var best_distance := INF
	var best_cell := base
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cell := base + Vector2i(dx, dz)
			var centre := Vector2(
				(float(cell.x) + Helper._cell_hash01(
					world_seed ^ channel_hash ^ COMMUNITY_X_SALT, cell.x, cell.y)) * scale,
				(float(cell.y) + Helper._cell_hash01(
					world_seed ^ channel_hash ^ COMMUNITY_Z_SALT, cell.x, cell.y)) * scale)
			var distance := point.distance_squared_to(centre)
			if distance < best_distance:
				best_distance = distance
				best_cell = cell
	return Helper._cell_hash01(world_seed ^ channel_hash ^ COMMUNITY_VALUE_SALT,
		best_cell.x, best_cell.y)

## One world-wide land-occupancy mask shared by every ground population.
## Broad low-frequency clearings combine with the boundary graph of a
## jittered-Voronoi field, whose connected edges read as wandering paths.
## Zero is a construction-level exclusion: no set can independently sprinkle
## itself back into these negative spaces.
static func land_occupancy01(point: Vector2, world_seed: int) -> float:
	var clearing_field := habitat01(point, world_seed, CLEARING_SALT, CLEARING_SCALE)
	var clearing_occupancy := suitability(clearing_field, CLEARING_COVERAGE,
		DressingHabitatLayer.Preference.INTERIOR, CLEARING_SOFTNESS)
	return clearing_occupancy * path_occupancy01(point, world_seed)

static func path_occupancy01(point: Vector2, world_seed: int) -> float:
	var base := Vector2i(floori(point.x / PATH_SCALE), floori(point.y / PATH_SCALE))
	var nearest := INF
	var second := INF
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cell := base + Vector2i(dx, dz)
			var centre := Vector2(
				(float(cell.x) + Helper._cell_hash01(
					world_seed ^ PATH_X_SALT, cell.x, cell.y)) * PATH_SCALE,
				(float(cell.y) + Helper._cell_hash01(
					world_seed ^ PATH_Z_SALT, cell.x, cell.y)) * PATH_SCALE)
			var distance := point.distance_squared_to(centre)
			if distance < nearest:
				second = nearest
				nearest = distance
			elif distance < second:
				second = distance
	var boundary_distance := sqrt(second) - sqrt(nearest)
	return smoothstep(PATH_HALF_WIDTH, PATH_HALF_WIDTH + PATH_FEATHER,
		boundary_distance)
