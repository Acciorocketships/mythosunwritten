# scripts/terrain/water/PondStamp.gd
# One pond/pool: a wobbly-radius bowl carved into the heightfield with a
# storey-aligned water level. Terminal lakes, river source pools, and (future)
# standalone decorative ponds are all this one primitive. Pure record + pure
# math — deterministic per (center, radius, shape_seed, level, depth).
class_name PondStamp
extends RefCounted

const STOREY := 4.0
const WOBBLE := 0.3          # ±30% radial noise on the footprint boundary
const SURFACE_DROP := 1.0    # water sits this far below the bank storey top
# Outer fraction of the footprint that eases to 0. Narrow: a wide feather
# leaves a broad shallow shelf under the surface, and the depth-based shore
# foam covers the whole shelf in white marbling instead of a thin lap line.
const RIM_FEATHER := 0.22

var center: Vector2          # world XZ
var radius: float            # base radius, metres
var shape_seed: int
var level: int               # storey index of the banks; water just below
var depth: float             # bowl depth below level*STOREY


func _init(p_center: Vector2, p_radius: float, p_shape_seed: int, p_level: int, p_depth: float) -> void:
	center = p_center
	radius = p_radius
	shape_seed = p_shape_seed
	level = p_level
	depth = p_depth


## Wobbled boundary radius along direction `ang` (radians): 2- and 3-lobed
## low-frequency sin wobble so ponds read organic, not stamped circles.
func radius_at(ang: float) -> float:
	var a: float = Helper._hash01(Helper._mix64(shape_seed)) * TAU
	var b: float = Helper._hash01(Helper._mix64(shape_seed + 1)) * TAU
	return radius * (1.0 + WOBBLE * (0.6 * sin(2.0 * ang + a) + 0.4 * sin(3.0 * ang + b)))


## Everything the pond can touch lies within this radius (bucketing bound).
func bound_radius() -> float:
	return radius * (1.0 + WOBBLE)


## Normalized footprint coordinate: < 1 inside the wobbled boundary.
func footprint_t(p: Vector2) -> float:
	var d: Vector2 = p - center
	if d.length_squared() < 0.000001:
		return 0.0
	return d.length() / radius_at(atan2(d.y, d.x))


func surface_y() -> float:
	return float(level) * STOREY - SURFACE_DROP


func bed_y() -> float:
	return float(level) * STOREY - depth


## Metres to remove at world point p given the pre-carve ground height there.
## Full bowl in the core, smootherstep feather over the outer RIM_FEATHER of
## the footprint. Only ever lowers ground.
func carve_at(p: Vector2, ground_y: float) -> float:
	var t: float = footprint_t(p)
	if t >= 1.0:
		return 0.0
	var w: float = SlopeProfile.smootherstep(clampf((1.0 - t) / RIM_FEATHER, 0.0, 1.0))
	return maxf(0.0, (ground_y - bed_y()) * w)
