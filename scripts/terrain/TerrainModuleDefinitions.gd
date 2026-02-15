class_name TerrainModuleDefinitions
extends Resource

### Individual Terrain Modules ###

static func load_ground_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/GroundTile.tscn")
	var tags: TagList = TagList.new(["ground", "24x24", "side"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	# Override computed AABB to have height 0.5 instead of computed value
	var bb: AABB = AABB(Vector3(-12.0, 0.0, -12.0), Vector3(24.0, 0.5, 24.0))

	var top_size_dist_corners: Distribution = Distribution.new({"point": 0.9, "12x12": 0.1})
	var top_fill_prob_corners: float = 0.05
	var top_size_dist_cardinal: Distribution = Distribution.new({"point": 0.9, "8x8": 0.1})
	var top_fill_prob_cardinal: float = 0.05
	var top_size_dist_center: Distribution = Distribution.new({"24x24": 1.0})
	var top_fill_prob_center: float = 0.2  # Increase level seed frequency
	var adjacent_tag_prob: Distribution = Distribution.new({"ground": 1.0})
	var top_tag_prob_corners: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "hill": 0.1})
	var top_tag_prob_cardinal: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "hill": 0.1})
	var top_tag_prob_center: Distribution = Distribution.new({
		"grass": 0.2,
		"rock": 0.15,
		"bush": 0.15,
		"tree": 0.15,
		"hill": 0.1,
		"level-center": 0.25
	})

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24": 1.0}),
		"back": Distribution.new({"24x24": 1.0}),
		"right": Distribution.new({"24x24": 1.0}),
		"left": Distribution.new({"24x24": 1.0}),
		"topfront": top_size_dist_cardinal,
		"topback": top_size_dist_cardinal,
		"topleft": top_size_dist_cardinal,
		"topright": top_size_dist_cardinal,
		"topcenter": top_size_dist_center,
		"topfrontright": top_size_dist_corners,
		"topfrontleft": top_size_dist_corners,
		"topbackright": top_size_dist_corners,
		"topbackleft": top_size_dist_corners,
	}
	var socket_required: Dictionary[String, TagList] = {
		"front": TagList.new(["ground", "side"]),
		"back": TagList.new(["ground", "side"]),
		"right": TagList.new(["ground", "side"]),
		"left": TagList.new(["ground", "side"]),
	}
	var socket_fill_prob: Dictionary[String, float] = {
		"front": 1.0,
		"back": 1.0,
		"right": 1.0,
		"left": 1.0,
		"topfront": top_fill_prob_cardinal,
		"topback": top_fill_prob_cardinal,
		"topleft": top_fill_prob_cardinal,
		"topright": top_fill_prob_cardinal,
		"topfrontright": top_fill_prob_corners,
		"topfrontleft": top_fill_prob_corners,
		"topbackright": top_fill_prob_corners,
		"topbackleft": top_fill_prob_corners,
		"topcenter": top_fill_prob_center,
	}

	var socket_tag_prob: Dictionary[String, Distribution] = {
		"front": adjacent_tag_prob,
		"back": adjacent_tag_prob,
		"right": adjacent_tag_prob,
		"left": adjacent_tag_prob,
		"topfront": top_tag_prob_cardinal,
		"topback": top_tag_prob_cardinal,
		"topleft": top_tag_prob_cardinal,
		"topright": top_tag_prob_cardinal,
		"topfrontright": top_tag_prob_corners,
		"topfrontleft": top_tag_prob_corners,
		"topbackright": top_tag_prob_corners,
		"topbackleft": top_tag_prob_corners,
		"topcenter": top_tag_prob_center,
	}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false  # replace_existing = false
	)

static func load_grass_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Grass1.tscn")
	var tags: TagList = TagList.new(["grass", "rotate", "point"])
	# Compute bounds from the mesh instead of manually authoring.
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)
	var visual_variants: Array[PackedScene] = [load("res://terrain/scenes/Grass2.tscn")]

	return TerrainModule.new(
		scene,
		bb,
		tags,
		{},
		visual_variants
	)

static func load_bush_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Bush1.tscn")
	var tags: TagList = TagList.new(["bush", "rotate", "point"])
	# Compute bounds from the mesh instead of manually authoring.
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)
	var visual_variants: Array[PackedScene] = []

	return TerrainModule.new(
		scene,
		bb,
		tags,
		{},
		visual_variants
	)

static func load_rock_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Rock1.tscn")
	var tags: TagList = TagList.new(["rock", "rotate", "point"])
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)
	var visual_variants: Array[PackedScene] = []

	return TerrainModule.new(
		scene,
		bb,
		tags,
		{},
		visual_variants
	)

static func load_tree_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Tree1.tscn")
	var tags: TagList = TagList.new(["tree", "rotate", "point"])
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)
	var visual_variants: Array[PackedScene] = []

	return TerrainModule.new(
		scene,
		bb,
		tags,
		{},
		visual_variants
	)

