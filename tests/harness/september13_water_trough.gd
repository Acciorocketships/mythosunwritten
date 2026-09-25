extends SceneTree
func _init()->void:_run.call_deferred()
func _run()->void:
	var source:="res://docs/qa/2026-09-13-manual/22-water/diagnostic-before/P39/geometry.scn"
	var output:="res://docs/qa/2026-09-13-manual/22-water/P39-animation-before/trough.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):source=arg.trim_prefix("--source=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	var scene:Node3D=(load(source) as PackedScene).instantiate();root.add_child(scene)
	var local:=Rect2(826,342,12,8)
	var triangles:={"terrain":[],"water":[],"trough":[],"ordinary":[]}
	for node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
		var wet:=node.is_in_group("tactical_preserve_surface")
		for surface in node.mesh.get_surface_count():
			var a:=node.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				indices.resize(vertices.size());for i in indices.size():indices[i]=i
			for i in range(0,indices.size(),3):
				var tri:=PackedVector3Array();var low:=PackedVector3Array();var ordinary:=PackedVector3Array()
				for j in 3:
					var ix:=indices[i+j];var v:=vertices[ix];tri.append(node.global_transform*v)
					if wet:
						low.append(node.global_transform*(v-a[Mesh.ARRAY_NORMAL][ix]*a[Mesh.ARRAY_COLOR][ix].r*1.4))
						ordinary.append(node.global_transform*(v-a[Mesh.ARRAY_NORMAL][ix]*a[Mesh.ARRAY_COLOR][ix].r*.5))
				var bounds:=Rect2(Vector2(tri[0].x,tri[0].z),Vector2.ZERO)
				for v:Vector3 in tri:bounds=bounds.expand(Vector2(v.x,v.z))
				if not bounds.intersects(local,true):continue
				triangles["water" if wet else "terrain"].append(tri)
				if wet:triangles.trough.append(low);triangles.ordinary.append(ordinary)
	var rows:=[];var worst:={};var count:=0;var ordinary_count:=0
	for z in 32:
		for x in 48:
			var p:=local.position+Vector2(x,z)*.25
			var heights:={}
			for role:String in triangles:
				var y:=-INF
				for tri:PackedVector3Array in triangles[role]:
					var hit:Variant=Geometry3D.ray_intersects_triangle(Vector3(p.x,30,p.y),Vector3.DOWN,tri[0],tri[1],tri[2])
					if hit!=null:y=maxf(y,hit.y)
				heights[role]=y
			if heights.water<=heights.terrain+.005:continue
			var gap:float=heights.trough-heights.terrain
			if gap<0:
				count+=1
				if heights.ordinary<heights.terrain:ordinary_count+=1
				if worst.is_empty() or gap<worst.gap:worst={"p":str(p),"gap":gap,"heights":heights}
				rows.append({"p":[p.x,p.y],"heights":heights})
	print("TROUGH_SCAN ",JSON.stringify({"count":count,"ordinary_count":ordinary_count,"worst":worst}))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
