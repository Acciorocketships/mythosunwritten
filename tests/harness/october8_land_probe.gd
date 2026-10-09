extends RefCounted

func run(review: Node) -> void:
	var camera: Camera3D = review._camera
	var view: Dictionary = review._views[0]
	camera.look_at_from_position(view.position,view.target,Vector3.UP)
	camera.force_update_transform()
	var reference := Vector3(-222.4,61.8,1330.8)
	var instances: Array = []
	for node: MultiMeshInstance3D in review.find_children("*","MultiMeshInstance3D",true,false):
		if node.get_parent().name != &"Dressing": continue
		for i in node.multimesh.instance_count:
			var transform := node.global_transform * node.multimesh.get_instance_transform(i)
			var distance := transform.origin.distance_to(reference)
			if distance<12.0:
				instances.append({"name":str(node.name),"mesh":node.multimesh.mesh.resource_path,"at":transform.origin,"distance":distance,"scale":transform.basis.get_scale()})
	instances.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.distance<b.distance)
	for instance: Dictionary in instances: print("[oct8_land] instance=",instance)
	var space: PhysicsDirectSpaceState3D = review.get_world_3d().direct_space_state
	for pixel: Vector2 in [Vector2(720,365),Vector2(720,410)]:
		var origin := camera.project_ray_origin(pixel)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(pixel)*100))
		print("[oct8_land] ray=",hit)
	# Save the exact natural lattice around the grooves before landform changes.
	var region: HeightfieldRegion = review._inputs[Vector2i(-2,7)].region
	var storeys := {};var levels := {}
	for z in range(100,126):
		for x in range(-40,-10):
			storeys[Vector2i(x,z)]=region.storey_at(x,z)
			levels[Vector2i(x,z)]=region.level_at(x,z)
	FileAccess.open(review._output_dir+"/dents-lattice.var",FileAccess.WRITE).store_var({"storeys":storeys,"levels":levels})
	review._categories=true
	await review._capture_all(1)
