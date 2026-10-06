extends GutTest
const Wings = preload("res://scripts/terrain/features/villages/kit/KitSteppedWings.gd")
func _mass(seed_value:int=31) -> BuildingMass:
	var mass := BuildingMass.new()
	mass.seed=seed_value
	mass.stable_id=&"stepped.fixture"
	for band in [0,2,4]: mass.add_storey(band,BuildingMass.rect_cells(Rect2i(0,0,6,3)),BuildingMass.MATERIAL_TIMBER)
	mass.storeys[0].openings[Vector3i(2,0,3)]=BuildingMass.OPENING_DOOR
	return mass

func test_lower_wing_has_a_real_roof_and_bearing_with_no_expansion() -> void:
	var mass := _mass()
	assert_true(Wings.shape(mass,Callable(),Callable()))
	var kit := SuntailBuildingKit.create()
	BuildingDesigner.new(kit).articulate(mass,{"terrain_storey":0,"terraced":true})
	assert_eq(mass.storeys[0].cells.size(),18)
	assert_lt(mass.storeys[-1].cells.size(),18)
	var lower_roofs := 0
	for roof: Dictionary in mass.roofs:
		if roof.eave_band>=mass.top_band(): continue
		lower_roofs+=1
		for cell: Vector2i in BuildingMass.rect_cells(roof.rect):
			assert_true(mass.cells_at_band(roof.eave_band-1).has(cell))
	for storey: Dictionary in mass.storeys:
		for cell: Vector2i in storey.cells:
			assert_true(Rect2i(0,0,6,3).has_point(cell))
	assert_gt(lower_roofs,0,"The new shoulder must be a roofed inhabited wing, not another flat deck")

func test_external_bearing_walks_and_doors_prevent_the_cut() -> void:
	var covered := func(_cell:Vector2i,_band:int)->bool:return true
	var mass := _mass()
	assert_false(Wings.shape(mass,covered,Callable()))
	assert_false(Wings.shape(mass,Callable(),covered))
	for x in [0,5]: mass.storeys[-1].openings[Vector3i(x,0,3)]=BuildingMass.OPENING_DOOR
	assert_false(Wings.shape(mass,Callable(),Callable()))
	assert_eq(mass.storeys[-1].cells.size(),18)

func test_seeded_wing_choices_are_repeatable_and_vary() -> void:
	var layouts := {}
	for value in range(12):
		var a := _mass(value)
		var b := _mass(value)
		assert_true(Wings.shape(a,Callable(),Callable()))
		assert_true(Wings.shape(b,Callable(),Callable()))
		assert_eq(a.storeys,b.storeys)
		layouts[str(a.storeys)]=true
	assert_gt(layouts.size(),1)

func test_two_storey_refusal_still_tries_a_shallower_roofed_wing() -> void:
	for value in range(16):
		var mass := _mass(value)
		mass.storeys[1]["bears_balcony"] = true
		var middle: Dictionary = mass.storeys[1].duplicate(true)
		assert_true(Wings.shape(mass,Callable(),Callable()),
			"A balcony on the middle floor does not forbid stepping only the top floor")
		assert_eq(mass.storeys[1].cells,middle.cells)
		assert_eq(mass.storeys[1].openings,middle.openings)
		assert_true(mass.storeys[1].bears_balcony)
		assert_lt(mass.storeys[2].cells.size(),18)

func test_compound_crown_can_lower_a_complete_borne_range() -> void:
	for value in range(12):
		var mass := _mass(value)
		var footprint := BuildingMass.rect_cells(Rect2i(0,0,6,2))
		footprint.merge(BuildingMass.rect_cells(Rect2i(0,2,2,2)))
		for floor: Dictionary in mass.storeys: floor.cells=footprint.duplicate()
		assert_true(Wings.shape(mass,Callable(),Callable()))
		assert_eq(mass.storeys[0].cells,footprint,"The inhabited bearing rooms remain intact")
		assert_true(preload("res://scripts/terrain/features/villages/kit/KitLoggias.gd")._connected(mass.storeys[-1].cells))
		for part: Rect2i in BuildingDesigner.decompose(mass.storeys[-1].cells):
			assert_gte(mini(part.size.x,part.size.y),2,"No roof slivers in the remaining compound")
		BuildingDesigner.new(SuntailBuildingKit.create()).articulate(mass,{"terrain_storey":0,"terraced":true})
		assert_true(mass.roofs.any(func(r:Dictionary)->bool:return r.eave_band<mass.top_band()),
			"The retained range receives a pitched roof")

func test_finished_towns_keep_clear_roofs_and_supported_mass() -> void:
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var changed := 0
	var corner_wings := 0
	for case: Array in [[13,&"large"],[43,&"grand"],[31,&"large"],[41,&"large"],[103,&"grand"],[53,&"grand"],[63,&"grand"]]:
		var spatial := WarrenVolumetricSolver.generate(case[0],{},program,WarrenVillageScaleProfile.for_id(case[1]))
		assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
		if spatial==null:continue
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial,fabric,kit)
		assert_true(built.payload.validate())
		assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0)
		assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,kit).intrusions),0)
		# These long crowns used to receive a loggia first, which made their
		# footprint nonrectangular and silently prevented the primary wing.
		var target: StringName = {53: &"kit.spatial.parcel.maze.house.018",
			63: &"kit.spatial.parcel.maze.house.001"}.get(case[0],&"")
		if target != &"":
			var found := false
			for mass: BuildingMass in built.houses:
				if mass.stable_id != target: continue
				found = true
				assert_true(mass.storeys.any(func(f:Dictionary)->bool:return f.get("stepped_wing",false)),
					"Primary roofed wings take precedence over small loggia notches")
				assert_true(mass.roofs.any(func(r:Dictionary)->bool:return r.eave_band<mass.top_band()),
					"The retained lower rooms need an actual pitched roof")
			assert_true(found,"The regression house must be built, not silently skipped")
		for mass: BuildingMass in built.masses:
			changed+=int(mass.storeys.any(func(f:Dictionary)->bool:return f.get("stepped_wing",false)))
			for floor: Dictionary in mass.storeys:
				if bool(floor.get("stepped_wing",false)):
					var bounds := BuildingDesigner._bounds(floor.cells)
					corner_wings+=int(floor.cells.size()<bounds.get_area())
	assert_gt(changed,0,"The shape rule must survive the production path")
	assert_gt(corner_wings,0,"The production order must preserve corner wings before loggias")

