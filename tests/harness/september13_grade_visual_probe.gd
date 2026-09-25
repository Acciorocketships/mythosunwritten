extends SceneTree

func _init() -> void:
	var region := preload("res://tests/fixtures/frozen_terrain_grade.gd").region("res://docs/qa/2026-09-13-manual/17-village-grade/P24-field.txt")
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	var data := mesher.compute_chunk(Vector2i(-2,2),region)
	print("KEYS ",data.keys())
	var arrays: Array = data.surface_arrays
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bins := {}
	for i in range(0,indices.size(),3):
		var a:=vertices[indices[i]]
		var b:=vertices[indices[i+1]]
		var c:=vertices[indices[i+2]]
		for z in range(floori(minf(a.z,minf(b.z,c.z))),ceili(maxf(a.z,maxf(b.z,c.z)))+1):
			for x in range(floori(minf(a.x,minf(b.x,c.x))),ceili(maxf(a.x,maxf(b.x,c.x)))+1):
				var key:=Vector2i(x,z)
				if not bins.has(key): bins[key]=[]
				bins[key].append([a,b,c])
	var rocks: PackedVector3Array = data.graded_cliff_arrays[Mesh.ARRAY_VERTEX]
	var errors:=[]
	for i in range(0,rocks.size(),3):
		var p:Vector3=(rocks[i]+rocks[i+1]+rocks[i+2])/3
		var y:float=-INF
		for tri:Array in bins.get(Vector2i(floori(p.x),floori(p.z)),[]):
			var hit:Variant=Geometry3D.segment_intersects_triangle(Vector3(p.x,100,p.z),Vector3(p.x,-100,p.z),tri[0],tri[1],tri[2])
			if hit!=null: y=maxf(y,hit.y)
		if p.y>y+.01: errors.append({"point":p,"rendered":y,"field":TerrainSurfaceField.surface_y(region,p.x,p.z)})
	print("EXPOSED VISUAL ",errors.size())
	for i in mini(30,errors.size()): print(errors[i])
	var eye:=Vector3(-267.095,23.7549,460.0706)
	var basis:=Basis(Vector3(.890299,0,-.455376),Vector3(-.252951,.831533,-.49454),Vector3(.37866,.555476,.740313))
	for pixel:Vector2 in [Vector2(480,222),Vector2(553,319),Vector2(816,158)]:
		var direction:Vector3=basis*Vector3((pixel.x-640)/400*tan(deg_to_rad(37.5)),(400-pixel.y)/400*tan(deg_to_rad(37.5)),-1)
		var end:=eye+direction.normalized()*200
		for name:String in ["surface_arrays","graded_cliff_arrays","wall_arrays"]:
			var source:Array=data[name]
			if source.is_empty(): continue
			var vs:PackedVector3Array=source[Mesh.ARRAY_VERTEX]
			var ids:PackedInt32Array=source[Mesh.ARRAY_INDEX] if source[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var hitpoint:Variant=null
			var distance:float=INF
			for i in range(0,ids.size() if not ids.is_empty() else vs.size(),3):
				var tri: Array[Vector3]=[]
				for j in 3: tri.append(vs[ids[i+j] if not ids.is_empty() else i+j])
				var hit:Variant=Geometry3D.segment_intersects_triangle(eye,end,tri[0],tri[1],tri[2])
				if hit!=null and eye.distance_to(hit)<distance: hitpoint=hit;distance=eye.distance_to(hit)
			print("PIXEL ",pixel," ",name," hit=",hitpoint," distance=",distance," field=",TerrainSurfaceField.surface_y(region,hitpoint.x,hitpoint.z) if hitpoint!=null else 0)
	quit()
