extends GutTest
const TURRET := preload("res://scripts/terrain/features/villages/kit/KitRoofTurrets.gd")
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
const AUDIT := preload("res://tests/fixtures/kit_roof_audit.gd")

func _host(value:int) -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id=&"kit.fixture"
	mass.seed=value
	for band in [0,2,4]: mass.add_storey(band,BuildingMass.rect_cells(Rect2i(0,0,4,2)),BuildingMass.MATERIAL_TIMBER)
	mass.add_roof(Rect2i(0,0,4,2),0,6,&"blue")
	return mass

func test_native_courses_emerge_through_roof_and_need_a_whole_room() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var count := 0
	for kit: BuildingKit in [SuntailBuildingKit.create(),preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()]:
		for value in 24:
			var host := _host(value)
			var before := host.storeys.duplicate(true)
			var candidate := TURRET.propose(host,kit,catalog,[],[],[],Callable())
			assert_eq(host.storeys,before)
			if candidate.is_empty():continue
			count+=1
			assert_eq(candidate.form,TOWER.Form.ROUND)
			assert_eq(candidate.parts[0].asset_id,&"pure_village.roof_turret.middle")
			assert_eq(candidate.pose.origin.y,6.0,"The shaft starts on the upper room's floor, not on a roof skin")
			assert_eq(candidate.parts,TURRET.propose(host,kit,catalog,[],[],[],Callable()).parts)
			assert_eq(candidate.pose,TURRET.propose(host,kit,catalog,[],[],[],Callable()).pose)
			var diverted := TURRET.propose(host,kit,catalog,[{"bounds":candidate.bounds}],[],[],Callable())
			if not diverted.is_empty(): assert_false((diverted.bounds as AABB).intersects(candidate.bounds),"Another end may fit, but no native piece may enter the blocked headroom")
			assert_true(TURRET.propose(host,kit,catalog,[],[],[],func(_c:Vector2i,_b:int)->bool:return true).is_empty())
			var other: Array[Dictionary]=[{"host":&"kit.other","role":&"wall","bounds":candidate.bounds}]
			# Block the whole host, not only its first candidate; neither end can fit.
			other[0].bounds=AABB(Vector3(-5,0,-5),Vector3(30,40,30))
			assert_true(TURRET.propose(host,kit,catalog,[],other,[],Callable()).is_empty())
			host.storeys[-1].cells.clear()
			assert_true(TURRET.propose(host,kit,catalog,[],[],[],Callable()).is_empty(),"No tower over missing rooms / loggias")
	assert_gt(count,4)
	assert_lt(count,48,"Seeded occurrence remains optional")

func test_hidden_cutters_require_present_native_shaft_courses() -> void:
	var candidate := {"parts":TURRET.parts(2),"pose":Transform3D.IDENTITY}
	var cuts := TURRET.cutters(candidate)
	assert_gt(cuts.size(),0)
	for cut: Dictionary in cuts:
		assert_lt((cut.bounds as AABB).end.y,6.0,"Never cut into the window / cap")
		assert_lt((cut.bounds as AABB).size.x,1.75,"Only the hidden shaft interior is removed")
	candidate.parts=candidate.parts.filter(func(p:Dictionary)->bool:return p.asset_id!=&"pure_village.roof_turret.middle")
	assert_true(TURRET.cutters(candidate).is_empty(),"Missing native stone cannot excuse a roof hole")

func test_generated_corner_turrets_replace_roof_emergent_fallback() -> void:
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var narrow := 0
	var lower_wings := 0
	for value in [13,43]:
		var spatial := WarrenVolumetricSolver.generate(value,{},program,WarrenVillageScaleProfile.for_id(&"large" if value == 13 else &"grand"))
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial,fabric,kit)
		assert_true(built.payload.validate())
		assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0)
		assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,kit).intrusions),0)
		assert_eq(int(AUDIT.audit(built,kit).uncapped_towers),0)
		var changed := 0
		for tower:Dictionary in built.towers:
			assert_ne(tower.attachment,&"roof","Owner correction: no roof-emergent fallback")
			if tower.attachment!=&"corner":continue
			narrow+=1
			if int(tower.storeys)==1:lower_wings+=1
			changed+=1
			for wall:Dictionary in built.walls:
				if wall.get("open",false):assert_false(tower.bounds.intersects(wall.bounds))
			for index in tower.parts.size():
				var part:Dictionary=tower.parts[index]
				var batch:Dictionary=built.payload.batches[part.asset_id]
				var at:int=batch.ids.find(StringName("%s/tower.%d"%[tower.host.stable_id,index]))
				assert_gte(at,0)
				if at>=0:assert_true(batch.collision_enabled[at])
			tower.parts=tower.parts.filter(func(p:Dictionary)->bool:return p.role!=&"tower.roof")
		assert_eq(int(AUDIT.audit(built,kit).uncapped_towers),changed,"Removing each actual cap must fail the audit")
	assert_gt(narrow,0,"Native corner turrets must reach finished production towns")
	assert_gt(lower_wings,0,"Short grounded corner shafts must reach real lower wings")
