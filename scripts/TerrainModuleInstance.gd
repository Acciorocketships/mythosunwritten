class_name TerrainModuleInstance
extends RefCounted

var def: TerrainModule
var root: Node3D = null
var socket_node: Node3D = null
var sockets: Dictionary = {}  # String -> Marker3D

var transform: Transform3D = Transform3D.IDENTITY
var aabb: AABB

func _init(_def: TerrainModule) -> void:
	def = _def
	set_world_aabb()

func debug_string() -> String:
	var tag_str: String = def.tags.tags[0] if def.tags.size() > 0 else "<no_tag>"
	return "TerrainModuleInstance(tag=%s, aabb=%s)" % [tag_str, str(aabb)]

func create() -> Node3D:
	root = def.scene.instantiate()
	root.global_transform = transform
	socket_node = root.get_node("Sockets") as Node3D
	_find_sockets()
	return root

func destroy() -> void:
	if root:
		# If it was never added to the scene tree, queue_free() will complain.
		if root.is_inside_tree():
			transform = root.global_transform
			root.queue_free()
		else:
			# Not in tree => safe to free immediately
			root.free()
	root = null
	socket_node = null
	sockets.clear()

func _find_sockets() -> void:
	sockets.clear()
	if socket_node == null:
		return
	for child in socket_node.get_children():
		if child is Marker3D:
			sockets[child.name] = child

func set_transform(tf: Transform3D) -> void:
	transform = tf
	set_world_aabb()
	if root:
		root.global_transform = tf

func set_position(pos: Vector3) -> void:
	transform.origin = pos
	set_world_aabb()
	if root:
		root.global_transform = transform

func get_position() -> Vector3:
	return transform.origin

func set_basis(basis: Basis) -> void:
	transform.basis = basis
	set_world_aabb()
	if root:
		root.global_transform = transform

func set_world_aabb() -> AABB:
	aabb = transform * def.size
	aabb.position = Helper.snap_vec3(aabb.position, 0.01)
	aabb.size = Helper.snap_vec3(aabb.size, 0.01)
	return aabb

func _to_string() -> String:
	var tag_str := ",".join(def.tags.tags)
	return "TerrainModuleInstance(tags=[%s], pos=%s, aabb=%s)" % [
		tag_str,
		str(transform.origin),
		str(aabb),
	]
