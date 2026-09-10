extends GutTest

func test_photographed_outcrop_end_has_one_visible_surface_owner() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program).compiled_fabric_cache()
	var payload := SettlementFabricAssembler.structural_support_payload(fabric)
	var town := Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(238.5,8.08,-365.5))
	var origin := Vector3(227.9064,16.1,-368.0)
	var ray := (Vector3(228.938,15.0561,-379.0019)-origin).normalized()
	var hits := _hits(payload,catalog,town,origin,ray)
	assert_gt(hits.size(),0,"The outcrop end must remain closed")
	if hits.is_empty(): return
	var owners := 0
	for distance:float in hits:
		if absf(distance-hits[0])<0.001: owners+=1
	assert_eq(owners,1,"Photo 8 corner stock and front panel may not compete for the same visible end face")

func test_photographed_floor_edge_has_one_visible_surface_owner() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://tests/fixtures/september8-night-center-source.txt"),program).compiled_fabric_cache()
	var payload := SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	var town := Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(352.5,20.08,498.5))
	var origin := Vector3(355.5507,34.1,510.0482)
	var ray := (Vector3(357.4565,31.98163,503.0)-origin).normalized()
	var hits := _hits(payload,catalog,town,origin,ray)
	assert_gt(hits.size(),0,"The floor perimeter must stay closed")
	if hits.is_empty(): return
	var owners := 0
	for distance:float in hits:
		if absf(distance-hits[0])<0.001: owners+=1
	assert_eq(owners,1,"Photo 14 room floor owns the exact edge shared with a ledge cap")


func _hits(payload:EnvironmentInstancePayload,catalog:EnvironmentCatalog,town:Transform3D,
		origin:Vector3,ray:Vector3)->Array[float]:
	var hits:Array[float]=[]
	for asset:StringName in payload.batches:
		var batch:Dictionary=payload.batches[asset]
		var visual:EnvironmentVisual=load(catalog.descriptor(asset).visual_path)
		for placement:Transform3D in batch.transforms:
			var pose:=town*placement
			if (pose*catalog.descriptor(asset).measured_aabb).intersects_ray(origin,ray)==null:continue
			var nearest:=INF
			for piece:EnvironmentVisualPiece in visual.pieces:
				var faces:=pose*piece.local_transform*piece.mesh.get_faces()
				for k in range(0,faces.size(),3):
					var hit=Geometry3D.ray_intersects_triangle(origin,ray,faces[k],faces[k+1],faces[k+2])
					if hit!=null:nearest=minf(nearest,origin.distance_to(hit))
			if nearest<INF:hits.append(nearest)
	for mesh:Dictionary in payload.surface_meshes:
		var points:PackedVector3Array=town*(mesh.vertices as PackedVector3Array)
		var indices:PackedInt32Array=mesh.indices
		var nearest:=INF
		for k in range(0,indices.size(),3):
			var hit=Geometry3D.ray_intersects_triangle(origin,ray,points[indices[k]],points[indices[k+1]],points[indices[k+2]])
			if hit!=null:nearest=minf(nearest,origin.distance_to(hit))
		if nearest<INF:hits.append(nearest)
	hits.sort()
	return hits

func test_every_removed_jetty_end_is_closed_by_its_authored_corner_stock() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var assets := {}
	for pool:Array[StringName] in [SettlementFabricProgram.WOOD_CELL_FACADE_BLUE,
			SettlementFabricProgram.WOOD_CELL_FACADE_ORANGE,SettlementFabricProgram.WOOD_CELL_FACADE_AMBER]:
		for asset:StringName in pool: assets[asset]=true
	var corner:EnvironmentVisual=load(catalog.descriptor(SettlementFabricAssembler.FACADE_OUTCROP_POST).visual_path)
	for asset:StringName in assets:
		var source:EnvironmentVisual=load(catalog.descriptor(asset).visual_path)
		for end in 2:
			var sign := -1.0 if end==0 else 1.0
			var half := SettlementFabricAssembler.FACADE_OUTCROP_POST_HALF
			var corner_pose := Transform3D(Basis.IDENTITY,Vector3(sign*(0.75-half),0,half))
			var closed := true
			var samples := 0
			for piece:EnvironmentVisualPiece in source.pieces:
				var faces:=piece.local_transform*piece.mesh.get_faces()
				for k in range(0,faces.size(),3):
					if absf(faces[k].x-sign*0.75)>0.002 or absf(faces[k+1].x-sign*0.75)>0.002 \
							or absf(faces[k+2].x-sign*0.75)>0.002:continue
					var point:Vector3=(faces[k]+faces[k+1]+faces[k+2])/3.0
					point.z+=SettlementFabricAssembler.FACADE_BUMP_REACH-SettlementFabricAssembler.FACADE_FRONT_DEPTH
					var origin:=Vector3(sign*2.0,point.y,point.z)
					var found:=false
					for post_piece:EnvironmentVisualPiece in corner.pieces:
						var post_faces:=corner_pose*post_piece.local_transform*post_piece.mesh.get_faces()
						for j in range(0,post_faces.size(),3):
							if Geometry3D.ray_intersects_triangle(origin,Vector3(-sign,0,0),post_faces[j],post_faces[j+1],post_faces[j+2])!=null:
								found=true
					closed=closed and found
					samples+=1
			if samples == 0:
				# Some authored panels already have an open positive-X end.
				var joined:EnvironmentVisual=load(catalog.descriptor(StringName("%s.outcrop_end%d" % [asset,1<<end])).visual_path)
				assert_eq(joined.pieces[0].mesh.get_faces().size(),source.pieces[0].mesh.get_faces().size(),
					"An already-open stock end must not lose unrelated triangles")
			assert_true(closed,"%s end %d retains a real corner surface across the omitted cap" % [asset,end])
