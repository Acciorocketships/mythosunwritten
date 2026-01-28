class_name TerrainModuleDefinitions
extends Resource

### Individual Terrain Modules ###

static func load_ground_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/GroundTile.tscn")
	var tags: TagList = TagList.new(["ground", "24x24"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var top_size_dist_corners: Distribution = Distribution.new({"point": 0.9, "12x12": 0.1})
	var top_fill_prob_corners: float = 0.05
	var top_size_dist_cardinal: Distribution = Distribution.new({"point": 0.9, "8x8": 0.1})
	var top_fill_prob_cardinal: float = 0.05
	var top_size_dist_center: Distribution = Distribution.new({"level": 1.0})
	var top_fill_prob_center: float = 0.05
	var adjacent_tag_prob: Distribution = Distribution.new({"ground": 1.0})
	var top_tag_prob_corners: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "hill": 0.1})
	var top_tag_prob_cardinal: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "hill": 0.1})
	var top_tag_prob_center: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "level": 0.1})

	var socket_size: Dictionary[String, Distribution] = {
		"main": Distribution.new({"24x24": 1.0}),
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
		"main": TagList.new(["ground"]),
		"back": TagList.new(["ground"]),
		"right": TagList.new(["ground"]),
		"left": TagList.new(["ground"]),
	}
	var socket_fill_prob: Dictionary[String, float] = {
		"main": 1.0,
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
		"main": adjacent_tag_prob,
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
		socket_tag_prob
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
		socket_tag_prob
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
	var scene = load("res://terrain/scenes/LevelSide.tscn")
	var tags: TagList = TagList.new(["level", "24x24"])
	var tags_per_socket: Dictionary[String, TagList] = {}
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, float] = {}
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
		socket_tag_prob
		)
