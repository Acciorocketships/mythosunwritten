extends GutTest
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")

func test_chimney_moves_as_one_complete_stack_on_either_roof_axis() -> void:
	var kit := SuntailBuildingKit.create()
	for axis in 2:
		var mass := BuildingMass.new()
		var wing := mass.add_roof(Rect2i(0,0,6,2) if axis == 0 else Rect2i(0,0,2,6),axis,4,&"red")
		wing.chimney = true
		wing.chimney_end = 1
		wing.union_index = 0
		var placements := BuildingKitAssembler.new(kit).assemble(mass)
		var before: Array = placements.filter(func(p: Dictionary) -> bool: return String(p.role).begins_with("chimney."))
		assert_gt(before.size(),1)
		var original := (before[0].transform as Transform3D).origin
		var blocker := UNION.box_volume(AABB(original-Vector3(0.8,1,0.8),Vector3(1.6,6,1.6)))
		blocker.open = true
		var ctx := UNION.prepare([wing],[blocker],kit)
		assert_false(UNION._chimney_is_clear(before,Vector3.ZERO,ctx),"measured original stack obstructs walking air")
		var result := UNION.fit_chimneys(placements,ctx)
		assert_eq(result.moved,1)
		assert_eq(result.omitted,0)
		var after: Array = placements.filter(func(p: Dictionary) -> bool: return String(p.role).begins_with("chimney."))
		assert_eq(after.size(),before.size(),"body and cap remain complete instances")
		assert_true(UNION._chimney_is_clear(after,Vector3.ZERO,ctx))
		for p: Dictionary in after:
			assert_true(UNION.realize(p,ctx).is_empty(),"a rigid stack is never triangle-clipped")
		# A roof with no clear ridge position omits the whole optional stack.
		var all := UNION.box_volume(AABB(Vector3(-5,0,-5),Vector3(30,30,30)))
		all.open = true
		ctx.walls = [all]
		result = UNION.fit_chimneys(placements,ctx)
		assert_eq(result.omitted,1)
		assert_false(wing.chimney)
		assert_true(placements.filter(func(p: Dictionary) -> bool: return String(p.role).begins_with("chimney.")).is_empty())

func test_generated_town_chimneys_clear_finished_walking_surfaces() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(1260018864828801968,{},program,
		WarrenVillageScaleProfile.for_id(&"large"))
	_assert_town_chimneys(spatial)

func test_reproduced_chimney_obstruction_moves_without_losing_the_stack() -> void:
	# Freeze the source town and the original end-of-ridge chimney choice.
	# Later articulation chooses the other (clear) end, so a moved-count on
	# the final town alone no longer exercises this actual walkway contact.
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var source := frozen.read("res://tests/fixtures/october1-chimney-source.txt")
	var spatial := frozen.spatial(source,SettlementFabricProgram.compile(EnvironmentCatalog.load_default()))
	var built := _assert_town_chimneys(spatial)
	var kit := SuntailBuildingKit.create()
	var context := UNION.prepare(built.roofs,built.walls,kit,built.roof_kits)
	var exercised := false
	for index in built.roofs.size():
		var roof: Dictionary = built.roofs[index].duplicate(true)
		if roof.rect != Rect2i(6,4,4,2) or roof.axis != 0 or roof.eave_band != 2: continue
		roof.chimney = true
		roof.chimney_end = 0
		roof.erase("chimney_u")
		roof.union_index = index
		var mass := BuildingMass.new()
		mass.roofs.append(roof)
		var parts := BuildingKitAssembler.new(built.roof_kits.get(index,kit)).assemble(mass)
		var stack: Array = parts.filter(func(part: Dictionary) -> bool: return String(part.role).begins_with("chimney."))
		assert_gt(stack.size(),1,"the actual body and cap remain complete native pieces")
		var original_count := stack.size()
		assert_false(UNION._chimney_is_clear(stack,Vector3.ZERO,context),"the original ridge end intersects this town's real public air")
		var fit := UNION.fit_chimneys(parts,context)
		assert_eq(int(fit.moved),1,"move the reproduced stack along its own ridge")
		assert_eq(int(fit.omitted),0)
		stack = parts.filter(func(part: Dictionary) -> bool: return String(part.role).begins_with("chimney."))
		assert_eq(stack.size(),original_count)
		assert_true(UNION._chimney_is_clear(stack,Vector3.ZERO,context))
		for part: Dictionary in stack:
			assert_true(UNION.realize(part,context).is_empty(),"no triangles are cut from a rigid chimney")
		exercised = true
	assert_true(exercised,"retain the original roof geometry and positive obstruction coverage")

func _assert_town_chimneys(spatial: WarrenSpatialPlan) -> Dictionary:
	assert_not_null(spatial)
	if spatial == null: return {}
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
	var ctx := UNION.prepare(built.roofs,built.walls,kit,built.roof_kits)
	var count := 0
	for p: Dictionary in built.placements:
		if not String(p.role).begins_with("chimney."): continue
		count += 1
		assert_true(UNION._chimney_is_clear([p],Vector3.ZERO,ctx),String(p.stable_id))
	assert_gt(count,20,"preserve the town's chimney variety")
	assert_eq(int(built.roof_audit.chimneys.omitted),0,"this town has room to keep every stack")
	return built
