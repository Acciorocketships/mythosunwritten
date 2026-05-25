class_name TerrainModuleDefinitions
extends Resource

const LEVEL_BASE_LATERAL_FILL_PROB: float = 0.3
const LEVEL_TOPCENTER_FILL_PROB: float = 0.3
const CLIFF_LATERAL_FILL_PROB: float = 0.35

### Individual Terrain Modules ###

static func load_ground_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/GroundTile.tscn")
	var tags: TagList = TagList.new(["ground", "ground-type", "24x24x0.5", "side"])
	# Override computed AABB to have height 0.5 instead of computed value
	var bb: AABB = AABB(Vector3(-12.0, 0.0, -12.0), Vector3(24.0, 0.5, 24.0))

	var top_size_dist_corners: Distribution = Distribution.new({"point": 0.9, "12x12x2": 0.1})
	var top_fill_prob_corners: float = 0.05
	var top_size_dist_cardinal: Distribution = Distribution.new({"point": 0.9, "8x8x2": 0.1})
	var top_fill_prob_cardinal: float = 0.05
	var top_size_dist_center: Distribution = Distribution.new({"24x24x0.5": 0.95, "24x24x4": 0.05})
	var top_fill_prob_center: float = 0.1
	var adjacent_tag_prob: Distribution = Distribution.new({"ground": 1.0})
	var top_tag_prob_corners: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "hill": 0.1})
	var top_tag_prob_cardinal: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "hill": 0.1})
	var top_tag_prob_center: Distribution = Distribution.new({"level-ground-center": 0.95, "cliff-side": 0.05})

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x0.5": 1.0}),
		"back": Distribution.new({"24x24x0.5": 1.0}),
		"right": Distribution.new({"24x24x0.5": 1.0}),
		"left": Distribution.new({"24x24x0.5": 1.0}),
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
	var socket_fill_prob: Dictionary[String, Variant] = {
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
		"bottom": null,
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
		visual_variants,
		{},
		{},
		{"bottom": null},
		{}
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
		visual_variants,
		{},
		{},
		{"bottom": null},
		{}
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
		visual_variants,
		{},
		{},
		{"bottom": null},
		{}
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
		visual_variants,
		{},
		{},
		{"bottom": null},
		{}
	)

static func load_8x8x2_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Hill_8x8x2.tscn")
	var tags: TagList = TagList.new(["hill", "8x8x2"])
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"point": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"topcenter": 0.5,
		"bottom": null,
		"topfrontright": null,
		"topfrontleft": null,
		"topbackright": null,
		"topbackleft": null,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {"topcenter": Distribution.new({"grass": 1.0})}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false  # replace_existing = false
	)


static func load_12x12x2_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Hill_12x12x2.tscn")
	var tags: TagList = TagList.new(["hill", "12x12x2"])
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"8x8x2": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"topcenter": 0.3,
		"bottom": null,
		"topfrontright": null,
		"topfrontleft": null,
		"topbackright": null,
		"topbackleft": null,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"hill": 1.0}),
	}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob
	)

