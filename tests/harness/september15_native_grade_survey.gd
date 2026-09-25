extends SceneTree
const Frozen = preload("res://tests/fixtures/frozen_terrain_grade.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	var report := []
	for site: String in ["P07","P08","P09"]:
		var original := Frozen.region("res://docs/qa/2026-09-15-manual/01-grass/%s-field.txt"%site)
		var native := original.without_terrain_grades().with_terrain_grades(original.terrain_grades)
		var chunks: Dictionary = {}
		var points: Array = []
		for grade: TerrainGradePatch in original.terrain_grades:
			for cell: Vector2i in grade._claims:
				for offset: Vector2 in [Vector2.ZERO,Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
					var point:=grade._origin+(Vector2(cell)+offset*.499)*grade._targets.pitch
					chunks[Vector2i(floori((point.x+12)/192),floori((point.y+12)/192))]=true
					chunks[Vector2i(floori(point.x/192),floori(point.y/192))]=true
					points.append([point,float(grade._claims[cell])])
		var view:=SubViewport.new()
		view.own_world_3d=true
		root.add_child(view)
		for chunk: Vector2i in chunks:
			view.add_child(mesher.commit_chunk(mesher.compute_chunk(chunk,native)))
		await physics_frame
		await physics_frame
		var missing:=0
		var maximum_error:=0.0
		var bad:=[]
		for sample: Array in points:
			var point:=Vector3(sample[0].x,sample[1],sample[0].y)
			var hit:=view.find_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*100,point-Vector3.UP*100,1))
			if hit.is_empty(): missing+=1;continue
			var error:float=absf(hit.position.y-sample[1])
			maximum_error=maxf(maximum_error,error)
			if error>.01 and bad.size()<20: bad.append({"point":str(point),"hit":str(hit.position),"error":error})
		var row:={"site":site,"reserved_footprint_ray_count":points.size(),"chunks":chunks.size(),"missing":missing,"max_datum_error_m":maximum_error,"bad_examples":bad}
		print("NATIVE_GRADE_SURVEY ",row)
		report.append(row)
		view.free()
	FileAccess.open("res://docs/qa/2026-09-15-manual/01-grass/native-support.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
