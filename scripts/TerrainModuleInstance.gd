extends RefCounted
class_name TerrainModuleInstance

var def: TerrainModule
var root: Node3D = null
var socket_node: Node3D = null
var sockets: Dictionary = {}  # String -> Marker3D

var transform: Transform3D = Transform3D.IDENTITY
var aabb: AABB
var debug_id: int = -1

func _init(_def: TerrainModule) -> void:
	def = _def
	aabb = get_world_aabb()

func debug_string() -> String:
	var tag_str := def.tags[0] if def.tags.size() > 0 else "<no_tag>"
	return "TerrainModuleInstance(id=%d, tag=%s, aabb=%s)" % [debug_id, tag_str, str(aabb)]

func create() -> Node3D:
	root = def.scene.instantiate()
	root.global_transform = transform
	socket_node = root.get_node("Sockets") as Node3D
	_find_sockets()
	return root

func destroy() -> void:
	if root:
		transform = root.global_transform
		root.queue_free()
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
	aabb = get_world_aabb()
	if root:
		root.global_transform = tf

func set_position(pos: Vector3) -> void:
	transform.origin = pos
	aabb = get_world_aabb()
	if root:
		root.global_transform = transform

func get_position() -> Vector3:
	return transform.origin

func set_basis(basis: Basis) -> void:
	transform.basis = basis
	aabb = get_world_aabb()
	if root:
		root.global_transform = transform

func get_world_aabb() -> AABB:
	return transform * def.size
