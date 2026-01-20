class_name TerrainModule
extends Resource

@export var scene: PackedScene
@export var size: AABB
@export var tags: TagList
@export var tags_per_socket: Dictionary[String, TagList]

@export var socket_size: Dictionary[String, Distribution]
@export var socket_required: Dictionary[String, TagList]
# Per-socket fill probabilities in [0, 1] (NOT a Distribution; does not sum to 1).
@export var socket_fill_prob: Dictionary[String, float]
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
	_socket_fill_prob: Dictionary[String, float] = {},
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

	# Validate authored distributions (fail fast in debug/tests).
	assert_distributions_normalized(socket_size, "socket_size")
	assert_distributions_normalized(socket_tag_prob, "socket_tag_prob")
	assert_probabilities_in_range(socket_fill_prob, "socket_fill_prob")

func spawn() -> TerrainModuleInstance:
	return TerrainModuleInstance.new(self)

func _to_string() -> String:
	var tag_str := ",".join(tags.tags)
	return "TerrainModule(tags=[%s], size=%s)" % [tag_str, str(size)]

static func assert_distributions_normalized(
	dists: Dictionary[String, Distribution],
	label: String = ""
) -> void:
	# Asserts each Distribution in a dict sums to ~1.0.
	# Intended for dicts like `socket_tag_prob` or `socket_size`.
	const EPS: float = 1e-4
	for k: String in dists.keys():
		var dist: Distribution = dists[k]
		assert(dist != null, "Null Distribution for key '%s' (%s)" % [k, label])
		assert(!dist.dist.is_empty(), "Empty Distribution for key '%s' (%s)" % [k, label])
		var s: float = 0.0
		for tag: String in dist.dist.keys():
			s += float(dist.dist[tag])
		assert(
			absf(s - 1.0) <= EPS,
			"Distribution not normalised for key '%s' (%s): sum=%s dist=%s"
			% [k, label, str(s), str(dist.dist)]
		)

static func assert_distribution_normalized(dist: Distribution, label: String = "") -> void:
	# Asserts a single Distribution sums to ~1.0 (e.g. `socket_fill_prob`).
	const EPS: float = 1e-4
	assert(dist != null, "Null Distribution (%s)" % label)
	assert(!dist.dist.is_empty(), "Empty Distribution (%s)" % label)
	var s: float = 0.0
	for tag: String in dist.dist.keys():
		s += float(dist.dist[tag])
	assert(
		absf(s - 1.0) <= EPS,
		"Distribution not normalised (%s): sum=%s dist=%s" % [label, str(s), str(dist.dist)]
	)

static func assert_probabilities_in_range(probs: Dictionary[String, float], label: String = "") -> void:
	# Asserts each probability is within [0, 1].
	for k: String in probs.keys():
		var p: float = float(probs[k])
		assert(
			p >= 0.0 and p <= 1.0,
			"Probability out of range for key '%s' (%s): p=%s"
			% [k, label, str(p)]
		)
