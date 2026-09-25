extends SceneTree
const FROZEN = preload("res://tests/fixtures/frozen_terrain_grade.gd")
const DIRECTORY := "res://docs/qa/2026-09-15-manual/01-grass/"

func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.size=Vector2i(1920,1080)
	Engine.max_fps=30
	var args:=OS.get_cmdline_user_args()
	var spot:=args[args.find("--spot")+1]
	var output:=args[args.find("--output")+1]
	var entry:Dictionary
	for record:Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-15-manual/photo-poses.json")):
		if record.id==spot: entry=record
	var feet:=Vector3(entry.player[0],entry.player[1],entry.player[2])
	var crosshair:=Vector3(entry.crosshair[0],entry.crosshair[1],entry.crosshair[2])
	var stage:=Node3D.new()
	root.add_child(stage)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("738080")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=.8
	stage.add_child(env)
	var sun:=DirectionalLight3D.new()
	stage.add_child(sun)
	sun.rotation_degrees=Vector3(-45,-30,0)
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.fov=75
	var mesher:=TerrainChunkMesher.new()
	mesher.set_seed(2697992464)
	mesher.prepare_resources()
	var region:=FROZEN.region(DIRECTORY+spot+"-field.txt")
	if "--grid-candidate" in args:
		region=preload("res://tests/fixtures/september15/grid_grade_candidate.gd").region(region)
	var terrain:=Node3D.new()
	stage.add_child(terrain)
	var home:=Vector2i(floori((feet.x+12)/192),floori((feet.z+12)/192))
	for z in range(home.y-1,home.y+2):
		for x in range(home.x-1,home.x+2):
			terrain.add_child(mesher.commit_chunk(mesher.compute_chunk(Vector2i(x,z),region)))
	var target:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var backward:=(target-crosshair).normalized()
	var eye:=ReviewCam.solve_cam(feet,crosshair,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	var poses:=[]
	for angle:int in [0,-8,8]:
		camera.position=target+(eye-target).rotated(Vector3.UP,deg_to_rad(angle))
		camera.look_at(target)
		poses.append({"angle":angle,"camera":str(camera.transform),"feet":str(feet),"crosshair":str(crosshair)})
		for frame in 10: await process_frame
		RenderingServer.force_draw(false)
		DirAccess.make_dir_recursive_absolute(output)
		root.get_texture().get_image().save_png(output.path_join("detail_%d.png"%angle))
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	quit()
