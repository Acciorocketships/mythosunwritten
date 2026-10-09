extends RefCounted
func run(review:Node)->void:
	var p:=Vector3(-274.1,400,914.2)
	var query:=PhysicsRayQueryParameters3D.create(p,p-Vector3.UP*500)
	var hit:Dictionary=review._camera.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty())
	var dy:float=hit.position.y-63.9
	review._views[0].position=Vector3(-281.6375,69.35425+dy,916.5118)
	review._views[0].target=Vector3(-274.1,67.1+dy,914.2)
	await review._capture_all(2)
	await preload("res://tests/harness/october8_visible_rivers.gd").new().run(review)
	print("LOCAL_CAMERA ground=",hit.position," lift=",dy)
