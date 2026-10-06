class_name WarrenVillageScaleProfile
extends RefCounted

## Pure, immutable-by-convention source-plan budget for one volumetric village.
## Selection happens before the massif exists; later stages consume these
## values and may not crop a larger sealed town or scale authored meshes.
##
## ONE DISTRIBUTION (September 27 owner review). Every town is a sample of the
## same algorithm: `size` is a continuous draw in [0, 1] and every budget is a
## piecewise-linear function of it. The four named ids are only reference
## points on that curve (sizes 0, 1/3, 2/3, 1) used by the corpus and tests,
## and `scale_id` is the nearest one, kept as a label. No generation stage may
## branch on the label; stages read budgets, or `scaled()` for their own
## per-size tables.
const COMPACT := &"compact"
const STANDARD := &"standard"
const LARGE := &"large"
const GRAND := &"grand"
const IDS: Array[StringName] = [COMPACT, STANDARD, LARGE, GRAND]

const ROLL_DENOMINATOR := 10000
## size = roll^SIZE_EXPONENT: small towns stay common (about two in three fall
## nearer the compact anchor than the standard one, one in ten past large).
const SIZE_EXPONENT := 4.0
const ANCHOR_SIZES := {COMPACT: 0.0, STANDARD: 1.0 / 3.0, LARGE: 2.0 / 3.0,
	GRAND: 1.0}

## Budgets at the four reference sizes, in constructor order after the label:
## radius, core target bands, core floor, route cells, route span, lanes, lane
## cells, room budget, residual rooms, residual kinds, skywalks, balconies,
## cantilevers, landmarks, overhead ratio. WORLD SCALE: the source massif stays
## on the authored 3 m macro lattice; the production frame maps the whole
## sealed town to 8 m world macro cells, so budgets scale parcel counts, never
## meshes. Radius is what grows a town: its footprint is a Gaussian-mixture
## level set whose building and street opportunities grow with that field.
const BUDGETS := {
	COMPACT: [5, Vector2i(10, 14), 6, Vector2i(8, 14), Vector2i(3, 5), 5, 20,
		Vector2i(6, 20), 4, 1, Vector2i(1, 4), Vector2i(0, 1), Vector2i.ZERO,
		Vector2i(5, 6), 0.29],
	STANDARD: [6, Vector2i(13, 17), 10, Vector2i(14, 22), Vector2i(5, 8), 7, 28,
		Vector2i(12, 35), 6, 2, Vector2i(2, 5), Vector2i(1, 3), Vector2i.ZERO,
		Vector2i(7, 8), 0.33],
	LARGE: [7, Vector2i(14, 18), 12, Vector2i(16, 26), Vector2i(6, 9), 10, 40,
		Vector2i(18, 50), 8, 3, Vector2i(3, 6), Vector2i(3, 4), Vector2i.ZERO,
		Vector2i(8, 9), 0.38],
	GRAND: [8, Vector2i(15, 18), 14, Vector2i(20, 30), Vector2i(7, 10), 12, 48,
		Vector2i(25, 75), 12, 4, Vector2i(4, 7), Vector2i(4, 6), Vector2i.ZERO,
		Vector2i(9, 10), 0.38],
}

var scale_id: StringName
## Continuous position on the one size distribution, 0 (compact) .. 1 (grand).
var size := 0.0
var radius_cells: int
## The lowest finished crown that still contains the complete stepped-town
## grammar. This is a validity floor, not a random-distribution parameter.
var minimum_core_bands: int
## Preferred source crown distribution. Keeping this separate means relaxing
## a proof floor cannot silently reroll the shape of every already-valid town.
var core_target_band_range: Vector2i
var maximum_core_bands: int
var route_cell_range: Vector2i
var route_span_range: Vector2i
var lane_budget: int
var lane_cell_budget: int
var room_volume_budget: Vector2i
var residual_room_budget: int
var residual_kind_budget: int
## Additional opportunities for supported inhabited crossings; source geometry
## still proves both endpoints and may yield fewer than the quota.
var skywalk_range: Vector2i
var balcony_range: Vector2i
var cantilever_range: Vector2i
var landmark_range: Vector2i
var minimum_inhabited_overhead_ratio: float
var requires_elevated_courtyard: bool
var requires_covered_market: bool
## The town's drawn odds (TownCharacter). Set per town by
## WarrenVolumetricSolver._generate / TownCharacter.of; never part of the
## size budgets above.
var character: TownCharacter


