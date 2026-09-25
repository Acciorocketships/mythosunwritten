extends SceneTree
func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for id in [&"lpfv.fabric.roof.compact.orange.03.rear.end.tight", &"lpfv.fabric.roof.compact.orange.06.front.end.tight", &"lpfv.fabric.roof.compact.orange.03.run.end.tight"]:
		var visual: EnvironmentVisual = load(catalog.descriptor(id).visual_path)
		var z_faces := {}
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var arrays := piece.mesh.surface_get_arrays(surface)
				var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for j in range(0, vs.size() if ids.is_empty() else ids.size(),3):
					var a := piece.local_transform * vs[j if ids.is_empty() else ids[j]]
					var b := piece.local_transform * vs[j+1 if ids.is_empty() else ids[j+1]]
					var c := piece.local_transform * vs[j+2 if ids.is_empty() else ids[j+2]]
					var normal := (b-a).cross(c-a).normalized()
					if absf(normal.z)>.999:
						var key := snappedf(a.z,0.0001)
						var record: Array = z_faces.get(key,[0,INF,-INF,INF,-INF])
						record[0]+=1
						for v in [a,b,c]:
							record[1]=minf(record[1],v.y);record[2]=maxf(record[2],v.y);record[3]=minf(record[3],v.x);record[4]=maxf(record[4],v.x)
						z_faces[key]=record
		print(id," ",z_faces)
	quit()
