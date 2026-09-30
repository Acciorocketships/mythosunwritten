extends RefCounted

## Minimal point-keyed terrain region for kernel tests: explicit heights (in
## metres) at 12 m lattice points, storey = floor(height / 4). Points absent
## from the map take `default_height`.

var heights: Dictionary
var default_height: float
var spacing: float


func _init(p_heights: Dictionary = {}, p_default := 0.0, p_spacing := 12.0) -> void:
	heights = p_heights
	default_height = p_default
	spacing = p_spacing


func terrain_tile_size() -> float:
	return spacing


func surface_height(i: int, j: int) -> float:
	return float(heights.get(Vector2i(i, j), default_height))


func storey_at(i: int, j: int) -> int:
	return floori(surface_height(i, j) / 4.0)


func level_at(i: int, j: int) -> int:
	return floori(fposmod(surface_height(i, j), 4.0))


## One tile (i..i+1, j..j+1) with corners a(0,0) b(1,0) c(1,1) d(0,1).
static func tile(a: float, b: float, c: float, d: float, default := -1.0):
	var script: GDScript = load("res://tests/fixtures/tile_point_region.gd")
	return script.new({Vector2i(0, 0): a, Vector2i(1, 0): b,
		Vector2i(1, 1): c, Vector2i(0, 1): d}, default if default >= 0.0 else minf(minf(a, b), minf(c, d)))
