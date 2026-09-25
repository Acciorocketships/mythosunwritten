extends SceneTree
func _init()->void:_run.call_deferred()
func _run()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(plan,water,0,0,64)
	var result:=[]
	for chunk:Vector2i in [Vector2i(3,-10),Vector2i(3,-9)]:
		var field:=fields.water(chunk);var ctx:=field.raw_context()
		var mesh:=WaterSkin.build(water,chunk,ctx.region,field)
		var verts:PackedVector3Array=mesh.arrays[Mesh.ARRAY_VERTEX]
		var ids:PackedInt32Array=mesh.arrays[Mesh.ARRAY_INDEX]
		var normals:PackedVector3Array=mesh.arrays[Mesh.ARRAY_NORMAL]
		var rows:=[]
		for i in verts.size():
			var v:=verts[i]
			if v.x>=650 and v.x<=710 and absf(v.z+1728)<.01:
				rows.append({"point":str(v),"normal":str(normals[i]),"field":str(WaterField.level_at(ctx,Vector2(v.x,v.z)))})
		var probes:=[]
		for x in range(650,711):
			var y:=-INF;var tri:=[]
			var origin:=Vector3(x,100,-1728)
			for i in range(0,ids.size(),3):
				var a:=verts[ids[i]];var b:=verts[ids[i+1]];var c:=verts[ids[i+2]]
				var hit:Variant=Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,a,b,c)
				if hit!=null and hit.y>y:y=hit.y;tri=[str(a),str(b),str(c)]
			probes.append({"x":x,"height":str(y),"field":str(WaterField.level_at(ctx,Vector2(x,-1728))),"triangle":tri})
		result.append({"chunk":str(chunk),"vertices":rows,"probes":probes})
		print("WATER_MESH_SEAM ",chunk)
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	quit()
