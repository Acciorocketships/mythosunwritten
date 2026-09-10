extends Node

## Render-only replay of real generated geometry; no world generation overlaps
## measurement. All variants share the same nodes, camera and instance buffers.
var _phase:="settling"
var _frames:Dictionary={}
var _last_usec:=0
var _world:Node3D
var _report:String

func _ready()->void:
	_last_usec=Time.get_ticks_usec()
	get_window().size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args:=OS.get_cmdline_user_args()
	var fixture:=args[0]
	_report=args[1]
	_world=(load(fixture) as PackedScene).instantiate()
	for key:StringName in _world.get_meta("shader_globals",{}):
		RenderingServer.global_shader_parameter_set(key,_world.get_meta("shader_globals")[key])
	add_child(_world)
	var camera:=_world.get_node("Camera3D") as Camera3D
	camera.make_current()
	_run.call_deferred(fixture)

func _process(_delta:float)->void:
	var now:=Time.get_ticks_usec()
	if not _frames.has(_phase):_frames[_phase]=[]
	_frames[_phase].append(float(now-_last_usec)/1000.0)
	_last_usec=now

func _run(fixture:String)->void:
	var grass:=_world.get_node("FieldTerrain/Grass") as Node3D
	var sun:=_world.get_node("DirectionalLight3D") as DirectionalLight3D
	var camera:=_world.get_node("Camera3D") as Camera3D
	var camera_transform:=camera.global_transform
	var angle:=sun.light_angular_distance
	var blur:=sun.shadow_blur
	var quality:int=ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")
	var rows:Array=[]
	var grass_batches:=grass.find_children("*","MultiMeshInstance3D",true,false)
	assert(not grass_batches.is_empty(),"the shader comparison must reach actual grass batches")
	var variants:Array=[
		{"name":"full"},
		{"name":"no_grass","grass":false},
		{"name":"no_shadows","shadows":false},
		{"name":"neither","grass":false,"shadows":false},
		{"name":"pcf_sun","angle":0.0},
		{"name":"very_low_pcss","quality":RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW},
		{"name":"full_repeat"}]
	if OS.get_cmdline_user_args().has("--grass-compare"):
		variants=[{"name":"before","shader":"res://tests/fixtures/september9_grass_before.gdshader"},
			{"name":"candidate","shader":"res://tests/fixtures/september9_grass_branch_candidate.gdshader"},
			{"name":"before_repeat","shader":"res://tests/fixtures/september9_grass_before.gdshader"},
			{"name":"candidate_repeat","shader":"res://tests/fixtures/september9_grass_branch_candidate.gdshader"},
			{"name":"pcf_before","angle":0.0,"shader":"res://tests/fixtures/september9_grass_before.gdshader"},
			{"name":"pcf_candidate","angle":0.0,"shader":"res://tests/fixtures/september9_grass_branch_candidate.gdshader"},
			{"name":"pcf_before_repeat","angle":0.0,"shader":"res://tests/fixtures/september9_grass_before.gdshader"}]
	if OS.get_cmdline_user_args().has("--shadow-compare"):
		variants=[{"name":"soft_before"},{"name":"pcf_blur2","angle":0.0,"blur":2.0},
			{"name":"pcf_blur4","angle":0.0,"blur":4.0},{"name":"soft_repeat"}]
	if OS.get_cmdline_user_args().has("--production-compare"):
		variants=[]
		for view in ["pinned","left","right"]:
			for version in ["before","after"]:
				variants.append({"name":view+"_"+version,"view":view,
					"production_grade":version=="after",
					"shader":"res://terrain/grass/grass.gdshader" if version=="after" else "res://tests/fixtures/september9_grass_before.gdshader"})
	for variant:Dictionary in variants:
		camera.global_transform=camera_transform
		if variant.get("view","")=="left":camera.global_position+=Vector3(-3,0,0)
		if variant.get("view","")=="right":camera.global_position+=Vector3(3,0,0)
		if variant.get("view","") in ["left","right"]:
			camera.look_at(Vector3(287.4,5,-1344),Vector3.UP)
		if variant.has("shader"):
			var shader:=Shader.new()
			# Pin shader time only in this render regression, for pixel comparison.
			shader.code=FileAccess.get_file_as_string(variant.shader).replace("TIME","123.0")
			for child:MultiMeshInstance3D in grass_batches:
				(child.material_override as ShaderMaterial).shader=shader
			assert((grass_batches[0].material_override as ShaderMaterial).shader==shader)
		grass.visible=variant.get("grass",true)
		sun.shadow_enabled=variant.get("shadows",true)
		sun.light_angular_distance=variant.get("angle",angle)
		sun.shadow_blur=variant.get("blur",blur)
		if variant.get("production_grade",false):
			var director:=AtmosphereDirector.new()
			director.environment_node=_world.get_node("WorldEnvironment")
			director.sun=sun
			director.camera=camera
			director._apply_grade()
			director.free()
		RenderingServer.directional_soft_shadow_filter_set_quality(variant.get("quality",quality))
		_phase="settling"
		await get_tree().create_timer(3.0).timeout
		_phase=variant.name
		await get_tree().create_timer(10.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_report.get_basename()+"_"+_phase+".png")
		rows.append({"variant":_phase,"frames":preload("res://tests/harness/travel_profile.gd").summary(_frames[_phase]),
			"sun_angular_distance":sun.light_angular_distance,"shadow_blur":sun.shadow_blur,
			"camera":str(camera.global_transform),
			"grass_batches":grass_batches.size(),
			"grass_shader_hash":(grass_batches[0].material_override as ShaderMaterial).shader.code.sha256_text(),
			"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	FileAccess.open(_report,FileAccess.WRITE).store_string(JSON.stringify({"fixture":fixture,
		"fixture_sha256":FileAccess.get_sha256(fixture),"camera":str((_world.get_node("Camera3D") as Camera3D).global_transform),
		"sun_angular_distance":angle,"shadow_filter_quality":quality,"rows":rows},"  "))
	print("FIXTURE_PROBE ",JSON.stringify(rows))
	_world.free()
	await get_tree().process_frame
	get_tree().quit()
