extends GutTest

func test_overlay_dormer_keeps_a_continuous_host_roof_and_complete_native_glazing() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var source:Node3D=load("res://assets/PureVillage/Models/Architecture/Window_Roof_1_3.glb").instantiate()
	var glass := PackedVector3Array()
	for node:MeshInstance3D in source.find_children("*","MeshInstance3D"):
		for i in node.mesh.get_surface_count():
			if node.mesh.surface_get_material(i).resource_name=="Glass_Out":glass=node.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
	assert_gt(glass.size(),0)
	for suffix:String in ["", ".wood_blue", ".wood_red", ".sage"]:
		var slope := load(catalog.descriptor(StringName("pure_village.roof.slope"+suffix)).visual_path) as EnvironmentVisual
		var backing := _vertices(slope,"RoofTiles")
		for kind:String in ["dormer","dormer_tight"]:
			var visual := load(catalog.descriptor(StringName("pure_village.roof."+kind+suffix)).visual_path) as EnvironmentVisual
			var tiles := _vertices(visual,"RoofTiles")
			for vertex:Vector3 in backing:
				assert_true(tiles.has(vertex),"The dormer overlays the continuous host panel: "+kind+suffix)
			assert_true(_vertices(visual,"Wood_3").is_empty(),"No framed-panel rear batten above the host skin")
			assert_true(_vertices(visual,"RoofTransition").is_empty(),"No upright transition sheet")
			var glazing := _vertices(visual,"Glass_Out")
			for vertex:Vector3 in glass:
				var adapted := Vector3(vertex.x*2.0/3.0,vertex.y,vertex.z*4.0/3.0).snapped(Vector3.ONE*.0001)
				assert_true(glazing.has(adapted),"Keep the complete native overlay window")
	source.free()

func _vertices(visual:EnvironmentVisual, name:String) -> Dictionary:
	var result := {}
	for piece:EnvironmentVisualPiece in visual.pieces:
		for i in piece.mesh.get_surface_count():
			if piece.mesh.surface_get_material(i).resource_name!=name:continue
			for vertex:Vector3 in piece.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
				result[(piece.local_transform*vertex).snapped(Vector3.ONE*.0001)]=true
	return result
