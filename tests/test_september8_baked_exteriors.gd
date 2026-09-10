extends GutTest

func test_miter_cut_is_closed_without_changing_the_retained_stock() -> void:
	var node := Node3D.new()
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size=Vector3(3,3,0.6)
	instance.mesh=box
	instance.position.y=1.5
	node.add_child(instance)
	var source:=EnvironmentBakeGeometry.merge_pieces(node,Transform3D.IDENTITY)
	var material:=StandardMaterial3D.new()
	material.cull_mode=BaseMaterial3D.CULL_BACK
	var plane:=Plane(Vector3.RIGHT,0)
	var open:=EnvironmentBakeGeometry.clip_half_space(source,plane)
	var closed:=EnvironmentBakeGeometry.closed_facade_miter(source,plane,material,Vector2(0.2,0.3))
	var from:=Vector3(0.1,1.5,0)
	var to:=Vector3(-0.1,1.5,0)
	assert_false(_hits(open,from,to),"The former open cut exposes the neighboring backing")
	assert_true(_hits(closed,from,to),"The finished timber cut closes the same stock")
	assert_almost_eq(open.get_aabb().position,closed.get_aabb().position,Vector3.ONE*0.00002)
	assert_almost_eq(open.get_aabb().end,closed.get_aabb().end,Vector3.ONE*0.00002,
		"Allow only the engine minimum extent of a planar mesh")
	for v:Vector3 in EnvironmentBakeGeometry.triangle_faces(closed):
		assert_lte(v.x,0.00001)
		assert_true(source.get_aabb().grow(0.00001).has_point(v))
	node.free()

func test_photographed_door_side_keeps_its_envelope_and_central_doorwork() -> void:
	var door_root:Node=load("res://tools/environment_bake/collision_sources/fantasy_village/sfv_wall_rock_door_closed_005.tscn").instantiate()
	var side_root:Node=load("res://assets/FantasyVillageFBX/FBX/Walls/Rock/Walls/SFV_Wall_Rock_001.fbx").instantiate()
	var source:=EnvironmentBakeGeometry.merge_pieces(door_root,Transform3D.IDENTITY)
	var stock:=EnvironmentBakeGeometry.merge_pieces(side_root,Transform3D.IDENTITY)
	var result:=EnvironmentBakeGeometry.finish_facade_sides(source,stock,0.25)
	var bounds:=source.get_aabb()
	assert_almost_eq(result.get_aabb().position,bounds.position,Vector3.ONE*0.00001)
	assert_almost_eq(result.get_aabb().end,bounds.end,Vector3.ONE*0.00001)
	var original:=_central_triangles(source)
	var finished:=_central_triangles(result)
	assert_gt(original.size(),100,"The fixture includes the actual door, leaf and arch")
	assert_eq(finished,original,"Finishing the sides must preserve the central authored door exactly")
	door_root.free()
	side_root.free()

func _hits(mesh:ArrayMesh,from:Vector3,to:Vector3) -> bool:
	var faces:=EnvironmentBakeGeometry.triangle_faces(mesh)
	for i in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(from,to,faces[i],faces[i+1],faces[i+2])!=null: return true
	return false

func _central_triangles(mesh:ArrayMesh) -> Dictionary:
	var result:Dictionary={}
	var faces:=EnvironmentBakeGeometry.triangle_faces(mesh)
	for i in range(0,faces.size(),3):
		var points:=PackedStringArray()
		for j in 3:
			var v:=faces[i+j]
			if absf(v.x)>=1.2: break
			points.append("%.5f/%.5f/%.5f"%[v.x,v.y,v.z])
		if points.size()!=3: continue
		points.sort()
		result[";".join(points)]=true
	return result

func test_retaining_stock_has_no_house_skirting_texels() -> void:
	var catalog:=EnvironmentCatalog.load_default()
	var house:EnvironmentVisual=load(catalog.descriptor(SettlementFabricProgram.ROCK_PLAIN).visual_path)
	var bank:EnvironmentVisual=load(catalog.descriptor(SettlementFabricAssembler.MAZE_STONE_MODULE).visual_path)
	assert_gt(_timber_palette_vertices(house),0,"The source house wall includes a wooden base course")
	assert_eq(_timber_palette_vertices(bank),0,"The retaining stock must contain stone through the whole course")
	var old_box:=catalog.descriptor(SettlementFabricProgram.ROCK_PLAIN).measured_aabb
	var new_box:=catalog.descriptor(SettlementFabricAssembler.MAZE_STONE_MODULE).measured_aabb
	assert_almost_eq(old_box.position,new_box.position,Vector3.ONE*0.0001)
	assert_almost_eq(old_box.size,new_box.size,Vector3.ONE*0.0001,
		"The stone profile retains the measured joining envelope")

func _timber_palette_vertices(visual:EnvironmentVisual) -> int:
	var count:=0
	for piece:EnvironmentVisualPiece in visual.pieces:
		for surface in piece.mesh.get_surface_count():
			var material:=piece.mesh.surface_get_material(surface) as StandardMaterial3D
			if material==null or material.albedo_texture==null: continue
			var image:=material.albedo_texture.get_image()
			if image.is_compressed(): image.decompress()
			var uvs:PackedVector2Array=piece.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]
			for uv:Vector2 in uvs:
				var color:=image.get_pixel(clampi(int(uv.x*image.get_width()),0,image.get_width()-1),
					clampi(int(uv.y*image.get_height()),0,image.get_height()-1))
				if color.r>color.b*1.3 and color.g>color.b*1.15: count+=1
	return count