func test_broad_stack_keeps_connected_l_upper_and_roofed_corner() -> void:
	var mass := _mass()
	for floor: Dictionary in mass.storeys:
		floor.cells=BuildingMass.rect_cells(Rect2i(0,0,6,4))
	assert_true(Wings.shape(mass,Callable(),Callable()))
	var upper: Dictionary = mass.storeys[-1].cells
	var expected := upper.duplicate()
	preload("res://scripts/terrain/features/villages/kit/KitLoggias.gd").recess(mass,Callable(),Callable())
	assert_eq(mass.storeys[-1].cells,expected,"Secondary loggias must not erode the primary roofed arms")
	assert_lt(upper.size(),24)
	assert_eq(BuildingDesigner._bounds(upper),Rect2i(0,0,6,4),"Both arms must survive; shortening the whole rectangle is not a corner wing")
	var reached := {}
	var queue: Array = [upper.keys()[0]]
	while not queue.is_empty():
		var cell: Vector2i=queue.pop_back()
		if reached.has(cell):continue
		reached[cell]=true
		for step: Vector2i in BuildingMass.DIRS:
			if upper.has(cell+step):queue.append(cell+step)
	assert_eq(reached.size(),upper.size(),"The upper dwelling must remain connected")
	BuildingDesigner.new(SuntailBuildingKit.create()).articulate(mass,{"terrain_storey":0,"terraced":true})
	var lower_roof_area := 0
	for roof: Dictionary in mass.roofs:
		if roof.eave_band<mass.top_band(): lower_roof_area+=roof.rect.size.x*roof.rect.size.y
	assert_gt(lower_roof_area,0,"The corner is an inhabited pitched-roof wing")

func test_local_balcony_bearings_allow_a_remote_wing_but_keep_support() -> void:
	for value in range(12):
		var mass := _mass(value)
		mass.storeys[-1]["bears_balcony"]=true
		mass.storeys[-1].openings[Vector3i(0,0,3)]=BuildingMass.OPENING_DOOR
		var bearing := func(cell:Vector2i,band:int)->bool:return cell.x<=1 and band>=3
		assert_true(Wings.shape(mass,Callable(),Callable(),bearing))
		for floor:Dictionary in mass.storeys:
			for x in 2:
				for z in 3:
					assert_true(floor.cells.has(Vector2i(x,z)),"Every bracket-bearing room remains")
		assert_lt(mass.storeys[-1].cells.size(),18)

func test_bracket_vertex_preserves_all_touching_room_cells() -> void:
	var mass := BuildingMass.new()
	mass.decor.append({"kind":&"raker","from":Vector3(2,3.15,4),"to":Vector3(2,3.92,5)})
	var masses:Array[BuildingMass]=[mass]
	var contacts:Dictionary=preload("res://scripts/terrain/features/villages/kit/KitBracketBearings.gd").cells(masses)
	assert_eq(contacts.size(),4)
	for x in [1,2]:
		for z in [3,4]:assert_true(contacts.has(Vector3i(x,3,z)))

func test_remote_wing_can_step_down_without_moving_abutted_skywalk_door() -> void:
	for value in range(12):
		var mass := _mass(value)
		var edge := BuildingMass.edge_key(Vector2i(0,1),1)
		for floor: Dictionary in mass.storeys:
			floor["abutted"] = true
			floor["passage_edges"] = {edge:true}
			floor.openings[edge] = BuildingMass.OPENING_DOOR
		var protected := func(cell:Vector2i,_band:int)->bool:return cell.x < 2
		assert_true(Wings.shape(mass,protected,Callable()),
			"A remote wing may step down while the full bridge landing stays intact")
		for floor: Dictionary in mass.storeys:
			assert_eq(floor.openings[edge],BuildingMass.OPENING_DOOR)
			assert_true(floor.passage_edges.has(edge))
			for x in 2:
				for z in 3:
					assert_true(floor.cells.has(Vector2i(x,z)),"Retain the complete landing room")
		assert_lt(mass.storeys[-1].cells.size(),18)

func test_skywalk_host_in_finished_town_keeps_a_lower_corner_wing() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(8,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
	if spatial == null: return
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
	var found := false
	for mass:BuildingMass in built.houses:
		if mass.stable_id != &"kit.spatial.parcel.maze.house.014": continue
		found = true
		assert_true(mass.storeys.any(func(f:Dictionary)->bool:return f.get("stepped_wing",false)),
			"The addressed bridge house must retain a varied primary silhouette")
		assert_true(mass.roofs.any(func(r:Dictionary)->bool:return r.eave_band < mass.top_band()),
			"Its lower inhabited corner remains roofed")
		var passage_count := 0
		for floor:Dictionary in mass.storeys:
			for edge:Vector3i in floor.get("passage_edges",{}):
				passage_count += 1
				assert_true(floor.cells.has(Vector2i(edge.x,edge.y)))
				assert_eq(floor.openings[edge],BuildingMass.OPENING_DOOR)
		assert_gt(passage_count,0,"Retain a real skywalk doorway, not a different unconnected house")
	assert_true(found)
