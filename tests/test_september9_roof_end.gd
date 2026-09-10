extends GutTest

func test_flush_roof_ends_retain_the_actual_native_gable_wall() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for theme in ["orange", "slate"]:
		for end_name in ["start", "end"]:
			for tight in ["", ".tight"]:
				var asset := StringName("lpfv.fabric.roof.compact.%s.03.run.%s%s.flush" % [theme,end_name,tight])
				var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
				var faces := PackedVector3Array()
				for piece: EnvironmentVisualPiece in visual.pieces:
					faces.append_array(_faces(piece.mesh,piece.local_transform))
				var sign_z := -1.0 if end_name == "start" else 1.0
				for x in [-0.6,0.0,0.6]:
					for y in [0.4,0.8,1.2]:
						var from := Vector3(x,y,sign_z*1.501)
						var to := Vector3(x,y,sign_z*0.751)
						assert_true(_hits(faces,from,to),"%s must close the gable at x=%.1f y=%.1f" % [asset,x,y])
				for vertex: Vector3 in faces:
					assert_lte(absf(vertex.z),1.50001)
					assert_gte(sign_z*vertex.z,0.74999)

func _hits(faces: PackedVector3Array, from: Vector3, to: Vector3) -> bool:
	for i in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(from,to,faces[i],faces[i+1],faces[i+2]) != null: return true
	return false

func _faces(mesh: Mesh, pose: Transform3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in (vertices.size() if indices.is_empty() else indices.size()):
			result.append(pose * vertices[i if indices.is_empty() else indices[i]])
	return result

func test_fitted_end_preserves_native_cross_section_and_texture_channels() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for theme in ["orange", "slate"]:
		for end_name in ["start", "end"]:
			for tight in ["", ".tight"]:
				var base := "lpfv.fabric.roof.compact.%s.03.run.%s%s" % [theme,end_name,tight]
				var source: EnvironmentVisual = load(catalog.descriptor(StringName(base)).visual_path)
				var result: EnvironmentVisual = load(catalog.descriptor(StringName(base+".flush")).visual_path)
				var source_mesh := source.pieces[0].mesh
				var result_mesh := result.pieces[0].mesh
				var old_bounds := source_mesh.get_aabb()
				var new_bounds := result_mesh.get_aabb()
				assert_almost_eq(new_bounds.position.y,old_bounds.position.y,0.000001)
				assert_almost_eq(new_bounds.end.y,old_bounds.end.y,0.000001)
				assert_eq(result_mesh.get_surface_count(),source_mesh.get_surface_count())
				for surface in source_mesh.get_surface_count():
					var before := _stream(source_mesh.surface_get_arrays(surface))
					var after := _stream(result_mesh.surface_get_arrays(surface))
					assert_eq(after.size(),before.size(),"The complete authored end retains every triangle")
					if after.size()!=before.size(): continue
					var preserved := true
					for i in before.size():
						var b: Vector3 = before[i][0]
						var a: Vector3 = after[i][0]
						var expected_z := new_bounds.position.z + (b.z-old_bounds.position.z) * new_bounds.size.z / old_bounds.size.z
						preserved = preserved and absf(a.x-b.x)<0.000001 and absf(a.y-b.y)<0.000001 and absf(a.z-expected_z)<0.000001 and after[i][1]==before[i][1]
					assert_true(preserved,"%s keeps native X/Y, all UVs and the inner seam; only Z fits" % base)

func _stream(arrays: Array) -> Array:
	var result: Array = []
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in (vertices.size() if indices.is_empty() else indices.size()):
		var index := i if indices.is_empty() else indices[i]
		result.append([vertices[index],uv[index]])
	return result
