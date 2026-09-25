extends "res://tests/harness/september16_town_qa.gd"

func _capture_views(world: Node3D) -> void:
	var old := _read("05-town-rails/before-payload.bin")
	var before := _read("13-bridge-overlap/before-payload.bin")
	var after := _read("14-rail-fragments/after-payload.bin")
	await _apply_delta(world,old,before)
	var output := _output_dir
	_output_dir = output.path_join("before")
	await super._capture_views(world)
	await _apply_delta(world,before,after)
	_output_dir = output.path_join("after")
	await super._capture_views(world)
	_output_dir = output

func _read(path: String) -> Dictionary:
	return FileAccess.open("res://docs/qa/2026-09-16-manual/"+path,FileAccess.READ).get_var()

func _apply_delta(world: Node3D, before: Dictionary, after: Dictionary) -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var removed := 0
	for asset: StringName in before.batches:
		var batch: Dictionary = before.batches[asset]
		var keep: Array = after.batches.get(asset,{}).get("ids",[])
		for i in batch.ids.size():
			if batch.ids[i] in keep: continue
			for piece: EnvironmentVisualPiece in cache.visual(asset).pieces:
				var target: Transform3D = before.transform*batch.transforms[i]*piece.local_transform
				var matches := 0
				for node: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
					if not String(node.name).begins_with(piece.mesh.resource_path.get_file().get_basename().get_slice("_piece_",0)): continue
					var mm := node.multimesh.duplicate() as MultiMesh
					for index in mm.instance_count:
						var pose := node.global_transform*mm.get_instance_transform(index)
						if pose.origin.distance_to(target.origin)>.001: continue
						assert(pose.basis.is_equal_approx(target.basis),"Matched piece retains its native orientation")
						mm.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
						matches += 1
					node.multimesh = mm
				if matches!=1: get_tree().quit(1)
				assert(matches==1,"Each removed piece must match exactly once: %s"%batch.ids[i])
				removed += matches
	var added := EnvironmentInstancePayload.new()
	for asset: StringName in after.batches:
		var batch: Dictionary = after.batches[asset]
		var previous: Array = before.batches.get(asset,{}).get("ids",[])
		for i in batch.ids.size():
			if batch.ids[i] not in previous:
				added.add(asset,batch.transforms[i],batch.colors[i],batch.ids[i])
	var stage := Node3D.new()
	world.add_child(stage)
	stage.global_transform = after.transform
	cache.prepare(added.asset_ids())
	var queue := FeatureCommitQueue.new(cache)
	queue.enqueue(Vector2i.ZERO,1,stage,added)
	while queue.pending_count()>0:
		queue.drain(100000,100000,100000)
		await get_tree().process_frame
	var changed := 0
	for i in before.surface_meshes.size():
		var a: Dictionary = before.surface_meshes[i]
		var b: Dictionary = after.surface_meshes[i]
		if a==b: continue
		var matches := 0
		for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
			if node.mesh==null or node.mesh.get_surface_count()!=1: continue
			var arrays := node.mesh.surface_get_arrays(0)
			var existing: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if existing.size()!=a.vertices.size(): continue
			var local_pose: Transform3D = node.global_transform.affine_inverse()*before.transform
			var same := true
			for v in existing.size():
				if existing[v].distance_to(local_pose*a.vertices[v])>.001:
					same=false
					break
			if not same: continue
			arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=local_pose*(b.vertices as PackedVector3Array)
			var normals := PackedVector3Array()
			for normal: Vector3 in b.normals: normals.append((local_pose.basis.inverse().transposed()*normal).normalized())
			arrays[Mesh.ARRAY_NORMAL]=normals
			arrays[Mesh.ARRAY_TEX_UV]=b.uvs
			arrays[Mesh.ARRAY_INDEX]=b.indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			assert(mesh.get_surface_count()==1,"The replacement must have a valid native surface")
			mesh.surface_set_material(0,node.mesh.surface_get_material(0))
			node.mesh=mesh
			matches+=1
		if matches!=1: get_tree().quit(1)
		assert(matches==1,"Each changed generated mesh must match exactly once: %s"%a.stable_id)
		changed+=matches
	print("TOWN_REPAIR_REPLAY removed=",removed," added_assets=",added.asset_ids()," generated=",changed)
