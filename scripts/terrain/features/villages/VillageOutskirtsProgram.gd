class_name VillageOutskirtsProgram
extends RefCounted

## Optional low-density edge grammar. The dense warren remains the required
## core; complete ground-only houses can then occupy a connected perimeter
## district and address short connected public lanes. Tents are deliberately ineligible:
## the outskirts are a terraced continuation of the settlement, not detached
## camp dressing.
const INNER_RADIUS := 36.0
const OUTSKIRTS_BAND_WIDTH := HeightfieldPlan.TILE
const OUTER_RADIUS := INNER_RADIUS + OUTSKIRTS_BAND_WIDTH
# The farthest admitted parcel must be able to connect to the canonical town
# entry. Legacy branch discovery still uses this geometric annulus bound.
# Volumetric towns instead derive their reach from the exact occupied contour
# and selected prefab footprint.
const MAX_CONNECTOR_LENGTH := OUTER_RADIUS
## The edge district is meant to RING the dense core so the skyline steps down
## toward open ground (2026-09-04); a sealed exit is still worth extra houses.
const TARGET_HOUSES := {
	&"village": 6,
	&"town": 9,
}
const HOUSES_PER_EXIT := 3
const SUBSTANTIAL_COHORT_FRACTION := 0.30

var house_specs: Array[VillageAssetSpec] = []


static func compile(assets: Dictionary) -> VillageOutskirtsProgram:
	var program := VillageOutskirtsProgram.new()
	for value: Variant in assets.values():
		var spec := value as VillageAssetSpec
		if spec == null or spec.role != VillageAssetSpec.Role.HOUSE:
			continue
		if not spec.is_enterable() or not spec.requires_foundation():
			continue
		if not spec.has_enclosed_interior():
			push_error("Village outskirts require complete inhabited houses")
			return null
		# `STACKABLE` describes what the dense grammar may do with a prefab; it
		# does not require stacking. The outskirts always place exactly one complete
		# authored house at terrain level, so the large multi-purpose SFV homes are
		# valid here and supply the city-scale silhouettes this unconstrained edge is
		# specifically meant to expose.
		program.house_specs.append(spec)
	program.house_specs.sort_custom(func(a: VillageAssetSpec,
			b: VillageAssetSpec) -> bool:
		return String(a.asset_id) < String(b.asset_id))
	if program.house_specs.is_empty():
		push_error("Village outskirts require at least one reviewed ground house")
		return null
	return program


func target_houses(tier: StringName, route_exit_count: int = 0) -> int:
	## The baseline keeps legacy settlements unchanged. A volumetric warren may
	## expose several real terrain exits; each exit is an opportunity for one
	## sparse branch and ground house, so the edge population grows from sealed
	## circulation topology rather than from a separate town-size table.
	return maxi(int(TARGET_HOUSES.get(tier, 0)),
		route_exit_count * HOUSES_PER_EXIT)


func spec_for_slot(settlement_id: StringName,
		slot_index: int, tier: StringName) -> VillageAssetSpec:
	var candidates := spec_candidates_for_slot(settlement_id, slot_index, tier)
	assert(not candidates.is_empty())
	return candidates[0]


func spec_candidates_for_slot(settlement_id: StringName,
		slot_index: int, tier: StringName) -> Array[VillageAssetSpec]:
	## Return a deterministic largest-first search order, not a single assumed
	## answer. The outskirts solver may therefore try the visually substantial
	## cohort first and fall back to the largest complete authored house that the
	## actual terrain contour, doorway, and neighboring mass can support. A tight
	## entrance cannot erase its whole edge district merely because one preferred
	## prefab is too broad.
	assert(not house_specs.is_empty() and slot_index >= 0)
	var permitted: Array[VillageAssetSpec] = []
	for spec: VillageAssetSpec in house_specs:
		if spec.allowed_in(tier):
			permitted.append(spec)
	assert(not permitted.is_empty())
	# Complete authored silhouettes pay off most at the unconstrained edge. Select
	# from the upper measured support-area cohort, so adding a
	# genuinely substantial prefab automatically makes it eligible while a tiny
	# infill house cannot dominate merely because its asset id hashed first.
	# Height breaks equal-footprint ties, naturally mixing broad one-storey
	# compounds with their taller variants. The remaining choice is still seeded
	# per settlement and cycles through that cohort before repeating.
	permitted.sort_custom(func(a: VillageAssetSpec,
			b: VillageAssetSpec) -> bool:
		var a_area := a.ground_contact_local_rect.size.x \
			* a.ground_contact_local_rect.size.y
		var b_area := b.ground_contact_local_rect.size.x \
			* b.ground_contact_local_rect.size.y
		if not is_equal_approx(a_area, b_area):
			return a_area > b_area
		if not is_equal_approx(a.measured_aabb.size.y, b.measured_aabb.size.y):
			return a.measured_aabb.size.y > b.measured_aabb.size.y
		return String(a.asset_id) < String(b.asset_id))
	var substantial_count := maxi(1, ceili(float(permitted.size()) \
		* SUBSTANTIAL_COHORT_FRACTION))
	var cohort_offset := posmod(String(settlement_id).hash() + slot_index,
		substantial_count)
	var ordered: Array[VillageAssetSpec] = []
	for cohort_index in substantial_count:
		ordered.append(permitted[(cohort_offset + cohort_index) \
			% substantial_count])
	var fallback_count := permitted.size() - substantial_count
	if fallback_count > 0:
		var fallback_offset := posmod(String(settlement_id).hash() \
			+ slot_index * 3, fallback_count)
		for fallback_index in fallback_count:
			ordered.append(permitted[substantial_count \
				+ (fallback_offset + fallback_index) % fallback_count])
	return ordered
