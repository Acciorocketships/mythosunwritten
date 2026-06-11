class_name TerrainModule
extends Resource

@export var scene: PackedScene
@export var size: AABB
@export var tags: TagList

@export var socket_size: Dictionary[String, Distribution]
@export var socket_required: Dictionary[String, TagList]
# Per-socket fill probabilities in [0, 1] (NOT a Distribution; does not sum to 1).
@export var socket_fill_prob: Dictionary
@export var socket_tag_prob: Dictionary[String, Distribution]
@export var visual_variants: Array[PackedScene]


# If true, this module can replace existing terrain pieces when placed.
# Instead of failing placement due to AABB collisions, it will remove overlapping pieces.
@export var replace_existing: bool = false

# If true, this module is a decoration that yields to structure: it never blocks
# placement, and any piece placed over it removes it (e.g. grass, bushes, rocks).
@export var displaceable: bool = false

# Optional per-socket suppression: socket name -> {"socket": String,
# "prob": float}. If the suppressor socket's deterministic position roll would
# pass at the given probability, the suppressed socket is never enqueued. The
# probability is authored independently of the current variant's fill prob so
# the verdict stays stable across retiles (e.g. a level edge that later
# becomes a stacking center). Used so decorations don't spawn on a tile whose
# topcenter is (ever) going to seed a structure, which would visibly displace
# them.
@export var socket_suppressed_by: Dictionary[String, Dictionary] = {}

func _init(
	_scene: PackedScene = null,
	_size: AABB = AABB(),
	_tags: TagList = TagList.new(),
	_visual_variants: Array[PackedScene] = [],
	_socket_size: Dictionary[String, Distribution] = {},
	_socket_required: Dictionary[String, TagList] = {},
	_socket_fill_prob: Dictionary = {},
	_socket_tag_prob: Dictionary[String, Distribution] = {},
	_replace_existing: bool = false,
	_displaceable: bool = false,
	_socket_suppressed_by: Dictionary[String, Dictionary] = {},
) -> void:
	scene = _scene
	size = _size
	tags = _tags
	socket_size = _socket_size
	socket_required = _socket_required
	socket_fill_prob = _socket_fill_prob
	socket_tag_prob = _socket_tag_prob
	visual_variants = _visual_variants.duplicate()
	visual_variants.append(_scene)
	replace_existing = _replace_existing
	displaceable = _displaceable
	socket_suppressed_by = _socket_suppressed_by


	# Validate authored distributions (fail fast in debug/tests).
	assert_distributions_normalized(socket_size, "socket_size")
	assert_distributions_normalized(socket_tag_prob, "socket_tag_prob")
	assert_probabilities_in_range(socket_fill_prob, "socket_fill_prob")
	assert_socket_fill_prob_matches_scene(scene, socket_fill_prob, "socket_fill_prob")

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
	# Null distributions are allowed and treated as uniform (no preference).
	const EPS: float = 1e-4
	for k: String in dists.keys():
		var dist: Distribution = dists[k]
		if dist == null:
			continue  # Null distributions are valid (treated as uniform)
		assert(!dist.dist.is_empty(), "Empty Distribution for key '%s' (%s)" % [k, label])
		var s: float = 0.0
		for tag: String in dist.dist.keys():
			s += float(dist.dist[tag])
		assert(
			absf(s - 1.0) <= EPS,
			"Distribution not normalised for key '%s' (%s): sum=%s dist=%s"
			% [k, label, str(s), str(dist.dist)]
		)

static func assert_probabilities_in_range(probs: Dictionary, label: String = "") -> void:
	# Asserts each probability is within [0, 1].
	for k: String in probs.keys():
		if probs[k] == null:
			continue
		var p: float = float(probs[k])
		assert(
			p >= 0.0 and p <= 1.0,
			"Probability out of range for key '%s' (%s): p=%s"
			% [k, label, str(p)]
		)


static func assert_socket_fill_prob_matches_scene(
	scene_ref: PackedScene,
	fill_probs: Dictionary,
	label: String = ""
) -> void:
	var socket_names: Array[String] = _scene_socket_names(scene_ref)
	if socket_names.is_empty():
		return

	for socket_name: String in socket_names:
		assert(
			fill_probs.has(socket_name),
			"Missing socket_fill_prob entry for socket '%s' (%s)"
			% [socket_name, label]
		)

	for authored_socket: String in fill_probs.keys():
		assert(
			socket_names.has(authored_socket),
			"Unknown socket_fill_prob entry '%s' not present in scene (%s)"
			% [authored_socket, label]
		)


static func _scene_socket_names(scene_ref: PackedScene) -> Array[String]:
	var out: Array[String] = []
	if scene_ref == null or not scene_ref.can_instantiate():
		return out
	var root_node: Node = scene_ref.instantiate()
	var sockets_node: Node = root_node.get_node_or_null("Sockets")
	if sockets_node == null:
		root_node.free()
		return out
	for child in sockets_node.get_children():
		var marker: Marker3D = child as Marker3D
		if marker != null:
			out.append(String(marker.name))
	root_node.free()
	return out
