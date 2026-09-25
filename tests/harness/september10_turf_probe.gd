extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://tests/fixtures/september10-"+("skywalk" if "--skywalk" in OS.get_cmdline_user_args() else "stone")+"-source.txt"), program).compiled_fabric_cache()
	var a = SettlementFabricAssembler
	var tx := a.maze_ground_skin_transaction(fabric)
	print("PLAZA ",fabric.planned_plaza_cells," SUSPENDED ",tx.suspended_plaza)
	var region := a.maze_terrain_surface_region(tx.capped_ground,a.maze_terrain_control_surface_cells(fabric))
	var layout := a.maze_green_rim_layout(tx.shell,tx.walked,tx.paved,tx.footprints,tx.capped_ground,true,region,tx.suspended_plaza)
	print("LAYOUT ",layout)
	for cell:Vector3i in tx.capped_ground:
		print("TURF ",cell," below ",fabric.retained_terrace_cells.has(cell+Vector3i.DOWN)," solidbelow ",tx.solids.has(cell+Vector3i.DOWN)," above ",tx.solids.has(cell+Vector3i.UP))
	var payload := a.terrace_retaining_payload(fabric)
	var catalog := EnvironmentCatalog.load_default()
	for cell:Vector3i in tx.capped_ground:
		var p := Vector3(cell)*1.5+Vector3(.13,1.5,.17)
		var hits:Array=[]
		for mesh:Dictionary in payload.surface_meshes:
			for i in range(0,(mesh.indices as PackedInt32Array).size(),3):
				var hit:Variant=Geometry3D.segment_intersects_triangle(p+Vector3.UP*.05,p-Vector3.UP*.5,mesh.vertices[mesh.indices[i]],mesh.vertices[mesh.indices[i+1]],mesh.vertices[mesh.indices[i+2]])
				if hit!=null:hits.append([hit.y,mesh.stable_id])
		for asset:StringName in payload.batches:
			var batch:Dictionary=payload.batches[asset]
			var visual:EnvironmentVisual=load(catalog.descriptor(asset).visual_path)
			for j in batch.transforms.size():
				var pose:Transform3D=batch.transforms[j]
				if not (pose*catalog.descriptor(asset).measured_aabb).grow(.05).has_point(p):continue
				for piece:EnvironmentVisualPiece in visual.pieces:
					var faces:=pose*piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh)
					for i in range(0,faces.size(),3):
						var hit:Variant=Geometry3D.segment_intersects_triangle(p+Vector3.UP*.05,p-Vector3.UP*.5,faces[i],faces[i+1],faces[i+2])
						if hit!=null:hits.append([hit.y,batch.ids[j]])
		if hits.size()<2: print("THIN_SOIL ",cell," ",hits)
		else: print("SOIL_RAYS ",cell," ",hits)
	quit()
