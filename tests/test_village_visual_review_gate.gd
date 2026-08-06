extends GutTest

const Gate = preload("res://tests/harness/VillageVisualReviewGate.gd")


func _index(full: bool = false) -> Dictionary:
	return {
		"source_coverage": {"full_spec_complete": full},
		"captures": [
			{"screenshot_id": "one"},
			{"screenshot_id": "two"},
		],
	}


func _report() -> Dictionary:
	return {
		"review_contract": {
			"intent": "falsification",
			"success_definition": "finding_a_real_issue",
			"full_resolution_reviewed": true,
			"independent_reviewer": false,
		},
		"closing_candidate": false,
		"captures": [
			{"screenshot_id": "one", "disposition": "finding",
				"finding_ids": ["F-1"], "notes": "visible overlap at the door"},
			{"screenshot_id": "two", "disposition": "clear",
				"finding_ids": [], "notes": "reverse view corroborates clearance"},
		],
		"findings": [{
			"id": "F-1", "severity": "P2", "screenshot_ids": ["one"],
			"evidence": "door overlaps wall", "invariant": "doors stay clear",
			"confidence": "high", "status": "open",
		}],
	}


func test_valid_review_can_succeed_by_finding_an_open_issue() -> void:
	assert_true(Gate.validate(_index(), _report(), {"pins": []}).is_empty())


func test_every_capture_must_be_accounted_for_exactly_once() -> void:
	var report := _report()
	report.captures.pop_back()
	assert_true(Array(Gate.validate(_index(), report, {"pins": []})).any(
		func(error: String) -> bool: return error.contains("unreviewed")))


func test_partial_or_non_independent_review_cannot_close() -> void:
	var errors := Gate.closure_errors(_index(), _report(), {"pins": []})
	assert_true(Array(errors).any(func(error: String) -> bool:
		return error.contains("full specification")))
	assert_true(Array(errors).any(func(error: String) -> bool:
		return error.contains("independent reviewer")))
	assert_true(Array(errors).any(func(error: String) -> bool:
		return error.contains("unresolved")))


func test_fixed_finding_requires_a_passing_regression_pin() -> void:
	var report := _report()
	report.findings[0].status = "fixed"
	var errors := Gate.validate(_index(), report, {"pins": []})
	assert_true(Array(errors).any(func(error: String) -> bool:
		return error.contains("lacks a regression pin")))
	var pins := {"pins": [{
		"finding_id": "F-1", "seed": 4242, "settlement_id": "settlement.x",
		"recipe": "door_outside", "status": "fixed",
		"passing_recaptures": ["one"],
	}]}
	assert_true(Gate.validate(_index(), report, pins).is_empty())


func test_closure_requires_camera_clearance_diagnostics() -> void:
	var index := _index(true)
	var report := _report()
	report.review_contract.independent_reviewer = true
	report.closing_candidate = true
	report.findings[0].status = "dismissed"
	var missing := Gate.closure_errors(index, report, {"pins": []})
	assert_true(Array(missing).any(func(error: String) -> bool:
		return error.contains("camera-clearance diagnostics")))
	index.view_diagnostics = {"authored_obstructed": 1,
		"adjusted": 1, "unresolved": 0}
	var obstructed := Gate.closure_errors(index, report, {"pins": []})
	assert_true(Array(obstructed).any(func(error: String) -> bool:
		return error.contains("obstructed authored views")))
	index.view_diagnostics.authored_obstructed = 0
	assert_true(Gate.closure_errors(index, report, {"pins": []}).is_empty())
