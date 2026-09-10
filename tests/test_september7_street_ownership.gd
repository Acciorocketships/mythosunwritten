extends GutTest

func test_photographed_frontage_has_one_street_and_connected_world_road() -> void:
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program.villages.settlement_fabric_program)
	var terrain := VillageTerrainView.from_region(HeightfieldRegion.new({},{}))
	var placement := {"transform":Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*2),Vector3(238.5,8.08,-365.5)),"yaw":0.0,"minimum_y":8.0,"maximum_y":8.0,"entrance_lift":0.08}
	placement.local_bounds = VillageWarrenFabricSolver._local_bounds(spatial.compiled_fabric_cache())
	var urban := VillageWarrenFabricSolver._materialize(terrain,&"manual-street",spatial,spatial.compiled_fabric_cache(),placement,program.villages,2697992464)
	var masks := {Vector2i(10,-16):11,Vector2i(9,-16):3,Vector2i(8,-16):3,Vector2i(11,-16):3,Vector2i(12,-16):3,Vector2i(10,-17):12,Vector2i(10,-18):12}
	var canonical := FeatureGroundField.new([],[],4.5,masks,{Vector2i(10,-16):true})
	var outskirts := VillageOutskirtsConstruction.generate(terrain.with_terrain_grades([urban.terrain_grade]),&"manual-street",Vector2(240,-384),Vector2.DOWN,&"village",&"blue",program.villages,urban,canonical)
	var surface := canonical.extended(urban.surfaces+outskirts.surfaces,[])
	assert_eq(surface.surface_at(Vector2(230,-384)),FeatureGroundField.NATURAL,"the competing world-road stripe yields to town frontage")
	assert_eq(surface.surface_at(Vector2(230,-390)),FeatureGroundField.WORN_PATH,"the shared perimeter stays painted")
	var runs := 0
	var prior := false
	for index in 121:
		var painted := surface.surface_at(Vector2(230,-397+index*0.125)) == FeatureGroundField.WORN_PATH
		if painted and not prior: runs += 1
		prior = painted
	assert_eq(runs,1,"one continuous street across the photographed frontage")
	for x in range(190,208):
		assert_eq(surface.surface_at(Vector2(x,-384)),FeatureGroundField.WORN_PATH,"incoming west road remains connected to the perimeter")
	for z in range(-384,-374):
		assert_eq(surface.surface_at(Vector2(207,z)),FeatureGroundField.WORN_PATH,"world road meets the shared circuit")
	var physical: Array[VillageOccupancyVolume] = []
	for volume: VillageOccupancyVolume in urban.volumes:
		if volume.role != VillageOccupancy.Role.GROUND_EXCLUSIVE: physical.append(volume)
	assert_eq(VillageOccupancy.first_cross_conflict(outskirts.volumes,physical),{},"boundary handoffs reserve real headroom before houses")

func test_world_road_boundary_handoffs_rotate_and_preserve_exterior_roads() -> void:
	for quarter in 4:
		var angle := quarter*PI*0.5
		var axis := Vector2.RIGHT.rotated(angle).round()
		var domain := FeatureGroundShape.oriented_rect(Vector2.ZERO,Vector2(15,21),angle,FeatureGroundField.NATURAL,VillagePlan.SURFACE_PRIORITY-1,&"domain")
		var masks: Dictionary = {}
		for x in range(-2,3):
			masks[Vector2i((Vector2(x,0).rotated(angle)).round())] = 3 if quarter%2==0 else 12
		var ground := FeatureGroundField.new([],[],4.5,masks)
		var routes := VillageOutskirtsConstruction._world_road_handoffs(domain,ground,&"rotated")
		assert_eq(routes.size(),2,"each crossing publishes one boundary handoff")
		var shapes: Array[FeatureGroundShape] = [domain]
		for route: Dictionary in routes:
			assert_almost_eq(domain.signed_distance(route.points[0]),0.0,0.001)
			assert_gt(domain.signed_distance(route.points[1]),0.0)
			shapes.append_array(PathProgram.filleted_path_shapes(route.points,2,FeatureGroundField.WORN_PATH,VillagePlan.SURFACE_PRIORITY,&"handoff"))
		var composed := ground.extended(shapes,[])
		assert_eq(composed.surface_at(Vector2.ZERO),FeatureGroundField.NATURAL,"the country route does not cross the town interior")
		for sign_value in [-1,1]:
			for distance in range(15,43):
				assert_eq(composed.surface_at(axis*distance*sign_value),FeatureGroundField.WORN_PATH,"continuous exterior road to the circuit")
		assert_eq(ground.surface_at(Vector2.ZERO),FeatureGroundField.WORN_PATH,"source road field remains immutable")
