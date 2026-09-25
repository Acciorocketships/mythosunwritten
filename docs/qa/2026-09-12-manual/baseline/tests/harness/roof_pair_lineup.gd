extends SceneTree

## Visual handedness probe for the two-slope gabled roof contract.
const SLOPE := "res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_S_Blue_002.fbx"
const GABLE := "res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Triangle/SFV_Roof_Wall_M_001.fbx"
const HALF_SPAN := 1.6217227

const CONFIGURATIONS: Array[Dictionary] = [
	{"label": "A left 0 / right 180", "left": 0.0, "right": PI},
	{"label": "B left 180 / right 0", "left": PI, "right": 0.0},
	{"label": "C both 0", "left": 0.0, "right": 0.0},
	{"label": "D both 180", "left": PI, "right": PI},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9eacb4")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var slope_scene := load(SLOPE) as PackedScene
	var gable_scene := load(GABLE) as PackedScene
	assert(slope_scene != null and gable_scene != null)
	for index in CONFIGURATIONS.size():
		var config := CONFIGURATIONS[index]
		var centre := Vector3(float(index % 2) * 12.0 - 6.0, 0.0,
			float(index / 2) * 11.0 - 5.5)
		for along in [-1.5, 1.5]:
			_add_slope(world, slope_scene,
				centre + Vector3(-HALF_SPAN, 0.0, along), float(config.left))
			_add_slope(world, slope_scene,
				centre + Vector3(HALF_SPAN, 0.0, along), float(config.right))
		for end_z in [-3.0, 3.0]:
			var gable := gable_scene.instantiate() as Node3D
			gable.position = centre + Vector3(0.0, 0.0, end_z)
			gable.rotation.y = 0.0 if end_z < 0.0 else PI
			world.add_child(gable)
		var label := Label3D.new()
		label.text = String(config.label)
		label.font_size = 64
		label.outline_size = 10
		label.position = centre + Vector3(0.0, 6.0, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	var camera := Camera3D.new()
	camera.fov = 52.0
	camera.position = Vector3(22.0, 21.0, 29.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 2.0, 0.0))
	for unused in 10:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var path := "/tmp/warren-roof-pair-lineup.png"
	var image := root.get_texture().get_image()
	assert(image != null and image.save_png(path) == OK)
	print("[roof_pair_lineup] captured %s" % path)
	quit()


static func _add_slope(parent: Node3D, scene: PackedScene, position: Vector3,
		yaw: float) -> void:
	var slope := scene.instantiate() as Node3D
	slope.position = position
	slope.rotation.y = yaw
	parent.add_child(slope)
