class_name VillageMassingPlan
extends RefCounted

## Immutable-by-convention output of the bounded building-packing solve.
var accepted: bool = false
var reason: StringName
var core: VillageTerrainPerch
var placements: Array[VillageMassingPlacement] = []
var building_count: int = 0
var required_building_count: int = 0
var core_radius: float = 0.0
var terrain_support_ratio: float = 0.0
var natural_ratio: float = 0.0
var half_rise_count: int = 0
var elevation_band_count: int = 0
var mean_nearest_distance: float = 0.0
var ground_building_count: int = 0
var platformizable_pair_count: int = 0
## Compact failure evidence retained by rejected solves. This stays plain data
## so headless corpus generation can explain why a site vanished instead of
## reducing every packing failure to one opaque reason.
var candidate_audit: Dictionary = {}


func validate(program: VillageMassingProgram, tier: StringName) -> bool:
	if not accepted:
		return placements.is_empty()
	return program != null and core != null \
		and building_count >= program.minimum_buildings(tier) \
		and core_radius <= VillageMassingProgram.CORE_RADIUS + 0.001 \
		and terrain_support_ratio >= VillageMassingProgram.MIN_TERRAIN_SUPPORT_RATIO \
		and elevation_band_count >= VillageMassingProgram.MIN_ELEVATION_BANDS \
		and half_rise_count > 0 \
		and ground_building_count >= program.minimum_ground_buildings(tier) \
		and platformizable_pair_count \
			>= VillageMassingProgram.MIN_PLATFORMIZABLE_PAIRS \
		and mean_nearest_distance <= VillageMassingProgram.MAX_LINK_RADIUS + 0.001


func rejection_reason(program: VillageMassingProgram,
		tier: StringName) -> StringName:
	if program == null or core == null:
		return &"program"
	if building_count < program.minimum_buildings(tier):
		return &"building_count"
	if core_radius > VillageMassingProgram.CORE_RADIUS + 0.001:
		return &"core_radius"
	if terrain_support_ratio \
			< VillageMassingProgram.MIN_TERRAIN_SUPPORT_RATIO:
		return &"terrain_support"
	if elevation_band_count < VillageMassingProgram.MIN_ELEVATION_BANDS:
		return &"elevation_bands"
	if half_rise_count <= 0:
		return &"half_rise"
	if ground_building_count < program.minimum_ground_buildings(tier):
		return &"ground_buildings"
	if platformizable_pair_count \
			< VillageMassingProgram.MIN_PLATFORMIZABLE_PAIRS:
		return &"platform_cluster"
	if mean_nearest_distance > VillageMassingProgram.MAX_LINK_RADIUS + 0.001:
		return &"neighbour_distance"
	return &"invalid"
