extends RefCounted
## Loads a town grade frozen by tests/harness/road_grade_freeze.gd with its
## natural terrain (no plan: the frozen region is the complete natural input)
## and the nearby accepted country-road lattice.
static func load_fixture(path: String) -> Dictionary:
	var d: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(path).decompress_dynamic(
		8000000, FileAccess.COMPRESSION_GZIP))
	d["region"] = HeightfieldRegion.new(d.storeys, d.levels, d.carved)
	d["grade_patch"] = grade(d.grade)
	return d

static func grade(d: Dictionary) -> TerrainGradePatch:
	if d.is_empty(): return null
	var result := TerrainGradePatch.new(StringName(d.id), d.claims, d.origin, d.pitch)
	result._continuous_source = grade(d.source)
	result._continuous_cells = d.continuous_cells
	result._continuous_datum = d.continuous_datum
	return result
