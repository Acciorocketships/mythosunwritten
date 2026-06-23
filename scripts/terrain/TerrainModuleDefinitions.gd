class_name TerrainModuleDefinitions
extends Resource

# Scene-name ↔ variant-tag tables. Each entry is loaded once per tier (level
# emits both "level-ground" and "level-stack" tiers; cliff currently emits only
# the base tier). The center/interior tiles carry extra tags and have their
# own loaders (load_level_middle_tile, load_level_stack_middle_tile,
# load_cliff_interior_tile).
const LEVEL_VARIANT_TABLE: Array = [
	["LevelSide", "level-side"],
	["LevelCorner", "level-corner"],
	["LevelLine", "level-line"],
	["LevelPeninsula", "level-peninsula"],
	["LevelIsland", "level-island"],
	["LevelInCorner", "level-inner-corner"],
	["LevelInCornerDiag", "level-inner-corner-diag"],
	["LevelInCornerSide", "level-inner-corner-side"],
	["LevelInCornerEdge1", "level-inner-corner-edge1"],
	["LevelInCornerEdge2", "level-inner-corner-edge2"],
	["LevelInCornerEdgeBoth", "level-inner-corner-edge-both"],
	["LevelInCornerSideEdge", "level-inner-corner-side-edge"],
	["LevelInCornerThree", "level-inner-corner-three"],
	["LevelInCornerAll", "level-inner-corner-all"],
]

const CLIFF_VARIANT_TABLE: Array = [
	["CliffSide", "cliff-side"],
	["CliffCorner", "cliff-corner"],
	["CliffLine", "cliff-line"],
	["CliffPeninsula", "cliff-peninsula"],
	["CliffIsland", "cliff-island"],
	["CliffInCorner", "cliff-inner-corner"],
	["CliffInCornerDiag", "cliff-inner-corner-diag"],
	["CliffInCornerSide", "cliff-inner-corner-side"],
	["CliffInCornerThree", "cliff-inner-corner-three"],
	["CliffInCornerAll", "cliff-inner-corner-all"],
	["CliffInCornerEdge1", "cliff-inner-corner-edge1"],
	["CliffInCornerEdge2", "cliff-inner-corner-edge2"],
	["CliffInCornerEdgeBoth", "cliff-inner-corner-edge-both"],
	["CliffInCornerSideEdge", "cliff-inner-corner-side-edge"],
]

# Mating C1 corner variants for multi-storey diagonal corners (selected by the
# heightfield's understacks detection). CliffCornerStacked = convex top half;
# CliffInCornerStacked = concave bottom half (spawned one tier below).
const CLIFF_STACKED_VARIANT_TABLE: Array = [
	["CliffCornerStacked", "cliff-corner-stacked"],
	["CliffInCornerStacked", "cliff-inner-corner-stacked"],
]


### Individual Terrain Modules ###

