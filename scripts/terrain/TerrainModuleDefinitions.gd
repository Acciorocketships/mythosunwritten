class_name TerrainModuleDefinitions
extends Resource

### Tuning knobs ###################################################
# All terrain-rendering tuning lives here. Change values in this block to
# adjust generation density / behavior without hunting through factories.

# --- Level (second-level patches that sit on top of ground tiles) ---
# Lateral expansion rate per cardinal socket — how aggressively level
# clusters grow outward on the second tier. Each frontier tile exposes ~3 new
# sockets, so keep this below 1/3 (subcritical) or patches grow unbounded and
# blanket the map.
const LEVEL_BASE_LATERAL_FILL_PROB: float = 0.3
# Lateral expansion rate for the level-stack tier (third level and above).
# Stacks can only sit on supported level tiles below, so this is intrinsically
# bounded and can stay high — upper tiers fill out their support, producing
# terraced slopes rather than spires.
const LEVEL_STACK_LATERAL_FILL_PROB: float = 0.7
# Vertical stacking rate from a level-center topcenter (seeds the level
# directly above). Applies to both level-ground and level-stack centers.
const LEVEL_TOPCENTER_FILL_PROB: float = 0.9
# Whether placing a level tile removes overlapping non-ground pieces in
# its footprint. True keeps LevelEdgeRule retiling clean.
const LEVEL_REPLACE_EXISTING: bool = false
# Per-socket foliage chance on each top edge/corner of a level-center tile.
const LEVEL_FOLIAGE_FILL_PROB: float = 0.1

# --- Cliff ---
# Same subcritical rule as LEVEL_BASE_LATERAL_FILL_PROB: keep below ~1/3 or
# cliff plateaus grow until they cover everything (they replace_existing, so
# runaway growth eats the rest of the terrain too).
const CLIFF_LATERAL_FILL_PROB: float = 0.3
# Vertical stacking rate from a cliff-interior topcenter (seeds the next
# cliff storey above the plateau). Bounded: a storey only stands on a
# cliff-interior tile, which requires a >=3x3 plateau below, so each storey
# shrinks and mountains taper naturally.
const CLIFF_TOPCENTER_FILL_PROB: float = 0.8
const CLIFF_REPLACE_EXISTING: bool = true
# Per-socket foliage chance on each top edge/corner of a cliff-interior plateau.
const CLIFF_INTERIOR_FOLIAGE_FILL_PROB: float = 0.05

# --- Ground topcenter (seeds level or cliff above each ground tile) ---
# Per-tile chance that the topcenter socket attempts to place anything.
const GROUND_TOPCENTER_FILL_PROB: float = 0.1
# Probability split of what a ground topcenter seeds when it does fire.
# Must sum to 1.0. Mirrors both the size and tag distributions used to
# pick between a level-ground-center (small) and a cliff-side (tall).
const GROUND_TOPCENTER_LEVEL_PROB: float = 0.65
const GROUND_TOPCENTER_CLIFF_PROB: float = 0.35

# --- Ground top-edge foliage (cardinals + corners on each ground tile) ---
const GROUND_FOLIAGE_FILL_PROB: float = 0.12
# Sampled tag distribution for foliage tiles on top-edges. Reused for
# cliff-interior plateau top-edges too. Weights need not sum to 1 — the
# Distribution normalises.
const FOLIAGE_TAG_WEIGHTS: Dictionary[String, float] = {
	"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.2, "hill": 0.1,
}

# --- Hill stacking (small hills can stack on top of each other) ---
# Per-hill chance that its topcenter seeds another (smaller) hill above.
const HILL_8X8_STACK_FILL_PROB: float = 0.5
const HILL_12X12_STACK_FILL_PROB: float = 0.3
####################################################################

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


### Shared surface spawning ###

