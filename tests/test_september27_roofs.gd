extends GutTest
## September 27 judging pass, roofs (seed 2697992464; photo towns
## 1260018864828801968:compact near (312,1056) and 85830433957479026:compact
## near (-216,1152)). Invariants measured on realized, union-trimmed pieces
## by tests/fixtures/kit_roof_audit.gd.
const AUDIT := preload("res://tests/fixtures/kit_roof_audit.gd")
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")


func _mass(id: String, cells: Rect2i, roof: Rect2i, axis: int) -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = StringName(id)
	mass.add_storey(0, BuildingMass.rect_cells(cells), BuildingMass.MATERIAL_TIMBER)
	mass.add_roof(roof, axis, 2, &"red")
	return mass


## Photo 2 / 5: a branch as deep as its host ran half a module past the
## host's ridge; its open end stood out of the far slope (a see-through
## "inverted dormer").
func test_equal_depth_branch_is_buried_at_the_host_ridge() -> void:
	var kit := SuntailBuildingKit.create()
	var host := _mass("host", Rect2i(0, 0, 6, 2), Rect2i(0, 0, 6, 2), 0)
	var branch := _mass("branch", Rect2i(2, 2, 2, 3), Rect2i(2, 2, 2, 3), 1)
	var masses: Array[BuildingMass] = [host, branch]
	var result := AUDIT.audit(AUDIT.assemble(masses, kit), kit)
	assert_true(branch.roofs[0].open_min, "the branch joins its host")
	assert_eq(result.open_exposed, 0, str(result.examples))


## Photo 13: a narrow roof ending against a deeper parallel roof kept both
## gables; the deeper roof's verge lay on the narrow roof's coplanar slope.
func test_stepped_parallel_wing_runs_into_its_deeper_neighbour() -> void:
	var kit := SuntailBuildingKit.create()
	var host := _mass("host", Rect2i(0, 0, 4, 4), Rect2i(0, 0, 4, 4), 1)
	var branch := _mass("branch", Rect2i(0, 4, 2, 3), Rect2i(0, 4, 2, 3), 1)
	var masses: Array[BuildingMass] = [host, branch]
	var result := AUDIT.audit(AUDIT.assemble(masses, kit), kit)
	assert_true(branch.roofs[0].open_min, "the narrow roof opens into the deeper one")
	assert_false(host.roofs[0].open_max, "the deeper roof keeps its gable above it")
	assert_eq(result.open_exposed + result.gable_holes, 0, str(result.examples))


## Photo 4 / 5 / 11: a one-module strip of the crown got its own ridge-top
## roof perched at the edge of the big roof.
func test_crown_sliver_merges_into_a_neighbouring_roof() -> void:
	var kit := SuntailBuildingKit.create()
	for nub: Rect2i in [Rect2i(2, 4, 2, 1), Rect2i(4, 0, 1, 2), Rect2i(0, -1, 1, 1)]:
		var mass := BuildingMass.new()
		mass.stable_id = &"sliver"
		mass.seed = 7
		var cells := BuildingMass.rect_cells(Rect2i(0, 0, 4, 4))
		cells.merge(BuildingMass.rect_cells(nub))
		mass.add_storey(0, cells, BuildingMass.MATERIAL_TIMBER)
		BuildingDesigner.new(kit).articulate(mass, {"terrain_storey": 0})
		var covered := {}
		for roof: Dictionary in mass.roofs:
			var r: Rect2i = roof.rect
			assert_gte(r.size[1 - int(roof.axis)], 2, "no one-module roof for nub %s" % nub)
			covered.merge(BuildingMass.rect_cells(r))
		for cell: Vector2i in BuildingMass.rect_cells(nub):
			assert_true(covered.has(cell), "nub %s stays under a roof" % nub)


func test_photo_towns_have_closed_roofs_without_tiny_wings() -> void:
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for city: Array in [[1260018864828801968, &"compact"], [85830433957479026, &"compact"]]:
		var source := WarrenMazeSitePlanner.plan(city[0], {},
			WarrenVillageScaleProfile.for_id(city[1]), &"", false)
		var spatial := FROZEN.spatial(source, program)
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
		var result := AUDIT.audit(built, kit)
		assert_eq(result.tiny, 0, "%s tiny roofs %s" % [city, result.examples])
		assert_eq(result.open_exposed, 0, "%s exposed open ends %s" % [city, result.examples])
		assert_eq(result.gable_holes, 0, "%s gable holes %s" % [city, result.examples])
		assert_eq(result.air_unsupported, 0, "%s unsupported roofs over air %s" % [city, result.examples])
		assert_eq(result.eaves_cut, 0, "%s eaves cut open by walking clearance %s" % [city, result.examples])


## Coordinator follow-up: a roof that shelters free air (a merged sliver's
## porch strip) stands on timber posts at every free corner of that air.
func test_roof_over_free_air_stands_on_posts() -> void:
	var kit := SuntailBuildingKit.create()
	var air_roofs := 0
	for size: Vector2i in [Vector2i(5, 4), Vector2i(5, 3), Vector2i(6, 5)]:
		for dir in 4:
			for seed_value in range(1000, 1012):
				var masses: Array[BuildingMass] = [KitStandaloneHouse.design(kit, size.x, size.y, dir, seed_value)]
				var result := AUDIT.audit(AUDIT.assemble(masses, kit), kit)
				air_roofs += int(result.air_roofs)
				assert_eq(result.air_unsupported, 0, "lot %s dir %d seed %d: %s" % [size, dir, seed_value, result.examples])
	assert_gt(air_roofs, 0, "porch roofs still occur")