static func load_ground_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/GroundTile.tscn")
	# "ground-plain" is the sampling tag: water and bank tiles also carry
	# "ground"/"side" (so they satisfy neighbour requirements), but only the
	# plain tile may be SAMPLED at the frontier — WaterRule swaps in the rest.
	var tags: TagList = TagList.new(["ground", "ground-plain", "ground-type", "24x24x0.5", "side"])
	# Override computed AABB to have height 0.5 instead of computed value
	var bb: AABB = AABB(Vector3(-12.0, 0.0, -12.0), Vector3(24.0, 0.5, 24.0))

	var surface: Dictionary = TerrainSpawnConfig.surface_spawn_sockets(
		Distribution.new({
			"24x24x0.5": TerrainSpawnConfig.GROUND_TOPCENTER_LEVEL_PROB,
			"24x24x4": TerrainSpawnConfig.GROUND_TOPCENTER_CLIFF_PROB,
		}),
		Distribution.new({
			"level-ground-center": TerrainSpawnConfig.GROUND_TOPCENTER_LEVEL_PROB,
			"cliff-base-side": TerrainSpawnConfig.GROUND_TOPCENTER_CLIFF_PROB,
		}),
		TerrainSpawnConfig.GROUND_TOPCENTER_FILL_PROB,
		TerrainSpawnConfig.GROUND_FOLIAGE_FILL_PROB
	)
	var adjacent_tag_prob: Distribution = Distribution.new({"ground-plain": 1.0})

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x0.5": 1.0}),
		"back": Distribution.new({"24x24x0.5": 1.0}),
		"right": Distribution.new({"24x24x0.5": 1.0}),
		"left": Distribution.new({"24x24x0.5": 1.0}),
	}
	socket_size.merge(surface["socket_size"])
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
		"bottom": null,
	}
	socket_fill_prob.merge(surface["socket_fill_prob"])
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"front": adjacent_tag_prob,
		"back": adjacent_tag_prob,
		"right": adjacent_tag_prob,
		"left": adjacent_tag_prob,
	}
	socket_tag_prob.merge(surface["socket_tag_prob"])

	var m := TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false,  # replace_existing
		false,  # displaceable
		surface["socket_suppressed_by"]
	)
	m.structural_socket_names = ["front", "back", "left", "right", "topcenter"]
	m.is_base_plane = true
	m.density_profile = "gentle"
	return m

static func load_grass_tile() -> TerrainModule:
	return _build_foliage_tile("res://terrain/scenes/Grass1.tscn", "grass", _load_scenes([
		"Grass2", "Grass3", "Grass4",
	]))

static func load_bush_tile() -> TerrainModule:
	return _build_foliage_tile("res://terrain/scenes/Bush1.tscn", "bush", _load_scenes([
		"Bush2", "Bush3", "Bush4", "Bush5", "Bush6",
	]))

static func load_rock_tile() -> TerrainModule:
	return _build_foliage_tile("res://terrain/scenes/Rock1.tscn", "rock", _load_scenes([
		"Rock2", "Rock3", "Rock4", "Rock5", "Rock6",
	]))

static func load_tree_tile() -> TerrainModule:
	return _build_foliage_tile("res://terrain/scenes/Tree1.tscn", "tree", _load_scenes([
		"Tree2", "Tree3", "Tree4", "Tree5", "Tree6", "Tree7", "TreeBare1",
	]))


static func _load_scenes(names: Array) -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	for scene_name in names:
		out.append(load("res://terrain/scenes/%s.tscn" % scene_name))
	return out


# Point-sized surface decoration: no expansion sockets, never blocks structure
# tiles (displaceable), bounds computed from the mesh.
static func _build_foliage_tile(
	scene_path: String, kind_tag: String, visual_variants: Array[PackedScene] = []
) -> TerrainModule:
	var scene = load(scene_path)
	var tags: TagList = TagList.new([kind_tag, "rotate", "point"])
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	return TerrainModule.new(
		scene,
		bb,
		tags,
		visual_variants,
		{},
		{},
		{"bottom": null},
		{},
		false,  # replace_existing
		true    # displaceable
	)

static func load_8x8x2_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Hill_8x8x2.tscn")
	var tags: TagList = TagList.new(["hill", "8x8x2"])
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new(TerrainSpawnConfig.HILL_8X8_STACK_SIZE_WEIGHTS),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"topcenter": TerrainSpawnConfig.HILL_8X8_STACK_FILL_PROB,
		"bottom": null,
		"topfrontright": null,
		"topfrontleft": null,
		"topbackright": null,
		"topbackleft": null,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new(TerrainSpawnConfig.HILL_8X8_STACK_TAG_WEIGHTS)
	}

	var m_8x8x2 := TerrainModule.new(
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
	m_8x8x2.requires_surface_support = true
	return m_8x8x2


static func load_12x12x2_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Hill_12x12x2.tscn")
	var tags: TagList = TagList.new(["hill", "12x12x2"])
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new(TerrainSpawnConfig.HILL_12X12_STACK_SIZE_WEIGHTS),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"topcenter": TerrainSpawnConfig.HILL_12X12_STACK_FILL_PROB,
		"bottom": null,
		"topfrontright": null,
		"topfrontleft": null,
		"topbackright": null,
		"topbackleft": null,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new(TerrainSpawnConfig.HILL_12X12_STACK_TAG_WEIGHTS),
	}

	var m_12x12x2 := TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob
	)
	m_12x12x2.requires_surface_support = true
	return m_12x12x2

