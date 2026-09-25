extends SceneTree
## Counter calibration against actual rendered black/white surfaces.
const Probe := preload("res://tests/harness/september11_black_gpu.gd")
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(640,360)
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.make_current()
	var probe := Probe.new()
	var compositor := Compositor.new()
	compositor.compositor_effects = [probe]
	camera.compositor = compositor
	var surface := MeshInstance3D.new()
	surface.mesh = QuadMesh.new()
	surface.mesh.size = Vector2(20,20)
	surface.position.z = -2
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, fog_disabled; uniform bool half_black = false; void fragment() { ALBEDO=vec3(half_black && SCREEN_UV.x<0.5 ? 0.0 : 1.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	surface.material_override = material
	stage.add_child(surface)
	for half_black: bool in [false,true,false]:
		material.set_shader_parameter("half_black",half_black)
		for frame in 12:
			await process_frame
			_draw.call_deferred()
			await RenderingServer.frame_post_draw
		var rows := probe.take_samples()
		assert(not rows.is_empty(),"No asynchronous GPU results")
		var row: Dictionary = rows.back()
		assert(row.samples == 9216)
		assert(row.invalid == 0)
		assert(row.black == (4608 if half_black else 0),str(row))
		print("GPU_COUNTER_CHECK half_black=",half_black," black=",row.black," invalid=",row.invalid)
	# Also verify asynchronous attribution under frame-by-frame changes. The
	# actual render camera encodes the expected state; delayed callbacks must
	# retain that frame's pixels rather than a later use of the shared buffer.
	var temporal: Array[Dictionary] = []
	for index in range(1,61):
		camera.position.x = float(index)*.001
		material.set_shader_parameter("half_black",index%2 == 1)
		await process_frame
		_draw.call_deferred()
		await RenderingServer.frame_post_draw
		temporal.append_array(probe.take_samples())
	camera.compositor = null
	for frame in 6:
		await process_frame
		_draw.call_deferred()
		await RenderingServer.frame_post_draw
	temporal.append_array(probe.take_samples())
	var checked := 0
	var states := {}
	for row: Dictionary in temporal:
		var index := roundi(float(row.camera_origin[0])*1000.0)
		if index == 0: continue
		assert(row.samples == 9216 and row.invalid == 0)
		assert(row.black == (4608 if index%2 == 1 else 0),str(row))
		checked += 1
		states[index] = true
	assert(states.size() == 60,str(states.keys()))
	print("GPU_TEMPORAL_CHECK frames=",checked," distinct_states=",states.size())
	var marker_holder := preload("res://tests/harness/september11_black_qa.gd").new()
	marker_holder._character = CharacterBody3D.new()
	stage.add_child(marker_holder._character)
	marker_holder._add_frame_marker()
	camera.position = Vector3.ZERO
	probe.decode_marker = true
	camera.compositor = compositor
	for tick: int in [0,1,31,32,1023,1024,5280,6239,32767]:
		marker_holder._frame_marker.set_shader_parameter("tick",tick)
		for frame in 12:
			await process_frame
			_draw.call_deferred()
			await RenderingServer.frame_post_draw
		var rows := probe.take_samples()
		assert(not rows.is_empty())
		root.get_texture().get_image().save_png("/private/tmp/september11-marker-check.png")
		assert(rows.back().rendered_tick == tick,str(rows.back()))
		print("GPU_MARKER_CHECK tick=",tick," decoded=",rows.back().rendered_tick)
	camera.compositor = null
	for frame in 6:
		await process_frame
		_draw.call_deferred()
		await RenderingServer.frame_post_draw
	marker_holder.free()
	stage.free()
	quit()

func _draw() -> void:
	RenderingServer.force_draw(true)
