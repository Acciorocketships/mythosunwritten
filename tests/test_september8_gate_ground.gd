extends GutTest

const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")

func test_raised_exit_does_not_force_a_three_metre_spike_into_ground() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := Frozen.spatial(Frozen.read("res://tests/fixtures/september8-west-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	for turn in 4:
		var pose := Transform3D(Basis(Vector3.UP,turn*PI*0.5).scaled(Vector3.ONE*2),Vector3(-412.5,13.08,-266.5))
		var grade := VillageWarrenFabricSolver._ground_grade(&"raised-exit",spatial,fabric,pose)
		var local := Vector3(0,0,-10.5)
		var world := pose*local
		assert_almost_eq(grade.surface_y(Vector2(world.x,world.z),13),13.0,0.00001,
			"A structural elevated portal must not become a narrow raised ground cell")
	var blocked := false
	for segment: Dictionary in fabric.surface_plan.guard_segments:
		blocked = blocked or String(segment.stable_key) in ["0:1:-6:0:-1","1:1:-6:0:-1"]
	assert_false(blocked,"The declared exterior approach must open its landing guard")

func test_gate_flight_lands_on_ground_with_shared_step_limits_and_unique_posts() -> void:
	for turn in 4:
		var outward := Vector3i((Vector3.FORWARD.rotated(Vector3.UP,turn*PI*0.5)).round())
		var lateral := Vector3i(-outward.z,0,outward.x)
		var cells: Array[Vector3i] = [Vector3i(0,1,0),Vector3i(0,1,0)+lateral]
		var spec := {"cells":cells,"outward":outward,"lateral":lateral,"ground_band":0}
		var geometry := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
		assert_true(geometry.has_stairs)
		assert_eq(geometry.outer_centre.y,0.0)
		assert_almost_eq((geometry.stair_end as Vector3).distance_to(geometry.outer_centre),1.5,0.00001,
			"The flight terminates at a full lower landing")
		var payload := WarrenTransitionSurfaceBuilder.build_gate_approach(&"gate",geometry)
		var triangles: Dictionary = {}
		var faces: PackedVector3Array = payload.collision_faces
		for i in range(0,faces.size(),3):
			var key: Array[String] = [str(faces[i]),str(faces[i+1]),str(faces[i+2])]
			key.sort()
			var joined := "|".join(key)
			assert_false(triangles.has(joined),"The landing/flight cannot duplicate a complete post face")
			triangles[joined] = true
		var treads: Array[float] = []
		var vertices: PackedVector3Array = payload.vertices
		var normals: PackedVector3Array = payload.normals
		for i in vertices.size():
			var point := vertices[i]
			if normals[i].y < 0.999 or point.y > 1.5 or point.y < 0: continue
			if not treads.has(point.y): treads.append(point.y)
		treads.sort()
		assert_gte(treads.size(),9)
		for i in range(1,treads.size()):
			assert_lte((treads[i]-treads[i-1])*2,TraversalEnvelope.MAX_PLANNED_STEP,
				"Exterior stairs reuse the public stair riser limit")
