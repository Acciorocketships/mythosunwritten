class_name HeightfieldPlan
extends RefCounted

## Deterministic, churn-free numerical terrain plan. A continuous height field
## H(cell) is quantized into integer cliff storeys and trickle-down clamped so
## adjacent cells never differ by more than one storey. The result is a pure
## function of (world_seed, cell), so a tile's planned height is final before it
## is ever instantiated — the anti-churn guarantee.
##
## Phase 1: storey (cliff) tier only. See
## docs/superpowers/specs/2026-06-17-heightfield-terrain-design.md.

const TILE: float = 24.0
const STOREY_HEIGHT: float = 4.0

var world_seed: int
var height_amplitude: float   # metres; macro field [0,1] -> [0, amplitude]
var max_storeys: int          # caps column height -> bounds clamp margin
var aggregation: String       # "min" (floor) | "mean" (nearest) | "max" (ceil)

var _raw_override: Callable = Callable()


func _init(
	p_world_seed: int,
	p_height_amplitude: float = 32.0,
	p_max_storeys: int = 8,
	p_aggregation: String = "mean"
) -> void:
	assert(p_height_amplitude > 0.0, "HeightfieldPlan: height_amplitude must be positive")
	# max_storeys is the clamp window margin; a non-positive value collapses the
	# window to a single cell and silently breaks the churn-free guarantee.
	assert(p_max_storeys > 0, "HeightfieldPlan: max_storeys must be positive")
	if not (p_aggregation == "min" or p_aggregation == "mean" or p_aggregation == "max"):
		push_warning("HeightfieldPlan: unknown aggregation '%s', defaulting to nearest (mean)" % p_aggregation)
	world_seed = p_world_seed
	height_amplitude = p_height_amplitude
	max_storeys = p_max_storeys
	aggregation = p_aggregation


## Replace the noise source with a synthetic field for tests. fn(cx, cz) -> float.
func set_raw_height_override(fn: Callable) -> void:
	_raw_override = fn


## Continuous height (metres) at a tile cell.
func raw_height(cx: int, cz: int) -> float:
	if _raw_override.is_valid():
		return _raw_override.call(cx, cz)
	var pos: Vector3 = Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)
	return Helper.macro_density01(pos, world_seed) * height_amplitude


## Quantize a height (metres) to an integer storey index, using the aggregation
## rounding mode (min=floor hugs valleys, max=ceil builds up, mean=nearest),
## clamped to [0, max_storeys].
func quantize_storey(h: float) -> int:
	var q: float = h / STOREY_HEIGHT
	var s: int
	match aggregation:
		"min":
			s = floori(q)
		"max":
			s = ceili(q)
		_:
			s = roundi(q)
	return clampi(s, 0, max_storeys)


const _CARDINALS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

## Monotone trickle-down clamp: repeatedly lower each cell to at most one storey
## above its lowest cardinal neighbour, until nothing changes. The operation
## only lowers and is bounded below by the input, so it terminates; the fixpoint
## (each cell <= min_neighbour + 1) is unique regardless of sweep order. `targets`
## maps Vector2i(cx, cz) -> storey; returns a new clamped map.
static func clamp_field(targets: Dictionary) -> Dictionary:
	var out: Dictionary = targets.duplicate()
	var changed: bool = true
	while changed:
		changed = false
		for cell in out.keys():
			var here: int = out[cell]
			for d in _CARDINALS:
				var nb: Vector2i = cell + d
				if not out.has(nb):
					continue
				# Reads the possibly-already-lowered neighbour (Gauss-Seidel): safe
				# and faster to converge because values only ever decrease.
				var cap: int = out[nb] + 1
				if here > cap:
					here = cap
					changed = true
			out[cell] = here
	return out


## Clamp influence fans out one storey per tile, and storeys are capped at
## max_storeys, so a window margin of max_storeys guarantees the center cell's
## clamped value equals the global (infinite-window) result.
func storey_margin() -> int:
	return max_storeys


## Final clamped storey for a cell. Reference implementation: builds a window of
## quantized targets and clamps it. (Production will batch this over chunks; the
## per-cell window here is for correctness/validation, not the hot path.)
func storey_at(cx: int, cz: int) -> int:
	var m: int = storey_margin()
	var targets: Dictionary = {}
	for dz in range(-m, m + 1):
		for dx in range(-m, m + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			# cell.x = cx, cell.y = cz (Vector2i stores the horizontal grid pair,
			# NOT world Y / the up-axis).
			targets[cell] = quantize_storey(raw_height(cell.x, cell.y))
	var clamped: Dictionary = clamp_field(targets)
	return clamped[Vector2i(cx, cz)]


## Rendered surface height (metres) for a cell.
func surface_height(cx: int, cz: int) -> float:
	return float(storey_at(cx, cz)) * STOREY_HEIGHT


## Read API for downstream instantiation: the storey index and its world height.
## (Phase 2 will add a "level" field and a fractional height contribution.)
func tile_plan(cx: int, cz: int) -> Dictionary:
	var s: int = storey_at(cx, cz)
	return {"storey": s, "height": float(s) * STOREY_HEIGHT}