func _init(p_scale_id: StringName, p_radius_cells: int,
		p_core_target_bands: Vector2i, p_minimum_core_bands: int,
		p_route_cell_range: Vector2i,
		p_route_span_range: Vector2i, p_lane_budget: int,
		p_lane_cell_budget: int, p_room_volume_budget: Vector2i,
		p_residual_room_budget: int, p_residual_kind_budget: int,
		p_skywalk_range: Vector2i, p_balcony_range: Vector2i,
		p_cantilever_range: Vector2i, p_landmark_range: Vector2i,
		p_minimum_inhabited_overhead_ratio: float,
		p_requires_elevated_courtyard: bool,
		p_requires_covered_market: bool = true) -> void:
	scale_id = p_scale_id
	radius_cells = p_radius_cells
	minimum_core_bands = p_minimum_core_bands
	core_target_band_range = p_core_target_bands
	maximum_core_bands = p_core_target_bands.y
	route_cell_range = p_route_cell_range
	route_span_range = p_route_span_range
	lane_budget = p_lane_budget
	lane_cell_budget = p_lane_cell_budget
	room_volume_budget = p_room_volume_budget
	residual_room_budget = p_residual_room_budget
	residual_kind_budget = p_residual_kind_budget
	skywalk_range = p_skywalk_range
	balcony_range = p_balcony_range
	cantilever_range = p_cantilever_range
	landmark_range = p_landmark_range
	minimum_inhabited_overhead_ratio = p_minimum_inhabited_overhead_ratio
	requires_elevated_courtyard = p_requires_elevated_courtyard
	requires_covered_market = p_requires_covered_market
	assert(validate())


func validate() -> bool:
	# Radius four remains the generic degenerate-input guard for explicit test
	# profiles; production's selected radii are 5/6/7/8. What actually decides
	# whether a footprint can form a town is `WarrenMassifBuilder`'s
	# terrace-level gate, not a validation minimum coupled to today's profiles.
	return scale_id in IDS and radius_cells >= 4 \
		and minimum_core_bands > 0 \
		and _positive_range(core_target_band_range) \
		and minimum_core_bands <= core_target_band_range.x \
		and _positive_range(route_cell_range) \
		and _positive_range(route_span_range) \
		and lane_budget > 0 and lane_cell_budget >= lane_budget \
		and _positive_range(room_volume_budget) \
		and residual_room_budget > 0 and residual_kind_budget > 0 \
		and residual_kind_budget * 4 >= residual_room_budget \
		and residual_room_budget <= room_volume_budget.y \
		and _nonnegative_range(skywalk_range) and skywalk_range.x >= 1 \
		and _nonnegative_range(balcony_range) \
		and _nonnegative_range(cantilever_range) \
		and _nonnegative_range(landmark_range) \
		and minimum_inhabited_overhead_ratio > 0.0 \
		and minimum_inhabited_overhead_ratio <= 0.5


func deterministic_signature() -> String:
	var text := "%s@%.4f/r%d/core-floor%d/target%d-%d/route%d-%d/span%d-%d/lanes%d:%d/rooms%d-%d/residual%d:%d/sky%d-%d/bal%d-%d/cant%d-%d/land%d-%d/over%.3f/court%d/market%d" % [
		String(scale_id), size, radius_cells, minimum_core_bands,
		core_target_band_range.x, core_target_band_range.y,
		route_cell_range.x, route_cell_range.y, route_span_range.x,
		route_span_range.y, lane_budget, lane_cell_budget,
		room_volume_budget.x, room_volume_budget.y,
		residual_room_budget, residual_kind_budget, skywalk_range.x,
		skywalk_range.y, balcony_range.x, balcony_range.y,
		cantilever_range.x, cantilever_range.y, landmark_range.x,
		landmark_range.y, minimum_inhabited_overhead_ratio,
		int(requires_elevated_courtyard),
		int(requires_covered_market)]
	return text + (character.signature_suffix() if character != null else "")


