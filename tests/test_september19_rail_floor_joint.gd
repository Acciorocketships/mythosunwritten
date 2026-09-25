extends GutTest

var _fabric: SettlementFabricPlan

func _plan() -> SettlementFabricPlan:
	if _fabric == null:
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
		_fabric = frozen.spatial(frozen.read("res://docs/qa/2026-09-16-manual/05-town-rails/current-source.txt"), program).compiled_fabric_cache()
	return _fabric

func test_p04_sloping_rail_stops_at_the_actual_upper_floor_underside() -> void:
	# P04's house wall begins at 7.5, but its finished timber floor reaches
	# down to 7.338948. The rail must meet that underside instead of crossing it.
	var found := false
	for mesh: Dictionary in _plan().surface_plan.mesh_payloads:
		if String(mesh.get("stable_id", "")) != "volume.transition.12.mesh": continue
		found = true
		for x: float in [-2.5,-2.7,-2.9]:
			var point := Vector3(x,7.15+(x+3.75)*.25,11.25)
			assert_false(_crosses(mesh.collision_faces,point), "Sloping timber must stop at the real floor, not emerge through it at %s" % point)
		assert_true(_crosses(mesh.collision_faces,Vector3(-3.4,7.2375,11.25)),"Exposed lower rail must remain")
		assert_true(_crosses(mesh.collision_faces,Vector3(-2.7,6.8605,11.25)),"The unobstructed lower rail must remain")
		var underside := 7.338948
		var join_x := (underside-7.15)/.25-3.75
		assert_true(_crosses(mesh.collision_faces,Vector3(join_x,6.95,11.25)), "The new upper rail end needs a post from its stair tread to the floor junction")
	assert_true(found)

func _crosses(faces: PackedVector3Array, point: Vector3) -> bool:
	for i in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(point-Vector3(0,0,.2),point+Vector3(0,0,.2),faces[i],faces[i+1],faces[i+2]) != null:
			return true
	return false

func test_clipped_handrail_supports_follow_the_flight_in_four_orientations() -> void:
	for quarter in 4:
		var turn := Basis(Vector3.UP,float(quarter)*PI*.5)
		var payload := WarrenTransitionSurfaceBuilder._empty_payload(&"floor-joint",[] as Array[Vector3i])
		var barriers: Array[AABB] = [Transform3D(turn,Vector3.ZERO)*AABB(Vector3(1.5,2.2,0),Vector3(2,5,6))]
		WarrenTransitionSurfaceBuilder._append_side_guards(payload,Vector3.ZERO,turn*Vector3(0,3,6),turn*Vector3.RIGHT,true,barriers)
		var local_faces := PackedVector3Array()
		for vertex: Vector3 in payload.collision_faces: local_faces.append(turn.inverse()*vertex)
		# y=2.2 meets the upper rail at z=2.1. That new end must bear on
		# the flight at y=1.05, independently of the regular 3 m post spacing.
		for height: float in [1.06,1.7,2.19]:
			assert_true(_crosses(local_faces,Vector3(1.5,height,2.1)),"New support must connect tread and clipped rail in orientation %d" % quarter)
