class_name VillageBuildingSupportPlan
extends RefCounted

## Atomic support output for one massed building. No piece or occupancy volume
## is committed unless the complete mode succeeds.
enum Mode {
	NATURAL_FOUNDATION,
	ROCK_CORE,
}

var accepted: bool = false
var reason: StringName
var stable_id: StringName
var mode: Mode
var floor_y: float = NAN
var terrain_bounds := Vector2(NAN, NAN)
var core: Dictionary = {}
var pieces: Array[Dictionary] = []
var volumes: Array[VillageOccupancyVolume] = []


func validate() -> bool:
	if not accepted:
		return pieces.is_empty() and volumes.is_empty() and core.is_empty()
	return not stable_id.is_empty() and reason == &"accepted" \
		and is_finite(floor_y) and terrain_bounds.is_finite() \
		and pieces.is_empty() == volumes.is_empty() \
		and (mode != Mode.ROCK_CORE \
			or (not core.is_empty() and not pieces.is_empty() \
				and not volumes.is_empty()))
