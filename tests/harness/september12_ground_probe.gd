extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	for spot: Array in [["30_heath",Vector3(-419.6,21.9,-660.4),Vector3(-424.8,28,-653.2)],["28_heath",Vector3(805.8,24,-1860.4),Vector3(796,32,-1853.4)]]:
		var world: Node3D = (load("res://docs/qa/2026-09-12-manual/01-ground/live/%s/world.scn"%spot[0]) as PackedScene).instantiate()
		root.add_child(world)
		await physics_frame
		await physics_frame
		var space := world.get_world_3d().direct_space_state
		var focus: Vector3 = spot[1]+Vector3.UP
		var eye := ReviewCam.solve_cam(spot[1],spot[2],26,16,1)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(focus,eye,1))
		print("GROUND_CAMERA ",spot[0]," focus=",focus," eye=",eye," hit=",hit)
		for fraction: float in [0,.1,.25,.5,.75,1]:
			var point := focus.lerp(eye,fraction)
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*150,point-Vector3.UP*150,1))
			print("GROUND_SAMPLE ",fraction," line=",point," floor=",floor_hit.get("position")," normal=",floor_hit.get("normal"))
		world.free()
	quit()
