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


# Deterministic per-position pseudo-random value in [0, 1). The same world
# position (snapped to a 0.5 grid — socket y positions sit on half-units)
# always yields the same value for a given seed, so probability rolls keyed on
# position survive piece retiles/replaces without granting fresh rolls.
static func position_hash01(pos: Vector3, world_seed: int) -> float:
	var key: Vector3i = Vector3i(roundi(pos.x * 2.0), roundi(pos.y * 2.0), roundi(pos.z * 2.0))
	return _hash01(_mix64(world_seed ^ _mix64(key.x ^ _mix64(key.y ^ _mix64(key.z)))))


# Smooth value-noise density field over XZ in [0, 1] with ~MACRO_SCALE-unit
# features. Used to modulate fill probabilities so terrain features cluster
# into coherent regions (mountain ranges, groves, open meadows) instead of
# being uniformly scattered. Deterministic per seed — infinite-terrain safe.
# The field fades to 0 within SPAWN_CLEAR_RADIUS of the world origin so the
# player always spawns in an open meadow rather than walled in by a mountain.
const MACRO_SCALE: float = 144.0
const SPAWN_CLEAR_RADIUS: float = 60.0
const SPAWN_CLEAR_FADE: float = 120.0

static func macro_density01(pos: Vector3, world_seed: int) -> float:
	# Two octaves: large cores (mountain ranges) plus smaller secondary
	# features between them, so any render-range-sized area reliably contains
	# some features regardless of where the big cores landed for this seed.
	var value: float = (
		0.65 * _value_noise01(pos, world_seed, MACRO_SCALE)
		+ 0.35 * _value_noise01(pos, world_seed + 1, MACRO_SCALE * 0.4)
	)
	var origin_falloff: float = clampf(
		(Vector2(pos.x, pos.z).length() - SPAWN_CLEAR_RADIUS) / SPAWN_CLEAR_FADE, 0.0, 1.0
	)
	return value * origin_falloff


static func _value_noise01(pos: Vector3, world_seed: int, scale: float) -> float:
	var x: float = pos.x / scale
	var z: float = pos.z / scale
	var cx: int = floori(x)
	var cz: int = floori(z)
	var fx: float = smoothstep(0.0, 1.0, x - float(cx))
	var fz: float = smoothstep(0.0, 1.0, z - float(cz))
	var h00: float = _cell_hash01(world_seed, cx, cz)
	var h10: float = _cell_hash01(world_seed, cx + 1, cz)
	var h01: float = _cell_hash01(world_seed, cx, cz + 1)
	var h11: float = _cell_hash01(world_seed, cx + 1, cz + 1)
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


# ------------------------------------------------------------
# Biome fields
# ------------------------------------------------------------
# Two independent low-frequency value noises define continuous biomes:
#   forest01 — woodland cores (dense trees, lush undergrowth)
#   rocky01  — rocky highlands (rocks, hills, extra cliff seeding)
# Where both are low the terrain reads as open meadow (grass-dominated).
# Continuous fields (not discrete IDs) give smooth biome borders for free and
# stay deterministic per seed — infinite-terrain safe. The smoothstep remaps
# carve distinct cores out of the noise so each biome covers a meaningful
# share of the map instead of everything being a 50/50 blend.
const BIOME_FOREST_SCALE: float = 190.0
const BIOME_ROCKY_SCALE: float = 150.0

static func biome_forest01(pos: Vector3, world_seed: int) -> float:
	return smoothstep(0.45, 0.75, _value_noise01(pos, world_seed + 31, BIOME_FOREST_SCALE))


static func biome_rocky01(pos: Vector3, world_seed: int) -> float:
	return smoothstep(0.5, 0.8, _value_noise01(pos, world_seed + 37, BIOME_ROCKY_SCALE))


