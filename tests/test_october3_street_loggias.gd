extends GutTest

func test_recesses_face_street_air_without_occupying_it() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-2,0,-2),Vector3i(11,10,8))
	var transaction := grid.begin_transaction(&"street")
	var air: Array[Vector3i] = []
	for y in range(2,10):
		for x in range(-1,8):
			for z in range(-1,5):
				if x<0 or x>=7 or z<0 or z>=4: air.append(Vector3i(x,y,z))
	transaction.assign_use(air,WarrenSpatialGrid.Use.PUBLIC_AIR,&"street.air")
	assert_true(grid.commit_transaction(transaction))
	var house := {"storeys":{},"cells":[],"doors":[],"terrain_band":0}
	var original := BuildingMass.rect_cells(Rect2i(0,0,7,4))
	for band in [0,2,4,6]: house.storeys[band]=original.duplicate()
	var mass := KitVillageBuildings._mass_for(&"street.house",house,grid,{},11,SuntailBuildingKit.create())
	var recesses := 0
	var covered := 0
	for floor: Dictionary in mass.storeys:
		if floor.get("loggia",false): recesses+=1
		for cell: Vector2i in floor.cells: assert_true(original.has(cell))
	for deck: Dictionary in mass.decks:
		if deck.band>=mass.top_band(): continue
		for cell: Vector2i in deck.cells:
			assert_true(original.has(cell),"The balcony withdraws inside the existing room envelope")
			assert_true(mass.cells_at_band(deck.band-1).has(cell),"A real lower room bears its floor")
			covered+=int(mass.cells_at_band(deck.band+2).has(cell))
	assert_gte(recesses,2,"Street-facing buildings need depth at several levels")
	assert_gt(covered,0,"An upper room overhangs the recessed balcony")

func test_narrow_house_keeps_a_complete_crown_over_its_lower_loggia() -> void:
	var mass := BuildingMass.new()
	mass.seed=31
	var crown := BuildingMass.rect_cells(Rect2i(0,0,4,2))
	for band in [0,2,4,6]: mass.add_storey(band,crown,BuildingMass.MATERIAL_TIMBER)
	preload("res://scripts/terrain/features/villages/kit/KitLoggias.gd").recess(mass,Callable(),Callable())
	assert_eq(mass.storeys[-1].cells,crown,"Do not turn a compact crown into skinny roof strips")
	assert_true(mass.storeys[1].get("loggia",false),"Keep the covered recess on a lower level")
	for cell: Vector2i in crown:
		if mass.storeys[1].cells.has(cell): continue
		assert_true(mass.cells_at_band(4).has(cell),"The whole upper room remains an overhang")

