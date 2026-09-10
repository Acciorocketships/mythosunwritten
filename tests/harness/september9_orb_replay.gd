extends Node

# Rebuild only the production orb adapters in a frozen, real generated world.
# The fixture was captured for the reported streaming approach; anchors below
# come from its existing luminous sprites, never new decorative placements.
var _world: Node3D
var _orbs: Array[SpiritOrb] = []
var _report: String
var _rows: Array = []

func _ready() -> void:
	Engine.max_fps = 30
	get_window().size = Vector2i(1280,720)
	var args := OS.get_cmdline_user_args()
	_report = args[1]
	_world = (load(args[0]) as PackedScene).instantiate()
	for key: StringName in _world.get_meta("shader_globals", {}):
		RenderingServer.global_shader_parameter_set(key, _world.get_meta("shader_globals")[key])
	add_child(_world)
	var camera := _world.get_node("Camera3D") as Camera3D
	camera.make_current()
	var nodes := _world.find_children("SpiritOrb*", "Node3D", true, false)
	print("ORB_FIXTURE_COUNT ", nodes.size())
	for old: Node3D in nodes:
		# Frozen scripts were omitted, so the snapshot's position is the
		# comparison anchor; both versions rebuild from this identical datum.
		var fog := PackedColorArray()
		fog.resize(169)
		var ground := PackedFloat32Array()
		ground.resize(169)
		var fx := BiomeChunkFx.build_field({"origin":Vector3.ZERO, "fog":fog,
			"ground":ground,"lo":0.0,"hi":0.0,"points":{},"orbs":[old.position]})
		var orb := fx.find_child("SpiritOrb",true,false) as SpiritOrb
		fx.remove_child(orb)
		old.get_parent().add_child(orb)
		old.get_parent().remove_child(old)
		old.free()
		fx.free()
		if args.has("--debug-material"):
			var debug_material := StandardMaterial3D.new()
			debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			debug_material.albedo_color = Color.MAGENTA
			debug_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			orb.get_child(0).material_override = debug_material
		if args.has("--debug-shader"):
			var material: ShaderMaterial = orb.get_child(0).mesh.material
			var shader := Shader.new()
			shader.code = material.shader.code.substr(0,material.shader.code.find("void fragment()"))+"void fragment(){ALBEDO=vec3(1.0,0.0,1.0);ALPHA=1.0;}"
			material.shader = shader
		_orbs.append(orb)
	assert(not _orbs.is_empty(), "Replay must contain real generated spirit orbs")
	if args.has("--inspect"):
		for orb in _orbs:
			print("ORB_NODE ",orb.global_position," visible=",orb.is_visible_in_tree()," sprite=",orb.get_child(0).is_visible_in_tree()," mesh=",orb.get_child(0).mesh.size," parent=",orb.get_parent().get_path())
		get_tree().quit()
		return
	_freeze_material_time(_world)
	_run.call_deferred(camera, args[0])

func _freeze_material_time(node: Node) -> void:
	if node is GeometryInstance3D and node.material_override is ShaderMaterial:
		_pin_shader(node.material_override)
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material is ShaderMaterial: _pin_shader(material)
	for child in node.get_children(): _freeze_material_time(child)

func _pin_shader(material: ShaderMaterial) -> void:
	var shader := Shader.new()
	shader.code = material.shader.code.replace("TIME", "123.0")
	material.shader = shader

func _sample_times() -> Array:
	return [0.0,5.0,10.0,20.0]

func _run(camera: Camera3D, fixture: String) -> void:
	DirAccess.make_dir_recursive_absolute(_report)
	var original := camera.global_transform
	var views := {"pinned":Vector3.ZERO,"near_orb":_orbs[0].get_parent().to_global(_orbs[0].anchor),
		"second_orb":_orbs[5].get_parent().to_global(_orbs[5].anchor)}
	for view: String in views:
		camera.global_transform = original
		if view != "pinned":
			camera.global_position = views[view]+Vector3(6,4,9)
			camera.look_at(views[view],Vector3.UP)
		for seconds in _sample_times():
			var positions: Array = []
			for orb in _orbs:
				orb.elapsed = 0.0
				orb._process(seconds)
				orb.force_update_transform()
				(orb.get_child(0) as Node3D).force_update_transform()
				positions.append(str(orb.global_position))
			await get_tree().create_timer(0.5).timeout
			RenderingServer.force_draw()
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(_report+"/%s_%02d.png"%[view,int(seconds)])
			print("ORB_FRAME ",view," ",seconds," target=",camera.unproject_position(_orbs[5].global_position))
			_rows.append({"view":view,"seconds":seconds,"positions":positions,"camera":str(camera.global_transform),"projected_orb":str(camera.unproject_position(_orbs[5].global_position)),"visible":_orbs[5].is_visible_in_tree(),"sprite_visible":_orbs[5].get_child(0).is_visible_in_tree(),"parent_visible":_orbs[5].get_parent().is_visible_in_tree()})
	FileAccess.open(_report+"/motion.json",FileAccess.WRITE).store_string(JSON.stringify({"fixture":fixture,"fixture_sha256":FileAccess.get_sha256(fixture),"count":_orbs.size(),"rows":_rows},"  "))
	_orbs.clear()
	_world.free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
