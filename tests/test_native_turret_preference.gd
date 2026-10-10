extends GutTest


func test_corner_turret_preference_varies_between_towns_and_stops_after_one() -> void:
	var preferred := 0
	var template: Dictionary
	for row: Dictionary in WarrenPlotReservations.ASSET_TEMPLATES:
		if bool(row.get("corner_turret", false)):
			template = row
	assert_false(template.is_empty())
	for seed_value in 100:
		preferred += int(WarrenPlotReservations._prefers_corner_turret(seed_value, {}))
		assert_false(
			WarrenPlotReservations._prefers_corner_turret(seed_value, {template.kind_id: 1}),
			"A second turret gets no extra preference"
		)
	assert_gt(preferred, 20)
	assert_lt(preferred, 80, "The feature is optional across towns")


func test_existing_held_building_wins_over_a_later_skyline_preference() -> void:
	var held := {
		"unheld": 0,
		"skyline_preference": 1,
		"reuse": 0,
		"cut_class": 0,
		"variety": 0,
		"cost": 0,
		"datum": 0,
		"anchor": Vector2i.ZERO,
		"orientation": 0,
		"template": 0
	}
	var candidate := held.duplicate()
	candidate.unheld = 1
	candidate.skyline_preference = 0
	assert_true(
		WarrenPlotReservations._site_less(held, candidate),
		"Do not spend an already protected site's footprint on a later preference"
	)
