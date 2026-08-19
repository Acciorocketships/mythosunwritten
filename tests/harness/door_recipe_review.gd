extends SceneTree

## Visual QA for the catalogued door walls and standalone authored leaves.
## Capturing each module from the facade normal and from the side makes an empty
## frame or swung leaf impossible to mistake for one that closes the arch.
const DOOR_IDS: Array[StringName] = [
	&"sfv.fabric.wall.wood.door.001",
	&"sfv.fabric.wall.wood.door.002",
	&"sfv.fabric.wall.wood.door.003",
	&"sfv.fabric.wall.wood.door.004",
	&"sfv.fabric.wall.wood.door.open.001",
	&"sfv.fabric.wall.wood.door.closed.001",
	&"sfv.fabric.wall.rock.door.closed.005",
]
const LEAF_SOURCES: Array[Dictionary] = [
	{"id": "sfv-door-leaf-001", "path":
		"res://assets/FantasyVillageFBX/FBX/Building Attachables/Doors/SFV_Door_001.fbx"},
	{"id": "sfv-door-leaf-002", "path":
		"res://assets/FantasyVillageFBX/FBX/Building Attachables/Doors/SFV_Door_002.fbx"},
]
const ROCK_DOOR_SOURCE := \
	"res://assets/FantasyVillageFBX/FBX/Walls/Rock/Doors/SFV_Wall_Rock_Door_005.fbx"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 1000)
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a6b4bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.72
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 38.0
	world.add_child(camera)
	var catalog := EnvironmentCatalog.load_default()
	for asset_id: StringName in DOOR_IDS:
		var descriptor := catalog.descriptor(asset_id)
		assert(descriptor != null)
		var visual := load(descriptor.visual_path) as EnvironmentVisual
		assert(visual != null)
		var construction := Node3D.new()
		world.add_child(construction)
		for piece: EnvironmentVisualPiece in visual.pieces:
			var instance := MeshInstance3D.new()
			instance.mesh = piece.mesh
			instance.transform = piece.local_transform
			instance.material_override = piece.material_override
			construction.add_child(instance)
		var bounds: AABB = descriptor.measured_aabb
		var target: Vector3 = bounds.get_center()
		for view: Dictionary in [
			{"id": "front", "direction": Vector3.BACK},
			{"id": "back", "direction": Vector3.FORWARD},
			{"id": "side", "direction": Vector3.RIGHT},
		]:
			camera.position = target + (view.direction as Vector3) * 7.5 \
				+ Vector3.UP * 0.25
			camera.look_at(target)
			for unused in 5:
				await process_frame
			RenderingServer.force_draw()
			await process_frame
			var path := "/tmp/warren-%s-%s.png" % [
				String(asset_id).replace(".", "-"), String(view.id)]
			var image := root.get_texture().get_image()
			assert(image != null and image.save_png(path) == OK)
			print("[door_recipe_review] captured %s" % path)
		construction.queue_free()
		await process_frame
	for source: Dictionary in LEAF_SOURCES:
		var scene := load(String(source.path)) as PackedScene
		assert(scene != null)
		var construction := scene.instantiate() as Node3D
		world.add_child(construction)
		var bounds := _visual_bounds(construction)
		print("[door_recipe_review] source=%s bounds=%s" % [source.id,
			bounds])
		await _capture_views(camera, String(source.id), bounds)
		construction.queue_free()
		await process_frame
	var composite := Node3D.new()
	world.add_child(composite)
	for source_path: String in [ROCK_DOOR_SOURCE,
			String(LEAF_SOURCES[0].path)]:
		var scene := load(source_path) as PackedScene
		assert(scene != null)
		var instance := scene.instantiate() as Node3D
		if source_path == String(LEAF_SOURCES[0].path):
			# The attachable leaf's authored hinge is local X=0. Centre its
			# one-metre slab in the wall module's origin-centred aperture.
			instance.position.x = -0.527
		composite.add_child(instance)
	print("[door_recipe_review] composite bounds=%s" % _visual_bounds(composite))
	await _capture_views(camera, "sfv-rock-door-005-closed-composite",
		_visual_bounds(composite))
	composite.queue_free()
	await process_frame
	quit()


func _capture_views(camera: Camera3D, asset_token: String,
		bounds: AABB) -> void:
	var target := bounds.get_center()
	for view: Dictionary in [
		{"id": "front", "direction": Vector3.BACK},
		{"id": "back", "direction": Vector3.FORWARD},
		{"id": "side", "direction": Vector3.RIGHT},
	]:
		camera.position = target + (view.direction as Vector3) * 7.5 \
			+ Vector3.UP * 0.25
		camera.look_at(target)
		for unused in 5:
			await process_frame
		RenderingServer.force_draw()
		await process_frame
		var path := "/tmp/warren-%s-%s.png" % [
			asset_token.replace(".", "-"), String(view.id)]
		var image := root.get_texture().get_image()
		assert(image != null and image.save_png(path) == OK)
		print("[door_recipe_review] captured %s" % path)


func _visual_bounds(construction: Node3D) -> AABB:
	var out := AABB()
	var found := false
	for child in construction.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var placed := instance.global_transform * instance.mesh.get_aabb()
		out = out.merge(placed) if found else placed
		found = true
	assert(found)
	return out
