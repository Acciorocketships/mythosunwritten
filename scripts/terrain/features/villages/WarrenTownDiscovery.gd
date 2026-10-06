extends RefCounted
## Resource-free discovery bounds. These do not reserve space or alter towns.
const FIELD := preload("res://scripts/terrain/features/villages/fabric/WarrenTownField.gd")

static func maximum_radius(asset_reach: float) -> float:
	var extent := 0
	for id: StringName in WarrenVillageScaleProfile.IDS:
		extent = maxi(extent,FIELD.maximum_sample_extent(WarrenVillageScaleProfile.for_id(id).radius_cells))
	return _radius((2 * extent + 1) * VillageWorldScale.WORLD_MACRO_CELL_M,asset_reach)

static func radius_for_seed(seed_value: int, asset_reach: float) -> float:
	var field := FIELD.sample(seed_value,WarrenVillageScaleProfile.select(seed_value))
	var bounds := Rect2()
	var first := true
	var columns: Dictionary = field.height_domain.duplicate()
	columns.merge(field.solid)
	for space: Dictionary in field.open_spaces: columns.merge(space.cells)
	for column: Vector2i in columns:
		var cell := Rect2(Vector2(column),Vector2.ONE)
		bounds = cell if first else bounds.merge(cell)
		first = false
	# The entrance is in this same domain. A cardinal turn cannot exceed
	# its longest side, measured from any possible entrance within it.
	return _radius(maxf(bounds.size.x,bounds.size.y) * VillageWorldScale.WORLD_MACRO_CELL_M,asset_reach)

static func _radius(source_span: float, asset_reach: float) -> float:
	var pitch := VillageWorldScale.WORLD_FINE_CELL_M
	# Entrance-to-road offset, full native parts on either side of their
	# anchor, and the outside road handoff (one half route-lattice edge).
	var reach := source_span + VillageWorldScale.WORLD_MACRO_CELL_M + pitch 		+ 2.0 * asset_reach * VillageWorldScale.HORIZONTAL_SCALE 		+ VillageWarrenFabricSolver.CLEARANCE_MARGIN * VillageWorldScale.HORIZONTAL_SCALE 		+ PathProgram.PATH_HALF_WIDTH + PathProgram.CORNER_RADIUS + HeightfieldPlan.CELL * 0.5
	# Street grading claims walking width plus one pitch, rounded outwards.
	reach += PathProgram.PATH_HALF_WIDTH + 2.0 * pitch
	# Every collar rectangle owns at least one claim. The bounding square
	# therefore supplies an upper bound on log(N) in the smooth-min collar.
	var side := ceili(2.0 * reach / pitch) + 3
	return reach + TerrainGradePatch.TRANSITION_WIDTH 		+ TerrainGradePatch.COLLAR_BLEND * log(float(side * side)) + pitch * 0.5
