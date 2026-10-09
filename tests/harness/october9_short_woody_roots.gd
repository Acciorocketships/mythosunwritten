extends RefCounted
func run(review:Node)->void:
	var excluded:Array[RID]=[]
	for body:StaticBody3D in review.find_children("DressingCollision","StaticBody3D",true,false):excluded.append(body.get_rid())
	var rows:=[]
	var misses:=0
	var space:PhysicsDirectSpaceState3D=review.get_world_3d().direct_space_state
	for node:MultiMeshInstance3D in review.find_children("*","MultiMeshInstance3D",true,false):
		if node.name == &"LeafShadow":continue
		if node.multimesh==null or node.multimesh.mesh==null:continue
		var name_and_path:=str(node.name)+" "+node.multimesh.mesh.resource_path
		var kind:="sapling" if name_and_path.contains("farm_sapling_") else "bush"
		if kind=="bush" and not name_and_path.contains("meadow_birch_bush_"):continue
		for i in node.multimesh.instance_count:
			var transform:=node.global_transform*node.multimesh.get_instance_transform(i)
			var at:=transform.origin
			var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*500,at-Vector3.UP*500,1)
			query.exclude=excluded
			var hit:=space.intersect_ray(query)
			if hit.is_empty():misses+=1;continue
			rows.append({"kind":kind,"asset":name_and_path,"at":str(at),"root_above_ground":at.y-hit.position.y,
				"visual_height":node.multimesh.mesh.get_aabb().size.y*transform.basis.y.length(),"collider":str(hit.collider.get_path())})
	FileAccess.open(review._output_dir+"/short-woody-roots.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"misses":misses},"  "))
	print("SHORT_WOODY_ROOTS count=",rows.size()," misses=",misses)
