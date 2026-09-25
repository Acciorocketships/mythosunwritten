extends SceneTree

func _init()->void:_run.call_deferred()
func _run()->void:
	Engine.max_fps=30
	var sim:=WaterRippleSim.new();root.add_child(sim)
	sim.set_process(false)
	sim._ambient_timer=1000
	sim._packet_timer=1000
	for frame in 90:
		sim._process(1.0/30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame in [2,10,30,89]:
			for kind in ["ripple","packet"]:
				var vp:SubViewport=sim._vp[sim._cur] if kind=="ripple" else sim._packet_vp
				var im:=vp.get_texture().get_image()
				print("REST_SAMPLE ",frame," ",kind," ",im.get_pixel(128,128)," edge=",im.get_pixel(10,128)," format=",im.get_format())
	quit()
