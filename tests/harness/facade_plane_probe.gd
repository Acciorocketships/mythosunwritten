extends SceneTree

func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for asset in ["sfv.fabric.wall.rock.door.closed.005", "sfv.fabric.wall.rock.window.m.016", "sfv.fabric.wall.wood.door.closed.001", "sfv.fabric.wall.wood.window.001"]:
		var descriptor := catalog.descriptor(StringName(asset))
		if descriptor == null:
			continue
		var visual: EnvironmentVisual = load(descriptor.visual_path)
		var areas := {}
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var arrays := piece.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for offset in range(0, indices.size(), 3):
					var a := vertices[indices[offset]]
					var b := vertices[indices[offset+1]]
					var c := vertices[indices[offset+2]]
					if maxf(absf(a.z-b.z), absf(a.z-c.z)) > 0.001:
						continue
					var z := snappedf(a.z,0.001)
					areas[z] = float(areas.get(z,0.0)) + (b-a).cross(c-a).length()*0.5
		var keys := areas.keys()
		keys.sort_custom(func(a,b): return areas[a] > areas[b])
		print(asset)
		for index in mini(12,keys.size()):
			print(keys[index], " area=", areas[keys[index]])
	quit()
