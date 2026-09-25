extends SceneTree

func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var result := {}
	for id in [SettlementFabricProgram.ROOF_BLUE,
			SettlementFabricProgram.ROOF_BISECT_LEFT_BLUE,
			SettlementFabricProgram.ROOF_BISECT_RIGHT_BLUE]:
		var visual: EnvironmentVisual = load(catalog.descriptor(id).visual_path)
		var triangles := []
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var arrays := piece.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for index in range(0, vertices.size() if indices.is_empty() else indices.size(), 3):
					var triangle := []
					for corner in 3:
						var vertex := piece.local_transform * vertices[index + corner if indices.is_empty() else indices[index + corner]]
						triangle.append([vertex.x, vertex.y, vertex.z])
					triangles.append(triangle)
		result[id] = triangles
	var recipe := program.recipe(&"roof.building.blue.valley.p0.positive")
	for placement in recipe.placements:
		print(placement)
	FileAccess.open("/tmp/roof-valley-native.json", FileAccess.WRITE).store_string(JSON.stringify(result))
	quit()
