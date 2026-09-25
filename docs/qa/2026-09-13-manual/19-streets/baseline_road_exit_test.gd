extends GutTest

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
	# Restore exactly the pre-review material adapter's unconditional gate paint.
	var specs := VillageWarrenFabricSolver.terrain_contact_specs(spatial,fabric)
	var paths: Array[Dictionary] = []
	for spec: Dictionary in specs:
		var geometry := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
		var b: Vector3 = urban.world_transform * (geometry.outer_centre as Vector3)
		var points: Array[Vector2] = [Vector2(b.x,b.z)]
		paths.append({"points":points})
	VillageWarrenFabricSolver._append_terrain_handoff_paint(urban,specs,paths,&"reported-exit.warren")
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
