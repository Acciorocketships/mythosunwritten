class_name Helper
extends RefCounted

const SNAP_POS: float = 0.01
const SOCKET_ROTATION_90: Dictionary = {
	"frontright": "backright",
	"backright": "backleft",
	"backleft": "frontleft",
	"frontleft": "frontright",
	"front": "right",
	"right": "back",
	"back": "left",
	"left": "front"
}

# Node3D -> transform relative to a given root (no scene tree needed)
static func to_root_tf(n: Node3D, root: Node3D) -> Transform3D:
	var tf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			tf = (p as Node3D).transform * tf
		p = p.get_parent()
	return tf


# Socket world position given a piece/world transform and socket node
static func socket_world_pos(piece_tf: Transform3D, socket_node: Node3D, root: Node3D) -> Vector3:
	return snap_vec3((piece_tf * to_root_tf(socket_node, root)).origin)

static func snap_vec3(v: Vector3, snap: float = SNAP_POS) -> Vector3:
	var new_pos = Vector3(
		snappedf(v.x, snap),
		snappedf(v.y, snap),
		snappedf(v.z, snap)
	)
	return new_pos

static func snap_transform_origin(tf: Transform3D, snap: float = SNAP_POS) -> Transform3D:
	var out := tf
	out.origin = snap_vec3(tf.origin, snap)
	return out


# ------------------------------------------------------------
# Mesh AABB helpers
# ------------------------------------------------------------

static func merge_aabb(a: AABB, b: AABB) -> AABB:
	# Union of two AABBs (min/max). We avoid relying on AABB.merge() semantics.
	var a_min: Vector3 = a.position
	var a_max: Vector3 = a.position + a.size
	var b_min: Vector3 = b.position
	var b_max: Vector3 = b.position + b.size

	var mn: Vector3 = Vector3(
		min(a_min.x, b_min.x),
		min(a_min.y, b_min.y),
		min(a_min.z, b_min.z)
	)
	var mx: Vector3 = Vector3(
		max(a_max.x, b_max.x),
		max(a_max.y, b_max.y),
		max(a_max.z, b_max.z)
	)
	return AABB(mn, mx - mn)


static func compute_local_mesh_aabb(root_node: Node3D) -> AABB:
	# Collect the root-space AABB of every CollisionShape3D under this root,
	# then merge them into one local-space bounds.
	if root_node == null:
		return AABB()

	var have_any: bool = false
	var merged: AABB = AABB()

	var to_visit: Array[Node] = [root_node]
	while not to_visit.is_empty():
		var node: Node = to_visit.pop_back()
		for child in node.get_children():
			to_visit.append(child)

		var collision_shape: CollisionShape3D = node as CollisionShape3D
		# everything that isn't a collision shape will be skipped
		if collision_shape == null:
			continue

		# Try to get debug mesh from collision shape
		var debug_mesh: Mesh = collision_shape.shape.get_debug_mesh()
		if debug_mesh == null:
			continue

		var tf_to_root: Transform3D = to_root_tf(collision_shape, root_node)
		var mesh_aabb_in_root: AABB = tf_to_root * debug_mesh.get_aabb()
		if not have_any:
			merged = mesh_aabb_in_root
			have_any = true
		else:
			merged = merge_aabb(merged, mesh_aabb_in_root)

	# If no collision shapes found, fall back to visual meshes
	if not have_any:
		to_visit = [root_node]
		while not to_visit.is_empty():
			var node: Node = to_visit.pop_back()
			for child in node.get_children():
				to_visit.append(child)

			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null:
				continue

			var tf_to_root: Transform3D = to_root_tf(mesh_instance, root_node)
			var mesh_aabb_in_root: AABB = tf_to_root * mesh_instance.mesh.get_aabb()
			if not have_any:
				merged = mesh_aabb_in_root
				have_any = true
			else:
				merged = merge_aabb(merged, mesh_aabb_in_root)

	if not have_any:
		push_error("[Helper.compute_local_mesh_aabb] No CollisionShape3D or MeshInstance3D with valid mesh found to compute AABB.")
		return AABB()
	return merged


static func compute_scene_mesh_aabb(scene: PackedScene) -> AABB:
	if scene == null:
		return AABB()
	if not scene.can_instantiate():
		return AABB()
	var root: Node = scene.instantiate()
	var root3: Node3D = root as Node3D
	if root3 == null:
		root.free()
		return AABB()

	var out: AABB = compute_local_mesh_aabb(root3)
	root.free()
	return out


# ------------------------------------------------------------
# Collision helpers
# ------------------------------------------------------------

static func scene_has_collision(scene: PackedScene) -> bool:
	if scene == null:
		return false
	if not scene.can_instantiate():
		return false
	var root: Node = scene.instantiate()
	if root == null:
		return false
	var out: bool = node_has_collision(root)
	root.free()
	return out


static func node_has_collision(root: Node) -> bool:
	if root == null:
		return false
	var to_visit: Array[Node] = [root]
	while not to_visit.is_empty():
		var node: Node = to_visit.pop_back()
		for child in node.get_children():
			to_visit.append(child)
		# Be permissive: support both collision nodes used in Godot 4.
		if node is CollisionShape3D or node is CollisionPolygon3D:
			return true
	return false


# ------------------------------------------------------------
# Terrain generation utilities
# ------------------------------------------------------------

static func get_attachment_socket_name(expansion_socket_name: String) -> String:
	# Determine which socket on the new piece should attach based on the expansion socket
	if "top" in expansion_socket_name:
		return "bottom"

	# Map cardinal directions to their opposites
	match expansion_socket_name:
		"front":
			return "back"
		"back":
			return "front"
		"left":
			return "right"
		"right":
			return "left"
		"frontright":
			return "backleft"
		"backright":
			return "frontleft"
		"backleft":
			return "frontright"
		"frontleft":
			return "backright"
		"bottom":
			return "topcenter"
		_:
			print("[Helper.get_attachment_socket_name] Unknown expansion socket name: ", expansion_socket_name)
			return "bottom"


static func rotate_adjacency(adjacency: Dictionary) -> Dictionary:
	var rotated: Dictionary[String, TerrainModuleSocket] = {}
	for socket_name in adjacency.keys():
		var rotated_name: String = rotate_name_with_map(socket_name, SOCKET_ROTATION_90)
		rotated[rotated_name] = adjacency[socket_name]
	return rotated


static func rotate_socket_name(socket_name: String) -> String:
	return rotate_name_with_map(socket_name, SOCKET_ROTATION_90)


static func rotate_name_with_map(socket_name: String, rotation_map: Dictionary) -> String:
	var rotated_name: String = socket_name
	var sorted_keys: Array = rotation_map.keys()
	sorted_keys.sort_custom(func(a, b): return String(a).length() > String(b).length())
	for original in sorted_keys:
		if original in rotated_name:
			rotated_name = rotated_name.replace(original, rotation_map.get(original, original))
			break
	return rotated_name
