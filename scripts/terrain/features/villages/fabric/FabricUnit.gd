class_name FabricUnit
extends RefCounted

## One placed FabricRecipe. Units contain no server-backed resources and can be
## produced on a worker. Socket bonds always point to earlier units, making both
## structural ancestry and public circulation deterministic DAGs.
var stable_id: StringName
var recipe_id: StringName
var lattice_origin: Vector3i
var yaw_quarters: int
var parent_ids: Array[StringName] = []
var socket_bonds: Array[Dictionary] = []
## Explicit authored intersections such as an awning fastened into the upper
## facade above its market socket. This is never inferred from role tags.
var visual_seam_ids: Array[StringName] = []
var public_node_id: StringName
var bounds := AABB()


func _init(p_stable_id: StringName, p_recipe_id: StringName,
		p_lattice_origin: Vector3i, p_yaw_quarters: int,
		p_parent_ids: Array[StringName] = [],
		p_socket_bonds: Array[Dictionary] = [],
		p_public_node_id: StringName = &"",
		p_visual_seam_ids: Array[StringName] = []) -> void:
	stable_id = p_stable_id
	recipe_id = p_recipe_id
	lattice_origin = p_lattice_origin
	yaw_quarters = p_yaw_quarters
	parent_ids.assign(p_parent_ids)
	for bond: Dictionary in p_socket_bonds:
		socket_bonds.append(bond.duplicate())
	visual_seam_ids.assign(p_visual_seam_ids)
	public_node_id = p_public_node_id


func is_valid() -> bool:
	if stable_id.is_empty() or recipe_id.is_empty() or yaw_quarters < 0 \
			or yaw_quarters > 3:
		return false
	var unique_parents: Dictionary = {}
	for parent_id: StringName in parent_ids:
		if parent_id.is_empty() or parent_id == stable_id \
				or unique_parents.has(parent_id):
			return false
		unique_parents[parent_id] = true
	var own_sockets: Dictionary = {}
	for bond: Dictionary in socket_bonds:
		var own_socket := StringName(bond.get("own_socket", ""))
		var target_unit := StringName(bond.get("target_unit", ""))
		var target_socket := StringName(bond.get("target_socket", ""))
		if own_socket.is_empty() or target_unit.is_empty() \
				or target_socket.is_empty() or target_unit == stable_id \
				or own_sockets.has(own_socket):
			return false
		own_sockets[own_socket] = true
	var unique_visual_seams: Dictionary = {}
	for seam_id: StringName in visual_seam_ids:
		if seam_id.is_empty() or seam_id == stable_id \
				or unique_visual_seams.has(seam_id):
			return false
		unique_visual_seams[seam_id] = true
	return true


func transform() -> Transform3D:
	return FabricRecipe.lattice_transform(lattice_origin, yaw_quarters)


static func bond(own_socket: StringName, target_unit: StringName,
		target_socket: StringName) -> Dictionary:
	return {
		"own_socket": own_socket,
		"target_unit": target_unit,
		"target_socket": target_socket,
	}
