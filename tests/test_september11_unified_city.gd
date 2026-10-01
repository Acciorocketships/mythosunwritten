extends GutTest

func test_a_source_generated_city_does_not_request_a_second_ground_house_pass() -> void:
	var city := VillageUrbanFabricPlan.new()
	city.generation_kind = VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN
	assert_false(city.requires_outskirts(),
		"Ground houses and upper rooms must be allocated before this one source city is sealed")


func test_photographed_city_allocates_low_native_neighborhood_before_modular_rooms() -> void:
	var source := WarrenMazeSitePlanner.plan(8922681140531148375, {},
		WarrenVillageScaleProfile.for_id(&"compact"))
	assert_not_null(source)
	var low_native := 0
	var grounded_native := 0
	for plot: Dictionary in source.plots:
		if plot.kind != WarrenMazeSourcePlan.PLOT_ASSET:
			continue
		grounded_native += int(plot.floor == 0)
		low_native += int(plot.floor <= WarrenBuildingParcel.STOREY_BANDS / 2)
	assert_gte(grounded_native, 2)
	assert_gte(low_native, 3,
		"The common allocation must retain more low native houses than the old two-prefab core, while sharing space with connected skywalks")


func test_world_roads_connect_only_real_crossings_to_source_gates() -> void:
	var router := preload("res://scripts/terrain/features/villages/VillageWarrenRoadConnections.gd")
	var contacts: Array[VillageCirculationNode] = []
	for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		contacts.append(VillageCirculationNode.new(StringName(str(direction)),
			VillageCirculationNode.Kind.TERRAIN_CONTACT, direction * 10.0,
			0.0, &"source", direction))
	var bounds := Rect2(-Vector2.ONE * 10.0, Vector2.ONE * 20.0)
	assert_eq(router.topology(bounds, contacts, null, &"isolated").paths.size(), 0,
		"No external roads means no invented perimeter street")
	for mask: Dictionary in [{Vector2i(1, 0): 2}, {Vector2i(0, 1): 8},
			{Vector2i(-1, 0): 1}, {Vector2i(0, -1): 4}]:
		var ground := FeatureGroundField.new([], [], 0.0, mask)
		var topology := router.topology(bounds, contacts, ground, &"connected")
		assert_eq(topology.paths.size(), 1)
		var points: Array[Vector2] = topology.paths[0].points
		assert_eq(points[0], Vector2(mask.keys()[0]) * HeightfieldPlan.CELL)
		assert_eq(points[-1], points[0].normalized() * 10.0)
		for point: Vector2 in points:
			assert_almost_eq(point.cross(points[0]), 0.0, 0.001,
				"A direct country-road handoff cannot acquire a ring detour")
		var field := FeatureGroundField.new([topology.domain], [], 0.0, mask)
		assert_eq(field.surface_at(Vector2.ZERO), FeatureGroundField.NATURAL,
			"Only source streets may paint the owned city interior")


func test_external_connector_uses_the_short_boundary_arc() -> void:
	var router := preload("res://scripts/terrain/features/villages/VillageWarrenRoadConnections.gd")
	var bounds := Rect2(-Vector2.ONE * 10, Vector2.ONE * 20)
	for a: Vector2 in [Vector2(-10, -5), Vector2(10, 5), Vector2(5, -10), Vector2(-5, 10)]:
		for b: Vector2 in [Vector2(-10, 5), Vector2(10, -5), Vector2(-5, -10), Vector2(5, 10)]:
			var points := router.boundary_path(a, b, bounds)
			assert_eq(points[0], a)
			assert_eq(points[-1], b)
			var length := 0.0
			for index in range(1, points.size()):
				length += points[index - 1].distance_to(points[index])
				assert_true(is_zero_approx(points[index - 1].x - points[index].x)
					or is_zero_approx(points[index - 1].y - points[index].y))
			assert_lte(length, 40.0, "A connector never walks the long way around the city")
