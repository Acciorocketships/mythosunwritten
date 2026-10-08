extends GutTest
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const KNOBS: Array[StringName] = [&"growing_house_chance", &"growth_street_face_chance",
	&"growth_other_face_chance", &"growth_step", &"growth_max_lean", &"lane_sky_gap",
	&"growth_gable_front_boost"]


func test_growth_knobs_are_in_the_table_with_their_shipped_values() -> void:
	var program := TownOddsProgram.builtin()
	assert_eq(program.errors.size(), 0, str(program.errors))
	for name: StringName in KNOBS:
		assert_true(program.knobs.has(name), String(name))
	for size: float in [0.0, 1.0]:
		var c := TownCharacter.draw(program, 53, size)
		assert_eq(c.value(GROWTH.HOUSE_KNOB), 0.0)
		assert_almost_eq(c.value(GROWTH.STREET_FACE_KNOB), 0.85, 1e-6)
		assert_eq(c.weights(GROWTH.STEP_KNOB).keys(), [&"0.5", &"1.0"])
		assert_gt(float(c.weights(GROWTH.STEP_KNOB)[&"1.0"]), float(c.weights(GROWTH.STEP_KNOB)[&"0.5"]),
			"the kit jetty is the usual step")
		assert_almost_eq(c.value(GROWTH.OTHER_FACE_KNOB), 0.85, 1e-6)
		assert_almost_eq(c.value(GROWTH.OTHER_FACE_KNOB), c.value(GROWTH.STREET_FACE_KNOB), 1e-6,
			"every exposed face is treated alike")
		assert_almost_eq(c.value(GROWTH.CAP_KNOB), 2.0, 1e-6)
		assert_almost_eq(c.value(GROWTH.GAP_KNOB), 0.75, 1e-6)
		assert_almost_eq(c.value(GROWTH.BOOST_KNOB), 2.0, 1e-6)


func test_eligible_house_needs_two_stacked_storeys_and_an_exposed_face() -> void:
	var street := Callable(FIXTURE, "street")
	var none := Callable(FIXTURE, "nothing_solid")
	assert_true(GROWTH.house_eligible(FIXTURE.house(&"kit.a", Rect2i(0, 0, 3, 2), 3, 3), none, street))
	assert_true(GROWTH.house_eligible(FIXTURE.house(&"kit.b", Rect2i(0, 0, 3, 2), 2, 3), none, street),
		"one storey above the ground can grow")
	assert_false(GROWTH.house_eligible(FIXTURE.house(&"kit.d", Rect2i(0, 0, 3, 2), 1, 3), none, street),
		"a ground-only house cannot grow")
	assert_true(GROWTH.house_eligible(FIXTURE.house(&"kit.c", Rect2i(0, 2, 3, 2), 3, 3), none, street),
		"any exposed face counts, not only street faces")
	var walled := func(_own: StringName, cell: Vector2i, _band: int) -> bool:
		return not Rect2i(0, 2, 3, 2).has_point(cell)
	assert_false(GROWTH.house_eligible(FIXTURE.house(&"kit.e", Rect2i(0, 2, 3, 2), 3, 3), walled, street),
		"a house touching other buildings on every face has nothing to step out")


func test_house_roll_is_keyed_by_house_and_untouched_by_other_growth_knobs() -> void:
	var a := TownCharacter.draw(TownOddsProgram.builtin().with_overrides(
		{&"growing_house_chance": 0.4}), 9, 0.5)
	var b := TownCharacter.draw(TownOddsProgram.builtin().with_overrides(
		{&"growing_house_chance": 0.4, &"growth_max_lean": 1.5, &"lane_sky_gap": 1.2,
		&"growth_street_face_chance": 0.1}), 9, 0.5)
	var grown := 0
	for i in 300:
		var key := "kit.house.%03d" % i
		assert_eq(a.chance(GROWTH.HOUSE_KNOB, key), b.chance(GROWTH.HOUSE_KNOB, key), key)
		assert_eq(a.pick(GROWTH.STEP_KNOB, key), b.pick(GROWTH.STEP_KNOB, key), key)
		if a.chance(GROWTH.HOUSE_KNOB, key):
			grown += 1
	assert_between(grown, 90, 150)


func test_zero_chance_never_grows_and_one_always_does() -> void:
	var street := Callable(FIXTURE, "street")
	var none := Callable(FIXTURE, "nothing_solid")
	var mass := FIXTURE.house(&"kit.a", Rect2i(0, 0, 3, 2), 4, 3)
	var off := TownCharacter.draw(TownOddsProgram.builtin().with_overrides(
		{&"growing_house_chance": 0.0}), 3, 0.5)
	var on := TownCharacter.draw(TownOddsProgram.builtin().with_overrides(
		{&"growing_house_chance": 1.0}), 3, 0.5)
	assert_false(GROWTH.house_grows(off, mass, none, street))
	assert_true(GROWTH.house_grows(on, mass, none, street))
	assert_false(GROWTH.house_grows(null, mass, none, street))


func test_build_marks_houses_growing_only_when_the_chance_is_positive() -> void:
	for chance: float in [0.0, 1.0]:
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		program.town_odds = program.town_odds.with_overrides({&"growing_house_chance": chance})
		var growing := 0
		for town: String in ["7:compact", "103:standard"]:
			var parts := town.split(":")
			var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program,
				WarrenVillageScaleProfile.for_id(StringName(parts[1])))
			assert_not_null(spatial, town)
			var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(),
				SuntailBuildingKit.create())
			growing += (built.houses as Array).filter(func(m: BuildingMass) -> bool: return m.grows).size()
		if chance == 0.0:
			assert_eq(growing, 0)
		else:
			assert_gt(growing, 0, "the two towns have eligible street houses")


func test_a_kit_without_the_jetty_brace_steps_half_a_jetty() -> void:
	var kit := SuntailBuildingKit.create()
	assert_eq(GROWTH.carried_step(kit, 1.0), 1.0, "Suntail carries a 1.0 step on bracket.jetty")
	assert_eq(GROWTH.carried_step(kit, 0.5), 0.5)
	kit.jetty_depth = 0.0
	assert_eq(GROWTH.carried_step(kit, 1.0), 0.5, "no matching jetty brace: the light step")
