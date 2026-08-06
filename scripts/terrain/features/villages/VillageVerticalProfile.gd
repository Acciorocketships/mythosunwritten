class_name VillageVerticalProfile
extends RefCounted

## Resource-free architectural height grammar compiled from the structures
## that may actually occur above another occupied layer. Terrain storeys are a
## separate natural-landform concept; village levels must clear whole roofs.
const ROOF_CLEARANCE := VillageProgram.MODULE * 0.5
const MINIMUM_FULL_LEVEL_MODULES := 4

var tallest_stackable_top: float = 0.0
var full_level_height: float = 0.0
var half_level_height: float = 0.0


static func compile(assets: Dictionary) -> VillageVerticalProfile:
	var profile := VillageVerticalProfile.new()
	for value: Variant in assets.values():
		var spec := value as VillageAssetSpec
		if spec == null or not spec.is_stackable():
			continue
		var top_above_floor := spec.measured_aabb.end.y \
			- spec.entrance_floor_local_y
		profile.tallest_stackable_top = maxf(
			profile.tallest_stackable_top, top_above_floor)
	if profile.tallest_stackable_top <= 0.0:
		push_error("Village vertical profile requires a stackable structure")
		return null
	# A full level must be divisible into two exact module-aligned half levels.
	# Rounding in pairs of 1.5 m modules makes stairs, platforms, supports, and
	# future facade pieces share one construction lattice by construction.
	var pair_height := VillageProgram.MODULE * 2.0
	var pairs := maxi(ceili((profile.tallest_stackable_top + ROOF_CLEARANCE) \
		/ pair_height), ceili(float(MINIMUM_FULL_LEVEL_MODULES) / 2.0))
	profile.full_level_height = float(pairs) * pair_height
	profile.half_level_height = profile.full_level_height * 0.5
	if not profile.is_valid():
		push_error("Village vertical profile could not express a valid level pair")
		return null
	return profile


func is_valid() -> bool:
	return is_finite(tallest_stackable_top) and tallest_stackable_top > 0.0 \
		and is_finite(full_level_height) and full_level_height > 0.0 \
		and is_finite(half_level_height) and half_level_height > 0.0 \
		and is_equal_approx(half_level_height * 2.0, full_level_height) \
		and _module_aligned(full_level_height) \
		and _module_aligned(half_level_height) \
		and full_level_height >= tallest_stackable_top + ROOF_CLEARANCE - 0.001


func floor_for_band(datum_y: float, band_index: int) -> float:
	assert(is_finite(datum_y) and band_index >= 0)
	return datum_y + float(band_index) * half_level_height


func band_for_floor(floor_y: float, datum_y: float) -> int:
	assert(is_finite(floor_y) and is_finite(datum_y))
	return maxi(0, roundi((floor_y - datum_y) / half_level_height))


func is_half_level_band(band_index: int) -> bool:
	return band_index > 0 and band_index % 2 == 1


static func _module_aligned(value: float) -> bool:
	return absf(value / VillageProgram.MODULE \
		- roundf(value / VillageProgram.MODULE)) <= 0.001
