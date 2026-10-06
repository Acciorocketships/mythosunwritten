extends GutTest
const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
const AUDIT := preload("res://tests/fixtures/kit_roof_audit.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")

func test_native_kit_closes_complete_town_gables_and_supported_joins() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var kit := PURE.roof_study()
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var roofs := 0
	# Preserve the original live cases and add the reported construction. Roof
	# sample coverage belongs to the corpus; a compact town may have 18 roofs.
	for job: Array in [[0,&"photo_fixture"],[7,&"compact"],[9,&"standard"],[1260018864828801968,&"large"]]:
		var spatial := FROZEN.spatial(FROZEN.read("res://tests/fixtures/october1-photo-roofs-source.txt"),program) \
			if job[1] == &"photo_fixture" else WarrenVolumetricSolver.generate(job[0],{},program,WarrenVillageScaleProfile.for_id(job[1]))
		assert_not_null(spatial,str(job))
		if spatial == null: continue
		var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
		_check_town(built,kit,job,cache,10)
		roofs += int(AUDIT.audit(built,kit).roofs)
	assert_gt(roofs,60,"retain the original three-town roof sample coverage")

func test_mixed_roof_families_close_representative_and_holdout_towns() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var kit := SuntailBuildingKit.create()
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	for job: Array in [[7,&"compact"],[13,&"large"],[34,&"compact"],[60,&"standard"]]:
		var spatial := WarrenVolumetricSolver.generate(job[0],{},program,WarrenVillageScaleProfile.for_id(job[1]))
		assert_not_null(spatial,str(job))
		if spatial == null: continue
		var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
		var families := {}
		for part: Dictionary in built.placements:
			if not String(part.role).begins_with("roof."): continue
			var family: BuildingKit = built.roof_kits[part.roof_index]
			assert_true(String(part.asset_id).begins_with(String(family.kit_id)+"."))
			families[family.kit_id] = true
		assert_true(families.has(&"suntail"))
		assert_true(families.has(&"pure_village"))
		_check_town(built,kit,job,cache,10)

func test_current_grand_town_keeps_closed_roofs_and_public_clearance() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var spatial := WarrenVolumetricSolver.generate(9, {}, program,
		WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null: return
	var fabric := spatial.compiled_fabric_cache()
	assert_true(fabric.validate())
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial, fabric, kit)
	_check_town(built, kit, [9, &"grand"], EnvironmentRenderCache.new(catalog))
	var air := preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, kit)
	assert_eq(int(air.intrusions), 0, "measured roof seams never exempt public walking air")
	assert_eq(KitFloatingMassAudit.audit(spatial, fabric, built.masses).count, 0)

