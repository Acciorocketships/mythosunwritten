extends RefCounted
func run(review:Node)->void:
	var excluded:Array[RID]=[]
	for body:StaticBody3D in review.find_children("DressingCollision","StaticBody3D",true,false):excluded.append(body.get_rid())
	var poses:=[]
	for view:Dictionary in review._views:
		var origin:Vector3=view.get("player",view.position)
		var query:=PhysicsRayQueryParameters3D.create(Vector3(origin.x,1000,origin.z),Vector3(origin.x,-500,origin.z),1)
		query.exclude=excluded
		var hit:Dictionary=review.get_world_3d().direct_space_state.intersect_ray(query)
		var rise:=maxf(0.0,hit.position.y-origin.y) if not hit.is_empty() else 0.0
		view.position.y+=rise
		view.target.y+=rise
		view.player.y+=rise
		query.from=Vector3(view.position.x,1000,view.position.z)
		query.to=Vector3(view.position.x,-500,view.position.z)
		hit=review.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():view.position.y=maxf(view.position.y,hit.position.y+3.0)
		poses.append({"id":view.id,"eye":str(view.position),"target":str(view.target),"player_rise":rise})
	await review._capture_all(2)
	FileAccess.open(review._output_dir+"/grounded-poses.json",FileAccess.WRITE).store_string(JSON.stringify(poses))
	print("GROUNDED_VIEWS_DONE ",JSON.stringify(poses))
