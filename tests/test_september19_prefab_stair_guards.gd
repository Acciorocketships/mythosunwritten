extends GutTest

var _fabric: SettlementFabricPlan

func _plan() -> SettlementFabricPlan:
	if _fabric == null:
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
		_fabric = frozen.spatial(frozen.read("res://docs/qa/2026-09-16-manual/05-town-rails/current-source.txt"), program).compiled_fabric_cache()
	return _fabric

func test_p15_rails_reach_the_lower_landing_outside_the_actual_prefab() -> void:
	# Original P15 player (-1999.3,33.6,1765.5), crosshair (-2002.6,34.1,1763.6).
	# Native image rays identify transition.11 at local x=5.25,z=9.75.
	# The prefab starts at x=6.327571: its rounded-up reservation is empty air.
	var found := false
	for mesh: Dictionary in _plan().surface_plan.mesh_payloads:
		if String(mesh.get("stable_id", "")) != "volume.transition.11.mesh": continue
		found = true
		var faces: PackedVector3Array = mesh.collision_faces
		for z: float in [9.9, 10.2, 10.5, 10.8, 11.1]:
			var floor_y := 9.0 - (z - 8.25) * .5
			for fraction: float in [.52, 1.0]:
				var point := Vector3(5.25, floor_y + WarrenTransitionSurfaceBuilder.GUARD_HEIGHT*fraction, z)
				assert_true(_crosses(faces, point), "Roof-side rail must protect the actual exposed flight at %s" % point)
		assert_true(_crosses(faces,Vector3(5.25,8.0,11.25)), "Lower end post must support the rail above its real landing")
	assert_true(found)

func test_photographed_rail_is_outside_every_native_prefab_part() -> void:
	var count := 0
	var air := AABB(Vector3(5.10,7.55,9.80),Vector3(.30,2.0,1.3))
	for placement: Dictionary in _plan().expanded_placements():
		if not "landmark.01.component.00" in String(placement.stable_id): continue
		count += 1
		assert_false((placement.bounds as AABB).intersects(air), "The authored prefab cannot replace a guard in this empty strip")
	assert_gt(count,0)

func _crosses(faces: PackedVector3Array, point: Vector3) -> bool:
	for i in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(point-Vector3(.2,0,0),point+Vector3(.2,0,0),faces[i],faces[i+1],faces[i+2]) != null:
			return true
	return false
