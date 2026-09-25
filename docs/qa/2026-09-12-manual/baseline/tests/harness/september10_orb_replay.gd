extends Node3D

## Timed replay of the actual photo-11 world, preserving its source anchors.
## --before uses the frozen original nodes and original large-orb shader.
var _world: Node3D
var _camera: Camera3D
var _output: String
var _small: Array = []
var _large: Array = []
var _batches: Array = []
var _particles: Array[GPUParticles3D] = []
var _before := false
var _rows: Array = []

func _ready() -> void:
	Engine.max_fps = 30
	get_window().size = Vector2i(1718,1035)
	var args := OS.get_cmdline_user_args()
	_output = args[1]
	_before = args.has("--before")
	_world = (load(args[0]) as PackedScene).instantiate()
	for key: StringName in _world.get_meta("shader_globals",{}):
		RenderingServer.global_shader_parameter_set(key,_world.get_meta("shader_globals")[key])
	add_child(_world)
	_camera = _world.get_node("Camera3D") as Camera3D
	_camera.make_current()
	for fx: Node3D in _world.find_children("BiomeFx*","Node3D",true,false):
		var small: PackedVector3Array = fx.get_meta("orb_small_anchors",PackedVector3Array())
		var large: Array = fx.get_meta("orb_large_anchors",[])
		for point in small: _small.append(fx.to_global(point))
		if _before:
			var index := 0
			for child in fx.get_children():
				if child is GPUParticles3D:
					child.use_fixed_seed = true
					child.seed = 7119
					_particles.append(child)
				if String(child.name).begins_with("SpiritOrb"):
					(child.get_child(0).mesh.material as ShaderMaterial).shader = load("res://tests/fixtures/september10_orb_before.gdshader")
					_large.append([child,large[index]])
					index+=1
		else:
			for child in fx.get_children():
				if (child is GPUParticles3D and child.name == &"fireflies") or String(child.name).begins_with("SpiritOrb"):
					child.free()
			var fog := PackedColorArray()
			fog.resize(169)
			fog.fill(Color(0,0,0,0))
			var ground := PackedFloat32Array()
			ground.resize(169)
			var replacement := BiomeChunkFx.build_field({"origin":fx.global_position,
				"fog":fog,"ground":ground,"lo":0.0,"hi":0.0,
				"points":{&"fireflies":small},"orbs":large})
			for child in replacement.get_children():
				replacement.remove_child(child)
				fx.add_child(child)
				if child is SpiritOrb: _large.append([child,child.anchor])
				if child.name == &"SmallSpiritOrbs": _batches.append(child)
			replacement.free()
	if args.has("--hide-cores"):
		for core in _world.find_children("Core*","GeometryInstance3D",true,false): core.visible=false
	if args.has("--hide-halos"):
		for halo in _world.find_children("Halo*","GeometryInstance3D",true,false): halo.visible=false
	if args.has("--hide-lights"):
		for light in _world.find_children("*","OmniLight3D",true,false): light.light_energy=0.0
	_pin_materials(_world)
	_run.call_deferred(args[0])

func _pin_materials(node: Node) -> void:
	var materials: Array = []
	if node is GeometryInstance3D: materials.append(node.material_override)
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count(): materials.append(node.mesh.surface_get_material(i))
	if node is MultiMeshInstance3D and node.multimesh != null:
		for i in node.multimesh.mesh.get_surface_count(): materials.append(node.multimesh.mesh.surface_get_material(i))
	if node is FogVolume: materials.append(node.material)
	for material in materials:
		if material is ShaderMaterial:
			var shader := Shader.new()
			shader.code = material.shader.code.replace("TIME","123.0")
			material.shader = shader
	for child in node.get_children(): _pin_materials(child)

func _target(points: Array, pixel: Vector2) -> Vector3:
	var closest := INF
	var chosen := Vector3.ZERO
	for point: Vector3 in points:
		if _camera.is_position_behind(point): continue
		var distance := _camera.unproject_position(point).distance_squared_to(pixel)
		if distance<closest:
			closest=distance
			chosen=point
	return chosen

func _sample(seconds: float) -> void:
	for row in _large:
		row[0].position = row[1]+SpiritOrb.offset_at(seconds,SpiritOrb.phase_at(row[1]))
		row[0].force_update_transform()
	for batch in _batches:
		batch.sample(seconds,batch.to_local(_camera.global_position))
	for particle in _particles:
		particle.preprocess = 5.0+seconds
		particle.speed_scale = 1.0
		particle.restart()
	# Freeze GPU simulation after a fixed warm-up for each discrete sample.
	for i in 6: await get_tree().process_frame
	for particle in _particles: particle.speed_scale = 0.0
	for i in 6: await get_tree().process_frame

func _run(fixture: String) -> void:
	DirAccess.make_dir_recursive_absolute(_output)
	var original := _camera.global_transform
	var large_points: Array = []
	for row in _large: large_points.append(row[0].get_parent().to_global(row[1]))
	var small_target := _target(_small,Vector2(1370,449))
	var large_target := _target(large_points,Vector2(1219,192))
	var views := {"exact":Vector3.ZERO,"small_close":small_target,"large_close":large_target,
		"small_side":small_target}
	if OS.get_cmdline_user_args().has("--quick"): views={"exact":Vector3.ZERO}
	for label: String in views:
		_camera.global_transform = original
		if label!="exact":
			_camera.global_position = views[label]+(Vector3(-5,2,4) if label=="small_side" else Vector3(4,3,6))
			_camera.look_at(views[label]-Vector3.UP*0.8,Vector3.UP)
		for seconds in [0.0,5.0,10.0,20.0]:
			await _sample(seconds)
			await _shot("%s_%02d"%[label,int(seconds)])
			var positions: Array = []
			for row in _large: positions.append(str(row[0].global_position))
			var small_position := small_target
			for batch in _batches:
				for i in batch.anchors.size():
					if batch.to_global(batch.anchors[i]).distance_to(small_target)<0.001:
						small_position=batch.to_global(batch._cores.multimesh.get_instance_transform(i).origin)
			_rows.append({"view":label,"seconds":seconds,"camera":str(_camera.global_transform),
				"large_positions":positions,"small_target":str(small_target),"large_target":str(large_target),
				"small_position":str(small_position),"small_projected":str(_camera.unproject_position(small_position)),
				"large_projected":str(_camera.unproject_position(large_target))})
			if seconds==0.0 and label!="exact":
				var lights := _world.find_children("*","OmniLight3D",true,false)
				var states: Array = []
				for light in lights:
					states.append(light.visible)
					light.visible=false
				await _shot(label+"_unlit")
				for i in lights.size(): lights[i].visible=states[i]
	FileAccess.open(_output+"/motion.json",FileAccess.WRITE).store_string(JSON.stringify({
		"fixture":fixture,"fixture_sha256":FileAccess.get_sha256(fixture),"before":_before,
		"small_count":_small.size(),"large_count":_large.size(),"rows":_rows},"  "))
	_small.clear()
	_large.clear()
	_batches.clear()
	_particles.clear()
	_world.free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _shot(label: String) -> void:
	RenderingServer.force_draw()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_output+"/"+label+".png")
	print("ORB_REPLAY ",label)
