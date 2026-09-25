extends SceneTree
func _init()->void:
	var scene:Node3D=(load("res://docs/qa/2026-09-13-manual/22-water/turf-candidate/P39/geometry.scn") as PackedScene).instantiate()
	var ray:=Vector3(830.25,30,345.5)
	for node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
		if not node.is_in_group("tactical_preserve_surface"):continue
		for surface in node.mesh.get_surface_count():
			var arrays:=node.mesh.surface_get_arrays(surface)
			var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ix:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for i in range(0,ix.size(),3):
				if Geometry3D.ray_intersects_triangle(ray,Vector3.DOWN,vs[ix[i]],vs[ix[i+1]],vs[ix[i+2]])==null:continue
				for j in 3:print("TRIANGLE_VERTEX p=",vs[ix[i+j]]," normal=",arrays[Mesh.ARRAY_NORMAL][ix[i+j]]," scale=",arrays[Mesh.ARRAY_COLOR][ix[i+j]].r)
	scene.free();quit()
