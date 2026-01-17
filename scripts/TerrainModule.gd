class_name TerrainModule
extends Resource

@export var scene: PackedScene
@export var size: AABB
@export var tags: TagList
@export var tags_per_socket: Dictionary[String, TagList]

@export var socket_size: Dictionary[String, Distribution]
@export var socket_required: Dictionary[String, TagList]
@export var socket_fill_prob: Distribution
@export var socket_tag_prob: Dictionary[String, Distribution]
@export var visual_variants: Array[PackedScene]

# True if this module has collision nodes in its scene (or any visual variant).
# Used by terrain placement to decide whether AABB overlap should block placement.
@export var has_collisions: bool = true

var debug_id: int = 0

func _init(
	_scene: PackedScene = null,
	_size: AABB = AABB(),
	_tags: TagList = TagList.new(),
	_tags_per_socket: Dictionary[String, TagList] = {},
	_visual_variants: Array[PackedScene] = [],
	_socket_size: Dictionary[String, Distribution] = {},
	_socket_required: Dictionary[String, TagList] = {},
	_socket_fill_prob: Distribution = Distribution.new(),
	_socket_tag_prob: Dictionary[String, Distribution] = {},
) -> void:
	scene = _scene
	size = _size
	tags = _tags
	tags_per_socket = _tags_per_socket
	socket_size = _socket_size
	socket_required = _socket_required
	socket_fill_prob = _socket_fill_prob
	socket_tag_prob = _socket_tag_prob
	visual_variants = _visual_variants.duplicate()
	visual_variants.append(_scene)

	# Compute collision presence automatically from scene content.
	has_collisions = false
	for s: PackedScene in visual_variants:
		if s == null:
			continue
		if not s.can_instantiate():
			continue
		if Helper.scene_has_collision(s):
			has_collisions = true
			break

func spawn() -> TerrainModuleInstance:
	return TerrainModuleInstance.new(self)

func _to_string() -> String:
	var tag_str := ",".join(tags.tags)
	return "TerrainModule(tags=[%s], size=%s)" % [tag_str, str(size)]