static func load_level_side_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelSide.tscn",
		TagList.new(["level", "level-ground", "level-side", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)

static func load_level_corner_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelCorner.tscn",
		TagList.new(["level", "level-ground", "level-corner", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)

static func load_level_line_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelLine.tscn",
		TagList.new(["level", "level-ground", "level-line", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)

static func load_level_peninsula_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelPeninsula.tscn",
		TagList.new(["level", "level-ground", "level-peninsula", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)

static func load_level_island_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelIsland.tscn",
		TagList.new(["level", "level-ground", "level-island", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)

static func load_level_middle_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelCenter.tscn",
		TagList.new(["level", "level-ground", "level-center", "level-ground-center", "ground-type", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		LEVEL_TOPCENTER_FILL_PROB,
		"level-ground-center",
		"level-stack-center"
	)

static func load_level_stack_middle_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelCenter.tscn",
		TagList.new(["level", "level-stack", "level-center", "level-stack-center", "24x24x0.5"]),
		null,
		LEVEL_TOPCENTER_FILL_PROB,
		"",
		"level-stack-center"
	)

static func load_level_inner_corner_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCorner.tscn",
		TagList.new(["level", "level-ground", "level-inner-corner", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)


static func load_level_inner_corner_diag_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerDiag.tscn",
		TagList.new(["level", "level-ground", "level-inner-corner-diag", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)


static func load_level_inner_corner_side_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerSide.tscn",
		TagList.new(["level", "level-ground", "level-inner-corner-side", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)


static func load_level_inner_corner_edge1_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerEdge1.tscn",
		TagList.new(["level", "level-ground", "level-inner-corner-edge1", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)


static func load_level_inner_corner_edge2_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerEdge2.tscn",
		TagList.new(["level", "level-ground", "level-inner-corner-edge2", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)


static func load_level_inner_corner_edge_both_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerEdgeBoth.tscn",
		TagList.new(["level", "level-ground", "level-inner-corner-edge-both", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)


static func load_level_inner_corner_side_edge_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerSideEdge.tscn",
		TagList.new(["level", "level-ground", "level-inner-corner-side-edge", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)


static func load_level_inner_corner_three_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerThree.tscn",
		TagList.new(["level", "level-ground", "level-inner-corner-three", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)


static func load_level_inner_corner_all_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerAll.tscn",
		TagList.new(["level", "level-ground", "level-inner-corner-all", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		null,
		"level-ground-center",
		""
	)

static func load_level_stack_side_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelSide.tscn",
		TagList.new(["level", "level-stack", "level-side", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_corner_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelCorner.tscn",
		TagList.new(["level", "level-stack", "level-corner", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_line_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelLine.tscn",
		TagList.new(["level", "level-stack", "level-line", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_peninsula_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelPeninsula.tscn",
		TagList.new(["level", "level-stack", "level-peninsula", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_island_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelIsland.tscn",
		TagList.new(["level", "level-stack", "level-island", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_inner_corner_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCorner.tscn",
		TagList.new(["level", "level-stack", "level-inner-corner", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_inner_corner_diag_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerDiag.tscn",
		TagList.new(["level", "level-stack", "level-inner-corner-diag", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_inner_corner_side_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerSide.tscn",
		TagList.new(["level", "level-stack", "level-inner-corner-side", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_inner_corner_edge1_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerEdge1.tscn",
		TagList.new(["level", "level-stack", "level-inner-corner-edge1", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_inner_corner_edge2_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerEdge2.tscn",
		TagList.new(["level", "level-stack", "level-inner-corner-edge2", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_inner_corner_edge_both_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerEdgeBoth.tscn",
		TagList.new(["level", "level-stack", "level-inner-corner-edge-both", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_inner_corner_side_edge_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerSideEdge.tscn",
		TagList.new(["level", "level-stack", "level-inner-corner-side-edge", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_inner_corner_three_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerThree.tscn",
		TagList.new(["level", "level-stack", "level-inner-corner-three", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)

static func load_level_stack_inner_corner_all_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelInCornerAll.tscn",
		TagList.new(["level", "level-stack", "level-inner-corner-all", "24x24x0.5"]),
		null,
		null,
		"",
		""
	)


static func load_cliff_side_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffSide.tscn",
		TagList.new(["cliff", "cliff-side", "24x24x4"])
	)


static func load_cliff_corner_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffCorner.tscn",
		TagList.new(["cliff", "cliff-corner", "24x24x4"])
	)


static func load_cliff_line_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffLine.tscn",
		TagList.new(["cliff", "cliff-line", "24x24x4"])
	)


static func load_cliff_peninsula_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffPeninsula.tscn",
		TagList.new(["cliff", "cliff-peninsula", "24x24x4"])
	)


static func load_cliff_island_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffIsland.tscn",
		TagList.new(["cliff", "cliff-island", "24x24x4"])
	)


static func load_cliff_inner_corner_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCorner.tscn",
		TagList.new(["cliff", "cliff-inner-corner", "24x24x4"])
	)


static func load_cliff_inner_corner_diag_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerDiag.tscn",
		TagList.new(["cliff", "cliff-inner-corner-diag", "24x24x4"])
	)


static func load_cliff_inner_corner_side_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerSide.tscn",
		TagList.new(["cliff", "cliff-inner-corner-side", "24x24x4"])
	)


static func load_cliff_inner_corner_three_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerThree.tscn",
		TagList.new(["cliff", "cliff-inner-corner-three", "24x24x4"])
	)


static func load_cliff_inner_corner_all_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerAll.tscn",
		TagList.new(["cliff", "cliff-inner-corner-all", "24x24x4"])
	)


static func load_cliff_inner_corner_edge1_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerEdge1.tscn",
		TagList.new(["cliff", "cliff-inner-corner-edge1", "24x24x4"])
	)


static func load_cliff_inner_corner_edge2_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerEdge2.tscn",
		TagList.new(["cliff", "cliff-inner-corner-edge2", "24x24x4"])
	)


static func load_cliff_inner_corner_edge_both_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerEdgeBoth.tscn",
		TagList.new(["cliff", "cliff-inner-corner-edge-both", "24x24x4"])
	)


static func load_cliff_inner_corner_side_edge_tile() -> TerrainModule:
	return _build_cliff_tile(
		"res://terrain/scenes/CliffInCornerSideEdge.tscn",
		TagList.new(["cliff", "cliff-inner-corner-side-edge", "24x24x4"])
	)


static func load_cliff_interior_tile() -> TerrainModule:
	# Cliff plateau interior: visually a ground tile, but tagged "cliff" so neighbour
	# cliff-sides' required-tag filters remain satisfied. Lateral cardinals are
	# non-expandable because the plateau perimeter is covered by cliff-sides.
	# Topcenter is NOT expanded — placing a level/cliff on top would cover the
	# cliff plateau with a second tile layer and merge plateaus into giant slabs.
	# Foliage spawns on the top corners (grass/trees on the cliff plateau surface).
	var scene: PackedScene = load("res://terrain/scenes/GroundTile.tscn")
	var tags: TagList = TagList.new(["cliff", "cliff-interior", "ground-type", "24x24x4"])
	var bb: AABB = AABB(Vector3(-12, -0.5, -12), Vector3(24, 0.5, 24))

	var top_size_dist_corners: Distribution = Distribution.new({"point": 0.9, "12x12x2": 0.1})
	var top_size_dist_cardinal: Distribution = Distribution.new({"point": 0.9, "8x8x2": 0.1})
	var top_tag_prob_corners: Distribution = Distribution.new({"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "hill": 0.1})
	var top_tag_prob_cardinal: Distribution = top_tag_prob_corners

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x4": 1.0}),
		"back": Distribution.new({"24x24x4": 1.0}),
		"right": Distribution.new({"24x24x4": 1.0}),
		"left": Distribution.new({"24x24x4": 1.0}),
		"topfront": top_size_dist_cardinal,
		"topback": top_size_dist_cardinal,
		"topleft": top_size_dist_cardinal,
		"topright": top_size_dist_cardinal,
		"topcenter": Distribution.new({"point": 1.0}),
		"topfrontright": top_size_dist_corners,
		"topfrontleft": top_size_dist_corners,
		"topbackright": top_size_dist_corners,
		"topbackleft": top_size_dist_corners,
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": null,
		"back": null,
		"right": null,
		"left": null,
		"topfront": 0.05,
		"topback": 0.05,
		"topleft": 0.05,
		"topright": 0.05,
		"topfrontright": 0.05,
		"topfrontleft": 0.05,
		"topbackright": 0.05,
		"topbackleft": 0.05,
		"topcenter": null,
		"bottom": null,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topfront": top_tag_prob_cardinal,
		"topback": top_tag_prob_cardinal,
		"topleft": top_tag_prob_cardinal,
		"topright": top_tag_prob_cardinal,
		"topfrontright": top_tag_prob_corners,
		"topfrontleft": top_tag_prob_corners,
		"topbackright": top_tag_prob_corners,
		"topbackleft": top_tag_prob_corners,
	}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		true  # replace_existing
	)


static func _build_cliff_tile(
	scene_path: String,
	tags: TagList
) -> TerrainModule:
	# All cliff edge variants share an identical socket layout:
	#   - Cardinals at top elevation, required=cliff, high lateral fill.
	#   - Diagonals are null (markers for inner-corner detection only).
	#   - Bottom attaches to a ground tile below (no expansion).
	#   - Topcenter does NOT expand on edge variants. Only cliff-interior
	#     (the rule's interior-swap target) carries the topcenter distribution
	#     for foliage and multi-storey cliff seeding.
	var scene: PackedScene = load(scene_path)
	var bb: AABB = AABB(Vector3(-12, -4, -12), Vector3(24, 4, 24))

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x4": 1.0}),
		"back": Distribution.new({"24x24x4": 1.0}),
		"left": Distribution.new({"24x24x4": 1.0}),
		"right": Distribution.new({"24x24x4": 1.0}),
		"topcenter": Distribution.new({"24x24x0.5": 1.0}),
		"bottom": Distribution.new({"24x24x0.5": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {
		"front": TagList.new(["cliff"]),
		"back": TagList.new(["cliff"]),
		"left": TagList.new(["cliff"]),
		"right": TagList.new(["cliff"]),
		"bottom": TagList.new(["ground"]),
	}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": CLIFF_LATERAL_FILL_PROB,
		"back": CLIFF_LATERAL_FILL_PROB,
		"left": CLIFF_LATERAL_FILL_PROB,
		"right": CLIFF_LATERAL_FILL_PROB,
		"frontleft": null,
		"frontright": null,
		"backleft": null,
		"backright": null,
		"bottom": null,
		"topcenter": null,
	}
	var cliff_lateral_dist: Distribution = Distribution.new({"cliff": 1.0})
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"front": cliff_lateral_dist,
		"back": cliff_lateral_dist,
		"left": cliff_lateral_dist,
		"right": cliff_lateral_dist,
	}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		true  # replace_existing
	)


static func _build_level_tile(
	scene_path: String,
	tags: TagList,
	cardinal_fill_prob: Variant = null,
	topcenter_fill_prob: Variant = null,
	cardinal_target_tag: String = "",
	topcenter_target_tag: String = ""
) -> TerrainModule:
	var scene = load(scene_path)
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)
	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x0.5": 1.0}),
		"back": Distribution.new({"24x24x0.5": 1.0}),
		"left": Distribution.new({"24x24x0.5": 1.0}),
		"right": Distribution.new({"24x24x0.5": 1.0}),
		"topcenter": Distribution.new({"24x24x0.5": 1.0})
	}
	var socket_required: Dictionary[String, TagList] = {
		"front": TagList.new(["level"]),
		"back": TagList.new(["level"]),
		"left": TagList.new(["level"]),
		"right": TagList.new(["level"]),
	}
	var socket_fill_prob_policy: Dictionary = {
		"front": cardinal_fill_prob,
		"back": cardinal_fill_prob,
		"left": cardinal_fill_prob,
		"right": cardinal_fill_prob,
		"bottom": null,
		"bottomfront": null,
		"bottomback": null,
		"bottomleft": null,
		"bottomright": null,
		"frontright": null,
		"frontleft": null,
		"backright": null,
		"backleft": null,
		"topcenter": topcenter_fill_prob,
		"topfront": null,
		"topback": null,
		"topright": null,
		"topleft": null,
		"topfrontright": null,
		"topfrontleft": null,
		"topbackright": null,
		"topbackleft": null,
	}
	var socket_fill_prob: Dictionary[String, Variant] = _socket_fill_prob_for_scene(scene, socket_fill_prob_policy)
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"front": null,
		"back": null,
		"left": null,
		"right": null,
	}
	if cardinal_target_tag != "":
		var cardinal_dist: Distribution = Distribution.new({cardinal_target_tag: 1.0})
		socket_tag_prob["front"] = cardinal_dist
		socket_tag_prob["back"] = cardinal_dist
		socket_tag_prob["left"] = cardinal_dist
		socket_tag_prob["right"] = cardinal_dist
	if topcenter_target_tag != "":
		socket_tag_prob["topcenter"] = Distribution.new({topcenter_target_tag: 1.0})
	return TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		true
	)



static func _socket_fill_prob_for_scene(scene: PackedScene, policy: Dictionary) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var socket_names: Array[String] = _scene_socket_names(scene)
	for socket_name in socket_names:
		assert(
			policy.has(socket_name),
			"Missing socket_fill_prob policy entry for scene socket '%s'" % socket_name
		)
		out[socket_name] = policy[socket_name]
	return out


static func _scene_socket_names(scene: PackedScene) -> Array[String]:
	var out: Array[String] = []
	if scene == null or not scene.can_instantiate():
		return out
	var root_node: Node = scene.instantiate()
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


### Test Pieces for Different Sizes ###

static func create_8x8_test_piece() -> TerrainModule:
	# Create a simple test piece with a bottom socket and appropriate dimensions
	var scene = load("res://terrain/scenes/Hill_8x8x2.tscn")  # Use existing hill as base
	var tags: TagList = TagList.new(["8x8x2"])
	var bb: AABB = AABB(Vector3(-4, -1, -4), Vector3(8, 2, 8))  # 8x2x8 centered

	var socket_size: Dictionary[String, Distribution] = {
		"bottom": Distribution.new({"point": 1.0}),
		"topcenter": Distribution.new({"point": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"bottom": 0.0,  # Test pieces don't expand
		"topcenter": 0.0,
		"topfrontright": null,
		"topfrontleft": null,
		"topbackright": null,
		"topbackleft": null,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {}

	return TerrainModule.new(
		scene,
		bb,
		tags,
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
	var tags: TagList = TagList.new(["12x12x2"])
	var bb: AABB = AABB(Vector3(-6, -1, -6), Vector3(12, 2, 12))  # 12x2x12 centered

	var socket_size: Dictionary[String, Distribution] = {
		"bottom": Distribution.new({"8x8x2": 1.0}),
		"topcenter": Distribution.new({"8x8x2": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"bottom": 0.0,  # Test pieces don't expand
		"topcenter": 0.0,
		"topfrontright": null,
		"topfrontleft": null,
		"topbackright": null,
		"topbackleft": null,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {}

	return TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false
	)


static func create_24x24x4_test_piece() -> TerrainModule:
	# Test piece for cliffs (24x24 footprint, 4 units tall).
	# Uses CliffSide.tscn for its socket layout (cardinals at local y=0, bottom at local y=-4).
	# The visual is irrelevant — only sockets matter for adjacency probing.
	var scene = load("res://terrain/scenes/CliffSide.tscn")
	var tags: TagList = TagList.new(["24x24x4"])
	# Override AABB to match cliff dimensions: 24x24x4, base at y=-4 relative to origin.
	var bb: AABB = AABB(Vector3(-12, -4, -12), Vector3(24, 4, 24))

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x4": 1.0}),
		"back": Distribution.new({"24x24x4": 1.0}),
		"left": Distribution.new({"24x24x4": 1.0}),
		"right": Distribution.new({"24x24x4": 1.0}),
		"topcenter": Distribution.new({"24x24x4": 1.0}),
		"bottom": Distribution.new({"24x24x0.5": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	# Every scene socket must have an entry (asserted by TerrainModule).
	# Test pieces don't expand; null = blocking-but-not-fillable.
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": 0.0,
		"back": 0.0,
		"left": 0.0,
		"right": 0.0,
		"frontleft": null,
		"frontright": null,
		"backleft": null,
		"backright": null,
		"bottom": 0.0,
		"topcenter": 0.0,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {}

	return TerrainModule.new(
		scene,
		bb,
		tags,
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
	var tags: TagList = TagList.new(["24x24x0.5"])
	var bb: AABB = AABB(Vector3(-12, 0, -12), Vector3(24, 0.5, 24))  # 24x0.5x24

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x0.5": 1.0}),
		"back": Distribution.new({"24x24x0.5": 1.0}),
		"left": Distribution.new({"24x24x0.5": 1.0}),
		"right": Distribution.new({"24x24x0.5": 1.0}),
		"topcenter": Distribution.new({"24x24x0.5": 1.0}),
		"topfront": Distribution.new({"8x8x2": 1.0}),
		"topback": Distribution.new({"8x8x2": 1.0}),
		"topleft": Distribution.new({"8x8x2": 1.0}),
		"topright": Distribution.new({"8x8x2": 1.0}),
		"topfrontright": Distribution.new({"12x12x2": 1.0}),
		"topfrontleft": Distribution.new({"12x12x2": 1.0}),
		"topbackright": Distribution.new({"12x12x2": 1.0}),
		"topbackleft": Distribution.new({"12x12x2": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": 1.0,  # Test pieces need fill_prob > 0 for adjacency detection
		"back": 1.0,
		"left": 1.0,
		"right": 1.0,
		"bottom": null,
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
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false
	)
