extends SceneTree
func _init()->void:
	var results:=[]
	for folder in ["diagnostic-before","candidate2"]:
		var scene:Node3D=(load("res://docs/qa/2026-09-13-manual/22-water/"+folder+"/P39/geometry.scn") as PackedScene).instantiate()
		var points:Array[String]=[]
		for node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
			if not node.is_in_group("tactical_preserve_surface"):continue
			for p:Vector3 in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if Rect2(822,336,24,24).has_point(Vector2(p.x,p.z)):points.append(str(p))
		points.sort();results.append({"folder":folder,"vertices":points.size(),"hash":"\n".join(points).sha256_text()});scene.free()
	print("LOCAL_GEOMETRY ",JSON.stringify(results))
	quit()
