extends RefCounted
func run(review:Node)->void:
	await preload("res://tests/harness/october8_apply_surface.gd").new().sample_path(review)
	var p:=Vector2(465.815673828125,1139.35693359375)
	var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,400,p.y),Vector3(p.x,-100,p.y))
	var excludes:Array[RID]=[]
	for i in 6:
		query.exclude=excludes
		var hit:Dictionary=review._camera.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():break
		print("RAY_DETAIL ",hit.position," ",hit.collider.get_path()," shape=",hit.collider.shape_owner_get_owner(hit.collider.shape_find_owner(hit.shape)).name)
		excludes.append(hit.rid)
