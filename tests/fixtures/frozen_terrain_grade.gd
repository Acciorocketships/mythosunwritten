extends RefCounted

static func grade(data: Dictionary) -> TerrainGradePatch:
	var result := TerrainGradePatch.new(data.id,data.claims,data.origin,data.pitch)
	if not data.source.is_empty(): result._continuous_source=grade(data.source)
	result._continuous_cells=data.continuous_cells
	result._continuous_datum=data.datum
	return result

static func region(path: String) -> HeightfieldRegion:
	var data: Dictionary=str_to_var(FileAccess.get_file_as_string(path))
	var result := HeightfieldRegion.new(data.storeys,data.levels,data.carved)
	for entry: Dictionary in data.grades: result.terrain_grades.append(grade(entry))
	return result
