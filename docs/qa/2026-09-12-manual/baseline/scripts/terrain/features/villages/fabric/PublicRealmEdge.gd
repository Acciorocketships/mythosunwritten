class_name PublicRealmEdge
extends RefCounted

## A player-width seam between two public-realm episodes. Each seam entry
## connects one 1.5 m lane; two entries prove the 3 m public corridor.
enum TransitionKind {
	LEVEL,
	HALF_STAIR,
	FULL_STAIR,
	RAMP,
}

var stable_id: StringName
var from_node_id: StringName
var to_node_id: StringName
var transition_kind: TransitionKind
var seams: Array[Dictionary] = []
var is_primary: bool
## Why the last `seal()` refused, in the edge's own words. TASK E2: the plan
## above could only ever say "invalid or duplicate edge", which conflates a
## repeated stable id with seven distinct seam faults — and cost a wave of
## work, because the maze corpus recorded the wrong diagnosis (a duplicate id)
## for a family that never had one.
var last_rejection := ""
var _sealed := false


func _init(p_stable_id: StringName, p_from_node_id: StringName,
		p_to_node_id: StringName, p_transition_kind: TransitionKind,
		p_is_primary: bool = true) -> void:
	stable_id = p_stable_id
	from_node_id = p_from_node_id
	to_node_id = p_to_node_id
	transition_kind = p_transition_kind
	is_primary = p_is_primary


func add_seam(from_cell: Vector3i, to_cell: Vector3i) -> void:
	assert(not _sealed)
	seams.append({"from_cell": from_cell, "to_cell": to_cell})


func seal(nodes: Dictionary) -> bool:
	last_rejection = ""
	if _sealed:
		return _reject("already sealed")
	if stable_id.is_empty() or from_node_id.is_empty() \
			or to_node_id.is_empty():
		return _reject("empty stable id or endpoint id")
	if from_node_id == to_node_id:
		return _reject("both endpoints are %s" % from_node_id)
	if not nodes.has(from_node_id) or not nodes.has(to_node_id):
		return _reject("endpoint %s is not a node in this realm" % (
			from_node_id if not nodes.has(from_node_id) else to_node_id))
	if transition_kind < TransitionKind.LEVEL \
			or transition_kind > TransitionKind.RAMP:
		return _reject("transition kind %d is out of range" % transition_kind)
	if seams.size() < 2:
		return _reject("%d seams cannot prove a 3 m corridor" % seams.size())
	var from_node := nodes[from_node_id] as PublicRealmNode
	var to_node := nodes[to_node_id] as PublicRealmNode
	var used_from: Dictionary = {}
	var used_to: Dictionary = {}
	for seam: Dictionary in seams:
		var from_cell := seam.get("from_cell", Vector3i()) as Vector3i
		var to_cell := seam.get("to_cell", Vector3i()) as Vector3i
		var from_key := _cell_key(from_cell)
		var to_key := _cell_key(to_cell)
		var horizontal_distance := absi(from_cell.x - to_cell.x) \
			+ absi(from_cell.z - to_cell.z)
		var vertical_distance := absi(from_cell.y - to_cell.y)
		if used_from.has(from_key) or used_to.has(to_key):
			return _reject("seam %s -> %s reuses a lane" % [from_cell, to_cell])
		if not from_node.has_cell(from_cell) \
				or not to_node.has_cell(to_cell):
			return _reject("seam %s -> %s leaves its own node" % [from_cell,
				to_cell])
		if horizontal_distance != 1 or vertical_distance > 1:
			return _reject("seam %s -> %s is not one adjacent lane" % [
				from_cell, to_cell])
		if transition_kind == TransitionKind.LEVEL \
				and vertical_distance != 0:
			return _reject("LEVEL seam %s -> %s steps %d band(s)" % [from_cell,
				to_cell, vertical_distance])
		used_from[from_key] = true
		used_to[to_key] = true
	_sealed = true
	return true


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false


func is_sealed() -> bool:
	return _sealed


func connects(a: StringName, b: StringName) -> bool:
	return (from_node_id == a and to_node_id == b) \
		or (from_node_id == b and to_node_id == a)


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]