func test_terminal_roof_retains_the_preproved_neighbor_contact() -> void:
	# Reconstruct the native contact from the original 9/grand failure log.
	# Current layout generation no longer creates this pair. Both actual roof
	# recipes and transforms are preserved; the two room supports are explicit.
	var compiler := preload("res://scripts/terrain/features/villages/fabric/WarrenSpatialFabricCompiler.gd")
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var grid := WarrenSpatialGrid.new(Vector3i(-20,0,-20),Vector3i(40,20,40))
	var source := WarrenSpatialPlan.new(&"terminal.fixture",9,grid)
	var room := WarrenRoomStamp.new(&"terminal.room",&"terminal.parcel",&"tower",
		Vector3i(-7,6,1),0,0,true,false)
	var parent := FabricUnit.new(&"terminal.parent",&"room.tower.base.blue.closed",room.lattice_origin,0)
	var neighbor := FabricUnit.new(&"neighbor.parent",&"room.base.blue.closed",Vector3i(-7,4,4),3)
	var prior := FabricUnit.new(&"prior.roof",&"roof.square.blue.dormer.left",Vector3i(-7,6,4),3,
		[neighbor.stable_id],[FabricUnit.bond(&"bearing.bottom",neighbor.stable_id,&"bearing.top")],
		&"",[parent.stable_id])
	var probe := SettlementFabricPlan.new(&"terminal.probe")
	for recipe: FabricRecipe in program.recipes(): assert_true(probe.register_recipe(recipe))
	for unit: FabricUnit in [parent,neighbor,prior]: assert_true(probe.add_unit(unit),probe.last_rejection)
	var faces: Array[Vector3i] = [Vector3i(-8,7,0),Vector3i(-7,7,0),Vector3i(-8,7,1),Vector3i(-7,7,1)]
	var closures: Array[Dictionary] = [{"owner_room_id":room.stable_id,"allowed_room_ids":{&"neighbor.room":true}}]
	var rejected := compiler._terminal_macro_cap_fallback(source,program,probe,faces,0,room.stable_id,
		room,parent,[parent.stable_id],[],{&"neighbor.room":neighbor},{},[prior],{},[],{})
	assert_true(rejected.units.is_empty(),"without the proved contact, the original intersection is rejected")
	assert_string_contains(String(rejected.failure),"intersects unrelated unit prior.roof")
	assert_eq(probe.units.size(),3,"failed atomic candidates leave the original transaction untouched")
	var accepted := compiler._terminal_macro_cap_fallback(source,program,probe,faces,0,room.stable_id,
		room,parent,[parent.stable_id],[],{&"neighbor.room":neighbor},{},[prior],{},closures,{})
	assert_eq(accepted.units.size(),2,"positive terminal fallback covers both native strips")
	var contact_count := 0
	for unit: FabricUnit in accepted.units:
		assert_string_contains(String(unit.stable_id),".terminal")
		assert_string_contains(String(unit.recipe_id),"roof.partial.gable.")
		if unit.visual_seam_ids.has(prior.stable_id): contact_count += 1
		assert_true(probe.add_unit(unit),probe.last_rejection)
	assert_eq(contact_count,1,"only the strip actually touching the neighbor inherits its measured seam")
	assert_eq(probe.units.size(),5,"both complete roof strips commit on their explicit room supports")
	assert_true(probe.visual_envelope_conflicts().is_empty(),"the native contact leaves no unrelated overlap")


func _check_town(built: Dictionary, kit: BuildingKit, job: Array, cache: EnvironmentRenderCache, minimum_roofs := 20) -> void:
	var audit := AUDIT.audit(built,kit)
	assert_gt(int(audit.roofs),minimum_roofs,"complete town, not an isolated house: %s" % str(job))
	assert_eq(int(audit.gable_holes),0,str(audit.examples))
	assert_eq(int(audit.open_exposed),0,str(audit.examples))
	assert_eq(int(audit.air_unsupported),0,str(audit.examples))
	assert_true((built.payload as EnvironmentInstancePayload).validate())
	var ctx := UNION.prepare(built.roofs,built.walls,kit,built.roof_kits)
	var checked := 0
	for p: Dictionary in built.placements:
		if not String(p.role).ends_with("dormer"): continue
		var actual := UNION.realize(p,ctx)
		var source: Array = ctx.data[p.asset_id]
		var visual := cache.visual(p.asset_id)
		for si in source.size():
			var surface: Dictionary = source[si]
			var name := String(visual.pieces[surface.piece].mesh.surface_get_material(surface.surface).resource_name)
			if name != "Glass_Out" and not name.begins_with("Window"): continue
			checked += 1
			if actual.is_empty(): continue
			assert_almost_eq(_area(actual.meshes[si],Transform3D.IDENTITY),_area(surface,p.transform),0.001,
				"finished union must preserve the whole dormer opening: %s %s" % [job,p.stable_id])
	assert_gt(checked,0,"the complete town exercises actual glazed dormers")

func _area(surface: Dictionary, pose: Transform3D) -> float:
	var area := 0.0
	for i in range(0,surface.indices.size(),3):
		var a: Vector3 = pose*surface.vertices[surface.indices[i]]
		var b: Vector3 = pose*surface.vertices[surface.indices[i+1]]
		var c: Vector3 = pose*surface.vertices[surface.indices[i+2]]
		area += (b-a).cross(c-a).length()*0.5
	return area