# Sampling-weight multipliers applied to socket tag/size distributions at
# placement time (TerrainGenerator._biome_scaled_dist). Keys are the tag or
# size strings that appear in those distributions; anything not listed keeps
# weight 1.0. Size entries mirror their tag counterparts ("24x24x4" is the
# cliff seed size, hill sizes pair with the "hill" tag) so the size and tag
# rolls stay consistent with each other.
static func biome_weights(pos: Vector3, world_seed: int) -> Dictionary[String, float]:
	var forest: float = biome_forest01(pos, world_seed)
	var rocky: float = biome_rocky01(pos, world_seed)
	var hill_weight: float = clampf(0.5 + 2.2 * rocky - 0.3 * forest, 0.1, 4.0)
	var cliff_weight: float = 0.6 + 2.6 * rocky
	return {
		"tree": 0.35 + 3.2 * forest,
		"bush": 0.6 + 1.4 * forest,
		"grass": clampf(1.7 - 1.2 * forest - 0.9 * rocky, 0.15, 2.0),
		"rock": 0.4 + 2.9 * rocky,
		"hill": hill_weight,
		"8x8x2": hill_weight,
		"12x12x2": hill_weight,
		"4x4x4": hill_weight,
		"cliff-base-side": cliff_weight,
		"24x24x4": cliff_weight,
	}


# Overall foliage density multiplier for decoration sockets: forests are
# dense, meadows open, rocky ground in between. Replaces the macro factor for
# point-capable sockets (structures keep the macro field) so flora clustering
# follows biomes instead of the structural density field.
static func biome_foliage_density(pos: Vector3, world_seed: int) -> float:
	var forest: float = biome_forest01(pos, world_seed)
	var rocky: float = biome_rocky01(pos, world_seed)
	return 0.55 + 1.35 * forest + 0.5 * rocky


# Deterministic water field: thin ridged-noise bands form winding rivers,
# a second blob noise forms lakes, and a finer noise carves islands inside
# water regions. Faded near the world origin so the spawn stays dry.
const WATER_RIVER_SCALE: float = 220.0
const WATER_LAKE_SCALE: float = 170.0
const WATER_ISLAND_SCALE: float = 55.0
const WATER_CLEAR_RADIUS: float = 130.0
const WATER_CLEAR_FADE: float = 90.0

static func is_water(pos: Vector3, world_seed: int) -> bool:
	if not _is_water_raw(pos, world_seed):
		return false
	# Erode isolated single-tile ponds: a water tile must have at least one
	# water neighbour (tile grid is 24u), or it reads as a square puddle.
	for offset in [Vector3(24, 0, 0), Vector3(-24, 0, 0), Vector3(0, 0, 24), Vector3(0, 0, -24)]:
		if _is_water_raw(pos + offset, world_seed):
			return true
	return false


static func _is_water_raw(pos: Vector3, world_seed: int) -> bool:
	var n: float = _value_noise01(pos, world_seed + 7, WATER_RIVER_SCALE)
	var river: float = (1.0 - absf(2.0 * n - 1.0)) - 0.865
	var lake: float = (_value_noise01(pos, world_seed + 13, WATER_LAKE_SCALE) - 0.78) * 1.5
	var wetness: float = maxf(river, lake)
	# Islands: pockets of high fine-noise stay land even inside water regions.
	wetness -= maxf(_value_noise01(pos, world_seed + 23, WATER_ISLAND_SCALE) - 0.72, 0.0) * 1.2
	# Keep the spawn area dry.
	wetness -= clampf(
		(WATER_CLEAR_RADIUS + WATER_CLEAR_FADE - Vector2(pos.x, pos.z).length()) / WATER_CLEAR_FADE,
		0.0, 1.0
	)
	return wetness > 0.0


static func _cell_hash01(world_seed: int, cx: int, cz: int) -> float:
	return _hash01(_mix64(world_seed ^ _mix64(cx ^ _mix64(cz))))


# splitmix64-style avalanche mix. Godot's built-in hash() of small integer
# tuples is correlated along diagonals, which shows up as straight stripes of
# placements across the map; this mixing removes that structure.
static func _mix64(value: int) -> int:
	var x: int = value + -7046029254386353131  # 0x9E3779B97F4A7C15
	x = (x ^ (x >> 30)) * -4658895280553007687  # 0xBF58476D1CE4E5B9
	x = (x ^ (x >> 27)) * -7723592293110705685  # 0x94D049BB133111EB
	return x ^ (x >> 31)


static func _hash01(h: int) -> float:
	return float(h & 0x7FFFFFFF) / float(0x80000000)


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
