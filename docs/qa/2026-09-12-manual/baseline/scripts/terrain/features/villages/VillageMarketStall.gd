class_name VillageMarketStall
extends RefCounted

var stable_key: StringName
var asset_id: StringName
var transform: Transform3D
var floor_y: float
var service_front: Vector2
var inward: Vector2
var solid_volume: VillageOccupancyVolume
var lot_shape: FeatureGroundShape


func is_valid() -> bool:
	return not stable_key.is_empty() and not asset_id.is_empty() \
		and transform.is_finite() and is_finite(floor_y) \
		and service_front.is_finite() and inward.is_normalized() \
		and solid_volume != null and lot_shape != null
