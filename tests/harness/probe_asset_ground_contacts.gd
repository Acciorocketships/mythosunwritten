extends SceneTree

const ASSETS: Array[StringName] = [
	&"sfv.building.interior.blue.001",
	&"sfv.building.interior.blue.002",
	&"sfv.building.interior.blue.005",
	&"sfv.building.interior.blue.006",
	&"aws.building.003",
	&"sft.building.001",
]


func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	assert(cache.prepare(ASSETS))
	for asset_id: StringName in ASSETS:
		var visual := cache.visual(asset_id)
		var vertices: Array[Vector3] = []
		var minimum_y := INF
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface_index in piece.mesh.get_surface_count():
				var arrays := piece.mesh.surface_get_arrays(surface_index)
				var surface_vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				for local_vertex: Vector3 in surface_vertices:
					var vertex := piece.local_transform * local_vertex
					vertices.append(vertex)
					minimum_y = minf(minimum_y, vertex.y)
		var contact_cells: Dictionary = {}
		for vertex: Vector3 in vertices:
			if vertex.y <= minimum_y + 0.35:
				contact_cells[Vector2i(roundi(vertex.x / 1.5),
					roundi(vertex.z / 1.5))] = true
		var cells: Array = contact_cells.keys()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y if a.y != b.y else a.x < b.x)
		print("%s min_y=%.3f contacts=%d %s" % [asset_id, minimum_y,
			cells.size(), cells])
	quit()
