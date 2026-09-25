extends SceneTree
func _init() -> void:
	var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/09-upper-wall/after-payload.bin",FileAccess.READ).get_var()
	var catalog := EnvironmentCatalog.load_default()
	var rows := []
	for asset: StringName in data.batches:
		if not ("barrel" in String(asset) or "bucket" in String(asset)): continue
		var batch: Dictionary = data.batches[asset]
		for index in batch.transforms.size():
			var frame: Transform3D = data.transform*batch.transforms[index]
			var bounds: AABB = frame*catalog.descriptor(asset).measured_aabb
			rows.append({"id":str(batch.ids[index]),"asset":str(asset),"transform":str(frame),"bounds":str(bounds)})
	print("BARREL_OWNERS ",JSON.stringify(rows))
	var start := Vector3(965.0054,35,-431.5)
	var floor_hits := []
	for asset: StringName in data.batches:
		if "barrel" in String(asset): continue
		var batch: Dictionary = data.batches[asset]
		for index in batch.transforms.size():
			var frame: Transform3D = data.transform*batch.transforms[index]
			if (frame*catalog.descriptor(asset).measured_aabb).intersects_ray(start,Vector3.DOWN) == null: continue
			var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
			for piece: EnvironmentVisualPiece in visual.pieces:
				var faces := EnvironmentBakeGeometry.triangle_faces(piece.mesh,frame*piece.local_transform)
				for i in range(0,faces.size(),3):
					var hit = Geometry3D.ray_intersects_triangle(start,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
					if hit != null: floor_hits.append({"asset":str(asset),"id":str(batch.ids[index]),"point":str(hit)})
	for mesh: Dictionary in data.surface_meshes:
		var vertices: PackedVector3Array = mesh.vertices
		var indices: PackedInt32Array = mesh.indices
		for i in range(0,indices.size(),3):
			var hit = Geometry3D.ray_intersects_triangle(start,Vector3.DOWN,data.transform*vertices[indices[i]],data.transform*vertices[indices[i+1]],data.transform*vertices[indices[i+2]])
			if hit != null: floor_hits.append({"surface":str(mesh.get("stable_id","")),"claims":str(mesh.get("claim_cells",[])),"point":str(hit)})
	print("BARREL_FLOORS ",JSON.stringify(floor_hits))
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/09-upper-wall/current-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var transaction := SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	print("BARREL_TRANSACTION_KEYS ",transaction.keys())
	for key in transaction:
		if "frontage" in String(key): print("BARREL_SITES ",key," ",var_to_str(transaction[key]))
	var local_point: Vector3 = data.transform.affine_inverse()*Vector3(965.0054,21.955,-431.5)
	var walked := SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)
	var nearby := []
	for cell: Vector3i in walked:
		if (Vector3(cell)*FabricRecipe.CELL_SIZE-local_point).length()<5: nearby.append(cell)
	print("BARREL_LOCAL_POINT ",local_point," WALKED ",nearby)
	quit()
