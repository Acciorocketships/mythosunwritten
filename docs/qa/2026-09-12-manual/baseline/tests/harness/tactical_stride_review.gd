extends Node3D
const CHARACTER := preload("res://characters/character.tscn")
var actors: Array[CharacterBody3D] = []
var uncorrected := false
var out := "res://.artifacts/tactical-full-stride"

func _ready() -> void:
	uncorrected = OS.get_cmdline_user_args().has("--uncorrected")
	out += "-before" if uncorrected else "-after"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1100,750)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("869a94")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30,30)
	floor.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("849c84")
	floor.material_override = material
	add_child(floor)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-25,0)
	light.shadow_enabled = true
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0,4.8,7.8)
	camera.look_at(Vector3(0,0.6,0))
	camera.fov = 38
	camera.make_current()
	for i in 2:
		var actor := CHARACTER.instantiate() as CharacterBody3D
		add_child(actor)
		actor.position.x = -1.25 if i == 0 else 1.25
		actor.rotation.y = deg_to_rad(135 if i == 0 else 225)
		actor.set_physics_process(false)
		actor.on_ground = true
		actor.velocity = Vector3.BACK * 10
		actor.anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actor.stride_modifier.active = not uncorrected
		actors.append(actor)
		var stripe := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025,0.01,3)
		stripe.mesh = box
		stripe.position = Vector3(actor.position.x,0.01,0)
		add_child(stripe)
	var label := Label.new()
	label.text = "BACKWARD TOWARD CAMERA / DIAGONAL AIM\n" + ("Original blended swing" if uncorrected else "Travel-aligned foot swing")
	label.position = Vector2(30,25)
	label.add_theme_font_size_override("font_size",24)
	add_child(label)
	for frame in 180:
		for actor in actors:
			actor.movement_animation(10.0,1.0/60)
			actor.anim_tree.advance(1.0/60)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if frame >= 120 and frame % 2 == 0:
			get_viewport().get_texture().get_image().save_png(out+"/stride_%03d.png" % (frame-120))
	get_tree().quit()