static func load_4x4x4_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Hill_4x4x4.tscn")
	var tags: TagList = TagList.new(["hill", "4x4x4"])
	# Origin at the top surface; the mesh hangs 4 units down (like cliffs).
	var bb: AABB = AABB(Vector3(-2.0, -4.0, -2.0), Vector3(4.0, 4.0, 4.0))

	var socket_size: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new(TerrainSpawnConfig.HILL_4X4_STACK_SIZE_WEIGHTS),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"topcenter": TerrainSpawnConfig.HILL_4X4_STACK_FILL_PROB,
		"bottom": null,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new(TerrainSpawnConfig.HILL_4X4_STACK_TAG_WEIGHTS),
	}

	var m_4x4x4 := TerrainModule.new(
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
	m_4x4x4.requires_surface_support = true
	return m_4x4x4


### Water and banks (data-driven) ###

# Bank variants reuse the cliff scenes placed at ground depth: the grassy top
# sits at ground level and the rock wall drops to the water floor. A variant's
# canonical missing set (see WaterRule) = the sides facing water.
const BANK_VARIANT_TABLE: Array = [
	["CliffSide", "bank-side"],
	["CliffCorner", "bank-corner"],
	["CliffLine", "bank-line"],
	["CliffPeninsula", "bank-peninsula"],
	["CliffIsland", "bank-island"],
	["CliffInCorner", "bank-inner-corner"],
	["CliffInCornerDiag", "bank-inner-corner-diag"],
	["CliffInCornerSide", "bank-inner-corner-side"],
	["CliffInCornerEdge1", "bank-inner-corner-edge1"],
	["CliffInCornerEdge2", "bank-inner-corner-edge2"],
	["CliffInCornerEdgeBoth", "bank-inner-corner-edge-both"],
	["CliffInCornerSideEdge", "bank-inner-corner-side-edge"],
	["CliffInCornerThree", "bank-inner-corner-three"],
	["CliffInCornerAll", "bank-inner-corner-all"],
]


static func load_water_and_bank_modules() -> Array[TerrainModule]:
	var out: Array[TerrainModule] = []
	out.append(load_water_tile())
	for entry in BANK_VARIANT_TABLE:
		out.append(load_bank_variant(entry[0], entry[1]))
	return out


static func load_water_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/WaterTile.tscn")
	# Rides the ground grid (origin at ground-top level); the water surface
	# and floor hang below. Tagged "ground"/"side" so it satisfies neighbour
	# requirements, but NOT "ground-plain" — it is only placed by WaterRule.
	var tags: TagList = TagList.new(["ground", "water", "side", "24x24x0.5"])
	var bb: AABB = AABB(Vector3(-12.0, 0.0, -12.0), Vector3(24.0, 0.5, 24.0))

	var lateral_size: Distribution = Distribution.new({"24x24x0.5": 1.0})
	var lateral_tags: Distribution = Distribution.new({"ground-plain": 1.0})
	var lateral_required: TagList = TagList.new(["ground", "side"])
	var socket_size: Dictionary[String, Distribution] = {
		"front": lateral_size,
		"back": lateral_size,
		"right": lateral_size,
		"left": lateral_size,
	}
	var socket_required: Dictionary[String, TagList] = {
		"front": lateral_required,
		"back": lateral_required,
		"right": lateral_required,
		"left": lateral_required,
	}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": 1.0,
		"back": 1.0,
		"right": 1.0,
		"left": 1.0,
		# Blocking: nothing may be probed above open water (a level expanding
		# laterally would otherwise cantilever over the river).
		"topcenter": 0.0,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"front": lateral_tags,
		"back": lateral_tags,
		"right": lateral_tags,
		"left": lateral_tags,
	}

	var m_water := TerrainModule.new(
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
	m_water.is_base_plane = true
	return m_water


static func load_bank_variant(scene_name: String, variant_tag: String) -> TerrainModule:
	var scene = load("res://terrain/scenes/%s.tscn" % scene_name)
	# Walkable land at ground level whose rock wall drops to the water floor.
	var tags: TagList = TagList.new(
		["ground", "ground-type", "side", "bank", variant_tag, "24x24x0.5"]
	)
	var bb: AABB = AABB(Vector3(-12.0, -4.0, -12.0), Vector3(24.0, 4.5, 24.0))

	var lateral_size: Distribution = Distribution.new({"24x24x0.5": 1.0})
	var lateral_tags: Distribution = Distribution.new({"ground-plain": 1.0})
	var lateral_required: TagList = TagList.new(["ground", "side"])
	var socket_size: Dictionary[String, Distribution] = {
		"front": lateral_size,
		"back": lateral_size,
		"right": lateral_size,
		"left": lateral_size,
	}
	var socket_required: Dictionary[String, TagList] = {
		"front": lateral_required,
		"back": lateral_required,
		"right": lateral_required,
		"left": lateral_required,
	}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": 1.0,
		"back": 1.0,
		"right": 1.0,
		"left": 1.0,
		"frontleft": null,
		"frontright": null,
		"backleft": null,
		"backright": null,
		"bottom": null,
		# Blocking: nothing may sit on a bank tile (the wall lip). A level
		# growing onto a bank would leave its naked side face hanging over
		# the waterline.
		"topcenter": 0.0,
	}
	# Shore vegetation: banks share the cliff scenes (and their 4 cardinal
	# foliage markers) and the walkable-surface decoration rules. The blocking
	# topcenter above survives the merge (merge keeps existing keys), and no
	# structure can ever land on a bank, so suppression stays 0.
	var surface: Dictionary = TerrainSpawnConfig.surface_spawn_sockets(
		Distribution.new({"24x24x0.5": 1.0}),
		Distribution.new({"ground-plain": 1.0}),
		0.0,
		TerrainSpawnConfig.GROUND_FOLIAGE_FILL_PROB,
		0.0
	)
	socket_size.merge(surface["socket_size"])
	# Point decorations only on banks: the shared surface size dists roll
	# hills 15% of the time, and a hill on a bank hangs its untextured base
	# over the waterline (same invariant as levels-never-on-banks).
	var bank_point_only: Distribution = Distribution.new({"point": 1.0})
	for foliage_socket in [
		"topfront", "topback", "topleft", "topright",
		"topfrontright", "topfrontleft", "topbackright", "topbackleft",
	]:
		socket_size[foliage_socket] = bank_point_only
	socket_fill_prob.merge(surface["socket_fill_prob"])
	socket_fill_prob = _socket_fill_prob_for_scene(scene, socket_fill_prob)
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"front": lateral_tags,
		"back": lateral_tags,
		"right": lateral_tags,
		"left": lateral_tags,
	}
	socket_tag_prob.merge(surface["socket_tag_prob"])

	var m_bank := TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		false,
		false,  # displaceable
		surface["socket_suppressed_by"]
	)
	m_bank.is_base_plane = true
	return m_bank


