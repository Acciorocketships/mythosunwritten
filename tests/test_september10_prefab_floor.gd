extends GutTest

func test_prefab_bearings_have_a_continuous_native_floor() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	for recipe: FabricRecipe in program.recipes():
		if not recipe.has_tag(&"prefab_anchor"):
			continue
		var floor_faces := PackedVector3Array()
		for placement: Dictionary in recipe.placements:
			if placement.asset_id != SettlementFabricProgram.FLOOR:
				continue
			var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
			for piece: EnvironmentVisualPiece in visual.pieces:
				floor_faces.append_array(placement.transform * piece.local_transform * EnvironmentBakeGeometry.triangle_faces(piece.mesh))
		var missed := 0
		for cell: Vector3i in recipe.terrain_bearing_cells:
			var point := Vector3(cell) * FabricRecipe.CELL_SIZE
			var hit := false
			for i in range(0, floor_faces.size(), 3):
				if Geometry3D.segment_intersects_triangle(point + Vector3.UP * .02, point - Vector3.UP * .25, floor_faces[i], floor_faces[i+1], floor_faces[i+2]) != null:
					hit = true
					break
			if not hit:
				missed += 1
		assert_eq(missed, 0, "%s: every bearing must meet an actual native floor" % recipe.recipe_id)

func test_rotated_prefab_floor_owns_every_complete_supported_cell() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var recipe := program.recipe(&"anchor.prefab.10")
	for yaw in 4:
		var plan := SettlementFabricPlan.new(&"prefab.floor")
		plan.set_asset_visual_bounds(program.asset_visual_bounds)
		plan.register_recipe(recipe)
		var unit := FabricUnit.new(&"house", recipe.recipe_id, Vector3i(-3,4,-3), yaw)
		plan.append_constructed_unit(unit)
		assert_true(plan.finish_construction())
		var cells := plan.floor_owned_cells()
		for z in range(-3,3):
			for x in range(-2,2):
				var cell := FabricRecipe.transform_cell(Vector3i(x,0,z), unit.lattice_origin, yaw)
				assert_true(cells.has(cell), "Rotated native floor must own the complete cell %s" % cell)

func test_prefab_platform_reserves_support_under_its_whole_floor() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for recipe: FabricRecipe in program.recipes():
		if not recipe.has_tag(&"prefab_anchor"):
			continue
		var plan := SettlementFabricPlan.new(&"prefab.support")
		plan.set_asset_visual_bounds(program.asset_visual_bounds)
		plan.register_recipe(recipe)
		plan.append_constructed_unit(FabricUnit.new(&"house", recipe.recipe_id, Vector3i.ZERO, 0))
		var missing := 0
		for cell: Vector3i in plan.floor_owned_cells():
			if not recipe.terrain_bearing_cells.has(cell):
				missing += 1
		assert_eq(missing, 0, "%s must reserve every platform cell before placement" % recipe.recipe_id)

func test_photographed_outer_ledge_sits_above_its_retaining_stone() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://tests/fixtures/september10-prefab-base-source.txt"), program).compiled_fabric_cache()
	var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
	var wall := catalog.descriptor(SettlementFabricAssembler.MAZE_STONE_MODULE)
	var visual: EnvironmentVisual = load(wall.visual_path)
	var batch: Dictionary = payload.batches[wall.id]
	var index: int = batch.ids.find(&"maze-stone/9/0/4/2")
	assert_gte(index, 0, "The photographed retaining face must remain present")
	if index < 0:
		return
	var highest := -INF
	for piece: EnvironmentVisualPiece in visual.pieces:
		for point: Vector3 in batch.transforms[index] * piece.local_transform * EnvironmentBakeGeometry.triangle_faces(piece.mesh):
			highest = maxf(highest, point.y)
	var deck := catalog.descriptor(SettlementFabricAssembler.PLANK_GALLERY).measured_aabb
	assert_lte(highest, 1.5 - deck.size.y + .001,
		"The native stone must end below the timber's underside, not intersect its top")
