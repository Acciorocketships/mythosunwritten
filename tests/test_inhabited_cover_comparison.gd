extends GutTest

const COMPARISON = preload("res://tests/fixtures/inhabited_cover_comparison.gd")


func test_equal_totals_cannot_hide_a_displaced_passage() -> void:
	var before := {"town": {"walks": {"old": [2, 2, -1, -1], "new": [-1, -1, -1, -1]}}}
	var after := {"town": {"walks": {"old": [-1, -1, -1, -1], "new": [2, 2, -1, -1]}}}
	var result := COMPARISON.compare(before, after)
	assert_eq(result.checked_quarters, 2)
	assert_eq(result.lost_quarters, 2)
	assert_eq(result.lost[0].walk, "old")
	assert_eq(result.lost[1].quarter, 1)


func test_missing_towns_walks_and_quarters_do_not_silently_pass() -> void:
	var before := {"town": {"walks": {"path": [2, 3, 4, -1]}}}
	assert_eq(COMPARISON.compare(before, {}).lost_quarters, 3)
	assert_eq(COMPARISON.compare(before, {"town": {"failure": "build failed"}}).lost_quarters, 3)
	assert_eq(COMPARISON.compare(before, {"town": {"walks": {"path": [2]}}}).lost_quarters, 2)


func test_ceiling_distance_matters_and_the_review_band_is_explicit() -> void:
	var before := {"town": {"walks": {"path": [2, 4, 10, -1]}}}
	var after := {"town": {"walks": {"path": [3, 2, -1, 2]}}}
	assert_eq(COMPARISON.compare(before, before).lost_quarters, 0)
	assert_eq(COMPARISON.compare(before, after).lost_quarters, 1)
	assert_eq(COMPARISON.compare(before, after, 12).lost_quarters, 2)
	assert_eq(COMPARISON.compare(before, after).checked_quarters, 2)
