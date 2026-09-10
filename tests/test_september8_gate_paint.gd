extends GutTest

func test_level_gate_paint_keeps_the_connecting_road_width_in_every_orientation() -> void:
	for quarter in 4:
		var urban:=VillageUrbanFabricPlan.new()
		urban.world_transform=Transform3D(Basis(Vector3.UP,quarter*PI/2).scaled(Vector3.ONE*2),Vector3(238.5,8.08,-365.5))
		var spec:Dictionary={"cells":[Vector3i(0,0,-4),Vector3i(1,0,-4)] as Array[Vector3i],
			"outward":Vector3i.FORWARD,"lateral":Vector3i.RIGHT,"ground_band":0,"stable_suffix":&"entry"}
		VillageWarrenFabricSolver._append_terrain_handoffs(urban,[spec] as Array[Dictionary],&"test")
		var shape:FeatureGroundShape=urban.surfaces[0]
		assert_almost_eq(shape._half_extents.y,PathProgram.PATH_HALF_WIDTH,0.001,
			"The connecting strip must not grow a 6 m painted tab beside a 4 m road")
		assert_almost_eq(urban.clearances[0]._half_extents.y,3.0,0.001,
			"The complete physical gate keeps its original reserved width")
