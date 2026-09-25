extends SceneTree
func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var original: Dictionary = FileAccess.open("res://docs/qa/2026-09-10-manual/09-roofs/native-before.bin",FileAccess.READ).get_var()
	var planes := {}
	for family in ["orange","slate"]:
		for side in ["start","end"]:
			var id := "lpfv.fabric.roof.compact.%s.03.run.%s.tight.flush" % [family,side]
			var visual: EnvironmentVisual = load(catalog.descriptor(StringName(id)).visual_path)
			var faces := EnvironmentBakeGeometry.triangle_faces(visual.pieces[0].mesh)
			var sign_z := -1.0 if side=="start" else 1.0
			var plane := 0.0
			for i in range(0,faces.size(),3):
				var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(0.5,0.8,sign_z*1.501),Vector3(0.5,0.8,sign_z*0.749),faces[i],faces[i+1],faces[i+2])
				if hit!=null:plane=maxf(plane,sign_z*(hit as Vector3).z)
			planes[id]=plane
			var arrays := []
			for surface in visual.pieces[0].mesh.get_surface_count(): arrays.append(visual.pieces[0].mesh.surface_get_arrays(surface))
			original[id]=arrays
	FileAccess.open("res://docs/qa/2026-09-10-manual/09-roofs/native-before.bin",FileAccess.WRITE).store_var(original)
	FileAccess.open("res://docs/qa/2026-09-10-manual/09-roofs/flush-probe-before.json",FileAccess.WRITE).store_string(JSON.stringify(planes,"  "))
	print("FLUSH_PLANES ",planes)
	quit()
