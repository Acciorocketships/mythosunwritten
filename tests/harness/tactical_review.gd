extends Node3D
## Deterministic rendered review: -- --gaits or default visibility bubble.
const CHARACTER := preload("res://characters/character.tscn")
var camera: Camera3D
var bubble: CameraVisibilityBubble
var actors: Array[CharacterBody3D] = []
var out := "res://.artifacts/tactical"

func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	if OS.get_cmdline_user_args().has("--retargeted"): out += "-retargeted"
	if OS.get_cmdline_user_args().has("--full-speed"): out += "-full-speed"
	if OS.get_cmdline_user_args().has("--views"): out += "-views"
	if OS.get_cmdline_user_args().has("--unaligned"): out += "-unaligned"
	DirAccess.make_dir_recursive_absolute(out)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a6b4bd")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.shadow_enabled = true
	add_child(light)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 45
	_box(Vector3(0,-0.15,0), Vector3(45,0.3,40), Color("718779"))
	if OS.get_cmdline_user_args().has("--views"):
		await _view_review()
	elif OS.get_cmdline_user_args().has("--gaits"):
		await _gaits()
	else:
		await _bubble_review()
	get_tree().quit()

func _view_review() -> void:
	var actor := _actor(Vector3.ZERO)
	actor.movement_animation(0.0)
	actor.anim_tree.advance(0.01)
	for z in [-15, -10, -5, 0, 5, 10, 15]:
		_box(Vector3(0,0.01,z), Vector3(40,0.02,0.06), Color("b0b7a0"))
		for x in [-15, -10, -5, 5, 10, 15]:
			_box(Vector3(x,0.4,z), Vector3(0.5,0.8,0.5), Color("b78353"))
	camera.position = Vector3(0,5,8)
	var controller := preload("res://scripts/camera/camera.gd").new()
	controller.camera = camera
	controller.target = actor
	add_child(controller)
	controller.set_physics_process(false)
	for mode in ["tactical", "legacy", "tactical_return"]:
		for frame in 10:
			controller._physics_process(1.0 / 60)
			await get_tree().process_frame
		await _shot("view_" + mode)
		print("VIEW ", mode, " position=", camera.position, " pitch=", camera.rotation_degrees.x, " fov=", camera.fov)
		controller.toggle_view()

func _actor(pos: Vector3) -> CharacterBody3D:
	var actor := CHARACTER.instantiate() as CharacterBody3D
	add_child(actor)
	actor.position = pos
	actor.set_physics_process(false)
	actor.anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actors.append(actor)
	return actor

func _box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	node.material_override = mat
	node.position = pos
	add_child(node)
	return node

func _label(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.no_depth_test = true
	label.pixel_size = 0.009
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _gaits() -> void:
	var names := ["Forward", "Forward / right", "Right", "Back / right", "Backward", "Back / left", "Left", "Forward / left"]
	for i in 8:
		var pos := Vector3((i % 4 - 1.5) * 3.4, 0, (i / 4) * 5.2)
		var actor := _actor(pos)
		if OS.get_cmdline_user_args().has("--unaligned"):
			var root := actor.anim_tree.tree_root as AnimationNodeStateMachine
			var blend := root.get_node("BlendTree") as AnimationNodeBlendTree
			var directions := blend.get_node("Direction") as AnimationNodeBlendSpace2D
			(directions.get_blend_point_node(1) as AnimationNodeAnimation).start_offset = 0.0
			var forward := directions.get_blend_point_node(0) as AnimationNodeBlendSpace1D
			(forward.get_blend_point_node(0) as AnimationNodeAnimation).start_offset = 0.0
		var angle := float(i) * TAU / 8.0
		var direction := Vector3(-sin(angle),0,cos(angle))
		actor.velocity = direction * DirectionalLocomotion.stride_length(direction, Basis.IDENTITY) * DirectionalLocomotion.RUN_CADENCE
		if OS.get_cmdline_user_args().has("--full-speed"): actor.velocity = direction * 10.0
		_label(names[i], pos + Vector3(0,0.3,1.4))
	camera.position = Vector3(1.5,7,20)
	camera.look_at(Vector3(0,0.6,2.5))
	for frame in 120:
		for actor in actors:
			actor.movement_animation(actor.velocity.length(), 1.0 / 60)
			actor.anim_tree.advance(1.0 / 60)
		await get_tree().process_frame
		if frame >= 60 and frame % 2 == 0:
			await _shot("gaits_%03d" % (frame - 60))

func _bubble_review() -> void:
	var actor := _actor(Vector3.ZERO)
	actor.movement_animation(0.0)
	actor.anim_tree.advance(0.01)
	camera.position = Vector3(4,16,14)
	camera.look_at(Vector3(0,1,0))
	# Separate walls/posts/roof; no collision objects or per-object fade hooks.
	for x in [-2.4, 0.0, 2.4]:
		_box(Vector3(x,2,2.8), Vector3(2.3,4,0.35), Color("b78353"))
		_box(Vector3(x-1.1,2.5,2.6), Vector3(0.18,5,0.25), Color("473b32"))
	_box(Vector3(0,4.2,1.2), Vector3(7.5,0.3,4), Color("586174"))
	_box(Vector3(0,1,-3.5), Vector3(2,2,0.5), Color("ba6647"))
	# Same batch has both an occluder and an object far outside the bubble.
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = BoxMesh.new()
	batch.multimesh.instance_count = 2
	batch.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3(1,3,1)), Vector3(1,1.5,1)))
	batch.multimesh.set_instance_transform(1, Transform3D(Basis.IDENTITY.scaled(Vector3(1,3,1)), Vector3(9,1.5,1)))
	var shader := Shader.new()
	shader.code = "shader_type spatial; void fragment() { ALBEDO = vec3(0.25,0.4,0.65); ROUGHNESS = 0.8; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	batch.multimesh.mesh.surface_set_material(0, material)
	add_child(batch)
	bubble = CameraVisibilityBubble.new()
	add_child(bubble)
	for frame in 5: await get_tree().process_frame
	await _shot("bubble_before")
	for frame in 5:
		bubble.update_bubble(camera, actor, actor.global_position, 3.8, 1.0, 1.0/60)
		await get_tree().process_frame
	await _shot("bubble_zero_fade")
	for frame in 45:
		bubble.update_bubble(camera, actor, actor.global_position, 3.8, 0.12, 1.0/60)
		await get_tree().process_frame
	await _shot("bubble_after")
	print("TACTICAL active bubble components: ", bubble._active.size())
	for i in 3:
		camera.position = Vector3(4,16,14).rotated(Vector3.UP, float(i+1)*PI/2)
		camera.look_at(Vector3(0,1,0))
		for frame in 20:
			bubble.update_bubble(camera,actor,actor.global_position,3.8,0.12,1.0/60)
			await get_tree().process_frame
		await _shot("bubble_orbit_%d" % i)
	bubble.clear()
	camera.position = Vector3(4,16,14)
	camera.look_at(Vector3(0,1,0))
	for frame in 5: await get_tree().process_frame
	await _shot("bubble_restored")

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
