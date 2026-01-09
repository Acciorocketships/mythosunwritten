extends Resource
class_name TerrainModule

@export var scene: PackedScene
@export var size: AABB
@export var tags: TagList
@export var tags_per_socket: Dictionary[String, TagList]

@export var socket_size: Dictionary[String, Distribution]
@export var socket_required: Dictionary[String, TagList]
@export var socket_fill_prob: Distribution
@export var socket_tag_prob: Dictionary[String, Distribution]
@export var visual_variants: Array[PackedScene]

var debug_id: int = 0

func _init(
	_scene: PackedScene = null,
	_size: AABB = AABB(),
	_tags: TagList = TagList.new(),
	_tags_per_socket: Dictionary[String, TagList] = {},
	_socket_size: Dictionary[String, Distribution] = {},
	_socket_required: Dictionary[String, TagList] = {},
	_socket_fill_prob: Distribution = Distribution.new(),
	_socket_tag_prob: Dictionary[String, Distribution] = {},
	_visual_variants: Array[PackedScene] = [],
) -> void:
	scene = _scene
	size = _size
	tags = _tags
	tags_per_socket = _tags_per_socket
	socket_size = _socket_size
	socket_required = _socket_required
	socket_fill_prob = _socket_fill_prob
	socket_tag_prob = _socket_tag_prob
	visual_variants = _visual_variants

func spawn() -> TerrainModuleInstance:
	return TerrainModuleInstance.new(self)
