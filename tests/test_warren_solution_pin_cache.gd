extends GutTest

const CACHE_PATH := "user://test_warren_solution_pins.json"


func before_each() -> void:
	if FileAccess.file_exists(CACHE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CACHE_PATH))
	WarrenSolutionPinCache.override_path_for_tests(CACHE_PATH)


func after_all() -> void:
	if FileAccess.file_exists(CACHE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CACHE_PATH))
	WarrenSolutionPinCache.override_path_for_tests("")


func test_success_pin_roundtrips_through_disk() -> void:
	assert_true(WarrenSolutionPinCache.pin_for(7, &"standard").is_empty(),
		"an empty cache answers with an empty pin, never a guess")
	WarrenSolutionPinCache.store_success(7, &"standard", 4,
		"warren.volume.mass.4000019.arcade0.arcade1", 0)
	# A fresh load must read the persisted file, not the in-memory copy.
	WarrenSolutionPinCache.override_path_for_tests(CACHE_PATH)
	var pin := WarrenSolutionPinCache.pin_for(7, &"standard")
	assert_eq(int(pin.get("attempt", -1)), 4)
	assert_eq(String(pin.get("source_id", "")),
		"warren.volume.mass.4000019.arcade0.arcade1")
	assert_eq(int(pin.get("variant", -1)), 0)
	assert_false(bool(pin.get("failed", false)))
	assert_true(WarrenSolutionPinCache.pin_for(7, &"compact").is_empty(),
		"pins are scoped to their scale contract")


func test_failure_pin_marks_exhausted_searches() -> void:
	WarrenSolutionPinCache.store_failure(1, &"standard")
	WarrenSolutionPinCache.override_path_for_tests(CACHE_PATH)
	assert_true(bool(WarrenSolutionPinCache.pin_for(1, &"standard") \
		.get("failed", false)),
		"an exhausted search is remembered so the worker never repeats it")


func test_invalid_success_values_are_not_stored() -> void:
	WarrenSolutionPinCache.store_success(9, &"standard", -1, "", -1)
	assert_true(WarrenSolutionPinCache.pin_for(9, &"standard").is_empty(),
		"a search that cannot name its winner must not poison the cache")


func test_entries_under_an_older_generation_salt_are_dropped() -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"stale-salt/7/standard": {"failed": true},
		"%s/7/standard" % WarrenSolutionPinCache.GENERATION_SALT:
			{"attempt": 4, "source_id": "x", "variant": 0},
	}))
	file.close()
	WarrenSolutionPinCache.override_path_for_tests(CACHE_PATH)
	var pin := WarrenSolutionPinCache.pin_for(7, &"standard")
	assert_eq(int(pin.get("attempt", -1)), 4,
		"current-salt entries survive the reload")
	WarrenSolutionPinCache.store_success(8, &"standard", 1, "y", 2)
	var raw: Variant = JSON.parse_string(FileAccess.open(CACHE_PATH,
		FileAccess.READ).get_as_text())
	for key_value: Variant in (raw as Dictionary).keys():
		assert_true(String(key_value).begins_with(
			WarrenSolutionPinCache.GENERATION_SALT + "/"),
			"stale-salt entries are dropped when the file is rewritten")


func test_pinned_solve_rejects_malformed_pins() -> void:
	assert_null(WarrenVolumetricSolver.solve_pinned(7, {}, null,
		{"attempt": 4}),
		"a pin without its complete identity must not start a solve")
