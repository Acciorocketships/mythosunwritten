class_name VillageCirculationPlan
extends RefCounted

## Immutable-by-convention output of the circulation solve. The graph keeps
## threshold, terrain-street, platform, and aerial links as ordinary edge
## kinds so validation never needs a settlement-specific escape hatch.
var accepted: bool = false
var reason: StringName
var nodes: Array[VillageCirculationNode] = []
var links: Array[VillageCirculationLink] = []
var platforms: Array[VillagePlatformRegion] = []
var ground_street_count: int = 0
var aerial_link_count: int = 0
var curved_link_count: int = 0
var maximum_aerial_length: float = 0.0
## Rejection-only bounded diagnostics; never used to repair topology.
var ground_candidate_count: int = 0
var aerial_candidate_count: int = 0
var platform_candidate_count: int = 0
var platform_region_count: int = 0
var aerial_candidate_edges: Array[Dictionary] = []
var disconnected_components: Array[Array] = []


func validate(massing: VillageMassingPlan) -> bool:
	return rejection_reason(massing).is_empty()


func rejection_reason(massing: VillageMassingPlan) -> StringName:
	if not accepted:
		return &"" if nodes.is_empty() and links.is_empty() \
			and platforms.is_empty() else &"rejected_payload"
	if massing == null or not massing.accepted:
		return &"massing"
	var node_table: Dictionary = {}
	var door_count := 0
	for node: VillageCirculationNode in nodes:
		if not node.is_valid() or node_table.has(node.stable_key):
			return &"node"
		node_table[node.stable_key] = node
		door_count += 1 if node.kind == VillageCirculationNode.Kind.DOOR else 0
	if door_count != massing.placements.size():
		return &"door_count"
	var adjacency: Dictionary = {}
	for key: StringName in node_table:
		adjacency[key] = []
	for link: VillageCirculationLink in links:
		if not link.is_valid() or not node_table.has(link.from_key) \
				or not node_table.has(link.to_key):
			return &"link"
		(adjacency[link.from_key] as Array).append(link.to_key)
		(adjacency[link.to_key] as Array).append(link.from_key)
	for platform: VillagePlatformRegion in platforms:
		if not platform.is_valid():
			return &"platform"
	if not _connected(adjacency, &"arrival"):
		return &"connectivity"
	if ground_street_count < massing.ground_building_count:
		return &"ground_streets"
	if platforms.is_empty():
		return &"platforms"
	if aerial_link_count < VillageMassingProgram.MIN_AERIAL_LINKS:
		return &"aerial_links"
	if curved_link_count <= 0:
		return &"curved_links"
	if maximum_aerial_length \
			> VillageMassingProgram.MAX_LINK_RADIUS + 0.001:
		return &"aerial_length"
	return &""


static func _connected(adjacency: Dictionary, root: StringName) -> bool:
	if not adjacency.has(root):
		return false
	var pending: Array[StringName] = [root]
	var seen: Dictionary = {}
	while not pending.is_empty():
		var key: StringName = pending.pop_back()
		if seen.has(key):
			continue
		seen[key] = true
		for neighbour: StringName in adjacency[key]:
			pending.append(neighbour)
	return seen.size() == adjacency.size()