### Level variants (data-driven) ###

# Returns every level variant in both tiers (level-ground and level-stack)
# plus the two center tiles. Used by TerrainModuleLibrary to populate the
# library in one call.
static func load_level_variants() -> Array[TerrainModule]:
	var out: Array[TerrainModule] = []
	for entry in LEVEL_VARIANT_TABLE:
		out.append(load_level_variant(entry[0], "level-ground", entry[1]))
		out.append(load_level_variant(entry[0], "level-stack", entry[1]))
	out.append(load_level_middle_tile())
	out.append(load_level_stack_middle_tile())
	return out


# Build a single level variant. tier is "level-ground" or "level-stack".
static func load_level_variant(
	scene_name: String, tier: String, variant_tag: String
) -> TerrainModule:
	var scene_path: String = "res://terrain/scenes/%s.tscn" % scene_name
	var tags: TagList = TagList.new(["level", tier, variant_tag, "24x24x0.5"])
	# Edge variants get a BLOCKING topcenter (0.0, not null): stacks may only
	# be probed above center tiles, otherwise stack expansion places over an
	# edge and is rejected afterwards, churning forever.
	if tier == "level-ground":
		return _build_level_tile(
			scene_path, tags, TerrainSpawnConfig.LEVEL_BASE_LATERAL_FILL_PROB, 0.0, "level-ground-center",
			TerrainSpawnConfig.GROUND_FOLIAGE_FILL_PROB
		)
	return _build_level_tile(
		scene_path, tags, TerrainSpawnConfig.LEVEL_STACK_LATERAL_FILL_PROB, 0.0, "level-stack-center",
		TerrainSpawnConfig.GROUND_FOLIAGE_FILL_PROB
	)


