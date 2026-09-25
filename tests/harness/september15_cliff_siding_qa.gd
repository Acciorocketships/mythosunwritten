extends "res://tests/harness/september15_reported_qa.gd"

func _capture_views(world: Node3D) -> void:
	if "--siding" in OS.get_cmdline_user_args():
		var meshes := {}
		var plants := preload("res://tests/harness/september15_mountain_study.gd").new()
		plants._stage=world
		plants._rng.seed=2697992464
		var plant_sites := {}
		var terrace := preload("res://scripts/terrain/field/CliffTerraces.gd")
		terrace.prepare()
		var asset_names: Array[String] = ["outer_wall", "inner_wall"]
		for width: int in [3,6,12,24]:
			for height: int in [4,8,12,16]: asset_names.append("wall_%dx%d" % [width,height])
		for key: String in asset_names:
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			assert(doc.append_from_file("res://assets/MythosCliffSiding/"+key+".glb",state)==OK)
			var source := doc.generate_scene(state)
			var combined := ArrayMesh.new()
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for child: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
				for i in child.mesh.get_surface_count(): surface.append_from(child.mesh,i,Transform3D.IDENTITY)
			surface.commit(combined)
			meshes[key] = combined
			if key.begins_with("wall_") and "--plants" in OS.get_cmdline_user_args(): plant_sites[key]=_plant_sites(combined)
			source.free()
		var material := load("res://terrain/environment/materials/mythos_mountains/limestone.tres") as ShaderMaterial
		var names := {"Walls":"wall", "OuterWalls":"outer_wall", "InnerWalls":"inner_wall"}
		var total := 0
		for node: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
			var role := ""
			for key: String in ["wall", "outer_wall", "inner_wall"]:
				var original := load("res://terrain/environment/visuals/kaykit/kaykit_cliff_"+key+".tres") as EnvironmentVisual
				var bounds := original.pieces[0].mesh.get_aabb()
				if node.multimesh.mesh.get_aabb().is_equal_approx(bounds) and node.multimesh.mesh.get_faces().size()==original.pieces[0].mesh.get_faces().size(): role=key
			if role.is_empty():
				if "--replace-stacks" in OS.get_cmdline_user_args():
					for id: StringName in terrace._pieces:
						if id==terrace.ROCK: continue
						var stock: Mesh = terrace._pieces[id][0]
						if node.multimesh.mesh.get_aabb().is_equal_approx(stock.get_aabb()) and node.multimesh.mesh.get_faces().size()==stock.get_faces().size(): node.visible=false
				continue
			if role == "wall":
				var poses := []
				for i in node.multimesh.instance_count: poses.append(node.multimesh.get_instance_transform(i))
				var panels := preload("res://scripts/terrain/field/CliffSiding.gd").panels(poses)
				for asset: String in panels:
					var mm := MultiMesh.new()
					mm.transform_format=MultiMesh.TRANSFORM_3D
					mm.mesh=meshes[asset]
					mm.instance_count=panels[asset].size()
					for i in mm.instance_count:
						mm.set_instance_transform(i,panels[asset][i])
						if plant_sites.has(asset):
							for point: Vector3 in plant_sites[asset]:
								var pos: Vector3 = node.global_transform*panels[asset][i]*point
								var scale_value := plants._rng.randf_range(.75,1.20)
								var pose := Transform3D(Basis(Vector3.UP,plants._rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale_value),pos-Vector3.UP*.05)
								plants._asset(plants.SOURCE+"Bush_Common.gltf",pose,"leaf")
					var child := MultiMeshInstance3D.new()
					child.multimesh=mm
					child.material_override=material
					world.add_child(child)
					child.global_transform=node.global_transform
				node.visible=false
			else:
				node.multimesh = node.multimesh.duplicate()
				# Retain the exact native corner socket in this experiment.
				node.multimesh.mesh = node.multimesh.mesh
				node.material_override = material
			total += node.multimesh.instance_count
		plants._flush()
		plants.free()
		assert(total>0,"The replacement must affect real production cliff instances")
		print("SIDING_PROTOTYPE_INSTANCES ",total)
	await super._capture_views(world)

func _plant_sites(mesh: Mesh) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var faces := mesh.get_faces()
	var bounds := mesh.get_aabb()
	var x := bounds.position.x+1.0
	while x<bounds.end.x-1.0:
		var best_point := Vector3.ZERO
		var best_y := -INF
		for z in [1.40,1.70,2.05,2.35]:
			var origin := Vector3(x,bounds.end.y+1,z)
			var hit_y := -INF
			var normal := Vector3.ZERO
			for i in range(0,faces.size(),3):
				var hit = Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
				if hit==null or hit.y<=hit_y: continue
				hit_y=hit.y
				normal=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
			if normal.y>.65 and hit_y>bounds.position.y+.8 and hit_y<bounds.end.y-.7 and hit_y>best_y:
				best_y=hit_y;best_point=Vector3(x,hit_y,z)
		if best_y>-INF: out.append(best_point)
		x+=2.3
	return out
