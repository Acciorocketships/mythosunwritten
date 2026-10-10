extends GutTest
const TOWERS := preload("res://scripts/terrain/features/villages/kit/KitTownTowers.gd")
const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")

func _host(seed_value: int) -> BuildingMass:
	var host := BuildingMass.new()
	host.stable_id = &"kit.host"
	host.seed = seed_value
	for band in [0,2,4]:
		host.add_storey(band,BuildingMass.rect_cells(Rect2i(0,0,4,4)),BuildingMass.MATERIAL_TIMBER)
	host.add_roof(Rect2i(0,0,4,4),0,6,&"red")
	return host

func test_seeded_tower_proposals_are_read_only_and_respect_complete_obstacles() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var count := 0
	for kit: BuildingKit in [SuntailBuildingKit.create(),PURE.roof_study()]:
		for seed_value in 12:
			var host := _host(seed_value)
			var before := host.storeys.duplicate(true)
			var before_roofs := host.roofs.duplicate(true)
			var candidates := TOWERS.propose([host],{&"host":kit},kit,catalog,[],Callable())
			assert_eq(host.storeys,before)
			assert_eq(host.roofs,before_roofs)
			if candidates.is_empty(): continue
			count += 1
			assert_eq(candidates.size(),1)
			var again := TOWERS.propose([host],{&"host":kit},kit,catalog,[],Callable())
			assert_eq(candidates[0].pose,again[0].pose)
			assert_eq(candidates[0].parts,again[0].parts)
			assert_true(TOWERS.propose([host],{&"host":kit},kit,catalog,[],
				func(_own:StringName,_cell:Vector2i,_band:int)->bool:return true).is_empty(),
				"Private/structural reservations remain authoritative.")
			var all_air: Array[Dictionary] = [{"bounds":AABB(Vector3(-30,-5,-30),Vector3(70,40,70))}]
			assert_true(TOWERS.propose([host],{&"host":kit},kit,catalog,all_air,Callable()).is_empty(),
				"Finished public headroom blocks the whole cap and corbel.")
	assert_gt(count,8,"This exercises both kit families and many admitted candidates.")
	assert_lt(count,24,"Towers remain a seeded choice.")

func test_production_towers_emit_collision_and_do_not_enter_walking_air() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var accepted := 0
	for seed_value in [12,13]:
		var spatial := WarrenVolumetricSolver.generate(seed_value,{},program,WarrenVillageScaleProfile.for_id(&"large"))
		var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
		accepted += built.towers.size()
		for tower: Dictionary in built.towers:
			assert_gte(int(tower.storeys),2,"Use a backed shaft, never the rejected one-course attic fallback")
			for wall: Dictionary in built.walls:
				if wall.get("open",false): assert_false(tower.bounds.intersects(wall.bounds))
			for index in tower.parts.size():
				var id := StringName("%s/tower.%d" % [tower.host.stable_id,index])
				var batch: Dictionary = built.payload.batches.get(tower.parts[index].asset_id,{})
				assert_false(batch.is_empty())
				if batch.is_empty(): continue
				var at: int = batch.ids.find(id)
				assert_gte(at,0,"Every admitted native course and cap is emitted.")
				if at >= 0: assert_true(batch.collision_enabled[at])
	assert_gt(accepted,0,"Full shafts must reach the production emitter across these towns")

func test_broad_gable_can_place_turret_beside_a_central_door() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var accepted := 0
	for seed_value in range(8):
		var host := _host(seed_value)
		# Both centred proposals cover an actual doorway. An off-centre
		# attachment may fit, but the generator must never close those doors.
		for floor: Dictionary in host.storeys:
			floor.openings[Vector3i(3,1,0)] = BuildingMass.OPENING_DOOR
			floor.openings[Vector3i(0,1,2)] = BuildingMass.OPENING_DOOR
		var before := host.storeys.duplicate(true)
		var towers := TOWERS.propose([host],{&"host":kit},kit,catalog,[],Callable())
		assert_eq(host.storeys,before)
		if towers.is_empty(): continue
		accepted += 1
		assert_false(is_equal_approx(towers[0].pose.origin.z,4.0),"The centre is blocked by the door.")
		for opening: Dictionary in towers[0].host_plan.openings:
			assert_ne(host.storeys[opening.storey].openings.get(opening.edge),BuildingMass.OPENING_DOOR)
	assert_gt(accepted,0,"Use the free part of the gable instead of discarding every turret.")

func test_tower_never_degrades_to_a_tacked_on_single_course() -> void:
	# Owner rejected the October 2 one-course fallback. Keep the jetty and
	# omit the tower if its full shaft cannot be backed by the house.
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	for seed_value in range(8):
		var host := _host(seed_value)
		host.storeys[0].inset = true
		host.storeys[1].inset = true
		var before := host.storeys.duplicate(true)
		var towers := TOWERS.propose([host],{&"host":kit},kit,catalog,[],Callable())
		assert_eq(host.storeys,before,"Preserve the existing overhang.")
		for tower: Dictionary in towers:
			assert_eq(tower.attachment,&"roof","A flush attic alone cannot carry a side attachment; a complete shaft borne inside a room remains valid.")


func test_gable_audit_requires_the_native_cap_closing_its_cutout() -> void:
	const AUDIT = preload("res://tests/fixtures/kit_roof_audit.gd")
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	# Keep this mutation on an actual generated shaft. The former 43/grand
	# opportunity disappeared with the native-building reservations.
	var source := WarrenMazeSitePlanner.plan(53, {},
		WarrenVillageScaleProfile.for_id(&"grand"), &"", false)
	var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source, program)
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
	assert_gt(built.towers.size(), 0)
	assert_eq(int(AUDIT.audit(built, kit).gable_holes), 0,
		"The authored cap closes the trimmed gable inside its measured skin.")
	for tower: Dictionary in built.towers:
		tower.parts = tower.parts.filter(func(part: Dictionary) -> bool:
			return part.role != &"tower.roof")
	assert_gt(int(AUDIT.audit(built, kit).uncapped_towers), 0,
		"A missing tower cap fails even when its taller host gable stays closed.")

func test_eave_cap_covers_its_roof_cut_in_a_generated_town() -> void:
	const AUDIT := preload("res://tests/fixtures/kit_roof_audit.gd")
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(43,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
	assert_gt(built.towers.size(),0)
	var eave_towers: Array = built.towers.filter(func(t: Dictionary)->bool:return t.attachment==&"eave")
	assert_gt(eave_towers.size(),0,"Exercise the new side-of-roof junction")
	for tower: Dictionary in eave_towers:
		assert_eq(tower.form,preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd").Form.GROUNDED_HALF,"Eave attachments need a grounded base, not the rejected hanging cylinder")
	var before := AUDIT.audit(built,kit)
	assert_eq(int(before.gable_holes),0)
	# This town has unrelated pre-existing eave cuts; mutation must expose
	# additional cuts at the actual tower instead of exempting the host.
	var covered_cut_count := int(before.eaves_cut)
	for tower: Dictionary in eave_towers:
		tower.parts = tower.parts.filter(func(part: Dictionary)->bool:return part.role != &"tower.roof")
	var after := AUDIT.audit(built,kit)
	assert_gt(int(after.eaves_cut),covered_cut_count,"Removing the real cap exposes additional eave cuts; do not blanket-exempt tower hosts")
	assert_gt(int(after.uncapped_towers),0)