static func load_level_middle_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelCenter.tscn",
		TagList.new(["level", "level-ground", "level-center", "level-ground-center", "ground-type", "24x24x0.5"]),
		TerrainSpawnConfig.LEVEL_BASE_LATERAL_FILL_PROB,
		TerrainSpawnConfig.LEVEL_TOPCENTER_FILL_PROB,
		"level-ground-center",
		TerrainSpawnConfig.GROUND_FOLIAGE_FILL_PROB
	)

static func load_level_stack_middle_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelCenter.tscn",
		TagList.new(["level", "level-stack", "level-center", "level-stack-center", "24x24x0.5"]),
		TerrainSpawnConfig.LEVEL_STACK_LATERAL_FILL_PROB,
		TerrainSpawnConfig.LEVEL_TOPCENTER_FILL_PROB,
		"level-stack-center",
		TerrainSpawnConfig.GROUND_FOLIAGE_FILL_PROB
	)


### Cliff variants (data-driven) ###

# Returns every cliff variant in both tiers (cliff-base sits on ground,
# cliff-stack sits on cliff-interior) plus the two interior tiles. Used by
# TerrainModuleLibrary to populate the library in one call.
static func load_cliff_variants() -> Array[TerrainModule]:
	var out: Array[TerrainModule] = []
	for entry in CLIFF_VARIANT_TABLE:
		out.append(load_cliff_variant(entry[0], "cliff-base", entry[1]))
		out.append(load_cliff_variant(entry[0], "cliff-stack", entry[1]))
	# Mating C1 stacked corners: their understacks detection (HeightfieldInstantiator)
	# selects these to render multi-storey diagonal corners continuously.
	for entry in CLIFF_STACKED_VARIANT_TABLE:
		out.append(load_cliff_variant(entry[0], "cliff-base", entry[1]))
		out.append(load_cliff_variant(entry[0], "cliff-stack", entry[1]))
	# Generative 2-storey corner variants for peninsula/island (one per outer-corner
	# subset that can sit above a 2-storey diagonal drop).
	for v in SlopeVariantLayout.generated_stacked_variants():
		out.append(load_cliff_variant(String(v.name), "cliff-base", String(v.tag)))
		out.append(load_cliff_variant(String(v.name), "cliff-stack", String(v.tag)))
	out.append(load_cliff_interior_tile())
	out.append(load_cliff_stack_interior_tile())
	return out


