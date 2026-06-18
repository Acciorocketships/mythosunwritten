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
