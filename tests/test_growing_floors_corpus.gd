extends GutTest
const AUDIT := preload("res://tests/fixtures/growth_audit.gd")


func test_growth_on_builds_clean_towns() -> void:
	# 7:compact and 103:standard (the brief's towns) grow no face under step-in (Task 9
	# corpus: 0 each), which made this test vacuous; 83:grand (10 faces: wraps, buried
	# ends, plinth caps) and 61:standard (an abut end, a recessed door) step.
	var total := 0
	for town: String in ["83:grand", "61:standard"]:
		var parts := town.split(":")
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		program.town_odds = program.town_odds.with_overrides({&"growing_house_chance": 1.0,
			&"growth_street_face_chance": 1.0, &"growth_other_face_chance": 1.0})
		var profile := WarrenVillageScaleProfile.for_id(StringName(parts[1]))
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program, profile)
		assert_not_null(spatial, town)
		if spatial == null:
			continue
		var fabric := spatial.compiled_fabric_cache()
		var kit := SuntailBuildingKit.create()
		var built := KitVillageBuildings.build(spatial, fabric, kit)
		assert_true(built.payload.validate(), town)
		var row := AUDIT.audit(spatial, fabric, built, kit, profile.character)
		total += int(row.faces)
		for key: String in AUDIT.VIOLATIONS:
			assert_eq(int(row[key]), 0, "%s %s" % [town, key])
	assert_gt(total, 0, "growth on steps at least one face")