# Build a single cliff variant. tier is "cliff-base" (bottom required tag
# "ground", sits on a ground tile) or "cliff-stack" (bottom required tag
# "cliff", sits on a cliff-interior plateau). Each variant also carries a
# tier-qualified variant tag (e.g. "cliff-base-side") so seeding distributions
# can pin the tier — the bare variant tag ("cliff-side") matches both tiers.
static func load_cliff_variant(
	scene_name: String, tier: String, variant_tag: String
) -> TerrainModule:
	var scene_path: String = "res://terrain/scenes/slope/%s.tscn" % scene_name
	var tier_variant_tag: String = variant_tag.replace("cliff-", tier + "-")
	var bottom_required: String = "cliff" if tier == "cliff-stack" else "ground"
	return _build_cliff_tile(
		scene_path,
		TagList.new(["cliff", tier, variant_tag, tier_variant_tag, "24x24x4"]),
		bottom_required
	)


static func load_cliff_interior_tile() -> TerrainModule:
	# Cliff plateau interior: visually a ground tile, but tagged "cliff" so neighbour
	# cliff-sides' required-tag filters remain satisfied. Lateral cardinals are
	# non-expandable because the plateau perimeter is covered by cliff-sides.
	# Topcenter seeds a cliff-stack-side with TerrainSpawnConfig.CLIFF_TOPCENTER_FILL_PROB so that
	# multi-storey cliff plateaus can grow upward, just like level-stack does for
	# levels. Foliage spawns on the top cardinals/corners (grass/trees on the
	# cliff plateau surface).
	return _build_cliff_interior_module(
		TagList.new(["cliff", "cliff-base", "cliff-interior", "ground-type", "24x24x4"])
	)


static func load_cliff_stack_interior_tile() -> TerrainModule:
	# Cliff-stack interior: the plateau surface tile at the second (or higher)
	# storey. Mirrors cliff-interior but is tagged "cliff-stack" so the next
	# tier of stacking can attach. Seeds another cliff-stack-side from its
	# topcenter, enabling infinite stacking limited by TerrainSpawnConfig.CLIFF_TOPCENTER_FILL_PROB.
	return _build_cliff_interior_module(
		TagList.new(["cliff", "cliff-stack", "cliff-interior", "ground-type", "24x24x4"])
	)


static func _build_cliff_interior_module(tags: TagList) -> TerrainModule:
	var scene: PackedScene = load("res://terrain/scenes/GroundTile.tscn")
	# Full-storey logical bounds, same as the edge variants in
	# _build_cliff_tile. The scene is visually a thin ground slab, but the
	# bounds must claim the whole 4u storey volume below the walkable top:
	# with slab-only bounds the volume under the plateau is unindexed, so a
	# buried ground tile's still-queued foliage sockets pass can_place and
	# plant trees inside the mesa (poking out of the plateau top).
	var bb: AABB = AABB(Vector3(-12, -4, -12), Vector3(24, 4, 24))

	# Same surface spawning as ground tiles; topcenter seeds the next cliff
	# storey instead of a level/cliff mix.
	var surface: Dictionary = TerrainSpawnConfig.surface_spawn_sockets(
		Distribution.new({"24x24x4": 1.0}),
		Distribution.new({"cliff-stack-side": 1.0}),
		TerrainSpawnConfig.CLIFF_TOPCENTER_FILL_PROB,
		TerrainSpawnConfig.GROUND_FOLIAGE_FILL_PROB
	)

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x4": 1.0}),
		"back": Distribution.new({"24x24x4": 1.0}),
		"right": Distribution.new({"24x24x4": 1.0}),
		"left": Distribution.new({"24x24x4": 1.0}),
	}
	socket_size.merge(surface["socket_size"])
	var socket_required: Dictionary[String, TagList] = {}
	# Laterals are BLOCKING (0.0, not null): the plateau interior is occupied
	# space. Non-blocking laterals let neighbouring cliff edges expand INTO
	# the plateau footprint (their facing socket has no expandable
	# counterpart), eat the interior via replace_existing, and churn forever.
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": 0.0,
		"back": 0.0,
		"right": 0.0,
		"left": 0.0,
		"bottom": null,
	}
	socket_fill_prob.merge(surface["socket_fill_prob"])
	var socket_tag_prob: Dictionary[String, Distribution] = {}
	socket_tag_prob.merge(surface["socket_tag_prob"])

	var m := TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		TerrainSpawnConfig.CLIFF_REPLACE_EXISTING,
		false,  # displaceable
		surface["socket_suppressed_by"]
	)
	m.structural_socket_names = ["front", "back", "left", "right", "topcenter"]
	m.grows_in_cliff_core = true
	return m


