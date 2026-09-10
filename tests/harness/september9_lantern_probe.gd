extends SceneTree
func _init() -> void:
	var result: Dictionary = {}
	for id: StringName in [&"sfv.light_pole.001",&"lpfv.fabric.prop.lantern.table.01",&"lpfv.fabric.prop.lantern.post.02"]:
		var descriptor := EnvironmentCatalog.load_default().descriptor(id)
		var visual := load(descriptor.visual_path) as EnvironmentVisual
		var rows: Array = []
		for piece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var material := piece.mesh.surface_get_material(surface) as StandardMaterial3D
				var arrays := piece.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bounds := AABB(piece.local_transform*vertices[0],Vector3.ZERO)
				for vertex in vertices: bounds=bounds.expand(piece.local_transform*vertex)
				rows.append({"surface":surface,"bounds":str(bounds),"emission":material.emission_enabled if material!=null else false,"uvs":str((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).slice(0,12))})
		result[id]=rows
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(result)
	quit()
