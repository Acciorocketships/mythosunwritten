class_name VillageMarketPlan
extends RefCounted

## Atomic ground-market seed for the urban solve. Buildings and elevated
## circulation consume its typed occupancy; no later stage needs to know that
## a reserved solid happened to be a stall.
var accepted: bool = false
var reason: StringName
var nodes: Array[VillageCirculationNode] = []
var links: Array[VillageCirculationLink] = []
var stalls: Array[VillageMarketStall] = []
var entries: Array[Dictionary] = []
var volumes: Array[VillageOccupancyVolume] = []
var surfaces: Array[FeatureGroundShape] = []
var clearances: Array[FeatureGroundShape] = []


func blocking_volumes() -> Array[VillageOccupancyVolume]:
	var out: Array[VillageOccupancyVolume] = []
	for stall: VillageMarketStall in stalls:
		out.append(stall.solid_volume)
	return out


func validate(program: VillageMarketProgram, tier: StringName) -> bool:
	return rejection_reason(program, tier).is_empty()


func rejection_reason(program: VillageMarketProgram,
		tier: StringName) -> StringName:
	if not accepted:
		return &"" if nodes.is_empty() and links.is_empty() and stalls.is_empty() \
			and entries.is_empty() and volumes.is_empty() \
			and surfaces.is_empty() and clearances.is_empty() else &"rejected_payload"
	if reason != &"accepted" or program == null \
			or stalls.size() < program.minimum_stalls(tier) \
			or links.is_empty() or nodes.is_empty():
		return &"structure"
	var node_keys: Dictionary = {}
	for node: VillageCirculationNode in nodes:
		if not node.is_valid() or node_keys.has(node.stable_key):
			return &"node"
		node_keys[node.stable_key] = true
	if not node_keys.has(&"arrival"):
		return &"arrival"
	for link: VillageCirculationLink in links:
		if not link.is_valid() or not node_keys.has(link.from_key) \
				or not node_keys.has(link.to_key) \
				or (link.kind != VillageCirculationLink.Kind.GROUND_STREET \
					and link.kind != VillageCirculationLink.Kind.GROUND_STAIR):
			return &"link"
	for stall: VillageMarketStall in stalls:
		if not stall.is_valid():
			return &"stall"
	var occupancy := VillageOccupancy.new()
	var conflict := occupancy.first_conflict(volumes)
	if not conflict.is_empty():
		return StringName("occupancy_%s_%s" % [
			(conflict.candidate as VillageOccupancyVolume).stable_id,
			(conflict.existing as VillageOccupancyVolume).stable_id])
	return &"" if entries.size() >= stalls.size() \
		and volumes.size() >= stalls.size() \
		and surfaces.size() >= links.size() else &"payload"
