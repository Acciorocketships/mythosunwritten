extends GutTest
## October 8: a town must never be lost to one room whose setback shoulder no
## roof can close. Seed 1/grand (taste defaults) and seed 141 (production size)
## both died at "macro setback roof ... and its complete fallbacks were
## rejected". The roof gate now withdraws that room's storey (and what stands
## on it) and the town composes again.

var _program: SettlementFabricProgram


func before_all() -> void:
	_program = SettlementFabricProgram.compile(EnvironmentCatalog.load_default())


func _assert_builds(seed_value: int, profile: WarrenVillageScaleProfile) -> WarrenSpatialPlan:
	var plan := WarrenVolumetricSolver.generate(seed_value, {}, _program, profile)
	assert_not_null(plan, "%d/%s: %s" % [seed_value, profile.scale_id,
		WarrenVolumetricSolver.last_failure])
	if plan != null:
		assert_true(plan.is_sealed(), "%d sealed" % seed_value)
		assert_not_null(plan.compiled_fabric_cache(), "%d fabric" % seed_value)
	return plan


func test_seed_1_grand_builds() -> void:
	var plan := _assert_builds(1, WarrenVillageScaleProfile.for_id(&"grand"))
	if plan != null:
		assert_gt((plan.audit.get("roof_withdrawn_room_ids", []) as Array).size(), 0,
			"the unroofable wall-room storey was withdrawn, not the town")


func test_seed_141_builds() -> void:
	_assert_builds(141, WarrenVillageScaleProfile.select(141))