static func _build_cliff_tile(
	scene_path: String,
	tags: TagList,
	bottom_required_tag: String = "ground"
) -> TerrainModule:
	# Shared layout for both cliff tiers:
	#   - Cardinals at top elevation, required=cliff, high lateral fill.
	#   - Diagonals are null (markers for inner-corner detection only).
	#   - Bottom attaches to a ground tile (cliff-base) or another cliff
	#     (cliff-stack) below; no expansion.
	#   - Topcenter does NOT expand on edge variants. Only the interior
	#     tiles (the rule's interior-swap target) carry the topcenter
	#     distribution for foliage and stacking.
	var scene: PackedScene = load(scene_path)
	var bb: AABB = AABB(Vector3(-12, -4, -12), Vector3(24, 4, 24))
	var bottom_size_tag: String = "24x24x0.5" if bottom_required_tag == "ground" else "24x24x4"
	var tier: String = "cliff-base" if bottom_required_tag == "ground" else "cliff-stack"

	# Foliage on the walkable plateau top (4 cardinal top sockets in the cliff
	# scenes), same spawn rules as ground tiles. Suppression prob is 0.0 — the
	# generator suppresses cliff foliage geometrically instead (a tile whose
	# whole neighbourhood is inside this storey's contour will retile to
	# interior and be covered by the next storey).
	var surface: Dictionary = TerrainSpawnConfig.surface_spawn_sockets(
		Distribution.new({"24x24x0.5": 1.0}),
		Distribution.new({tier + "-side": 1.0}),
		0.0,
		TerrainSpawnConfig.GROUND_FOLIAGE_FILL_PROB,
		0.0
	)

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x4": 1.0}),
		"back": Distribution.new({"24x24x4": 1.0}),
		"left": Distribution.new({"24x24x4": 1.0}),
		"right": Distribution.new({"24x24x4": 1.0}),
		"topcenter": Distribution.new({"24x24x0.5": 1.0}),
		"bottom": Distribution.new({bottom_size_tag: 1.0}),
	}
	socket_size.merge(surface["socket_size"])
	var socket_required: Dictionary[String, TagList] = {
		"bottom": TagList.new([bottom_required_tag]),
	}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"front": TerrainSpawnConfig.CLIFF_LATERAL_FILL_PROB,
		"back": TerrainSpawnConfig.CLIFF_LATERAL_FILL_PROB,
		"left": TerrainSpawnConfig.CLIFF_LATERAL_FILL_PROB,
		"right": TerrainSpawnConfig.CLIFF_LATERAL_FILL_PROB,
		"frontleft": null,
		"frontright": null,
		"backleft": null,
		"backright": null,
		"bottom": null,
		# Blocking (0, not null): a stack tier must never be probed above an
		# edge tile — only interiors support the next storey. Non-blocking
		# would let stack lateral expansion place here and get rejected
		# afterwards, churning forever.
		"topcenter": 0.0,
	}
	socket_fill_prob.merge(surface["socket_fill_prob"])
	# Cliff scenes carry only the 4 cardinal foliage markers (no corners);
	# filter the merged policy down to the sockets the scene actually has.
	socket_fill_prob = _socket_fill_prob_for_scene(scene, socket_fill_prob)
	var socket_tag_prob: Dictionary[String, Distribution] = {}
	socket_tag_prob.merge(surface["socket_tag_prob"])

	var m := TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		TerrainSpawnConfig.CLIFF_REPLACE_EXISTING,
		false,  # displaceable
		surface["socket_suppressed_by"]
	)
	m.structural_socket_names = ["front", "back", "left", "right", "topcenter"]
	m.grows_in_cliff_core = true
	return m


