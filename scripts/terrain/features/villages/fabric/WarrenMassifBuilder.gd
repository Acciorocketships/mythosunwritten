class_name WarrenMassifBuilder
extends RefCounted

## Builds the terraced solid massif. Heights come from a warped Gaussian
## quantised into 1-2 band terrace risers, with radial spur/notch warping so
## silhouettes vary per seed. Gates reject domes, low cores, and plateaus.
const RADIUS_CELLS := 12
const MIN_CORE_BANDS := 16
const MAX_CORE_BANDS := 20
const MIN_TERRACE_LEVELS := 5
const MAX_PLATEAU_CELLS := 6
const MIN_COLUMN_BANDS := 2
# A Gaussian's outer tail is asymptotically flat by construction, so the ring
# just inside the MIN_COLUMN_BANDS cutoff barely changes in raw height over
# many cells; a narrow jitter (e.g. +/-1) leaves that ring's pre-quantisation
# value constant across a wide arc and produces >6-cell plateaus. Widened to
# +/-8 to break those rings up (see task-1-report.md for the seed sweep).
const TERRACE_JITTER_SPAN := 17
# IMPORTANT: existence (whether a column is in the massif at all) is decided
# from the smooth pre-jitter `raw` value, never from the jittered terrace.
# An earlier version gated existence on the jittered value directly, which
# tied column presence to the same per-cell noise breaking up plateaus and
# fractured the mass into 30-60 disconnected islands (largest as small as
# ~75% of the columns) -- the opposite of "solid". Because `raw` is monotonic
# along every ray from the centre (the angular warp only rescales radius, it
# never makes height increase outward), thresholding on it alone yields one
# simply-connected, hole-free footprint regardless of jitter magnitude.
# TERRACE_UNDERSHOOT_FOLD then wraps (never clamps) any jittered terrace that
# would otherwise dip below MIN_COLUMN_BANDS back into a small, still-varied
# band above it -- clamping every undershoot to one fixed floor recreates a
# giant same-height ring around the whole boundary (worst case seen: 48
# cells); wrapping keeps the per-cell variation that avoids that.
const TERRACE_UNDERSHOOT_FOLD := 16

static var last_failure := ""


static func build(world_seed: int,
		ground_bands: Dictionary = {}) -> WarrenMassif:
	last_failure = ""
	var massif := WarrenMassif.new(world_seed)
	var core := MIN_CORE_BANDS + posmod(_hash(world_seed, 5, 0, 0),
		MAX_CORE_BANDS - MIN_CORE_BANDS + 1)
	var warp_phase := float(posmod(_hash(world_seed, 7, 0, 0), 1000)) \
		/ 1000.0 * TAU
	var warp_strength := 0.22 + float(posmod(_hash(world_seed, 11, 0, 0),
		100)) / 100.0 * 0.18
	for z in range(-RADIUS_CELLS, RADIUS_CELLS + 1):
		for x in range(-RADIUS_CELLS, RADIUS_CELLS + 1):
			var column := Vector2i(x, z)
			var radius := Vector2(float(x), float(z)).length()
			var angle := atan2(float(z), float(x))
			var warped := radius * (1.0 + warp_strength \
				* sin(angle * 3.0 + warp_phase))
			var gaussian := exp(-pow(warped / float(RADIUS_CELLS) * 1.9,
				2.0))
			var raw := float(core) * gaussian
			if raw < float(MIN_COLUMN_BANDS):
				continue
			var jitter := posmod(_hash(world_seed, 13, x, z),
				TERRACE_JITTER_SPAN) - TERRACE_JITTER_SPAN / 2
			var terrace := _quantise_terrace(raw, world_seed, x, z) + jitter
			if terrace < MIN_COLUMN_BANDS:
				terrace = MIN_COLUMN_BANDS + posmod(
					terrace - MIN_COLUMN_BANDS, TERRACE_UNDERSHOOT_FOLD)
			var base := int(ground_bands.get(column, 0))
			massif.columns[column] = {
				"base": base,
				"top": base + terrace,
				"terrace": terrace,
			}
	massif.core_top_bands = 0
	for column: Vector2i in massif.columns:
		massif.core_top_bands = maxi(massif.core_top_bands,
			massif.top_at(column) - massif.base_at(column))
	if massif.core_top_bands < MIN_CORE_BANDS:
		last_failure = "core reaches %d bands; %d required" % [
			massif.core_top_bands, MIN_CORE_BANDS]
		return null
	if massif.terrace_levels().size() < MIN_TERRACE_LEVELS:
		last_failure = "only %d terrace levels" \
			% massif.terrace_levels().size()
		return null
	if massif.widest_plateau_cells() > MAX_PLATEAU_CELLS:
		last_failure = "plateau of %d cells exceeds %d" % [
			massif.widest_plateau_cells(), MAX_PLATEAU_CELLS]
		return null
	if not massif.seal():
		last_failure = "empty massif"
		return null
	return massif


static func _quantise_terrace(raw_bands: float, world_seed: int, x: int,
		z: int) -> int:
	## Snap to 1-2 band risers; the riser rhythm itself is seed-varied so
	## terraces do not repeat one global step size.
	var riser := 1 + posmod(_hash(world_seed, 17, x / 4, z / 4), 2)
	return int(floorf(raw_bands / float(riser))) * riser


static func _hash(world_seed: int, salt: int, x: int, z: int) -> int:
	var value := world_seed * 73856093 ^ salt * 19349663 \
		^ x * 83492791 ^ z * 2971215073
	value = posmod(value, 2147483647)
	return value