static func load_8x8x2_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Hill_8x8x2.tscn")
	var tags: TagList = TagList.new(["hill", "8x8"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"point": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, float] = {
		"topcenter": 0.5,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {"topcenter": Distribution.new({"grass": 1.0})}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false  # replace_existing = false
	)


static func load_12x12x2_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Hill_12x12x2.tscn")
	var tags: TagList = TagList.new(["hill", "12x12"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"8x8": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, float] = {
		"topcenter": 0.3,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"hill": 1.0}),
	}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob
		)

static func load_level_side_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelSide.tscn",
		TagList.new(["level", "level-side", "24x24"])
	)

static func load_level_corner_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelCorner.tscn",
		TagList.new(["level", "level-corner", "24x24"])
	)

static func load_level_line_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelLine.tscn",
		TagList.new(["level", "level-line", "24x24"])
	)

static func load_level_peninsula_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelPeninsula.tscn",
		TagList.new(["level", "level-peninsula", "24x24"])
	)

static func load_level_island_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelIsland.tscn",
		TagList.new(["level", "level-island", "24x24"])
	)

static func load_level_middle_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/GroundTile.tscn",
		TagList.new(["level", "level-center", "24x24"])
	)


static func _build_level_tile(scene_path: String, tags: TagList) -> TerrainModule:
	var scene = load(scene_path)
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)
	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24": 1.0}),
		"back": Distribution.new({"24x24": 1.0}),
		"left": Distribution.new({"24x24": 1.0}),
		"right": Distribution.new({"24x24": 1.0})
	}
	var socket_required: Dictionary[String, TagList] = {
		"front": TagList.new(["level"]),
		"back": TagList.new(["level"]),
		"left": TagList.new(["level"]),
		"right": TagList.new(["level"]),
		"bottom": TagList.new(["ground"])
	}
	var socket_fill_prob: Dictionary[String, float] = {
		"front": 0.8,
		"back": 0.8,
		"left": 0.8,
		"right": 0.8,
		"topcenter": 0.0
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"front": null,
		"back": null,
		"left": null,
		"right": null
	}
	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false
	)


### Test Pieces for Different Sizes ###

static func create_8x8_test_piece() -> TerrainModule:
	# Create a simple test piece with a bottom socket and appropriate dimensions
	var scene = load("res://terrain/scenes/Hill_8x8x2.tscn")  # Use existing hill as base
	var tags: TagList = TagList.new(["8x8"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = AABB(Vector3(-4, -1, -4), Vector3(8, 2, 8))  # 8x2x8 centered

	var socket_size: Dictionary[String, Distribution] = {
		"bottom": Distribution.new({"point": 1.0}),
		"topcenter": Distribution.new({"point": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, float] = {
		"bottom": 0.0,  # Test pieces don't expand
		"topcenter": 0.0,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false
	)


static func create_12x12_test_piece() -> TerrainModule:
	# Create a simple test piece with a bottom socket and appropriate dimensions
	var scene = load("res://terrain/scenes/Hill_12x12x2.tscn")  # Use existing hill as base
	var tags: TagList = TagList.new(["12x12"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = AABB(Vector3(-6, -1, -6), Vector3(12, 2, 12))  # 12x2x12 centered

	var socket_size: Dictionary[String, Distribution] = {
		"bottom": Distribution.new({"8x8": 1.0}),
		"topcenter": Distribution.new({"8x8": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, float] = {
		"bottom": 0.0,  # Test pieces don't expand
		"topcenter": 0.0,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false
	)


static func create_24x24_test_piece() -> TerrainModule:
	# Create a simple test piece for the ground size
	var scene = load("res://terrain/scenes/GroundTile.tscn")  # Use existing ground as base
	var tags: TagList = TagList.new(["24x24"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = AABB(Vector3(-12, 0, -12), Vector3(24, 0.5, 24))  # 24x0.5x24

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24": 1.0}),
		"back": Distribution.new({"24x24": 1.0}),
		"left": Distribution.new({"24x24": 1.0}),
		"right": Distribution.new({"24x24": 1.0}),
		"topcenter": Distribution.new({"24x24": 1.0}),
		"topfront": Distribution.new({"8x8": 1.0}),
		"topback": Distribution.new({"8x8": 1.0}),
		"topleft": Distribution.new({"8x8": 1.0}),
		"topright": Distribution.new({"8x8": 1.0}),
		"topfrontright": Distribution.new({"12x12": 1.0}),
		"topfrontleft": Distribution.new({"12x12": 1.0}),
		"topbackright": Distribution.new({"12x12": 1.0}),
		"topbackleft": Distribution.new({"12x12": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, float] = {
		"front": 1.0,  # Test pieces need fill_prob > 0 for adjacency detection
		"back": 1.0,
		"left": 1.0,
		"right": 1.0,
		"topcenter": 0.0,  # Only level tiles expand from these
		"topfront": 0.0,
		"topback": 0.0,
		"topleft": 0.0,
		"topright": 0.0,
		"topfrontright": 0.0,
		"topfrontleft": 0.0,
		"topbackright": 0.0,
		"topbackleft": 0.0,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		tags_per_socket,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false
	)
