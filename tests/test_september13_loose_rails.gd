extends GutTest

func test_p08_ramp_rails_yield_to_the_finished_upper_house_wall() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/04-path/source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var town := Transform3D(Basis.from_scale(Vector3(-2,2,-2)),Vector3(-214.5,8.08,-944.5))
	# P08: player (-233.4,12.4,-954.4), crosshair (-235.2,13.5,-958.6).
	# Two sloping rails float across the completed house above the lower stone.
	# Its exterior plane is x=-231, floor y=14.08, and ends z=-961/-955.
	var fragments := 0
	var matched := 0
	for mesh: Dictionary in fabric.surface_plan.mesh_payloads:
		if String(mesh.get("stable_id","")) != "volume.transition.06.mesh": continue
		matched += 1
		var points: PackedVector3Array = mesh.vertices
		for i in range(0,points.size(),4):
			var p := town*((points[i]+points[i+1]+points[i+2]+points[i+3])*.25)
			if p.x > -231.2 and p.x < -230.8 and p.z > -960.9 and p.z < -955.1 and p.y > 14.2:
				fragments += 1
	assert_eq(matched,1,"The actual photographed ramp is present")
	assert_eq(fragments,0,"No unsupported rail fragments across the completed native house wall")

func test_finished_native_wall_clips_deferred_guards_without_removing_exposed_guard() -> void:
	for quarter in 4:
		var rotate := Basis(Vector3.UP,float(quarter)*PI*.5)
		var plan := PublicRealmSurfacePlan.new(&"native-wall-socket")
		var payload := WarrenTransitionSurfaceBuilder._empty_payload(&"socket",[] as Array[Vector3i])
		payload.pending_guard_span = {"start":Vector3.ZERO,"end":rotate*Vector3(0,1.5,3),"lateral":rotate*Vector3.RIGHT}
		plan._transition_mesh_payloads.append(payload)
		var native_walls: Array[AABB] = [Transform3D(rotate,Vector3.ZERO)*AABB(Vector3(1.5,0,0),Vector3(1.5,4,1.5))]
		assert_true(plan.finish_transition_guards([],native_walls))
		var blocked := 0
		var exposed := 0
		var opposite := 0
		var points: PackedVector3Array = payload.vertices
		for i in range(0,points.size(),4):
			var p := rotate.inverse()*((points[i]+points[i+1]+points[i+2]+points[i+3])*.25)
			if p.x>1.4 and p.z>.01 and p.z<1.49 and p.y>.01: blocked+=1
			if p.x>1.4 and p.z>1.6: exposed+=1
			if p.x< -1.4: opposite+=1
		assert_eq(blocked,0,"Native wall terminates the rail at the real wall socket")
		assert_gt(exposed,0,"Exposed side retains a guard")
		assert_gt(opposite,0,"Opposite open edge retains its guard")
		assert_eq(payload.collision_faces.size(),points.size()/4*6,"Every surviving face retains collision")