static func select(city_seed: int) -> WarrenVillageScaleProfile:
	var mixed := Helper._mix64(city_seed ^ 0x4f1bbcdc)
	return from_roll(posmod(mixed, ROLL_DENOMINATOR))


static func from_roll(roll: int) -> WarrenVillageScaleProfile:
	assert(roll >= 0 and roll < ROLL_DENOMINATOR)
	return from_size(pow(float(roll) / float(ROLL_DENOMINATOR - 1),
		SIZE_EXPONENT))


static func for_id(id: StringName) -> WarrenVillageScaleProfile:
	## A reference point on the size curve (tests, corpus, review fixtures).
	if not ANCHOR_SIZES.has(id):
		return null
	return from_size(float(ANCHOR_SIZES[id]))


static func from_record(id: StringName, recorded_size: Variant) -> WarrenVillageScaleProfile:
	## The profile a sealed plan recorded: its exact size when present, else
	## the named reference point (plans sealed before sizes were recorded).
	if recorded_size != null:
		return from_size(float(recorded_size))
	return for_id(id)


static func from_size(value: float) -> WarrenVillageScaleProfile:
	var t := clampf(value, 0.0, 1.0)
	var args: Array = []
	for index in (BUDGETS[COMPACT] as Array).size():
		args.append(_interpolate(index, t))
	# Residual kinds must be able to hold the residual rooms (four per kind).
	args[9] = maxi(int(args[9]), ceili(float(args[8]) / 4.0))
	var label := COMPACT
	for id: StringName in IDS:
		if absf(float(ANCHOR_SIZES[id]) - t) < absf(float(ANCHOR_SIZES[label]) - t):
			label = id
	var profile := WarrenVillageScaleProfile.new(label, args[0], args[1],
		args[2], args[3], args[4], args[5], args[6], args[7], args[8],
		args[9], args[10], args[11], args[12], args[13], args[14],
		t >= 0.5, t >= 0.5)
	profile.size = t
	return profile


func scaled(table: Dictionary) -> Variant:
	## This town's value from a per-reference-size table ({COMPACT: v, ...}):
	## ints and Vector2i round, floats blend.
	return _blend([table[COMPACT], table[STANDARD], table[LARGE],
		table[GRAND]], size)


static func _interpolate(index: int, t: float) -> Variant:
	var values: Array = []
	for id: StringName in IDS:
		values.append((BUDGETS[id] as Array)[index])
	return _blend(values, t)


static func _blend(values: Array, t: float) -> Variant:
	var span := clampf(t, 0.0, 1.0) * float(values.size() - 1)
	var lower := mini(floori(span), values.size() - 2)
	var w := span - float(lower)
	var a: Variant = values[lower]
	var b: Variant = values[lower + 1]
	if a is Vector2i:
		# A range between two reference sizes spans both: its floor rounds
		# down and its ceiling up, so no in-between town is asked for more
		# than either neighbour could build.
		return Vector2i(floori(lerpf(float(a.x), float(b.x), w) + 0.0001),
			ceili(lerpf(float(a.y), float(b.y), w) - 0.0001))
	if a is int:
		return roundi(lerpf(float(a), float(b), w))
	return lerpf(float(a), float(b), w)


static func review_fixture() -> WarrenVillageScaleProfile:
	## Explicit escape hatch for the adversarial showcase. Production must call
	## select(); harnesses use one named size contract so screenshot comparisons
	## do not silently change tier.
	return for_id(LARGE)


static func _positive_range(value: Vector2i) -> bool:
	return value.x > 0 and value.y >= value.x


static func _nonnegative_range(value: Vector2i) -> bool:
	return value.x >= 0 and value.y >= value.x
