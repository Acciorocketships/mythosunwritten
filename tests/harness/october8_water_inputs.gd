extends RefCounted

func run(review: Node) -> void:
	var inputs: Dictionary=review._inputs[Vector2i(2,5)]
	var region: HeightfieldRegion=inputs.region
	var box: Array=[region,inputs.water,review._output_dir]
	var task:=WorkerThreadPool.add_task(_export.bind(box))
	while not WorkerThreadPool.is_task_completed(task):
		await review.get_tree().create_timer(.2).timeout
	WorkerThreadPool.wait_for_task_completion(task)

func _export(box:Array) -> void:
	var region: HeightfieldRegion=box[0]
	var water: WaterFieldContext=box[1]
	var directory:String=box[2]
	var data:Dictionary={"storeys":region._storeys,"levels":region._levels,"carved":region._carved,
		"native":region.native_control_heights,
		"water_region":{"storeys":water._region._storeys,"levels":water._region._levels,"carved":water._region._carved,"native":water._region.native_control_heights},"water":water._ctx.fill,"fill_base":water._ctx.fill_base,
		"fill_size":water._ctx.get("fill_size",WaterField.FILL_M+1),"coverage":water.coverage(),"rivers":[]}
	for trace:RiverTrace in water._ctx.rivers:
		var profile:=WaterField.profile(trace,region)
		data.rivers.append({"points":trace.points,"beds":trace.beds,"widths":trace.widths,"profile":profile})
	FileAccess.open(directory+"/water-inputs.var.gz",FileAccess.WRITE).store_buffer(var_to_bytes(data).compress(FileAccess.COMPRESSION_GZIP))
	print("[oct8_water_inputs] exported rivers=",data.rivers.size()," grades=",region.terrain_grades.size())
	box.clear()
