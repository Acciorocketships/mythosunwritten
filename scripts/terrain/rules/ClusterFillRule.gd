class_name ClusterFillRule
extends TerrainGenerationRule

## Convexifies cliff/level clusters: when a placed tile leaves an empty
## cardinal position that already has >=2 same-family neighbours at the same
## height, that position's expansion socket is pushed onto the queue directly
## (bypassing the sparsity roll). Notches and 1-wide slots in a cluster always
## fill, so clusters grow into chunky plateaus that can host interior tiles —
## which is what enables vertical stacking — instead of staying snake-shaped.
## Growth stays bounded: a fill needs two pre-existing neighbours, so the rule
## can only thicken a cluster within its existing extent, never extend it.

const CARDINAL_SOCKETS: Array[String] = ["front", "right", "back", "left"]
const SAME_LEVEL_EPS: float = 0.1
# Base tiers only: stack-tier placements can be rejected by the edge rules'
# support checks, and a rejected fill would be re-pushed on every neighbour
# recheck — an infinite place/remove cycle. Base placements always stand.
const FAMILY_BY_TIER: Dictionary[String, String] = {
	"cliff-base": "cliff",
	"level-ground": "level",
}
const MIN_NEIGHBORS_TO_FILL: int = 2


func matches(context: Dictionary) -> bool:
	var chosen_piece: TerrainModuleInstance = context.get("chosen_piece", null)
	if chosen_piece == null:
		return false
	return _family_of(chosen_piece) != ""


func apply(context: Dictionary) -> Dictionary:
	var piece: TerrainModuleInstance = context["chosen_piece"]
	var terrain_index: TerrainIndex = context.get("terrain_index", null)
	var out: Dictionary = {
		"chosen_piece": piece,
		"piece_updates": {},
		"sockets_for_queue": [],
	}
	if terrain_index == null:
		return out
	var family: String = _family_of(piece)
	for socket_name in CARDINAL_SOCKETS:
		if not piece.sockets.has(socket_name):
			continue
		var target: Vector3 = _adjacent_center(piece, socket_name)
		if _piece_at(target, family, terrain_index) != null:
			continue  # already occupied
		if _count_family_cardinals(target, family, piece, terrain_index) < MIN_NEIGHBORS_TO_FILL:
			continue
		out["sockets_for_queue"].append(TerrainModuleSocket.new(piece, socket_name))
	return out


func _family_of(piece: TerrainModuleInstance) -> String:
	if piece == null or piece.def == null:
		return ""
	for tier in FAMILY_BY_TIER.keys():
		if piece.def.tags.has(tier):
			return FAMILY_BY_TIER[tier]
	return ""


## Center of the tile adjacent to `piece` across `socket_name` (sockets sit at
## edge midpoints, so the neighbour center is twice the socket offset).
func _adjacent_center(piece: TerrainModuleInstance, socket_name: String) -> Vector3:
	var center: Vector3 = piece.transform.origin
	var socket_pos: Vector3 = TerrainModuleSocket.new(piece, socket_name).get_socket_position()
	var offset: Vector3 = socket_pos - center
	offset.y = 0.0
	return center + offset * 2.0


## Count occupied same-family same-height tiles at the 4 cardinal positions
## around `target` (a tile center). `placed` is the just-placed piece — it is
## already in the index and counts like any other neighbour.
func _count_family_cardinals(
	target: Vector3,
	family: String,
	placed: TerrainModuleInstance,
	terrain_index: TerrainIndex
) -> int:
	var tile: float = 24.0
	var count: int = 0
	for offset in [
		Vector3(tile, 0, 0), Vector3(-tile, 0, 0), Vector3(0, 0, tile), Vector3(0, 0, -tile)
	]:
		if _piece_at(target + offset, family, terrain_index) != null:
			count += 1
	return count


func _piece_at(
	center: Vector3, family: String, terrain_index: TerrainIndex
) -> TerrainModuleInstance:
	var query_box: AABB = AABB(center + Vector3(-0.6, -2.0, -0.6), Vector3(1.2, 4.0, 1.2))
	for hit in terrain_index.query_box(query_box):
		if not (hit is TerrainModuleInstance):
			continue
		var other: TerrainModuleInstance = hit
		if not other.def.tags.has(family):
			continue
		if absf(other.transform.origin.y - center.y) > SAME_LEVEL_EPS:
			continue
		var delta: Vector3 = other.transform.origin - center
		if absf(delta.x) <= 0.6 and absf(delta.z) <= 0.6:
			return other
	return null
