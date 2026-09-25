extends SceneTree
func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var records := []
	for asset: StringName in [SettlementFabricProgram.ROOF_WINDOW_02,SettlementFabricProgram.ROOF_WINDOW_03,SettlementFabricProgram.ROOF_WINDOW_04]:
		var visual := load(catalog.descriptor(asset).visual_path) as EnvironmentVisual
		var surfaces := []
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var arrays := piece.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var points := []
				for i in (indices.size() if not indices.is_empty() else vertices.size()):
					var v := piece.local_transform*vertices[indices[i] if not indices.is_empty() else i]
					points.append([v.x,v.y,v.z])
				surfaces.append({"material":piece.mesh.surface_get_material(surface).resource_name,"faces":points})
		records.append({"asset":str(asset),"surfaces":surfaces})
	FileAccess.open("res://docs/qa/2026-09-13-manual/41-dormers/native-windows.json",FileAccess.WRITE).store_string(JSON.stringify(records))
	quit()
