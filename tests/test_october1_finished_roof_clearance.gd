extends GutTest
const AIR := preload("res://tests/fixtures/kit_roof_public_air_audit.gd")
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")

func test_mixed_roof_skins_and_trims_clear_finished_public_air() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var kit := SuntailBuildingKit.create()
	var raw_intrusions := 0
	# Central greens redistribute houses and streets; fortified tiers add
	# covered passages. Include both in the final-triangle clearance corpus.
	for job: Array in [[7,&"compact"],[13,&"large"],[17,&"large"],
			[24,&"large"],[58,&"large"],[0,&"photo_fixture"]]:
		# Keep a known intersecting source even when procedural layouts change.
		var spatial := FROZEN.spatial(FROZEN.read(
			"res://tests/fixtures/october1-photo-roofs-source.txt"), program) \
			if job[1] == &"photo_fixture" else WarrenVolumetricSolver.generate(
				job[0],{},program,WarrenVillageScaleProfile.for_id(job[1]))
		assert_not_null(spatial)
		if spatial == null: continue
		var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
		var raw := AIR.audit(built,kit,false)
		raw_intrusions += int(raw.intrusions)
		var finished := AIR.audit(built,kit)
		print("ROOF_AIR ",job," raw=",raw," finished=",finished)
		assert_gt(int(finished.triangles),1000)
		assert_eq(int(finished.intrusions),0,"%s: %s" % [job,finished])
	assert_gt(raw_intrusions,0,"the corpus includes roof triangles requiring clearance cuts")
