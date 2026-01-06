extends Resource
class_name TerrainModule

@export var scene: PackedScene
@export var size: AABB
@export var tags: Array[String] = []

@export var socket_size: Dictionary = {}          # String -> Distribution
@export var socket_required: Dictionary = {}      # String -> Array[String]
@export var socket_fill_prob: Distribution = Distribution.new() # String -> float
@export var socket_tag_prob: Dictionary = {}      # String -> Distribution
@export var visual_variants: Array[PackedScene] = []

func _init(
	_scene: PackedScene = null,
	_size: AABB = AABB(),
	_tags: Array[String] = [],
	_socket_size: Dictionary = {},
	_socket_required: Dictionary = {},
	_socket_fill_prob: Distribution = Distribution.new(),
	_socket_tag_prob: Dictionary = {},
	_visual_variants: Array[PackedScene] = [],
) -> void:
	scene = _scene
	size = _size
	tags = _tags
	socket_size = _socket_size
	socket_required = _socket_required
	socket_fill_prob = _socket_fill_prob
	socket_tag_prob = _socket_tag_prob
	visual_variants = _visual_variants

func spawn() -> TerrainModuleInstance:
	return TerrainModuleInstance.new(self)
