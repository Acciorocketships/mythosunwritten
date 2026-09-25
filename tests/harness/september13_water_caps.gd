extends SceneTree
func _init()->void:
	var scene:Node3D=(load("res://docs/qa/2026-09-13-manual/22-water/turf-candidate2/P39/geometry.scn") as PackedScene).instantiate()
	var point:=Vector3(835.3,16,347.5)
	for node:MultiMeshInstance3D in scene.find_children("*","MultiMeshInstance3D",true,false):
		var mm:=node.multimesh
		for i in mm.instance_count:
			var tr:=node.transform*mm.get_instance_transform(i)
			if tr.origin.distance_to(point)>10:continue
			print("CAP ",node.name," ",tr," bounds=",tr*mm.mesh.get_aabb()," surface=",mm.mesh.get_surface_count())
	print("CAP_COUNTS ",scene.find_children("*","MultiMeshInstance3D",true,false).size())
	scene.free();quit()
