extends GutTest

func _real_plan() -> PathPlan:
	var seed_value := 2697992464
	var water := WaterPlan.new(seed_value, 22.0, 8)
	var settlements := SettlementPlan.new(seed_value, water)
	var heights := HeightfieldPlan.new(seed_value, 22.0, 8, "mean", 3)
	heights.set_water_plan(water)
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights, water, program.query_margin,
		program.shore_distance_limit, program.FIELD_CACHE_CAP)
	return PathPlan.new(seed_value, water, fields, program,
		program.query_margin, settlements)

func test_site_discovery_is_canonical_from_either_bank() -> void:
	var plan := _real_plan()
	var discovered: Dictionary = {}
	# One pinned Phase-0 crossing block. Discovery itself is planning-water only.
	for z in range(-50, -38):
		for x in range(-2, 11):
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.DOWN, Vector2i.UP]:
				var site: Dictionary = plan._site_from_start(Vector2i(x, z), direction)
				if not site.is_empty():
					discovered[String(site.key)] = site
	assert_gt(discovered.size(), 0, "pinned corpus contains prospective crossings")
	for site: Dictionary in discovered.values():
		var reverse_start: Vector2i = site.b
		var reverse_direction: Vector2i = (site.a - site.b).sign()
		var reverse := plan._site_from_start(reverse_start, reverse_direction)
		if not reverse.is_empty():
			assert_eq(reverse.key, site.key,
				"opposite-bank discovery coalesces to one canonical identity")

func test_profiled_bridge_transform_is_the_placement_transform() -> void:
	var plan := _real_plan()
	var valid: Dictionary = {}
	for z in range(-50, -38):
		for x in range(-2, 11):
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var site := plan._site_from_start(Vector2i(x, z), direction)
				if site.is_empty():
					continue
				var bridge := plan.bridge_site(site)
				if not bridge.is_empty():
					valid = bridge
					break
			if not valid.is_empty():
				break
		if not valid.is_empty():
			break
	assert_false(valid.is_empty(), "pinned corpus retains at least one exact bridge")
	if valid.is_empty():
		return
	assert_eq(plan.bridge_site(valid.key).transform, valid.transform,
		"the validated transform is returned byte-identically for placement")
	assert_gt(valid.connections.size(), 1)
