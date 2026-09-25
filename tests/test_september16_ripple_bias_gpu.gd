extends GutTest

# P09: use the native feedback textures and decode through the production
# water material's own height function, rather than assuming its encoding.
func test_ambient_ripples_do_not_accumulate_a_domain_sized_depression() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Native GPU feedback/readback required")
		return
	var sim := WaterRippleSim.new()
	add_child(sim)
	sim.set_process(false)
	for frame in 600:
		sim._process(1.0/30.0)
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	var source := FileAccess.get_file_as_string("res://terrain/water/water_unified.gdshader")
	var functions := ""
	for function_name: String in ["domain_fade","ripple_height_at"]:
		var start := source.find("float " + function_name + "(")
		var end := source.find("\n}\n",start)+3
		functions += source.substr(start,end-start) + "\n"
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nrender_mode blend_disabled;\nuniform sampler2D ripple_tex : repeat_disable, filter_linear;\nuniform vec2 ripple_origin = vec2(0.0);\nuniform float ripple_size = 96.0;\nuniform float ripple_height = 0.75;\n" + functions + "\nvoid fragment() { COLOR = vec4(vec3(ripple_height_at(UV * ripple_size)),1.0); }"
	var view := SubViewport.new()
	view.size = Vector2i(256,256)
	view.disable_3d = true
	view.use_hdr_2d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := ColorRect.new()
	rect.size = view.size
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("ripple_tex",sim._vp[sim._cur].get_texture())
	rect.material = material
	view.add_child(rect)
	add_child(view)
	for frame in 3: await get_tree().process_frame
	RenderingServer.force_draw(false)
	var image := view.get_texture().get_image()
	var mean := 0.0
	var largest := 0.0
	for y in image.get_height():
		for x in image.get_width():
			var height := image.get_pixel(x,y).r
			mean += height
			largest = maxf(largest,absf(height))
	mean /= image.get_width()*image.get_height()
	assert_lt(absf(mean),0.002,"600 native feedback frames must not create a broad artificial basin")
	assert_lt(largest,0.06,"Tiny ambient drops cannot drive the water to its trough clamp")
	print("RIPPLE_BIAS mean_m=",mean," max_m=",largest)
	view.free()
	sim.free()
