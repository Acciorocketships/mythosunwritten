class_name VillageOutskirtsPlan
extends RefCounted

## Optional sealed edge payload. Failure to place a shelter never invalidates
## the already-proved inhabited core, but accepted pieces still pass the same
## typed occupancy transaction as every other village structure.
var accepted: bool = false
var reason: StringName
var entries: Array[Dictionary] = []
var volumes: Array[VillageOccupancyVolume] = []
var surfaces: Array[FeatureGroundShape] = []
var clearances: Array[FeatureGroundShape] = []
var placements: Array[VillageMassingPlacement] = []
var route_stair_count: int = 0
var audit: Array[Dictionary] = []


func validate(program: VillageOutskirtsProgram,
		tier: StringName) -> bool:
	if not accepted:
		return entries.is_empty() and volumes.is_empty() \
			and surfaces.is_empty() and clearances.is_empty() \
			and placements.is_empty()
	if reason != &"accepted" or program == null \
			or placements.size() > program.target_shelters(tier) \
			or route_stair_count < 0:
		return false
	var occupancy := VillageOccupancy.new()
	return occupancy.first_conflict(volumes).is_empty()
