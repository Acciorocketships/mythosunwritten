extends RefCounted

static func grade(data: Dictionary) -> TerrainGradePatch:
	var result := TerrainGradePatch.new(data.id,data.claims,data.origin,data.pitch)
	if not data.source.is_empty(): result._continuous_source=grade(data.source)
	result._continuous_cells=data.continuous_cells
	result._continuous_datum=data.datum
	return result

## The frozen fields (September 8-15) store the natural terrain per 24 m CELL.
## The dual-grid region is keyed by 12 m lattice POINTS: point p lies inside
## cell round(p / 2) (its odd points on a cell border take the upper cell, a
## fixed deterministic tie). This re-freezes the recorded geography at 12 m
## without inventing heights; the town grades are world-space and unchanged.
static func region(path: String) -> HeightfieldRegion:
	var data: Dictionary=str_to_var(FileAccess.get_file_as_string(path))
	var storeys := _points(data.storeys)
	var result := HeightfieldRegion.new(storeys,_points(data.levels),_points(data.carved))
	for entry: Dictionary in data.grades: result.terrain_grades.append(grade(entry))
	return result

static func _points(cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if cells.is_empty(): return out
	var lo: Vector2i = cells.keys()[0]
	var hi := lo
	for cell: Vector2i in cells:
		lo = Vector2i(mini(lo.x,cell.x),mini(lo.y,cell.y))
		hi = Vector2i(maxi(hi.x,cell.x),maxi(hi.y,cell.y))
	for z in range(lo.y*2-1,hi.y*2+1):
		for x in range(lo.x*2-1,hi.x*2+1):
			var cell := Vector2i(floori(x*.5+.5),floori(z*.5+.5))
			if cells.has(cell): out[Vector2i(x,z)] = cells[cell]
	return out
