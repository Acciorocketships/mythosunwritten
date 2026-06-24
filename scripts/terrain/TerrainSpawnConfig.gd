class_name TerrainSpawnConfig
extends Resource

# Single source of truth for ground-spawn behaviour: which pieces spawn in which
# sockets, with what probabilities, and the level/slope rule that keeps
# structures off sloped surfaces. This file is the authoritative home for all
# spawn tuning constants, the shared surface socket builder, and the level/slope
# gating rule.

### Level / slope socket gating ###

# Plateau (walkable, flat) sockets are baked at y~0; sockets sitting over a
# slope band are baked below 0 (see tests/test_slope_socket_grounding.gd). A
# socket more than this far below the plateau is on the slope.
const SLOPE_Y_THRESHOLD: float = -0.5

# Sizes that denote a multi-cell structure (a hill) rather than a point
# decoration. Dropped from slope sockets and from cliff-core suppression — one
# definition, two callers.
const STRUCTURE_SIZES: Array[String] = ["8x8x2", "12x12x2", "4x4x4"]

# Structural seed identifiers a topcenter can roll (the level/cliff tiles it
# seeds). Named so the cliff-core suppression and the slope gate share the
# strings instead of hardcoding them in two places.
const SEED_SIZE_LEVEL: String = "24x24x0.5"
const SEED_SIZE_CLIFF: String = "24x24x4"
const SEED_TAG_LEVEL_GROUND: String = "level-ground-center"
const SEED_TAG_LEVEL_STACK: String = "level-stack-center"
const SEED_TAG_CLIFF_BASE: String = "cliff-base-side"
const SEED_TAG_CLIFF_STACK: String = "cliff-stack-side"

# Tags dropped from a slope socket's roll: hills plus every structural seed.
# Foliage tags (grass/rock/bush/tree) are intentionally absent so they survive.
# Mirrors SEED_TAG_* consts above — GDScript 4 cannot reference consts inside a const array literal.
const SLOPE_BLOCKED_TAGS: Array[String] = [
	"hill",
	"level-ground-center", "level-stack-center",
	"cliff-base-side", "cliff-stack-side",
]


# Level vs slope from a socket's baked local Y.
static func category_for_y(y: float) -> String:
	return "slope" if y < SLOPE_Y_THRESHOLD else "level"


# Drop structure entries (hill sizes + structural seed/hill tags) from a
# distribution when the socket is on a slope; return the distribution untouched
# on level sockets. Never empties a distribution (Distribution.sample asserts on
# an empty / zero-sum dist) — point foliage always survives a foliage roll, and
# a dist of only-structures is left as-is rather than nulled.
# Note: structural SEED SIZES (24x24x4 / 24x24x0.5) are intentionally NOT size-gated
# here — no slope socket bears a topcenter seed (every baked topcenter sits at the
# plateau, y≈0 → level category); seed suppression on a slope topcenter relies on the
# tag filter (SLOPE_BLOCKED_TAGS) rather than a size gate.
static func filter_for_category(dist: Distribution, category: String) -> Distribution:
	if category != "slope" or dist == null or dist.is_empty():
		return dist
	var filtered: Distribution = dist.copy()
	var changed: bool = false
	for key: String in STRUCTURE_SIZES:
		if filtered.dist.has(key):
			filtered.dist.erase(key)
			changed = true
	for key: String in SLOPE_BLOCKED_TAGS:
		if filtered.dist.has(key):
			filtered.dist.erase(key)
			changed = true
	if not changed:
		return dist
	if filtered.dist.is_empty() or not filtered.has_positive_weight():
		return dist
	filtered.normalise()
	return filtered


### Migrated spawn tuning (authoritative home) ###

# --- Level (second-level patches that sit on top of ground tiles) ---
# Lateral expansion rate per cardinal socket — how aggressively level
# clusters grow outward on the second tier. Each frontier tile exposes ~3 new
# sockets, so keep this below 1/3 (subcritical) or patches grow unbounded and
# blanket the map.
const LEVEL_BASE_LATERAL_FILL_PROB: float = 0.33
# Lateral expansion rate for the level-stack tier (third level and above).
# Stacks can only sit on supported level tiles below, so this is intrinsically
# bounded and can stay high — upper tiers fill out their support, producing
# terraced slopes rather than spires.
const LEVEL_STACK_LATERAL_FILL_PROB: float = 0.7
# Vertical stacking rate from a level-center topcenter (seeds the level
# directly above). Applies to both level-ground and level-stack centers.
const LEVEL_TOPCENTER_FILL_PROB: float = 0.9
# Whether placing a level tile removes overlapping non-ground pieces in
# its footprint. True keeps level-variant retiling clean.
const LEVEL_REPLACE_EXISTING: bool = false

