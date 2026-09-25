extends SceneTree

func _init() -> void:
	var world:Node3D=(load("res://docs/qa/2026-09-11-manual/12-landforms/gorge-live/village.scn") as PackedScene).instantiate()
	var cells:Dictionary={}
	var counts:Dictionary={"vertices":0,"flowing_interior":0,"max_grade":0.0,"max_slope":0.0,"max_speed":0.0,"max_shore":0.0}
	for node:Node in world.find_children("*","MeshInstance3D",true,false):
		var mesh:=node as MeshInstance3D
		var material:=mesh.material_override as ShaderMaterial
		if material==null or not material.shader.code.contains("water_dynamic_height"): continue
		for surface:int in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var frame:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM0].to_float32_array() if arrays[Mesh.ARRAY_CUSTOM0] is PackedByteArray else arrays[Mesh.ARRAY_CUSTOM0]
			var flow:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM1].to_float32_array() if arrays[Mesh.ARRAY_CUSTOM1] is PackedByteArray else arrays[Mesh.ARRAY_CUSTOM1]
			for i:int in vertices.size():
				var velocity:=Vector2(flow[i*4],flow[i*4+1])
				var n:Vector3=mesh.transform.basis*normals[i]
				var grade:=Vector2(n.x,n.z).dot(velocity.normalized())/maxf(absf(n.y),.05)
				counts.vertices+=1
				counts.max_grade=maxf(counts.max_grade,grade)
				counts.max_slope=maxf(counts.max_slope,frame[i*4+2])
				counts.max_speed=maxf(counts.max_speed,velocity.length())
				counts.max_shore=maxf(counts.max_shore,frame[i*4+3])
				if velocity.length()<.1 or frame[i*4+3]<6.0: continue
				counts.flowing_interior+=1
				var point:=mesh.transform*vertices[i]
				var cell:=Vector2i(floori(point.x/24),floori(point.z/24))
				if cells.has(cell) and float(cells[cell].grade)>=grade: continue
				cells[cell]={"point":str(point),"grade":grade,"profile_slope":frame[i*4+2],"speed":velocity.length(),"shore":frame[i*4+3]}
	var rows:Array=cells.values()
	rows.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.grade>b.grade)
	rows=rows.slice(0,30)
	print("GORGE_MESH ",counts," ",rows)
	FileAccess.open("res://docs/qa/2026-09-11-manual/12-landforms/gorge-mesh-survey.json",FileAccess.WRITE).store_string(JSON.stringify({"counts":counts,"steepest":rows},"  "))
	world.free()
	quit()
