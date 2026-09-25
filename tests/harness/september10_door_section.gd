extends SceneTree
func _init() -> void:
	var catalog:=EnvironmentCatalog.load_default()
	for id in [&"sfv.fabric.wall.wood.door.closed.001", &"sfv.fabric.wall.wood.window.004.mirror_x", &"sfv.fabric.wall.rock.door.closed.001"]:
		var descriptor:=catalog.descriptor(id)
		if descriptor==null:continue
		print("ASSET ",id," ",descriptor.measured_aabb)
		var visual:EnvironmentVisual=load(descriptor.visual_path)
		var faces:=PackedVector3Array()
		for piece:EnvironmentVisualPiece in visual.pieces:faces.append_array(piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh))
		for x in [-1.49,-1.4,-1.3,-1.2,1.2,1.3,1.4,1.49]:
			for y in [0.4,1.5,2.7]:
				var hits:Array=[]
				for i in range(0,faces.size(),3):
					var hit:Variant=Geometry3D.segment_intersects_triangle(Vector3(x,y,-2),Vector3(x,y,2),faces[i],faces[i+1],faces[i+2])
					if hit!=null:hits.append((hit as Vector3).z)
				print(x," ",y," ",hits)
	quit()
