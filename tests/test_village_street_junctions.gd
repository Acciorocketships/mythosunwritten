extends GutTest

func test_independently_declared_streets_round_both_sides_of_the_same_t_junction() -> void:
	var paths: Array[Dictionary] = [
		{"points":[Vector2(-16,0),Vector2.ZERO,Vector2(0,16)] as Array[Vector2]},
		{"points":[Vector2.ZERO,Vector2(16,0)] as Array[Vector2]}]
	var shapes: Array[FeatureGroundShape] = []
	for path: Dictionary in paths:
		shapes.append_array(PathProgram.filleted_path_shapes(path.points,2.0,1,1,&"test"))
	shapes.append_array(PathProgram.shared_junction_shapes(paths,2.0,1,1,&"junctions"))
	for x: float in [2.1,2.4,2.8,3.2,3.6]:
		for y: float in [2.1,2.4,2.8,3.2,3.6]:
			assert_eq(_contains(shapes,Vector2(x,y)),_contains(shapes,Vector2(-x,y)),
				"both inward corners belong to the same junction, regardless of route declaration")

func _contains(shapes: Array[FeatureGroundShape],point: Vector2) -> bool:
	for shape: FeatureGroundShape in shapes:
		if shape.contains(point): return true
	return false

func test_short_door_landing_does_not_extend_paint_beyond_its_end() -> void:
	var points: Array[Vector2] = [Vector2(-8, 0), Vector2.ZERO, Vector2(0, 1)]
	var shapes := PathProgram.filleted_path_shapes(points, 2.0, 1, 1, &"porch")
	var corridor_bounds := Rect2(Vector2(-8, -2), Vector2(10, 4))
	for x in range(-90, 31):
		for y in range(-30, 41):
			var point := Vector2(x, y) * 0.1
			if corridor_bounds.grow(0.001).has_point(point):
				continue
			assert_false(_contains(shapes, point),
				"a rounded short landing must not paint inside the house past its endpoint")

func test_frontage_connects_at_the_first_existing_street_without_an_unused_spur() -> void:
	var gate: Array[Vector2] = [Vector2(264,290), Vector2(264,270), Vector2(312,270)]
	var branch: Array[Vector2] = [Vector2(264,290), Vector2(264,276), Vector2(276,276)]
	var contact := Vector2(275.6221,276)
	var door := Vector2(275.6221,239.8379)
	var actual := VillageOutskirtsConstruction._frontage_path(
		[{"points":gate}] as Array[Dictionary], branch, contact, door)
	assert_eq(actual, [Vector2(264,290), Vector2(264,270),
		Vector2(275.6221,270), door] as Array[Vector2],
		"the house connects to the nearer existing road, without extending a dead branch")
