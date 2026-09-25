class_name VillageMassingSlot
extends RefCounted

## One semantic inhabited role in the terrain-led massing solve. Candidate
## rejection never changes this identity or the ordering of later roles.
var stable_key: StringName
var asset_id: StringName
var minimum_radius: float
var maximum_radius: float


func _init(p_stable_key: StringName, p_asset_id: StringName,
		p_minimum_radius: float = 0.0,
		p_maximum_radius: float = VillageMassingProgram.CORE_RADIUS) -> void:
	stable_key = p_stable_key
	asset_id = p_asset_id
	minimum_radius = p_minimum_radius
	maximum_radius = p_maximum_radius


func is_valid(assets: Dictionary, tier: StringName) -> bool:
	var spec := assets.get(asset_id) as VillageAssetSpec
	return not stable_key.is_empty() and spec != null \
		and spec.is_enterable() \
		and is_finite(minimum_radius) and minimum_radius >= 0.0 \
		and is_finite(maximum_radius) and maximum_radius >= minimum_radius \
		and spec.allowed_in(tier)


func admits_radius(radius: float) -> bool:
	return radius >= minimum_radius - 0.001 \
		and radius <= maximum_radius + 0.001
