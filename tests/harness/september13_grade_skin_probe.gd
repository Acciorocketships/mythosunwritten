extends SceneTree
func _init() -> void:
	var region:=preload("res://tests/fixtures/frozen_terrain_grade.gd").region("res://docs/qa/2026-09-13-manual/17-village-grade/P24-field.txt")
	var mesher:=TerrainChunkMesher.new()
	mesher.prepare_resources()
	var data:=mesher.compute_chunk(Vector2i(-2,2),region)
	var vertices:PackedVector3Array=data.graded_cliff_arrays[Mesh.ARRAY_VERTEX]
	var errors:=[]
	var exposed:=[]
	for i in range(0,vertices.size(),3):
		for sample:Vector3 in [vertices[i],vertices[i+1],vertices[i+2],(vertices[i]+vertices[i+1]+vertices[i+2])/3]:
			var ground:=TerrainSurfaceField.surface_y(region,sample.x,sample.z)
			if sample.y>ground+.005 and sample.z>420 and sample.z<451:
				exposed.append({"point":sample,"ground":ground,"error":sample.y-ground})
		var source:=PackedVector3Array()
		var valid:=true
		for j in 3:
			var p:=vertices[i+j]
			var zero:=region.graded_height(p.x,p.z,0)
			var remaining:=region.graded_height(p.x,p.z,1)-zero
			if remaining<.001: valid=false; break
			source.append(Vector3(p.x,(p.y-zero)/remaining,p.z))
		if not valid: continue
		var p:Vector3=(source[0]+source[1]+source[2])/3
		var actual:Vector3=(vertices[i]+vertices[i+1]+vertices[i+2])/3
		var expected:=region.graded_height(p.x,p.z,p.y)
		var error:=absf(expected-actual.y)
		if error>.01: errors.append({"error":error,"actual":actual,"expected":expected,"source":source})
	errors.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.error>b.error)
	print("SKIN_ERROR count=",errors.size()," triangles=",vertices.size()/3)
	exposed.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.error>b.error)
	print("EXPOSED ",exposed.size())
	for i in mini(exposed.size(),15): print(exposed[i])
	for i in mini(errors.size(),10):
		var p:Vector3=errors[i].actual
		print(errors[i]," ground=",TerrainSurfaceField.surface_y(region,p.x,p.z)," natural=",TerrainSurfaceField.surface_y(region.without_terrain_grades(),p.x,p.z))
	for z in range(17,21):
		for x in range(-13,-10): print("CELL ",Vector2i(x,z)," height=",region.surface_height(x,z)," flat=",TerrainSurfaceField.is_flat_cell(region,x,z))
	quit()
