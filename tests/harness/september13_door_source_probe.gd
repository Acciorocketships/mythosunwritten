extends SceneTree
func _init() -> void:
	var node: Node = load("res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Door/SFV_Door_Wall_Wooden_001_1.fbx").instantiate()
	for child: Node in node.find_children("*","",true,false):
		if child is MeshInstance3D:
			print(node.get_path_to(child)," ",child.mesh.get_aabb()," surfaces=",child.mesh.get_surface_count())
	var mesh := EnvironmentBakeGeometry.merge_pieces(node,Transform3D.IDENTITY)
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var xs := {};var zs := {}
		for v in vertices:
			xs[snappedf(v.x,.001)]=true;zs[snappedf(v.z,.001)]=true
		print("SURFACE ",si," xs=",xs.keys()," zs=",zs.keys())
	node.free()
	quit()
