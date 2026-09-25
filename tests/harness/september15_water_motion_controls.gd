extends SceneTree

const BEFORE = preload("res://tests/fixtures/september15/water-motion/sim_before.gd")
const OUT := "res://docs/qa/2026-09-15-manual/04-water-motion/controls"
class Swimmer extends CharacterBody3D:
	var in_water := false

func _init() -> void: _run.call_deferred()

func _run() -> void:
	Engine.max_fps=30
	DirAccess.make_dir_recursive_absolute(OUT)
	var player:=Swimmer.new()
	root.add_child(player)
	var sam:=WaterSampler.new()
	sam._origin=Vector2(-300,-300)
	sam._step=100.0
	sam._nx=7
	sam._nz=7
	sam._h.resize(49)
	sam._h.fill(1.0)
	sam._velocity.resize(49)
	sam._velocity.fill(Vector2(2,0))
	sam._vorticity.resize(49)
	sam._compression.resize(49)
	var owner:=Node.new()
	root.add_child(owner)
	owner.add_to_group("water_volume")
	owner.set_meta("sampler",sam)
	var results:=[]
	var baseline_images:Dictionary={}
	for phase:String in ["before","after"]:
		player.position=Vector3.ZERO
		player.in_water=false
		player.velocity=Vector3.ZERO
		var sim=BEFORE.new() if phase=="before" else WaterRippleSim.new()
		sim.player=player
		root.add_child(sim)
		sim.set_process(false)
		RenderingServer.viewport_set_measure_render_time(sim._packet_vp.get_viewport_rid(),true)
		var timings:=[]
		for frame in 480:
			if frame==30:
				player.in_water=true
				player.velocity=Vector3(2,-3,0)
			if frame>=31:
				player.position.x=(frame-30)/30.0*2.0
				player.velocity.y=0.0
			var start:=Time.get_ticks_usec()
			sim._process(1.0/30.0)
			var elapsed:=Time.get_ticks_usec()-start
			await process_frame
			RenderingServer.force_draw(false)
			if frame>=240: timings.append({"cpu_us":elapsed,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(sim._packet_vp.get_viewport_rid())})
			if frame in [15,31,45,90,240,479]:
				var im:Image=sim._vp[sim._cur].get_texture().get_image()
				im.save_png(OUT+"/%s_ripple_%d.png"%[phase,frame])
				if phase=="before": baseline_images[frame]=im
				else:
					var diff:=0.0
					var previous:Image=baseline_images[frame]
					for y in im.get_height():
						for x in im.get_width(): diff=maxf(diff,absf(im.get_pixel(x,y).r-previous.get_pixel(x,y).r))
					results.append({"control":"entry_and_travel","frame":frame,"max_height_difference":diff})
					assert(diff<.000001,"unchanged contact rings must match exactly")
		results.append({"phase":phase,"timings":timings,"state":sim.debug_state()})
		sim.free()
	# Evaluate the actual production fade in a GPU pass with a constant packet
	# texture. This isolates boundary shape from changing packet crest phases.
	var source:=FileAccess.get_file_as_string("res://terrain/water/water_unified.gdshader")
	var begin:=source.find("float packet_fade(")
	var end:=source.find("float ripple_height_at(",begin)
	var shader:=Shader.new()
	shader.code="shader_type canvas_item;\nuniform sampler2D packet_tex;\nuniform vec2 packet_origin=vec2(-96);\nuniform vec2 packet_center=vec2(0);\nuniform float packet_size=192.0;\n"+source.substr(begin,end-begin)+"\nvoid fragment(){vec2 p=UV*240.0-vec2(120); COLOR=vec4(vec3(packet_height_at(p)+.5),1); }"
	var tex:=Image.create(2,2,false,Image.FORMAT_RGBAF)
	tex.fill(Color(.75,0,0,1))
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("packet_tex",ImageTexture.create_from_image(tex))
	var vp:=SubViewport.new()
	vp.size=Vector2i(480,480)
	vp.use_hdr_2d=true
	vp.disable_3d=true
	var rect:=ColorRect.new()
	rect.size=Vector2(480,480)
	rect.material=mat
	vp.add_child(rect)
	root.add_child(vp)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for frame in 4:
		await process_frame
		RenderingServer.force_draw(false)
	var im:=vp.get_texture().get_image()
	im.save_png(OUT+"/circular-envelope.png")
	var max_error:=0.0
	for y in range(0,480,7):
		for x in range(0,480,7):
			var p:Vector2=(Vector2(x,y)+Vector2(.5,.5))*.5-Vector2(120,120)
			var expected:=.5+.25*WaterRippleSim.packet_fade(p,Vector2.ZERO)
			max_error=maxf(max_error,absf(im.get_pixel(x,y).r-expected))
	results.append({"control":"gpu_cpu_envelope","samples":69*69,"max_error":max_error})
	assert(max_error<.001,"GPU height and CPU buoyancy fade agree")
	FileAccess.open(OUT+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("WATER_MOTION_CONTROLS_DONE error=",max_error)
	quit()
