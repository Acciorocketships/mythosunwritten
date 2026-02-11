class_name Helper
extends RefCounted

const SNAP_POS: float = 0.01

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
# Terrain Module Utilities
# ------------------------------------------------------------

## Creates rotated variants of a TerrainModule by cycling socket directions.
static func create_rotated_terrain_modules(base_module: TerrainModule) -> Array[TerrainModule]:
	# Define 90° clockwise rotation mapping - substrings will be replaced in longer names
	var rotation_90 := {
		# Base directions
		"front": "main",  # front becomes new attachment point
		"main": "right",  # main becomes right
		"right": "back",
		"back": "left",
		"left": "front",  # left becomes front (will be handled by special case)
		# Corner combinations
		"frontright": "mainright",
		"mainright": "backright",
		"backright": "backleft",
		"backleft": "frontleft",
		"frontleft": "frontright"
	}

	var variants: Array[TerrainModule] = []

	# 90° rotation
	variants.append(create_socket_swapped_module(base_module, rotation_90))

	# 180° rotation (apply rotation twice)
	var rotation_180 := apply_direction_mapping(rotation_90, rotation_90)
	variants.append(create_socket_swapped_module(base_module, rotation_180))

	# 270° rotation (apply rotation three times)
	var rotation_270 := apply_direction_mapping(rotation_180, rotation_90)
	variants.append(create_socket_swapped_module(base_module, rotation_270))

	return variants

## Creates a TerrainModule with swapped socket names.
static func create_socket_swapped_module(base_module: TerrainModule, swaps: Dictionary) -> TerrainModule:
	var tags_per_socket := swap_dict_keys(base_module.tags_per_socket, swaps)
	var socket_size := swap_dict_keys(base_module.socket_size, swaps)
	var socket_required := swap_dict_keys(base_module.socket_required, swaps)
	var socket_fill_prob := swap_dict_keys(base_module.socket_fill_prob, swaps)
	var socket_tag_prob := swap_dict_keys(base_module.socket_tag_prob, swaps)

	return TerrainModule.new(
		base_module.scene,
		base_module.size,
		base_module.tags,
		tags_per_socket,
		base_module.visual_variants,
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		base_module.replace_existing
	)

## Swaps dictionary keys according to the provided mapping.
static func swap_dict_keys(dict: Dictionary, swaps: Dictionary) -> Dictionary:
	var result := {}
	for key: String in dict.keys():
		var original_key := key
		var new_key := key

		# Process swaps in order from longest to shortest to handle compound directions first
		# This prevents single direction replacements from interfering with compound ones
		var sorted_swaps := swaps.keys()
		sorted_swaps.sort_custom(func(a, b): return a.length() > b.length())  # Sort by length descending

		for swap_key: String in sorted_swaps:
			if swap_key in new_key:
				new_key = new_key.replace(swap_key, swaps[swap_key])
				break  # Only apply the first (longest) matching replacement

		# Special case: if the key was exactly "left", it should become "main" (new attachment point)
		if original_key == "left":
			new_key = "main"

		result[new_key] = dict[key]
	return result

## Applies one direction mapping to another.
static func apply_direction_mapping(first: Dictionary, second: Dictionary) -> Dictionary:
	var result := {}
	for key: String in first.keys():
		result[key] = second.get(first[key], first[key])
	return result


## Terrain generation utilities

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
		"bottom":
			return "topcenter"
		_:
			print("[Helper.get_attachment_socket_name] Unknown expansion socket name: ", expansion_socket_name)
			return "bottom"


static func rotate_adjacency(adjacency: Dictionary) -> Dictionary:
	# Rotate adjacency by renaming socket keys according to the rotation rule
	# Process longer substrings first as requested
	var rotation_map = {
		"frontright": "backright",
		"backright": "backleft",
		"backleft": "frontleft",
		"frontleft": "frontright",
		"front": "right",
		"right": "back",
		"back": "left",
		"left": "front"
	}

	var rotated: Dictionary[String, TerrainModuleSocket] = {}

	for socket_name in adjacency.keys():
		var rotated_name = socket_name
		# Apply rotations, checking longer matches first
		for original in rotation_map.keys():
			if original in rotated_name:
				rotated_name = rotated_name.replace(original, rotation_map[original])
				break  # Only apply first match

		rotated[rotated_name] = adjacency[socket_name]

	return rotated


static func rotate_socket_name(socket_name: String) -> String:
	# Rotate a single socket name according to the rotation rule
	var rotation_map = {
		"frontright": "backright",
		"backright": "backleft",
		"backleft": "frontleft",
		"frontleft": "frontright",
		"front": "right",
		"right": "back",
		"back": "left",
		"left": "front"
	}

	var rotated_name = socket_name
	# Apply rotations, checking longer matches first
	for original in rotation_map.keys():
		if original in rotated_name:
			rotated_name = rotated_name.replace(original, rotation_map[original])
			break  # Only apply first match

	return rotated_name
