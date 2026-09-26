extends SceneTree
## Rebuild worker-side triangle data from the catalog after changing kit assets.
func _init() -> void:
	var kit := SuntailBuildingKit.create()
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var data := {}
	for role: StringName in kit.roles:
		if not (String(role).begins_with("roof.") or String(role).begins_with("gable.") or String(role).begins_with("trim.")):
			continue
		for id: StringName in kit.roles[role]:
			if data.has(id): continue
			var visual := cache.visual(id)
			var surfaces: Array = []
			for pi in visual.pieces.size():
				var piece: EnvironmentVisualPiece = visual.pieces[pi]
				for si in piece.mesh.get_surface_count():
					var a := piece.mesh.surface_get_arrays(si)
					var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
					for i in vertices.size():
						vertices[i] = piece.local_transform * vertices[i]
						normals[i] = (piece.local_transform.basis.inverse().transposed() * normals[i]).normalized()
					var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
					if indices.is_empty():
						for i in vertices.size(): indices.append(i)
					surfaces.append({"vertices": vertices, "normals": normals, "uvs": a[Mesh.ARRAY_TEX_UV], "indices": indices, "piece": pi, "surface": si})
			data[id] = surfaces
	var file := FileAccess.open("res://terrain/environment/geometry/suntail_roofs.bin", FileAccess.WRITE)
	file.store_var(data)
	print("BAKED_ROOFS ", data.size())
	quit()
