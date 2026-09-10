extends GutTest

func test_primary_gate_does_not_invent_a_country_road_in_four_orientations() -> void:
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september9-offset-source.txt"),program.villages.settlement_fabric_program)
	var fabric := spatial.compiled_fabric_cache()
	for quarter in 4:
		var angle := quarter*PI*0.5
		var terrain := VillageTerrainView.from_region(HeightfieldRegion.new({},{}))
		var placement := {"transform":Transform3D(Basis(Vector3.UP,-angle).scaled(Vector3.ONE*2),Vector3(0,6.08,0)),"yaw":angle,"minimum_y":6.0,"maximum_y":6.0,"entrance_lift":0.08,"local_bounds":VillageWarrenFabricSolver._local_bounds(fabric)}
		var urban := VillageWarrenFabricSolver._materialize(terrain,&"road-exit",spatial,fabric,placement,program.villages,2697992464)
		var outskirts := VillageOutskirtsConstruction.generate(terrain.with_terrain_grades([urban.terrain_grade]),&"road-exit",Vector2.ZERO,Vector2.DOWN.rotated(angle),&"village",&"blue",program.villages,urban,null)
		var domain: FeatureGroundShape = outskirts.surfaces[0]
		var gates := 0
		for street: Dictionary in outskirts.street_paths:
			if String(street.owner).contains(".outskirts.house."): continue
			if String(street.owner).contains(".gate."): gates += 1
			for point: Vector2 in street.points:
				assert_lte(domain.signed_distance(point),0.001,"Without a world-road connection, all town streets end on or inside the perimeter: %s" % street.owner)
		assert_gt(gates,0,"Town gates still connect to the perimeter")

func test_photographed_north_spur_disappears_and_south_road_stays_connected() -> void:
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september9-offset-source.txt"),program.villages.settlement_fabric_program)
	var fabric := spatial.compiled_fabric_cache()
	var terrain := VillageTerrainView.from_region(HeightfieldRegion.new({},{}))
	var placement := {"transform":Transform3D(Basis(Vector3.UP,-PI*0.5).scaled(Vector3.ONE*2),Vector3(289.5,6.08,-1157.5)),"yaw":-PI*0.5,"minimum_y":6.0,"maximum_y":6.0,"entrance_lift":0.08,"local_bounds":VillageWarrenFabricSolver._local_bounds(fabric)}
	var urban := VillageWarrenFabricSolver._materialize(terrain,&"reported-exit",spatial,fabric,placement,program.villages,2697992464)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/september9-road-masks.json"))
	var masks: Dictionary = {}
	for entry: Array in data.masks: masks[Vector2i(entry[0],entry[1])] = int(entry[2])
	var canonical := FeatureGroundField.new([],[],4.5,masks,{Vector2i(12,-49):true})
	var outskirts := VillageOutskirtsConstruction.generate(terrain.with_terrain_grades([urban.terrain_grade]),&"reported-exit",Vector2(288,-1176),Vector2.DOWN,&"village",&"blue",program.villages,urban,canonical)
	var surface := canonical.extended(urban.surfaces+outskirts.surfaces,[])
	for z in range(-1247,-1220):
		assert_eq(surface.surface_at(Vector2(288,z)),FeatureGroundField.NATURAL,"The photographed empty north field has no invented road")
	var handoffs := 0
	for street: Dictionary in outskirts.street_paths:
		if not String(street.owner).contains(".world-road."): continue
		handoffs += 1
		assert_lt((street.points[0] as Vector2).distance_to(Vector2(288,-1113)),0.001)
		assert_lt((street.points[1] as Vector2).distance_to(Vector2(288,-1104)),0.001)
	assert_eq(handoffs,1,"The actual south road supplies the only exit")
	for z in range(-1113,-1079):
		assert_eq(surface.surface_at(Vector2(288,z)),FeatureGroundField.WORN_PATH,"South handoff remains continuously painted")
