class_name VillageGroundActivitySpec
extends RefCounted

## Ground-level activity associated with an inhabited elevated building. The
## association is semantic only: placement may sit beneath an overhang, beside
## its supports, or between buildings, and the shared 3D occupancy transaction
## decides which physical relationships are legal.
var stable_key: StringName
var building_key: StringName
var asset_id: StringName
var local_door: Vector2
var local_outward: Vector2

func _init(p_stable_key: StringName, p_building_key: StringName,
		p_asset_id: StringName, p_local_door: Vector2,
		p_local_outward: Vector2) -> void:
	assert(not p_stable_key.is_empty() and not p_building_key.is_empty())
	assert(not p_asset_id.is_empty() and p_local_door.is_finite())
	assert(p_local_outward.is_normalized())
	stable_key = p_stable_key
	building_key = p_building_key
	asset_id = p_asset_id
	local_door = p_local_door
	local_outward = p_local_outward
