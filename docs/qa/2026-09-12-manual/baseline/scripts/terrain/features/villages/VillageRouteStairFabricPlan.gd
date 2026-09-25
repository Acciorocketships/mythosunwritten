class_name VillageRouteStairFabricPlan
extends RefCounted

## Atomic fixed-stair payload shared by ground and aerial circulation.
var accepted: bool = false
var reason: StringName
var runs: Array[VillageRouteStairRun] = []
var entries: Array[Dictionary] = []
var volumes: Array[VillageOccupancyVolume] = []
var clearances: Array[FeatureGroundShape] = []
var stair_count: int = 0
var railing_count: int = 0


func runs_for(link_key: StringName) -> Array[VillageRouteStairRun]:
	var out: Array[VillageRouteStairRun] = []
	for run: VillageRouteStairRun in runs:
		if run.link_key == link_key:
			out.append(run)
	return out


func interval_is_stair(link_key: StringName,
		minimum: float, maximum: float) -> bool:
	for run: VillageRouteStairRun in runs:
		if run.link_key == link_key and run.overlaps_interval(minimum, maximum):
			return true
	return false


func validate() -> bool:
	if not accepted:
		return runs.is_empty() and entries.is_empty() and volumes.is_empty()
	if reason != &"accepted":
		return false
	if runs.is_empty():
		return stair_count == 0 and railing_count == 0 and entries.is_empty() \
			and volumes.is_empty() and clearances.is_empty()
	if stair_count <= 0 or railing_count != stair_count * 2 \
			or entries.size() != stair_count + railing_count \
			or volumes.size() != stair_count + railing_count \
			or clearances.size() != stair_count:
		return false
	var total := 0
	for run: VillageRouteStairRun in runs:
		if not run.is_valid():
			return false
		total += run.stair_count
	# Multiple semantic routes may share one coincident physical stair before
	# branching. Every emitted piece belongs to at least one frozen run, while
	# exact duplicates are materialized only once.
	return total >= stair_count
