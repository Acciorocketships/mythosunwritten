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

func test_source_shortfalls_reach_advisory_list() -> void:
	WarrenVolumetricSolver.last_advisory_shortfalls = {}
	WarrenVolumetricSolver._forward_aesthetic_shortfalls({
		"loop_join": {"limit": 1, "found": 0}})
	assert_eq(WarrenVolumetricSolver.last_advisory_shortfalls["loop_join"],
		{"limit": 1, "found": 0})
	WarrenVolumetricSolver.last_advisory_shortfalls = {}

func test_source_audit_has_record_without_diagnostics() -> void:
	# Production path: collect_diagnostics off still records shortfalls.
	var plan := WarrenMazeSitePlanner.plan(13, {},
		WarrenVillageScaleProfile.for_id(&"standard"), &"", false)
	assert_not_null(plan)
	assert_true(plan.audit.has("aesthetic_shortfalls"))
