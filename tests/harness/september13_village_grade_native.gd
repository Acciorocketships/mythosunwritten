extends SceneTree
const BEFORE = preload("res://docs/qa/2026-09-13-manual/17-village-grade/baseline_grade.gd")
const FROZEN = preload("res://tests/fixtures/frozen_terrain_grade.gd")
const DIRECTORY := "res://docs/qa/2026-09-13-manual/17-village-grade/"

func _init() -> void: call_deferred("_run")
func _grade(data: Dictionary, original: bool) -> TerrainGradePatch:
	var result: TerrainGradePatch = BEFORE.new(data.id,data.claims,data.origin,data.pitch) if original else TerrainGradePatch.new(data.id,data.claims,data.origin,data.pitch)
	if not data.source.is_empty(): result._continuous_source=_grade(data.source,original)
	result._continuous_cells=data.continuous_cells
	result._continuous_datum=data.datum
	return result

func _run() -> void:
	root.size=Vector2i(1280,800)
	Engine.max_fps=30
	var p11 := "--p11" in OS.get_cmdline_user_args()
	var spot := "P11" if p11 else "P24"
	var output := DIRECTORY+spot+"-native"
	var hide_skin := "--hide-skin" in OS.get_cmdline_user_args()
	if hide_skin: output += "-without-rock"
	if "--seams" in OS.get_cmdline_user_args(): output += "-seams"
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
	var data:Dictionary=str_to_var(FileAccess.get_file_as_string(DIRECTORY+spot+"-field.txt"))
	var mesher:=TerrainChunkMesher.new()
	mesher.set_seed(2697992464)
	mesher.prepare_resources()
	var scenes:Array[Node3D]=[]
	for original:bool in [true,false]:
		var region:=HeightfieldRegion.new(data.storeys,data.levels,data.carved)
		for grade:Dictionary in data.grades: region.terrain_grades.append(_grade(grade,original))
		var terrain:=Node3D.new()
		stage.add_child(terrain)
		var home:=Vector2i(5,-2) if p11 else Vector2i(-2,2)
		for chunk:Vector2i in ([home,home+Vector2i.UP] if p11 else [home]):
			terrain.add_child(mesher.commit_chunk(mesher.compute_chunk(chunk,region)))
		if hide_skin:
			for skin: MeshInstance3D in terrain.find_children("GradedCliffs","MeshInstance3D",true,false): skin.visible=false
		terrain.visible=false
		scenes.append(terrain)
	var feet:=Vector3(980.5,17,-374.7) if p11 else Vector3(-270.2,16,454)
	var crosshair:=Vector3(981.3,19.5,-377.4) if p11 else Vector3(-275.1,12,444.4)
	var target:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var backward:=(target-crosshair).normalized()
	var eye:=ReviewCam.solve_cam(feet,crosshair,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	var poses:=[]
	for angle:int in [0,-8,8]:
		camera.position=target+(eye-target).rotated(Vector3.UP,deg_to_rad(angle))
		camera.look_at(target)
		poses.append({"angle":angle,"camera":str(camera.transform),"feet":str(feet),"crosshair":str(crosshair)})
		for index in scenes.size():
			scenes[index].visible=true
			for frame in 10: await process_frame
			RenderingServer.force_draw(false)
			var dir:=output.path_join("before" if index==0 else "after")
			DirAccess.make_dir_recursive_absolute(dir)
			root.get_texture().get_image().save_png(dir.path_join("detail_%d.png"%angle))
			scenes[index].visible=false
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	quit()
