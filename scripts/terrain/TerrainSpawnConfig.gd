class_name TerrainSpawnConfig
extends Resource

# Single source of truth for ground-spawn behaviour: which pieces spawn in which
# sockets, with what probabilities, and the level/slope rule that keeps
# structures off sloped surfaces. (Tuning constants + surface_spawn_sockets are
# migrated here in a follow-up step; this block defines the gating contract.)

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
