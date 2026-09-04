class_name VillageOutskirtsPlan
extends RefCounted

## Optional sealed edge payload. Failure to place a house never invalidates
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
## Stocked stalls mirrored across a market street from the town's own frontage.
var market_stall_count: int = 0
## Distinct entrance-neighbourhood street sides that serve at least one edge
## parcel. This is not the number of house spurs: several houses may address
## the same short local street, while each sealed city exit still needs a
## connected neighborhood before remote frontage can count.
var branch_count: int = 0
var side_served_house_count: int = 0
## Number of sealed public terrain exits that authored the branch budget.
## Retained on the plan so validation never falls back to the legacy tier-only
## ceiling after a volumetric solve has already composed several real exits.
var route_exit_count: int = 0
var supported_house_count: int = 0
var foundation_piece_count: int = 0
var audit: Array[Dictionary] = []


func validate(program: VillageOutskirtsProgram,
		tier: StringName) -> bool:
	if not accepted:
		return entries.is_empty() and volumes.is_empty() \
			and surfaces.is_empty() and clearances.is_empty() \
			and placements.is_empty()
	var minimum_branches := mini(placements.size(), route_exit_count) \
		if route_exit_count > 0 else mini(placements.size(), 1)
	if reason != &"accepted" or program == null \
			or route_exit_count < 0 \
			or placements.size() > program.target_houses(tier, route_exit_count) \
			or supported_house_count != placements.size() \
			or side_served_house_count != placements.size() \
			or branch_count < minimum_branches \
			or route_stair_count < 0 or foundation_piece_count < 0:
		return false
	var occupancy := VillageOccupancy.new()
	return occupancy.first_conflict(volumes).is_empty()
