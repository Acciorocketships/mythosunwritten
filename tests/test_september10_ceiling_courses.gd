extends GutTest
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")
const A = preload("res://scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd")

func test_photographed_stone_courses_do_not_hang_below_their_owned_band() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var plan := Frozen.spatial(Frozen.read("res://tests/fixtures/september10-ceiling-source.txt"),program).compiled_fabric_cache()
	var tx := A.maze_ground_skin_transaction(plan)
	var payload := A.terrace_retaining_payload(plan)
	var targets := [Vector4i(-2,3,-5,0), Vector4i(-2,3,-5,1), Vector4i(-2,3,-5,2), Vector4i(-2,3,-5,3), Vector4i(3,3,4,1), Vector4i(3,3,5,1)]
	var checked := 0
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		for index in batch.ids.size():
			var id := String(batch.ids[index])
			if not id.begins_with("maze-stone/"): continue
			var parts := id.split("/")
			var key := Vector4i(int(parts[1]),int(parts[2]),int(parts[3]),int(parts[4]))
			if key not in targets: continue
			assert_false(tx.shell.exposed.has(Vector4i(key.x,key.y-1,key.z,key.w)),"The lower face is not owned by this course")
			var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
			var low := INF
			for piece: EnvironmentVisualPiece in visual.pieces:
				for point: Vector3 in (batch.transforms[index] as Transform3D) * piece.local_transform * EnvironmentBakeGeometry.triangle_faces(piece.mesh):
					low = minf(low,point.y)
			assert_gte(low, float(key.y)*1.5-.17,"Actual masonry may meet the native board socket, but not hang an extra band below it: "+id)
			checked += 1
	assert_eq(checked,targets.size())

func test_garden_tunnel_turn_uses_city_stone_inside_the_native_grass_lip() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	for turn in [Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1),Vector2i(1,-1)]:
		var cell := Vector3i(0,3,0)
		var dx := Vector3i(turn.x,0,0)
		var dz := Vector3i(0,0,turn.y)
		var a := Vector4i(0,3,0,A.STONE_FACE_DIRECTIONS.find(dx))
		var b := Vector4i(0,3,0,A.STONE_FACE_DIRECTIONS.find(dz))
		var faces := {a:Vector3i.ZERO,b:Vector3i.ZERO}
		var exposed := faces.duplicate()
		exposed[Vector4i(0,2,0,a.w)] = true # Only this side owns the lower band.
		var treatments := {a:A.SkinTreatment.MASONRY,b:A.SkinTreatment.MASONRY}
		var payload := A.maze_stone_walls({}, {}, {}, {}, {},
			{"faces":faces,"exposed":exposed,"treatments":treatments},0,{cell:true},[],program.asset_wall_interfaces)
		var entries := []
		for asset: StringName in payload.batches:
			var batch: Dictionary = payload.batches[asset]
			var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
			for index in batch.ids.size():
				var triangles := PackedVector3Array()
				for piece: EnvironmentVisualPiece in visual.pieces:
					triangles.append_array((batch.transforms[index] as Transform3D)*piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh))
				entries.append({"id":String(batch.ids[index]),"asset":asset,"triangles":triangles})
		for mesh: Dictionary in payload.surface_meshes:
			var source: Dictionary = program.asset_wall_interfaces[A.MAZE_STONE_MODULE].complete_surfaces[0]
			var original_uvs := PackedVector2Array()
			for vertex: Dictionary in source.triangles: original_uvs.append(vertex.uv)
			assert_eq(mesh.uvs,original_uvs,"Every native face and UV survives the rounded fitting")
			var degenerate := 0
			for i in range(0,(mesh.vertices as PackedVector3Array).size(),3):
				if ((mesh.vertices[i+1] as Vector3)-(mesh.vertices[i] as Vector3)).cross((mesh.vertices[i+2] as Vector3)-(mesh.vertices[i] as Vector3)).length_squared()<1e-18: degenerate+=1
			assert_eq(degenerate,0,"Fitting cannot collapse a source face or its end closure")
			entries.append({"id":String(mesh.stable_id),"asset":StringName(mesh.material_asset_id),"triangles":mesh.vertices})
		assert_eq(entries.size(),2,"Each side keeps its own owned height at the turn")
		var grass_visual: EnvironmentVisual = load(catalog.descriptor(A.GREEN_RIM_OUTER_CORNER).visual_path)
		var grass_faces := PackedVector3Array()
		for piece: EnvironmentVisualPiece in grass_visual.pieces:
			grass_faces.append_array(A._maze_green_rim_corner_transform(cell,turn)*piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh))
		for entry: Dictionary in entries:
			assert_eq(entry.asset,A.MAZE_STONE_MODULE,"The tunnel and garden share the city's masonry stock")
			var low := INF
			var outside := 0
			for point: Vector3 in entry.triangles:
				low = minf(low,point.y)
				# Classify a shared float32 silhouette edge within one micrometre.
				# This changes the ray witness, never a source or fitted vertex.
				var covered := false
				for triangle in range(0,grass_faces.size(),3):
					var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(point.x*(1.0-0.000001),7,point.z*(1.0-0.000001)),Vector3.DOWN,grass_faces[triangle],grass_faces[triangle+1],grass_faces[triangle+2])
					if hit != null and (hit as Vector3).y >= point.y-0.0001:
						covered = true
						break
				if not covered: outside += 1
			assert_eq(outside,0,"Actual native stone stays beneath the complete rounded grass silhouette")
			var is_short := int(String(entry.id).split("/")[4]) == b.w
			assert_almost_eq(low,4.45 if is_short else 2.95,0.001,"The corner does not borrow the other side's lower band")

func test_a_short_neighbor_course_cannot_own_a_full_facade_miter() -> void:
	var east := A.STONE_FACE_DIRECTIONS.find(Vector3i.RIGHT)
	var south := A.STONE_FACE_DIRECTIONS.find(Vector3i.BACK)
	var facade := Vector4i(0,1,0,east)
	var stone := Vector4i(0,1,0,south)
	var faces := {facade:Vector3i.ZERO,stone:Vector3i.ZERO}
	var exposed := faces.duplicate()
	exposed[Vector4i(0,0,0,east)] = true
	var treatments := {facade:A.SkinTreatment.FACADE,stone:A.SkinTreatment.MASONRY}
	var payload := A.maze_stone_walls({}, {}, {}, {}, {},
		{"faces":faces,"exposed":exposed,"treatments":treatments})
	var checked := 0
	for asset: StringName in payload.batches:
		for id: StringName in payload.batches[asset].ids:
			if String(id) != "maze-stone/0/1/0/%d"%east: continue
			assert_false(String(asset).contains("retaining_miter"),"The absent lower stone band cannot remove the facade's full-height native end")
			checked += 1
	assert_eq(checked,1)
