class_name VillageElevatedBuildingSpec
extends RefCounted

## One inhabited node in the vertical-street graph. There is deliberately no
## freestanding platform node: rock support, overhang skirt, access route, and
## the building are compiled from this one semantic object.
var stable_key: StringName
var asset_id: StringName
var local_door: Vector2
var local_outward: Vector2
var level: int

func _init(p_stable_key: StringName, p_asset_id: StringName,
		p_local_door: Vector2, p_local_outward: Vector2,
		p_level: int) -> void:
	assert(not p_stable_key.is_empty() and not p_asset_id.is_empty())
	assert(p_local_door.is_finite() and p_local_outward.is_normalized())
	assert(p_level > 0)
	stable_key = p_stable_key
	asset_id = p_asset_id
	local_door = p_local_door
	local_outward = p_local_outward
	level = p_level

