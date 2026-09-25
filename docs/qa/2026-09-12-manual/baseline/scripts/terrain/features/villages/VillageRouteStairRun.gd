class_name VillageRouteStairRun
extends RefCounted

## One fixed-module stair interval on a circulation polyline. Distances are
## measured from the link's first sample, so every downstream materializer can
## remove the same floor/path interval without rediscovering geometry.
var stable_key: StringName
var link_key: StringName
var start_distance: float
var end_distance: float
var from_y: float
var to_y: float
var stair_count: int


func _init(p_stable_key: StringName, p_link_key: StringName,
		p_start_distance: float, p_end_distance: float,
		p_from_y: float, p_to_y: float, p_stair_count: int) -> void:
	stable_key = p_stable_key
	link_key = p_link_key
	start_distance = p_start_distance
	end_distance = p_end_distance
	from_y = p_from_y
	to_y = p_to_y
	stair_count = p_stair_count


func is_valid() -> bool:
	return not stable_key.is_empty() and not link_key.is_empty() \
		and is_finite(start_distance) and is_finite(end_distance) \
		and start_distance >= 0.0 and end_distance > start_distance \
		and is_finite(from_y) and is_finite(to_y) and stair_count > 0


func overlaps_interval(minimum: float, maximum: float) -> bool:
	return minimum < end_distance - 0.001 \
		and start_distance < maximum - 0.001
