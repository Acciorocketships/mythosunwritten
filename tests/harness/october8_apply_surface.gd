extends RefCounted
# Offline visual experiment: project one captured source solve into the
# already-idle review harness, then rebuild its photographed chunks.
func run(review:Node)->void:
	var source:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("/tmp/oct8-surface-trial.var.gz").decompress_dynamic(200000000,FileAccess.COMPRESSION_GZIP))
	for chunk:Vector2i in review._inputs:
		var water:WaterFieldContext=review._inputs[chunk].water
		var c:Dictionary=water._ctx.duplicate()
		var offset:=Vector2i(((c.fill_base-source.base)/WaterField.FILL_STEP).round())
		var fill:Dictionary={}
		for key:String in ["levels","sub_levels","sub_ground"]:
			var sub:=key!="levels"
			var side:=roundi(sqrt(c.fill[key].size()))
			var source_side:int=(source.size-1)*2+1 if sub else source.size
			var source_rows:int=(source.rows-1)*2+1 if sub else source.rows
			var off:=offset*2 if sub else offset
			var values:PackedFloat32Array=c.fill[key].duplicate()
			for z in side:
				for x in side:
					if x+off.x>=0 and z+off.y>=0 and x+off.x<source_side and z+off.y<source_rows:
						values[z*side+x]=source[key][(z+off.y)*source_side+x+off.x]
			fill[key]=values
		c.fill=fill
		water._ctx=c
		water._shore_lock.lock()
		water._shore_curves.clear();water._shore_curves_ready=false
		water._shore_lock.unlock()
	# The measured reach crosses the southern chunk boundary. Rebuild both
	# sides even though the original screenshot aims at the upper reach.
	review._views.append({"target":Vector3(467,30,1160)})
	await review._rebuild_full()
	review._views.pop_back()
	await review._capture_all(1)
	await sample_path(review)

func sample_path(review:Node)->void:
	await review.get_tree().physics_frame
	var hits:Array=[]
	var data:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/october8/water-inputs.var.gz").decompress_dynamic(100000000,FileAccess.COMPRESSION_GZIP))
	for river:Dictionary in data.rivers:
		for i in range(1,river.points.size()):
			var a:Vector2=river.points[i-1];var b:Vector2=river.points[i]
			var steps:=ceili(a.distance_to(b)/.5)
			for j in steps:
				var at:=a.lerp(b,float(j)/steps)
				if not Rect2(440,1090,70,74).has_point(at):continue
				var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,400,at.y),Vector3(at.x,-100,at.y))
				var hit:Dictionary=review._camera.get_world_3d().direct_space_state.intersect_ray(query)
				var obstacle:Dictionary={}
				if not hit.is_empty() and str(hit.collider.get_path()).contains("/CliffSlopeRocks/"):
					obstacle={"height":hit.position.y,"collider":str(hit.collider.get_path())}
					query.exclude=[hit.rid]
					hit=review._camera.get_world_3d().direct_space_state.intersect_ray(query)
				var chunk:=FieldTerrainStreamer.chunk_of(Vector3(at.x,0,at.y))
				var water:WaterFieldContext=review._inputs[chunk].water
				var level:=water.level_at(at)
				if not hit.is_empty():hits.append({"x":at.x,"z":at.y,"ground":hit.position.y,"water":level,"collider":str(hit.collider.get_path()),"rock_obstacle":obstacle})
	FileAccess.open(review._output_dir+"/path-rays.json",FileAccess.WRITE).store_string(JSON.stringify(hits,"  "))
	print("[oct8_surface] trial captured, ray samples=",hits.size())
