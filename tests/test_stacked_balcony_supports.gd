extends GutTest
const Supports = preload("res://scripts/terrain/features/villages/kit/KitBalconySupports.gd")

func _fixture() -> Array[BuildingMass]:
	var low := BuildingMass.new()
	low.stable_id = &"kit.feature.balcony.lower"
	low.decks.append({"band":2,"cells":BuildingMass.rect_cells(Rect2i(0,0,1,2))})
	var high := BuildingMass.new()
	high.stable_id = &"kit.feature.balcony.upper"
	high.decks.append({"band":4,"cells":BuildingMass.rect_cells(Rect2i(1,0,1,2))})
	high.decor.append({"kind":&"raker","dir":0,"centre":Vector2(1,1),"from":Vector3(1,3.15,1),"to":Vector3(1.85,3.92,1)})
	return [low,high]

func test_shifted_balcony_uses_lower_deck_for_complete_triangle() -> void:
	var masses := _fixture()
	var grid := WarrenSpatialGrid.new(Vector3i(-3,0,-3),Vector3i(8,8,8))
	assert_eq(Supports.seat(masses,{},grid),1)
	assert_eq(masses[1].decor.size(),2)
	var brace: Dictionary = masses[1].decor[0]
	var post: Dictionary = masses[1].decor[1]
	assert_eq(brace.from,Vector3(1,2,1),"Brace lands on the lower balcony rim")
	assert_eq(brace.to,Vector3(1.85,3.92,1),"Keep the upper deck connection")
	assert_eq(post.from,brace.from)
	assert_eq(post.to,Vector3(1,3.92,1),"Post closes the triangle below the upper soffit")
	assert_eq(Supports.seat(masses,{},grid),0,"Repeated fitting adds no duplicate posts")
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var measured := 0
	for part: Dictionary in BuildingKitAssembler.new(kit).assemble(masses[1]):
		if part.role != &"post.timber" or not part.transform.basis.y.normalized().is_equal_approx(Vector3.UP): continue
		var bounds: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_almost_eq(bounds.position.y,2 * kit.band_height(),.001,"Native post starts on the lower deck")
		assert_almost_eq(bounds.end.y,3.92 * kit.band_height(),.001,"Native post stops below the upper deck")
		measured += 1
	assert_eq(measured,1)

func test_wall_borne_bracket_and_unavailable_lower_deck_are_unchanged() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-3,0,-3),Vector3i(8,8,8))
	var masses := _fixture()
	var houses := {&"host":{"storeys":{2:BuildingMass.rect_cells(Rect2i(0,0,1,2))}}}
	assert_eq(Supports.seat(masses,houses,grid),0)
	assert_eq(masses[1].decor.size(),1)
	masses[0].decks.clear()
	assert_eq(Supports.seat(masses,{},grid),0,"Never invent a ground-reaching pole")

func test_public_air_prevents_post_placement() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-3,0,-3),Vector3i(8,8,8))
	var tx := grid.begin_transaction(&"street")
	var cells: Array[Vector3i] = [Vector3i(1,2,1)]
	tx.assign_use(cells,WarrenSpatialGrid.Use.PUBLIC_AIR,&"street")
	assert_true(grid.commit_transaction(tx))
	assert_eq(Supports.seat(_fixture(),{},grid),0)

func test_finished_stacked_balconies_have_real_lower_deck_bearings() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var kit := SuntailBuildingKit.create()
	for seed_value in [63,103]:
		var spatial := WarrenVolumetricSolver.generate(seed_value,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial,fabric,kit)
		assert_gt(int(built.roof_audit.seated_balcony_brackets),0,"Exercise the shifted balcony stack")
		var upright := 0
		for mass: BuildingMass in built.masses:
			for part: Dictionary in mass.decor:
				if not part.get("deck_bearing",false): continue
				var foot: Vector3 = part.from
				var bearing := false
				for lower: BuildingMass in built.masses:
					if lower == mass: continue
					for deck: Dictionary in lower.decks:
						if is_equal_approx(float(deck.band),foot.y) and Supports._touches_cells(deck.cells,Vector2(foot.x,foot.z)): bearing=true
				assert_true(bearing,"Every new member meets another balcony's real deck")
				assert_lte((part.to as Vector3).y-foot.y,2.01,"No ground-reaching poles")
				if is_equal_approx(foot.x,part.to.x) and is_equal_approx(foot.z,part.to.z): upright+=1
		assert_eq(upright,int(built.roof_audit.seated_balcony_brackets),"One upright closes each triangle")
		assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0)
		assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,kit).intrusions),0)