# --- Cliff ---
# Same subcritical rule as LEVEL_BASE_LATERAL_FILL_PROB: keep below ~1/3 or
# cliff plateaus grow until they cover everything (they replace_existing, so
# runaway growth eats the rest of the terrain too).
# Authored lateral fill marks the socket expandable (>0); the actual growth
# verdict is the contour test below (TerrainGenerator._cliff_contour_fill).
const CLIFF_LATERAL_FILL_PROB: float = 0.3
# --- Cliff mesa contours ---
# Cliff plateaus are carved from the macro density field instead of rolled
# per-socket: a cliff lateral expands iff the target position's macro density
# exceeds the threshold for its storey. Mesas come out as solid field-shaped
# blobs (independent rolls produce single-storey snake mazes that never form
# the 3x3 interiors stacking needs), and each storey's threshold rises so
# mountains terrace and taper like contour lines on a heightmap.
const CLIFF_CONTOUR_BASE: float = 0.56
# Small step: the 3x3-interior support requirement already insets each storey
# by a tile, so mountains taper geometrically into stepped pyramids; the
# threshold step only needs to fade the very top against the field falloff.
# Lower step => more storeys clear the threshold => taller mountains.
const CLIFF_CONTOUR_STEP: float = 0.012
# Inside a contour core, ground topcenters seed much more eagerly (and the
# seed mix skews toward cliffs) so every core actually grows its mountain —
# the base rates alone can miss a whole core and leave it flat.
const CLIFF_CORE_SEED_FILL_PROB: float = 0.5
const CLIFF_CORE_SEED_MIX_BOOST: float = 3.0
# Vertical stacking rate from a cliff-interior topcenter (seeds the next
# cliff storey above the plateau). Bounded: a storey only stands on a
# cliff-interior tile, which requires a >=3x3 plateau below, so each storey
# shrinks and mountains taper naturally.
# 1.0 = structural: every interior tile seeds the storey above. Vertical
# growth is already bounded by the 3x3-interior requirement plus the rising
# contour threshold, and a probabilistic roll here just leaves ragged holes
# in upper tiers that block the NEXT tier's interiors from ever forming.
const CLIFF_TOPCENTER_FILL_PROB: float = 1.0
const CLIFF_REPLACE_EXISTING: bool = true

# --- Ground topcenter (seeds level or cliff above each ground tile) ---
# Per-tile chance that the topcenter socket attempts to place anything.
const GROUND_TOPCENTER_FILL_PROB: float = 0.2
# Probability split of what a ground topcenter seeds when it does fire.
# Must sum to 1.0. Mirrors both the size and tag distributions used to
# pick between a level-ground-center (small) and a cliff-side (tall).
# The rocky biome multiplies the cliff side of both distributions at
# placement time (Helper.biome_weights), so highlands skew further toward
# cliffs than this base split.
const GROUND_TOPCENTER_LEVEL_PROB: float = 0.7
const GROUND_TOPCENTER_CLIFF_PROB: float = 0.3

# --- Top-edge foliage (cardinals + corners on each walkable surface) ---
# Shared by ground tiles, level tiles, and cliff plateau tops: every walkable
# surface uses the same decoration spawn rules.
const GROUND_FOLIAGE_FILL_PROB: float = 0.2
# Sampled tag distribution for foliage tiles on top-edges. Reused for
# cliff-interior plateau top-edges too. Weights need not sum to 1 — the
# Distribution normalises.
const FOLIAGE_TAG_WEIGHTS: Dictionary[String, float] = {
	"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.25, "hill": 0.05,
}
# Size mix for a top-edge foliage socket: mostly point decorations, occasionally
# a small hill. Cardinals can seed an 8x8x2; corners (more open space) a 12x12x2.
# The slope gate (filter_for_category) drops the hill sizes on slope sockets.
const FOLIAGE_CARDINAL_SIZE_WEIGHTS: Dictionary[String, float] = {"point": 0.85, "8x8x2": 0.1, "4x4x4": 0.05}
const FOLIAGE_CORNER_SIZE_WEIGHTS: Dictionary[String, float] = {"point": 0.85, "12x12x2": 0.1, "4x4x4": 0.05}

# --- Hill stacking (small hills can stack on top of each other) ---
# Per-hill chance that its topcenter seeds another (smaller) hill above.
const HILL_8X8_STACK_FILL_PROB: float = 0.5
const HILL_12X12_STACK_FILL_PROB: float = 0.3
const HILL_4X4_STACK_FILL_PROB: float = 0.4
# What each hill seeds from its topcenter when it stacks: a size mix and a tag
# mix. (Companion to the HILL_*_STACK_FILL_PROB rates above.)
const HILL_8X8_STACK_SIZE_WEIGHTS: Dictionary[String, float] = {"4x4x4": 0.4, "point": 0.6}
const HILL_8X8_STACK_TAG_WEIGHTS: Dictionary[String, float] = {"hill": 0.4, "grass": 0.6}
const HILL_12X12_STACK_SIZE_WEIGHTS: Dictionary[String, float] = {"8x8x2": 1.0}
const HILL_12X12_STACK_TAG_WEIGHTS: Dictionary[String, float] = {"hill": 1.0}
const HILL_4X4_STACK_SIZE_WEIGHTS: Dictionary[String, float] = {"point": 1.0}
const HILL_4X4_STACK_TAG_WEIGHTS: Dictionary[String, float] = {"grass": 1.0}


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
	var corner_size: Distribution = Distribution.new(FOLIAGE_CORNER_SIZE_WEIGHTS)
	var cardinal_size: Distribution = Distribution.new(FOLIAGE_CARDINAL_SIZE_WEIGHTS)
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
	# Mark every socket this function creates as a surface socket. This is the
	# authoritative source of surface-socket identity — callers merge this into
	# the module's socket_role dict so _lateral_neighbours can test role
	# instead of name-prefix heuristics.
	var socket_role: Dictionary[String, String] = {
		"topfront": "surface",
		"topback": "surface",
		"topleft": "surface",
		"topright": "surface",
		"topfrontright": "surface",
		"topfrontleft": "surface",
		"topbackright": "surface",
		"topbackleft": "surface",
		"topcenter": "surface",
	}
	return {
		"socket_size": socket_size,
		"socket_fill_prob": socket_fill_prob,
		"socket_tag_prob": socket_tag_prob,
		"socket_suppressed_by": socket_suppressed_by,
		"socket_role": socket_role,
	}
