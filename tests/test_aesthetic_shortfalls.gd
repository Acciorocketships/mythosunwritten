extends GutTest

func test_shortfalls_reported_not_rejected() -> void:
	var audit := {"max_spine_straight_run": WarrenMazeSourcePlan.MAX_SPINE_STRAIGHT_RUN + 2,
		"max_alley_straight_run": WarrenMazeSourcePlan.MAX_ALLEY_STRAIGHT_RUN}
	var out := WarrenMazeSourcePlan.aesthetic_shortfalls(audit, 0)
	assert_eq(out["loop_join"], {"limit": 1, "found": 0})
	assert_eq(out["spine_straight_run"], {"limit": WarrenMazeSourcePlan.MAX_SPINE_STRAIGHT_RUN,
		"found": WarrenMazeSourcePlan.MAX_SPINE_STRAIGHT_RUN + 2})
	assert_false(out.has("alley_straight_run"))

func test_clean_audit_has_no_shortfalls() -> void:
	assert_eq(WarrenMazeSourcePlan.aesthetic_shortfalls({"max_spine_straight_run": 1,
		"max_alley_straight_run": 1}, 2), {})

func test_sealed_town_carries_shortfall_record() -> void:
	var plan := WarrenMazeSitePlanner.plan(13, {}, WarrenVillageScaleProfile.for_id(&"standard"))
	assert_not_null(plan)
	assert_true(plan.audit.has("aesthetic_shortfalls"))
