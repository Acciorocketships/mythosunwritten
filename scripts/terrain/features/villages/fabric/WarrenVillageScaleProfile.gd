class_name WarrenVillageScaleProfile
extends RefCounted

## Pure, immutable-by-convention source-plan budget for one volumetric village.
## Selection happens before the massif exists; later stages consume these
## values and may not crop a larger sealed town or scale authored meshes.
const COMPACT := &"compact"
const STANDARD := &"standard"
const LARGE := &"large"
const GRAND := &"grand"
const IDS: Array[StringName] = [COMPACT, STANDARD, LARGE, GRAND]

## 55 / 30 / 12 / 3 percent. Integer thresholds keep selection exact and
## independent of floating-point platform details.
const ROLL_DENOMINATOR := 10000
const COMPACT_END := 5500
const STANDARD_END := 8500
const LARGE_END := 9700

var scale_id: StringName
var radius_cells: int
var minimum_core_bands: int
var maximum_core_bands: int
var route_cell_range: Vector2i
var route_span_range: Vector2i
var lane_budget: int
var lane_cell_budget: int
var room_volume_budget: Vector2i
var residual_room_budget: int
var residual_kind_budget: int
var skywalk_range: Vector2i
var balcony_range: Vector2i
var cantilever_range: Vector2i
var landmark_range: Vector2i
var minimum_inhabited_overhead_ratio: float
var requires_elevated_courtyard: bool
var requires_covered_market: bool


func _init(p_scale_id: StringName, p_radius_cells: int,
		p_core_bands: Vector2i, p_route_cell_range: Vector2i,
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
	minimum_core_bands = p_core_bands.x
	maximum_core_bands = p_core_bands.y
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
	return scale_id in IDS and radius_cells >= 6 \
		and _positive_range(Vector2i(minimum_core_bands,
			maximum_core_bands)) \
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
	return "%s/r%d/core%d-%d/route%d-%d/span%d-%d/lanes%d:%d/rooms%d-%d/residual%d:%d/sky%d-%d/bal%d-%d/cant%d-%d/land%d-%d/over%.3f/court%d/market%d" % [
		String(scale_id), radius_cells, minimum_core_bands, maximum_core_bands,
		route_cell_range.x, route_cell_range.y, route_span_range.x,
		route_span_range.y, lane_budget, lane_cell_budget,
		room_volume_budget.x, room_volume_budget.y,
		residual_room_budget, residual_kind_budget, skywalk_range.x,
		skywalk_range.y, balcony_range.x, balcony_range.y,
		cantilever_range.x, cantilever_range.y, landmark_range.x,
		landmark_range.y, minimum_inhabited_overhead_ratio,
		int(requires_elevated_courtyard),
		int(requires_covered_market)]


static func select(city_seed: int) -> WarrenVillageScaleProfile:
	var mixed := Helper._mix64(city_seed ^ 0x4f1bbcdc)
	return from_roll(posmod(mixed, ROLL_DENOMINATOR))


static func from_roll(roll: int) -> WarrenVillageScaleProfile:
	assert(roll >= 0 and roll < ROLL_DENOMINATOR)
	if roll < COMPACT_END:
		return for_id(COMPACT)
	if roll < STANDARD_END:
		return for_id(STANDARD)
	if roll < LARGE_END:
		return for_id(LARGE)
	return for_id(GRAND)


static func for_id(id: StringName) -> WarrenVillageScaleProfile:
	match id:
		COMPACT:
			return WarrenVillageScaleProfile.new(COMPACT, 10,
				Vector2i(14, 17), Vector2i(29, 35), Vector2i(7, 9),
				8, 34, Vector2i(18, 110), 12, 3, Vector2i(1, 1),
				Vector2i(2, 3), Vector2i(4, 4), Vector2i(0, 0), 0.29, false)
		STANDARD:
			return WarrenVillageScaleProfile.new(STANDARD, 11,
				Vector2i(15, 18), Vector2i(29, 35), Vector2i(7, 9),
				10, 42, Vector2i(30, 190), 16, 4, Vector2i(2, 2),
				Vector2i(5, 5), Vector2i(5, 5), Vector2i(1, 1), 0.33, false)
		LARGE:
			# Skywalk range (3, 4): request four links, but the sealed occluder
			# ranking may keep three when the fourth provably adds no distinct
			# inhabited route coverage. The raw four-link experiment measured
			# zero coverage gain, so link count alone is not the contract.
			return WarrenVillageScaleProfile.new(LARGE, 12,
				Vector2i(16, 18), Vector2i(30, 36), Vector2i(8, 10),
				16, 64, Vector2i(50, 220), 24, 6, Vector2i(3, 4),
				Vector2i(6, 8), Vector2i(6, 8), Vector2i(2, 2), 0.38, true)
		GRAND:
			return WarrenVillageScaleProfile.new(GRAND, 14,
				Vector2i(16, 18), Vector2i(32, 40), Vector2i(8, 12),
				20, 80, Vector2i(80, 300), 32, 8, Vector2i(3, 4),
				Vector2i(8, 12), Vector2i(8, 12), Vector2i(3, 3), 0.38, true)
		_:
			return null


static func review_fixture() -> WarrenVillageScaleProfile:
	## Explicit escape hatch for the adversarial existing showcase. Production
	## must call select(); harnesses use the exact legacy radius-12 constraints
	## so screenshot comparisons do not silently change scale.
	return for_id(LARGE)


static func _positive_range(value: Vector2i) -> bool:
	return value.x > 0 and value.y >= value.x


static func _nonnegative_range(value: Vector2i) -> bool:
	return value.x >= 0 and value.y >= value.x
