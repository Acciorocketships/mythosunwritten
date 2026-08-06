extends GutTest

const CaptureHarness = preload("res://tests/harness/village_capture.gd")
const VisualHarness = preload("res://tests/harness/village_visual_corpus.gd")


func test_camera_fallbacks_are_bounded_and_preserve_the_authored_view_first() -> void:
	var authored := Vector3(30.0, 4.0, -20.0)
	var target := Vector3(5.0, 2.0, 7.0)
	var candidates: Array[Vector3] = CaptureHarness._camera_candidates(
		authored, target)
	assert_eq(candidates[0], authored)
	assert_eq(candidates.size(), 16)
	for candidate: Vector3 in candidates:
		var horizontal_shift := Vector2(candidate.x - authored.x,
			candidate.z - authored.z).length()
		assert_lte(horizontal_shift, 3.001,
			"verification may clear a local obstruction but never invent a distant angle")
		assert_gte(candidate.y, authored.y)
		assert_lte(candidate.y - authored.y, 6.001)


func test_authored_sightline_rejects_unrelated_buildings_by_footprint() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := VillageProgram.compile({}, catalog)
	assert_not_null(program)
	var subject := {
		"asset_id": "sfv.building.interior.blue.001",
		"stable_id": "subject",
		"origin": [0.0, 0.0, 0.0],
		"yaw": 0.0,
	}
	var obstruction := {
		"asset_id": "sfv.building.interior.blue.001",
		"stable_id": "obstruction",
		"origin": [-15.0, 0.0, 0.0],
		"yaw": 0.0,
	}
	var position := Vector3(-30.0, 4.0, 0.0)
	var target := Vector3.ZERO
	assert_eq(VisualHarness._building_sightline_penalty(position, target,
		[subject], subject, program), 0.0)
	assert_gte(VisualHarness._building_sightline_penalty(position, target,
		[subject, obstruction], subject, program), 10000.0,
		"an unrelated solid may not occupy the authored review sightline")
	assert_gte(VisualHarness._building_sightline_penalty(
		Vector3(-15.0, 4.0, 0.0), target,
		[subject, obstruction], subject, program), 100000.0,
		"the camera itself may never be authored inside another structure")


func test_elevated_camera_orbits_away_from_roofs_before_capture() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var frame := _flat_frame()
	var obstruction := {
		"asset_id": "sfv.building.interior.blue.001",
		"stable_id": "obstruction",
		"origin": [0.0, 0.0, 0.0],
		"yaw": 0.0,
	}
	var target := Vector3(20.0, 5.0, 0.0)
	var preferred := Vector3(0.0, 14.0, 0.0)
	var resolved := VisualHarness._safe_elevated_camera(frame,
		preferred, target,
		[obstruction], program)
	assert_ne(resolved, preferred,
		"a camera projected through a roof must be re-authored, not patched later")
	assert_true(VisualHarness._elevated_sightline_clear(frame,
		resolved, target,
		[obstruction], program),
		"the selected orbit keeps both camera and named sightline clear")


func test_elevated_camera_orbits_away_from_support_and_rock_volumes() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var frame := _flat_frame()
	var support := VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
		Vector2(-15.0, 0.0), Vector2(2.0, 2.0), 0.0,
		0.0, 24.0, &"support", &"support_owner")
	var target := Vector3.ZERO
	var preferred := Vector3(-30.0, 8.0, 0.0)
	var volumes: Array[VillageOccupancyVolume] = [support]
	var resolved := VisualHarness._safe_elevated_camera(frame,
		preferred, target, [], program, &"", volumes)
	assert_ne(resolved, preferred,
		"review cameras must account for planned structure, not buildings alone")
	assert_true(VisualHarness._elevated_sightline_clear(frame,
		resolved, target, [], program, &"", volumes))


func test_capture_timeout_extends_only_for_relevant_active_work() -> void:
	var centre := Vector2i(4, -7)
	assert_true(CaptureHarness._relevant_worker_is_active({
		"active": true, "phase": &"feature_context", "chunk": centre,
		"phase_elapsed_msec": 146000,
	}, centre, 1), "a slow but live complex-village solve receives bounded grace")
	assert_false(CaptureHarness._relevant_worker_is_active({
		"active": true, "phase": &"feature_context",
		"chunk": centre + Vector2i(2, 0), "phase_elapsed_msec": 1000,
	}, centre, 1), "unrelated work cannot keep a capture alive")
	assert_false(CaptureHarness._relevant_worker_is_active({
		"active": true, "phase": &"feature_context", "chunk": centre,
		"phase_elapsed_msec": 301000,
	}, centre, 1), "a genuinely stalled phase still has a hard bound")
	assert_false(CaptureHarness._progress_lease_expired(180.0, 0.25, false),
		"a phase handoff receives a short lease instead of failing instantly")
	assert_true(CaptureHarness._progress_lease_expired(180.0, 30.0, false),
		"an inactive worker still expires after the bounded handoff lease")
	assert_false(CaptureHarness._progress_lease_expired(180.0, 60.0, true),
		"live relevant work always renews the lease")


func test_foundation_review_targets_the_complete_stack_not_its_bottom_tile() -> void:
	var owner := &"settlement.test.urban.house.00"
	var selected := {
		"origin": [10.0, 2.0, -4.0],
		"stable_id": "%s.rock.000.support.0.4" % owner,
	}
	var foundations: Array[Dictionary] = [selected, {
		"origin": [10.0, 5.0, -4.0],
		"stable_id": "%s.rock.000.support.0.3" % owner,
	}, {
		"origin": [10.0, 14.0, -4.0],
		"stable_id": "%s.rock.000.support.0.0" % owner,
	}, {
		"origin": [40.0, 30.0, -4.0],
		"stable_id": "settlement.test.urban.house.01.rock.000",
	}]
	assert_eq(VisualHarness._foundation_stack_target(selected, foundations,
		owner, 3.0), Vector3(10.0, 9.5, -4.0),
		"the review target bisects only the selected owner's visible stack")


func test_representative_review_subset_spans_every_visual_risk_category() -> void:
	var source: Array = []
	for recipe: String in ["skyline", "skyline_reverse", "plaza_eye",
			"main_approach", "street_inbound", "lowest_foundation_edge",
			"urban_web_above", "urban_lower_street",
			"door_sfm_stall_blue_007_outside",
			"urban_building_core_house_00_overhang",
			"urban_aerial_link_a_side_a", "urban_platform_shared_side_a",
			"urban_stair_run_side_a", "outskirts_shelter_00",
			"door_sfv_building_interior_blue_001_inside"]:
		source.append({"recipe": recipe})
	var selected := CaptureHarness._representative_views(source)
	assert_eq(selected.size(), 14)
	assert_eq((selected[0] as Dictionary).recipe, "skyline")
	assert_eq((selected[-1] as Dictionary).recipe, "outskirts_shelter_00")
	assert_false(selected.has({
		"recipe": "door_sfv_building_interior_blue_001_inside"}),
		"the development subset omits redundant door views; full capture does not")


func test_representative_warren_review_cannot_collapse_to_zero_images() -> void:
	var source: Array = []
	for recipe: String in ["warren_skyline_ne", "warren_ground_entry",
			"warren_ground_cross_b", "warren_network_above"]:
		source.append({"recipe": recipe})
	var selected := CaptureHarness._representative_views(source)
	assert_eq(selected, source,
		"the compact warren battery is already representative and must stay whole")


func _flat_frame() -> VillageFrame:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-8, 9):
		for x in range(-8, 9):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 0
	var frame := VillageFrame.new()
	frame.region = HeightfieldRegion.new(storeys, levels)
	return frame
