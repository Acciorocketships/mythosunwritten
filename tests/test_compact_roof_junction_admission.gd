extends GutTest
const PLAN = preload("res://scripts/terrain/features/villages/fabric/FabricCompactRoofJunctionPlan.gd")

func proposal(id: StringName, kind: StringName, origin: Vector3i, yaw: int) -> Dictionary:
	return {"stable_id":id,"kind":kind,"origin":origin,"yaw_quarters":yaw,"storeys":1}

func arrangement(eave: int, end: int, yaw: int) -> Array[Dictionary]:
	return [proposal(&"host",&"slim",Vector3i.ZERO,yaw),
		proposal(&"branch",&"tower",FabricRecipe.transform_direction(Vector3i(eave*2,0,end),yaw),yaw)]

func test_both_hands_and_ends_rotate_without_seed_or_name_rules() -> void:
	for yaw in 4:
		for eave in [-1,1]:
			for end in [-1,1]:
				var result := PLAN.build(arrangement(eave,end,yaw))
				assert_eq(result.size(),1,"One complete offset junction in orientation %s" % [Vector3i(yaw,eave,end)])
				if result.size()!=1: continue
				assert_eq(result[0].eave_sign,eave)
				assert_eq(result[0].end_sign,end)
				assert_eq(result[0].host_yaw,yaw)
				assert_eq(result[0].host_id,&"host")
				assert_eq(result[0].branch_id,&"branch")

func test_unprepared_crossings_do_not_acquire_a_compact_valley() -> void:
	var items := arrangement(1,1,0)
	items[1].origin.y=1
	assert_true(PLAN.build(items).is_empty(),"Different roof datums remain a stepped joint")
	items=arrangement(1,1,0)
	items[1].kind=&"slim"
	assert_true(PLAN.build(items).is_empty(),"A wide branch is outside this native section vocabulary")
	items=arrangement(1,1,0)
	items[1]["partial_plate"]=true
	assert_true(PLAN.build(items).is_empty(),"A partial plate cannot stand in for a complete branch")
	items=arrangement(1,1,0)
	items.append(proposal(&"continuation",&"slim",Vector3i(0,0,4),0))
	assert_true(PLAN.build(items).is_empty(),"The prepared end junction cannot cut an interior host repeat")
	items=arrangement(1,1,0)
	items.append(proposal(&"second_branch",&"tower",Vector3i(2,0,-1),0))
	assert_true(PLAN.build(items).is_empty(),"Two branch reservations cannot consume one host")

func test_unrelated_order_and_identity_do_not_change_the_owned_pair() -> void:
	var items := arrangement(-1,-1,2)
	items[0].stable_id=&"other_house"
	items[1].stable_id=&"other_annex"
	items.append(proposal(&"remote",&"tower",Vector3i(30,0,30),0))
	var forward := PLAN.build(items)
	items.reverse()
	assert_eq(PLAN.build(items),forward)
	assert_eq(forward.size(),1)

func test_prepared_branches_keep_native_datums_instead_of_recentering_cut_bounds() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for theme: StringName in [&"blue",&"orange"]:
		for eave in [-1,1]:
			for end in [-1,1]:
				var recipe := program.recipe(SettlementFabricProgram.compact_valley_recipe_id(&"branch",theme,eave,end))
				assert_true(SettlementFabricPlan._pitched_roof_alignment_holds(recipe))
				var pose: Transform3D=recipe.placements[0].transform
				recipe.placements[0].transform.origin.x+=.2
				assert_false(PLAN.branch_alignment_holds(recipe),"Shifting a prepared section cannot acquire valid bearing")
				recipe.placements[0].transform=pose
				var centre: Vector3=recipe.compact_roof_junction.centre
				recipe.compact_roof_junction.centre+=Vector3(.2,0,0)
				assert_false(PLAN.branch_alignment_holds(recipe),"Moving the declared datum cannot hide an offset")
				recipe.compact_roof_junction.centre=centre

func test_all_prepared_hosts_and_chimneys_reject_displaced_stock() -> void:
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for theme: StringName in [&"blue",&"orange"]:
		for eave in [-1,1]:
			for end in [-1,1]:
				var host:=program.recipe(SettlementFabricProgram.compact_valley_recipe_id(&"host",theme,eave,end))
				assert_true(PLAN.alignment_holds(host),String(host.recipe_id))
				for index in host.placements.size():
					var pose: Transform3D=host.placements[index].transform
					host.placements[index].transform.origin.z+=.1
					assert_false(PLAN.alignment_holds(host),"Every native host section owns its fixed datum")
					host.placements[index].transform=pose
					if ".valley." in String(host.placements[index].asset_id):
						host.placements[index].transform.origin.y+=.1
						assert_false(PLAN.alignment_holds(host),"Trimmed stock cannot be lifted from its original bearing datum")
						host.placements[index].transform=pose
				for yaw in 4:
					var branch:=program.recipe(SettlementFabricProgram.compact_valley_recipe_id(&"branch",theme,eave,end,yaw))
					assert_true(PLAN.alignment_holds(branch))
					var pose: Transform3D=branch.placements[1].transform
					branch.placements[1].transform.origin.y+=.1
					assert_false(PLAN.alignment_holds(branch),"The chimney cannot float off its original datum")
					branch.placements[1].transform=pose
