extends RefCounted

func run(review: Node) -> void:
	var camera: Camera3D = review._camera
	var space: PhysicsDirectSpaceState3D = review.get_world_3d().direct_space_state
	for pixel: Vector2 in [Vector2(700,240),Vector2(670,280),Vector2(710,320),Vector2(760,220)]:
		var origin := camera.project_ray_origin(pixel)
		var direction := camera.project_ray_normal(pixel)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*500))
		print("[oct8_geometry] pixel=",pixel," hit=",hit)
		if hit.is_empty(): continue
		var p: Vector3 = hit.position
		var chunk := FieldTerrainStreamer.chunk_of(p)
		var inputs: Dictionary = review._inputs.get(chunk,{})
		if inputs.is_empty(): continue
		print("[oct8_geometry] world=",p," kernel=",TerrainTileField.surface_y(inputs.region,p.x,p.z),
			" water=",inputs.water.level_at(Vector2(p.x,p.z))," collider=",hit.collider.get_path())
	for node: Node in review.find_children("WaterSheet","MeshInstance3D",true,false): node.visible=false
	for node: Node in review.find_children("CliffRockFormations","Node3D",true,false): node.visible=false
	RenderingServer.force_draw()
	review.get_viewport().get_texture().get_image().save_png(review._output_dir+"/kernel_only.png")
	for node: Node in review.find_children("CliffRockFormations","Node3D",true,false): node.visible=true
	for node: Node in review.find_children("WaterSheet","MeshInstance3D",true,false): node.visible=true
