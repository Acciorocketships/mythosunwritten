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
	# TASK I1: the radius floor was 6, one under the smallest profile of the
	# day. It is 4 for the same reason and by the same rule — one under the
	# smallest profile there is, which is now compact's 5. The floor is a
	# degenerate-input guard, not a design statement: what actually decides how
	# small a town may be is `WarrenMassifBuilder`'s terrace-level gate, which a
	# radius-4 footprint cannot satisfy at any core.
	return scale_id in IDS and radius_cells >= 4 \
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
	# Reviewed sizing (2026-08-14): the former radius-12 large town read as a
	# metropolis in review captures. Footprints shrink to village scale —
	# a standard town is roughly one fifth of that reviewed city's mass —
	# while core heights stay nearly unchanged, so the hill remains tall and
	# the warren remains vertical; only the sprawl contracts. Feature quotas
	# scale with the smaller fabric so the gates stay satisfiable.
	#
	# TASK I1 (2026-08-26). The user's /goal — "i also want the city to be
	# smaller, it's too big now" — against reference frames whose village core
	# is a few dozen houses. The 2026-08-14 sentence above is applied a second
	# time and its exact terms are what moved: THE FOOTPRINT RADIUS IS THE WHOLE
	# CUT (7/8/9/11 → 5/6/7/8) and the core MINIMA are untouched, so the hill
	# keeps its height and only the sprawl contracts again.
	#
	# WHY RADIUS AND NOTHING ELSE. The footprint is a Gaussian level set, so its
	# column count is quadratic in `radius_cells` and the building count is very
	# nearly linear in the column count (measured 0.55-0.85 buildings per column
	# across the four scales). Every other candidate lever was measured on the
	# 12-seed corpus and rejected on the measurement, not on taste:
	# `room_volume_budget` is guidance the solver records and never gates on;
	# `residual_room_budget`/`residual_kind_budget` are ceilings the residual
	# backfill never reaches (compact 6→3 leaves every town's count byte-
	# identical); `WarrenPlotPlanner.BUILDING_CAP` +2 on every scale moved the
	# compact corpus mean 36.0 → 35.9; and the alley/spine budgets only reshuffle
	# which columns front a street. The full lever map is in the task I1 report.
	#
	# THE CORE MAXIMA WIDEN BY TWO BANDS, which is a SEAL lever rather than a
	# height lever: `footprint_core` rolls over [min, max] and a wider roll gives
	# the terraced field more distinct fields to try, and the per-depth terrace
	# ceiling still holds every measured town's crown at its own minimum (every
	# sealed compact town measures core_top_bands = 12, exactly as before).
	#
	# MEASURED over seeds 1-12 at each scale, buildings per sealed town,
	# before → after: compact 59.5 → 29.4 mean (44-82 → 14-46), standard
	# 89.4 → 49.2 (63-109 → 23-63), large 134.0 → 85.4 (116-153 → 55-112),
	# grand 236 → ~108 (one town → 99-120). Column counts fall 96 → 52,
	# 129 → 78, 172 → ~105, 252 → 132 at the medians. See
	# `WarrenMassifBuilder.MIN_CLUSTER_CELLS` and `FIELD_PHASE_ATTEMPTS` for the
	# two builder constants that had to follow the footprint down for the
	# smaller field to seal at all, and STANDARD's own note below for the one
	# street term that had to follow it too.
	match id:
		COMPACT:
			return WarrenVillageScaleProfile.new(COMPACT, 5,
				Vector2i(12, 17), Vector2i(12, 18), Vector2i(5, 7),
				4, 16, Vector2i(10, 30), 6, 2, Vector2i(1, 1),
				Vector2i(0, 2), Vector2i.ZERO, Vector2i(4, 4), 0.29, false,
				false)
		STANDARD:
			# The one street term that moved, and it moved because it was
			# MEASURED to. `route_span_range.x` is how many bands the single
			# spine must CLIMB between its portal and the summit; the core is
			# unchanged at 13 bands but the footprint that has to carry the
			# climb is a third smaller, so a six-band demand is a steeper spine
			# on a shorter hill. At 6 this corpus seals 10 of 12 — seed 3 at
			# `bridge room ... has no built flank` and seed 10 at a retained
			# cross-lineage room; at 5 it seals 12 of 12 with both of those
			# towns' counts inside the band (47 and 54 buildings). The MAXIMUM
			# is untouched at 8 and provably does not bind: (5,7) and (5,8)
			# produce byte-identical counts on all twelve seeds.
			return WarrenVillageScaleProfile.new(STANDARD, 6,
				Vector2i(13, 17), Vector2i(14, 22), Vector2i(5, 8),
				5, 20, Vector2i(16, 60), 8, 3, Vector2i(1, 2),
				Vector2i(1, 3), Vector2i.ZERO, Vector2i(4, 5), 0.33, false,
				false)
		LARGE:
			# Skywalk range minimum below maximum: request the richer link
			# count, but the sealed occluder ranking may keep fewer when an
			# extra link provably adds no distinct inhabited route coverage.
			return WarrenVillageScaleProfile.new(LARGE, 7,
				Vector2i(14, 18), Vector2i(16, 26), Vector2i(6, 9),
				8, 32, Vector2i(25, 70), 12, 4, Vector2i(2, 3),
				Vector2i(3, 4), Vector2i.ZERO, Vector2i(5, 6), 0.38, true)
		GRAND:
			# The core maximum stops at `WarrenMassif.BUILDABLE_LAYER_BANDS`
			# and not at the +2 the other three scales take: the massif suite
			# holds every profile to "may not ask for more mass than the
			# compiler builds", and 18 is what the compiler builds.
			return WarrenVillageScaleProfile.new(GRAND, 8,
				Vector2i(15, 18), Vector2i(20, 30), Vector2i(7, 10),
				10, 40, Vector2i(40, 110), 16, 5, Vector2i(3, 4),
				Vector2i(4, 6), Vector2i.ZERO, Vector2i(6, 8), 0.38, true)
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