static func _build_level_tile(
	scene_path: String,
	tags: TagList,
	cardinal_fill_prob: Variant = null,
	topcenter_fill_prob: Variant = null,
	cardinal_target_tag: String = "",
	foliage_fill_prob: Variant = null
) -> TerrainModule:
	var scene = load(scene_path)
	# Authored logical bounds: a level tile is exactly one 24x24x0.5 slab with
	# its origin on the top plane (edge-variant meshes overhang below with
	# their skirts; that must not count as occupancy).
	var bb: AABB = AABB(Vector3(-12.0, -0.5, -12.0), Vector3(24.0, 0.5, 24.0))
	# Same surface spawning as ground tiles; topcenter seeds the stack tier
	# above. Edge-variant scenes lack the foliage sockets, so those entries are
	# filtered out by _socket_fill_prob_for_scene below.
	var surface: Dictionary = TerrainSpawnConfig.surface_spawn_sockets(
		Distribution.new({"24x24x0.5": 1.0}),
		Distribution.new({"level-stack-center": 1.0}),
		topcenter_fill_prob,
		foliage_fill_prob,
		TerrainSpawnConfig.LEVEL_TOPCENTER_FILL_PROB
	)
	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x0.5": 1.0}),
		"back": Distribution.new({"24x24x0.5": 1.0}),
		"left": Distribution.new({"24x24x0.5": 1.0}),
		"right": Distribution.new({"24x24x0.5": 1.0}),
	}
	socket_size.merge(surface["socket_size"])
	var socket_required: Dictionary[String, TagList] = {
		# Pin topcenter to "level-stack": topcenter expansion of any level
		# tile must produce a level-stack tile, never ground or a level-ground
		# variant. A wrong-tier tile placed at y > 0.5 is invisible to the
		# stack support checks (no "level-stack" tag), so it would persist and
		# seed a chain of legitimate-looking level placements above it (the
		# "cantilever" the regression test catches).
		"topcenter": TagList.new(["level-stack"]),
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
		# Top-corner sockets on inner-corner variants are adjacency-only rule
		# markers, never foliage spawners. Listed before the surface merge so
		# the foliage fill prob cannot attach to them (merge keeps existing
		# keys). Level foliage spawns from the 4 top cardinals only.
		"topfrontright": null,
		"topfrontleft": null,
		"topbackright": null,
		"topbackleft": null,
	}
	socket_fill_prob_policy.merge(surface["socket_fill_prob"])
	var socket_fill_prob: Dictionary[String, Variant] = _socket_fill_prob_for_scene(scene, socket_fill_prob_policy)
	var socket_tag_prob: Dictionary[String, Distribution] = {}
	socket_tag_prob.merge(surface["socket_tag_prob"])
	var m := TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		TerrainSpawnConfig.LEVEL_REPLACE_EXISTING,
		false,  # displaceable
		surface["socket_suppressed_by"]
	)
	m.structural_socket_names = ["front", "back", "left", "right", "topcenter"]
	m.vertical_stack_family = "level"
	m.density_profile = "level"
	return m



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


static func create_4x4x4_test_piece() -> TerrainModule:
	# Test piece for the small hill spire (4x4 footprint, 4 units tall,
	# origin at the top surface like the real module).
	var scene = load("res://terrain/scenes/Hill_4x4x4.tscn")
	var tags: TagList = TagList.new(["4x4x4"])
	var bb: AABB = AABB(Vector3(-2, -4, -2), Vector3(4, 4, 4))

	var socket_size: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"point": 1.0}),
		"bottom": Distribution.new({"point": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"topcenter": 0.0,
		"bottom": 0.0,
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
