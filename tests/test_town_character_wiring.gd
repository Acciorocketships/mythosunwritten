extends GutTest

func test_generate_attaches_character_for_its_seed() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	var spatial := WarrenVolumetricSolver.generate(103, {}, program, profile)
	assert_not_null(spatial)
	assert_not_null(profile.character)
	assert_eq(profile.character.town_seed, 103)
	assert_eq(profile.character.values, TownCharacter.draw(program.town_odds, 103, profile.size).values)

func test_profile_reuse_redraws_per_seed() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var first := TownCharacter.of(profile, 1)
	var second := TownCharacter.of(profile, 2)
	assert_eq(first.town_seed, 1)
	assert_eq(second.town_seed, 2)
	assert_eq(profile.character, second)

func test_direct_planner_call_draws_builtin_character() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"standard")
	var plan := WarrenMazeSitePlanner.plan(13, {}, profile)
	assert_not_null(plan)
	assert_eq(TownCharacter.of(profile, 13).values,
		TownCharacter.draw(TownOddsProgram.builtin(), 13, profile.size).values)

func test_signature_unchanged_without_overrides() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	var before := profile.deterministic_signature()
	TownCharacter.attach(profile, TownOddsProgram.builtin(), 5)
	assert_eq(profile.deterministic_signature(), before)
