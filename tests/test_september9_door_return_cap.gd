extends GutTest

func test_photographed_window_return_closes_its_native_cut_face() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var asset := &"sfv.fabric.wall.wood.window.013.mirror_x.doorreturn.back1070858.square"
	var visual: EnvironmentVisual=load(catalog.descriptor(asset).visual_path)
	var faces := PackedVector3Array()
	for piece: EnvironmentVisualPiece in visual.pieces:faces.append_array(piece.local_transform*piece.mesh.get_faces())
	var cut := -1.5+1.07085800170898
	for y in [0.4,1.0,1.6,2.2,2.8]:
		for z in [-0.2,0.0,0.2]:
			var hit := false
			for i in range(0,faces.size(),3):
				if Geometry3D.segment_intersects_triangle(Vector3(cut-.01,y,z),Vector3(cut+.01,y,z),faces[i],faces[i+1],faces[i+2])!=null:hit=true;break
			assert_true(hit,"The exposed return end needs a real cut face at y=%.1f z=%.1f"%[y,z])

func test_both_window_hands_and_floor_owned_variants_have_closed_returns() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/environment_bake/manifests/fantasy_village_door_returns.json"))
	var checked := 0
	for entry: Dictionary in manifest.assets:
		if not String(entry.id).begins_with("sfv.fabric.wall.wood.window.013"):continue
		for suffix in ["", ".course_open"]:
			var visual: EnvironmentVisual=load(catalog.descriptor(StringName(String(entry.id)+suffix)).visual_path)
			var faces := PackedVector3Array()
			for piece: EnvironmentVisualPiece in visual.pieces:faces.append_array(piece.local_transform*piece.mesh.get_faces())
			for end in 2:
				var depth := float(entry.facade_return_depths[end])
				if depth<=0.0:continue
				var cut := -1.5+depth if end==0 else 1.5-depth
				for turn in 4:
					var pose:=Transform3D(Basis(Vector3.UP,float(turn)*PI/2),Vector3(10,4,7))
					var rotated:=pose*faces
					for y in [0.4,1.0,1.6,2.2,2.8]:
						var hit:=false
						for i in range(0,rotated.size(),3):
							if Geometry3D.segment_intersects_triangle(pose*Vector3(cut-.01,y,0),pose*Vector3(cut+.01,y,0),rotated[i],rotated[i+1],rotated[i+2])!=null:hit=true;break
						assert_true(hit,"%s%s end %d turn %d height %.1f must close"%[entry.id,suffix,end,turn,y])
			checked+=1
	assert_eq(checked,20)

func test_closed_return_vertices_stay_inside_the_declared_cut_planes() -> void:
	var catalog:=EnvironmentCatalog.load_default()
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/environment_bake/manifests/fantasy_village_door_returns.json"))
	var checked:=0
	for entry:Dictionary in manifest.assets:
		if not entry.has("facade_miter_cap_source"):continue
		var depths:Array=entry.facade_return_depths
		var source_id:=StringName(String(entry.id).split(".doorreturn.")[0])
		# Native ArrayMesh decoding can extend tens of micrometres past its
		# stored AABB. Compare real source vertices, not that metadata box.
		var source_visual:EnvironmentVisual=load(catalog.descriptor(source_id).visual_path)
		var source_min:=Vector3.INF
		var source_max:=-Vector3.INF
		for piece:EnvironmentVisualPiece in source_visual.pieces:
			for vertex:Vector3 in piece.local_transform*piece.mesh.get_faces():
				source_min=source_min.min(vertex)
				source_max=source_max.max(vertex)
		var original:=AABB(source_min,source_max-source_min).grow(0.000001)
		for suffix in ["", ".course_open"]:
			var visual:EnvironmentVisual=load(catalog.descriptor(StringName(String(entry.id)+suffix)).visual_path)
			var contained:=true
			for piece:EnvironmentVisualPiece in visual.pieces:
				for vertex:Vector3 in piece.local_transform*piece.mesh.get_faces():
					contained=contained and original.has_point(vertex)
					if float(depths[0])>0:contained=contained and vertex.x>=-1.5+float(depths[0])-0.000001
					if float(depths[1])>0:contained=contained and vertex.x<=1.5-float(depths[1])+0.000001
			assert_true(contained,"%s%s: actual vertices stay within the native stock and exact return planes"%[entry.id,suffix])
			checked+=1
	assert_eq(checked,674)
