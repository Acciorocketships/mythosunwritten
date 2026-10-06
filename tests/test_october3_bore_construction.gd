extends GutTest


func test_corner_roof_has_native_attic_closures_inside_one_cell() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	for family: String in ["blue", "orange"]:
		var recipe := program.recipe(StringName("roof.partial.gable.%s.1" % family))
		assert_not_null(recipe)
		assert_eq(recipe.occluder_cells, [Vector3i.ZERO] as Array[Vector3i])
		assert_eq(recipe.placements.size(), 3, "Native pitched shell and two attic ends")
		assert_eq(recipe.roof_gable_edge, Vector3i.ZERO, "Neither end is an open party cut")
		assert_true(
			recipe.compact_roof_runs.is_empty(), "A closed corner is not a continuous ridge"
		)
		for part: Dictionary in recipe.placements:
			var descriptor := catalog.descriptor(part.asset_id)
			var box: AABB = part.transform * descriptor.measured_aabb
			assert_gt(descriptor.collision_piece_count, 0)
			assert_gte(box.position.x, -.7501)
			assert_gte(box.position.z, -.7501)
			assert_lte(box.end.x, .7501)
			assert_lte(box.end.z, .7501)
		assert_gt(recipe.local_bounds.size.y, .8, "The private crown is pitched, not a walk slab")
		var cache := EnvironmentRenderCache.new(catalog)
		for end: int in [-1, 1]:
			for point: Vector2 in [
				Vector2(-.35, .2),
				Vector2(.35, .2),
				Vector2(-.12, .5),
				Vector2(.12, .5),
				Vector2(0, .75)
			]:
				assert_true(
					_attic_hit(recipe, cache, end, point),
					"Native end panel closes the attic at %s/%s" % [end, point]
				)


func test_odd_private_crown_builds_without_recarving_or_exposing_the_street() -> void:
	# The two-band bore retains this room, whose five exposed roof cells form
	# an L beside upper public air. Even-area native strips alone cannot close it.
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		58, {}, program, WarrenVillageScaleProfile.for_id(&"large")
	)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var fabric := spatial.compiled_fabric_cache()
	var corner_parents := {}
	var original_corner := false
	var corners := 0
	for unit: FabricUnit in fabric.units:
		if (
			String(unit.recipe_id).begins_with("roof.partial.gable.")
			and String(unit.recipe_id).ends_with(".1")
		):
			corners += 1
			assert_false(corner_parents.has(unit.parent_ids[0]), "At most one small roof per crown")
			corner_parents[unit.parent_ids[0]] = true
	# Identify the original five-cell L by geometry. Array-index room names
	# change when another seed is admitted; that must not erase this regression.
	for parent: StringName in corner_parents:
		var crown := {}
		for unit: FabricUnit in fabric.units:
			if (
				unit.parent_ids.is_empty()
				or unit.parent_ids[0] != parent
				or not String(unit.recipe_id).begins_with("roof.")
			):
				continue
			for cell: Vector3i in program.recipe(unit.recipe_id).occluder_cells:
				var transformed := FabricRecipe.transform_cell(
					cell, unit.lattice_origin, unit.yaw_quarters
				)
				crown[Vector2i(transformed.x, transformed.z)] = true
		var bounds := BuildingDesigner._bounds(crown)
		original_corner = (
			original_corner
			or (crown.size() == 5 and bounds.size in [Vector2i(2, 4), Vector2i(4, 2)])
		)
	assert_eq(corners, 2, "Completing the first odd crown exposes a second in the same town")
	assert_true(original_corner, "Retain the original failing five-cell corner")
	assert_true(fabric.validate())
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial, fabric, kit)
	assert_eq(KitFloatingMassAudit.audit(spatial, fabric, built.masses).count, 0)
	assert_eq(
		preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, kit).intrusions, 0
	)
	assert_gt(built.room_projections.size(), 0, "Inhabited wall projections survive the lower bore")


func _attic_hit(
	recipe: FabricRecipe, cache: EnvironmentRenderCache, end: int, point: Vector2
) -> bool:
	var start := Vector3(point.x, point.y, end * .76)
	var finish := Vector3(point.x, point.y, end * .54)
	for part: Dictionary in recipe.placements:
		if part.id != StringName("attic.%d" % end):
			continue
		for piece: EnvironmentVisualPiece in cache.visual(part.asset_id).pieces:
			var pose: Transform3D = part.transform * piece.local_transform
			var faces := piece.mesh.get_faces()
			for index in range(0, faces.size(), 3):
				if (
					Geometry3D.segment_intersects_triangle(
						start,
						finish,
						pose * faces[index],
						pose * faces[index + 1],
						pose * faces[index + 2]
					)
					!= null
				):
					return true
	return false


func test_cross_gabled_halls_keep_complete_dormers_after_lower_boring() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		60, {}, program, WarrenVillageScaleProfile.for_id(&"standard")
	)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
	var dressed_branches := 0
	for roof: Dictionary in built.roofs:
		if roof.open_min or roof.open_max:
			dressed_branches += roof.dormers.size()
	assert_gt(dressed_branches, 0, "The inhabited cross wings must not all be bare slopes")
	var audit := preload("res://tests/fixtures/kit_roof_audit.gd").audit(built, kit)
	assert_eq(int(audit.gable_holes), 0)
	assert_eq(int(audit.open_exposed), 0)
	assert_eq(int(audit.air_unsupported), 0)
	assert_eq(
		preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, kit).intrusions, 0
	)
