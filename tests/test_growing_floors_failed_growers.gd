extends GutTest
## A house that rolls growth but keeps no step must be built exactly like a house
## that never rolled: its kit jetty and porch awnings stay (Task 11 fix round 1).
## 31:large at the shipped defaults: house.000 rolls growth, every step withdraws
## (`air`), and no other face in the town steps, so the whole kit payload must match
## the town built with growing_house_chance = 0.


func _built(overrides: Dictionary) -> Dictionary:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	if not overrides.is_empty():
		program.town_odds = program.town_odds.with_overrides(overrides)
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	var spatial := WarrenVolumetricSolver.generate(31, {}, program, profile)
	assert_not_null(spatial)
	return KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create())


func _awnings(built: Dictionary) -> int:
	var count := 0
	for mass: BuildingMass in built.houses:
		for item: Dictionary in mass.decor:
			if StringName(item.kind) == &"awning":
				count += 1
	return count


func test_a_grower_that_keeps_no_step_is_built_like_a_house_that_never_grew() -> void:
	var plain := _built({&"growing_house_chance": 0.0})
	var shipped := _built({})
	assert_eq((shipped.growth as Array).size(), 0, "31:large steps no face at the shipped defaults")
	assert_true((shipped.get("growth_withheld", {}) as Dictionary).has(&"kit.spatial.parcel.maze.house.000"),
		"house.000 rolled growth, kept no step and was rebuilt as a plain house")
	assert_eq(_awnings(shipped), _awnings(plain), "no porch awning lost")
	for mass: BuildingMass in shipped.houses:
		assert_false(mass.grows, "%s keeps no step, so it is not a growing house" % mass.stable_id)
	assert_true(var_to_bytes(shipped.payload.batches) == var_to_bytes(plain.payload.batches),
		"identical kit payload")