# One source of truth for what spawns on top of a walkable surface tile
# (ground tiles, level centers, cliff plateau interiors): foliage on the top
# cardinal/corner sockets and a seeding distribution on topcenter.
# Returns {"socket_size": ..., "socket_fill_prob": ..., "socket_tag_prob": ...};
# callers merge each sub-dictionary into their socket dicts. Scenes that lack
# some of these sockets filter the fill-prob entries via
# _socket_fill_prob_for_scene; size/tag entries for absent sockets are inert.
static func surface_spawn_sockets(
	topcenter_size: Distribution,
	topcenter_tag_prob: Distribution,
	topcenter_fill_prob: Variant,
	foliage_fill_prob: Variant,
	topcenter_suppression_prob: Variant = null
) -> Dictionary:
	var corner_size: Distribution = Distribution.new({"point": 0.9, "12x12x2": 0.1})
	var cardinal_size: Distribution = Distribution.new({"point": 0.9, "8x8x2": 0.1})
	var foliage_tags: Distribution = Distribution.new(FOLIAGE_TAG_WEIGHTS)
	var socket_size: Dictionary[String, Distribution] = {
		"topfront": cardinal_size,
		"topback": cardinal_size,
		"topleft": cardinal_size,
		"topright": cardinal_size,
		"topfrontright": corner_size,
		"topfrontleft": corner_size,
		"topbackright": corner_size,
		"topbackleft": corner_size,
		"topcenter": topcenter_size,
	}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"topfront": foliage_fill_prob,
		"topback": foliage_fill_prob,
		"topleft": foliage_fill_prob,
		"topright": foliage_fill_prob,
		"topfrontright": foliage_fill_prob,
		"topfrontleft": foliage_fill_prob,
		"topbackright": foliage_fill_prob,
		"topbackleft": foliage_fill_prob,
		"topcenter": topcenter_fill_prob,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topfront": foliage_tags,
		"topback": foliage_tags,
		"topleft": foliage_tags,
		"topright": foliage_tags,
		"topfrontright": foliage_tags,
		"topfrontleft": foliage_tags,
		"topbackright": foliage_tags,
		"topbackleft": foliage_tags,
		"topcenter": topcenter_tag_prob,
	}
	# Foliage never spawns on a tile whose topcenter is (ever) going to seed a
	# structure — the structure would visibly displace it. The suppression
	# probability defaults to the actual topcenter fill, but variants whose
	# topcenter is currently disabled (level edges) pass the prob their center
	# form would have, so the verdict stays stable across retiles.
	var suppression_prob: float = 0.0
	if topcenter_suppression_prob != null:
		suppression_prob = float(topcenter_suppression_prob)
	elif topcenter_fill_prob != null:
		suppression_prob = float(topcenter_fill_prob)
	var suppression_entry: Dictionary = {"socket": "topcenter", "prob": suppression_prob}
	var socket_suppressed_by: Dictionary[String, Dictionary] = {
		"topfront": suppression_entry,
		"topback": suppression_entry,
		"topleft": suppression_entry,
		"topright": suppression_entry,
		"topfrontright": suppression_entry,
		"topfrontleft": suppression_entry,
		"topbackright": suppression_entry,
		"topbackleft": suppression_entry,
	}
	return {
		"socket_size": socket_size,
		"socket_fill_prob": socket_fill_prob,
		"socket_tag_prob": socket_tag_prob,
		"socket_suppressed_by": socket_suppressed_by,
	}


### Individual Terrain Modules ###

static func load_ground_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/GroundTile.tscn")
	var tags: TagList = TagList.new(["ground", "ground-type", "24x24x0.5", "side"])
	# Override computed AABB to have height 0.5 instead of computed value
	var bb: AABB = AABB(Vector3(-12.0, 0.0, -12.0), Vector3(24.0, 0.5, 24.0))

	var surface: Dictionary = surface_spawn_sockets(
		Distribution.new({
			"24x24x0.5": GROUND_TOPCENTER_LEVEL_PROB,
			"24x24x4": GROUND_TOPCENTER_CLIFF_PROB,
		}),
		Distribution.new({
			"level-ground-center": GROUND_TOPCENTER_LEVEL_PROB,
			"cliff-base-side": GROUND_TOPCENTER_CLIFF_PROB,
		}),
		GROUND_TOPCENTER_FILL_PROB,
		GROUND_FOLIAGE_FILL_PROB
	)
	var adjacent_tag_prob: Distribution = Distribution.new({"ground": 1.0})

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

	return TerrainModule.new(
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

static func load_grass_tile() -> TerrainModule:
	var visual_variants: Array[PackedScene] = [load("res://terrain/scenes/Grass2.tscn")]
	return _build_foliage_tile("res://terrain/scenes/Grass1.tscn", "grass", visual_variants)

static func load_bush_tile() -> TerrainModule:
	return _build_foliage_tile("res://terrain/scenes/Bush1.tscn", "bush")

static func load_rock_tile() -> TerrainModule:
	return _build_foliage_tile("res://terrain/scenes/Rock1.tscn", "rock")

static func load_tree_tile() -> TerrainModule:
	return _build_foliage_tile("res://terrain/scenes/Tree1.tscn", "tree")


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
		"topcenter": Distribution.new({"point": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"topcenter": HILL_8X8_STACK_FILL_PROB,
		"bottom": null,
		"topfrontright": null,
		"topfrontleft": null,
		"topbackright": null,
		"topbackleft": null,
	}
	var socket_tag_prob: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"grass": 1.0})
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


