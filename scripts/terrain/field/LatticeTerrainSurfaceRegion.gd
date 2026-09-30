class_name LatticeTerrainSurfaceRegion
extends RefCounted

## Immutable-by-convention adapter from an arbitrary procedural column field to
## the dual-grid terrain kernel's read contract (TerrainTileField). The world
## heightfield and a village's retained earth use one cliff/slope classifier
## and one smootherstep tile kernel at their respective lattice scales. Each
## column is a lattice POINT at its centre (x * cell_size); its dual cell is the
## column itself, so a cliff (two or more bands) stands exactly on the column
## face at x * cell_size + cell_size / 2, like the voxel walls, and a one-band
## step is one slope tile from column centre to column centre.
## Values are top-surface bands (not solid-cell indices).

var _top_by_cell: Dictionary
var _cell_size: float
var _default_top: int


func _init(top_by_cell: Dictionary, cell_size: float,
		default_top: int) -> void:
	assert(is_finite(cell_size) and cell_size > 0.0)
	_top_by_cell = top_by_cell.duplicate()
	_cell_size = cell_size
	_default_top = default_top


func terrain_tile_size() -> float:
	return _cell_size


func storey_at(cx: int, cz: int) -> int:
	return int(_top_by_cell.get(Vector2i(cx, cz), _default_top))


func level_at(_cx: int, _cz: int) -> int:
	return 0


func surface_height(cx: int, cz: int) -> float:
	return float(storey_at(cx, cz)) * _cell_size


func is_carved(_cx: int, _cz: int) -> bool:
	return false
