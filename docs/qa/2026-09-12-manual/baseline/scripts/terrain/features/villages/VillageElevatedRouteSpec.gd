class_name VillageElevatedRouteSpec
extends RefCounted

## One polyline in the vertical street graph. Contacts carry explicit levels:
## equal-level edges become thin orthogonal walkways, while a one-level edge
## becomes the compiled fixed stair sequence. Shared contacts form branches by
## construction instead of requiring junction-specific placement code.
var stable_key: StringName
var points: Array[Vector2] = []
var levels: Array[int] = []

func _init(p_stable_key: StringName, p_points: Array[Vector2],
		p_levels: Array[int]) -> void:
	assert(not p_stable_key.is_empty() and p_points.size() >= 2)
	assert(p_points.size() == p_levels.size())
	stable_key = p_stable_key
	points.assign(p_points)
	levels.assign(p_levels)

func has_ground_contact() -> bool:
	return levels.has(0)