static func load_12x12x2_tile() -> TerrainModule:
	var scene = load("res://terrain/scenes/Hill_12x12x2.tscn")
	var tags: TagList = TagList.new(["hill", "12x12x2"])
	var bb: AABB = Helper.compute_scene_mesh_aabb(scene)

	var socket_size: Dictionary[String, Distribution] = {
		"topcenter": Distribution.new({"8x8x2": 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {}
	var socket_fill_prob: Dictionary[String, Variant] = {
		"topcenter": HILL_12X12_STACK_FILL_PROB,
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
	# edge and is rejected by LevelEdgeRule afterwards, churning forever.
	if tier == "level-ground":
		return _build_level_tile(
			scene_path, tags, LEVEL_BASE_LATERAL_FILL_PROB, 0.0, "level-ground-center",
			LEVEL_FOLIAGE_FILL_PROB
		)
	return _build_level_tile(
		scene_path, tags, LEVEL_STACK_LATERAL_FILL_PROB, 0.0, "level-stack-center",
		LEVEL_FOLIAGE_FILL_PROB
	)


static func load_level_middle_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelCenter.tscn",
		TagList.new(["level", "level-ground", "level-center", "level-ground-center", "ground-type", "24x24x0.5"]),
		LEVEL_BASE_LATERAL_FILL_PROB,
		LEVEL_TOPCENTER_FILL_PROB,
		"level-ground-center",
		LEVEL_FOLIAGE_FILL_PROB
	)

static func load_level_stack_middle_tile() -> TerrainModule:
	return _build_level_tile(
		"res://terrain/scenes/LevelCenter.tscn",
		TagList.new(["level", "level-stack", "level-center", "level-stack-center", "24x24x0.5"]),
		LEVEL_STACK_LATERAL_FILL_PROB,
		LEVEL_TOPCENTER_FILL_PROB,
		"level-stack-center",
		LEVEL_FOLIAGE_FILL_PROB
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
	var scene_path: String = "res://terrain/scenes/%s.tscn" % scene_name
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
	# Topcenter seeds a cliff-stack-side with CLIFF_TOPCENTER_FILL_PROB so that
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
	# topcenter, enabling infinite stacking limited by CLIFF_TOPCENTER_FILL_PROB.
	return _build_cliff_interior_module(
		TagList.new(["cliff", "cliff-stack", "cliff-interior", "ground-type", "24x24x4"])
	)


static func _build_cliff_interior_module(tags: TagList) -> TerrainModule:
	var scene: PackedScene = load("res://terrain/scenes/GroundTile.tscn")
	var bb: AABB = AABB(Vector3(-12, -0.5, -12), Vector3(24, 0.5, 24))

	# Same surface spawning as ground tiles; topcenter seeds the next cliff
	# storey instead of a level/cliff mix.
	var surface: Dictionary = surface_spawn_sockets(
		Distribution.new({"24x24x4": 1.0}),
		Distribution.new({"cliff-stack-side": 1.0}),
		CLIFF_TOPCENTER_FILL_PROB,
		CLIFF_INTERIOR_FOLIAGE_FILL_PROB
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

	return TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		CLIFF_REPLACE_EXISTING,
		false,  # displaceable
		surface["socket_suppressed_by"]
	)


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

	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x4": 1.0}),
		"back": Distribution.new({"24x24x4": 1.0}),
		"left": Distribution.new({"24x24x4": 1.0}),
		"right": Distribution.new({"24x24x4": 1.0}),
		"topcenter": Distribution.new({"24x24x0.5": 1.0}),
		"bottom": Distribution.new({bottom_size_tag: 1.0}),
	}
	var socket_required: Dictionary[String, TagList] = {
		"front": TagList.new(["cliff"]),
		"back": TagList.new(["cliff"]),
		"left": TagList.new(["cliff"]),
		"right": TagList.new(["cliff"]),
		"bottom": TagList.new([bottom_required_tag]),
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
		# Blocking (0, not null): a stack tier must never be probed above an
		# edge tile — only interiors support the next storey. Non-blocking
		# would let stack lateral expansion place here and get rejected by
		# CliffEdgeRule afterwards, churning forever.
		"topcenter": 0.0,
	}
	# Pin lateral growth to this tier's side variant: the bare "cliff" tag
	# matches both tiers, and a cliff-stack placed at ground level (or vice
	# versa) is invalid and gets removed by CliffEdgeRule's support check.
	var cliff_lateral_dist: Distribution = Distribution.new({tier + "-side": 1.0})
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
		CLIFF_REPLACE_EXISTING
	)


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
	var surface: Dictionary = surface_spawn_sockets(
		Distribution.new({"24x24x0.5": 1.0}),
		Distribution.new({"level-stack-center": 1.0}),
		topcenter_fill_prob,
		foliage_fill_prob,
		LEVEL_TOPCENTER_FILL_PROB
	)
	var socket_size: Dictionary[String, Distribution] = {
		"front": Distribution.new({"24x24x0.5": 1.0}),
		"back": Distribution.new({"24x24x0.5": 1.0}),
		"left": Distribution.new({"24x24x0.5": 1.0}),
		"right": Distribution.new({"24x24x0.5": 1.0}),
	}
	socket_size.merge(surface["socket_size"])
	var socket_required: Dictionary[String, TagList] = {
		"front": TagList.new(["level"]),
		"back": TagList.new(["level"]),
		"left": TagList.new(["level"]),
		"right": TagList.new(["level"]),
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
	socket_tag_prob.merge(surface["socket_tag_prob"])
	return TerrainModule.new(
		scene,
		bb,
		tags,
		[],
		socket_size,
		socket_required,
		socket_fill_prob,
		socket_tag_prob,
		LEVEL_REPLACE_EXISTING,
		false,  # displaceable
		surface["socket_suppressed_by"]
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
