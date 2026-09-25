extends SceneTree
func _init() -> void:
	var before: Dictionary = FileAccess.open("res://docs/qa/2026-09-10-manual/09-roofs/native-before.bin",FileAccess.READ).get_var()
	var catalog := EnvironmentCatalog.load_default()
	var report := {}
	for id: String in before:
		var visual: EnvironmentVisual = load(catalog.descriptor(StringName(id)).visual_path)
		var surfaces := []
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count(): surfaces.append(piece.mesh.surface_get_arrays(surface))
		var same: bool = surfaces.size()==before[id].size()
		var count := 0
		var moved := 0
		var degenerate := 0
		for j in surfaces.size():
			var old: Array = before[id][j]
			var now: Array = surfaces[j]
			var old_ids: PackedInt32Array = old[Mesh.ARRAY_INDEX]
			var ids: PackedInt32Array = now[Mesh.ARRAY_INDEX]
			var old_vs: PackedVector3Array = old[Mesh.ARRAY_VERTEX]
			var vs: PackedVector3Array = now[Mesh.ARRAY_VERTEX]
			var n := vs.size() if ids.is_empty() else ids.size()
			same=same and n==(old_vs.size() if old_ids.is_empty() else old_ids.size())
			for k in n:
				var oi := k if old_ids.is_empty() else old_ids[k]
				var ni := k if ids.is_empty() else ids[k]
				var a := old_vs[oi]
				var b := vs[ni]
				same=same and absf(a.x-b.x)<0.000001 and absf(a.y-b.y)<0.000001 and old[Mesh.ARRAY_TEX_UV][oi]==now[Mesh.ARRAY_TEX_UV][ni]
				if absf(a.z)<0.00001 or absf(absf(a.z)-1.5)<0.00001 or (id.ends_with(".flush") and absf(absf(a.z)-0.75)<0.00001): same=same and absf(a.z-b.z)<0.000001
				if absf(a.z-b.z)>0.000001:moved+=1
				count+=1
			for k in range(0,n,3):
				var a := vs[k if ids.is_empty() else ids[k]]
				var b := vs[k+1 if ids.is_empty() else ids[k+1]]
				var c := vs[k+2 if ids.is_empty() else ids[k+2]]
				if (b-a).cross(c-a).length_squared()<1e-16: degenerate+=1
		assert(same)
		assert(degenerate==0)
		report[id]={"native_stream_vertices":count,"longitudinal_vertices_moved":moved,"xy_uv_boundaries_preserved":same,"degenerate_triangles":degenerate}
	FileAccess.open("res://docs/qa/2026-09-10-manual/09-roofs/native-preservation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ROOF_PRESERVATION ",report)
	quit()
