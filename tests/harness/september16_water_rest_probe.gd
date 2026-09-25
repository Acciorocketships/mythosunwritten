extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var sim := WaterRippleSim.new()
	root.add_child(sim)
	sim.set_process(false)
	for frame in 600:
		sim._process(1.0/30)
		await process_frame
		RenderingServer.force_draw(false)
	for entry: Array in [["packet",sim._packet_vp],["ripple",sim._vp[sim._cur]]]:
		var image: Image = entry[1].get_texture().get_image()
		var lo := 1.0; var hi := 0.0; var total := 0.0
		for y in image.get_height():
			for x in image.get_width():
				var r := image.get_pixel(x,y).r
				lo = minf(lo,r); hi = maxf(hi,r); total += r
		print("FIELD_STATS ",entry[0]," ",lo," ",hi," mean=",total/(image.get_width()*image.get_height()))
		print("REST ",entry[0]," ",image.get_pixel(128,128)," ",image.get_pixel(0,0)," format=",image.get_format())
		image.save_exr("res://docs/qa/2026-09-16-manual/02-water-distance/"+entry[0]+"-rest.exr")
	sim.free()
	quit()
