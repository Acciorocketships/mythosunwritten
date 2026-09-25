extends SceneTree
## Renders frozen town payloads at the September 22 photo angles.
## Usage (GUI): -s native.gd -- --town=town-e --payloads=payload,after --out=DIR [--angles=0,-8,8] [--photos=photo1]
const SPOTS := preload("res://tests/fixtures/september22/spots.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.size = SPOTS.SIZE
	Engine.max_fps = 30
	var town_name := "town-e"
	var names: PackedStringArray = ["payload"]
	var output := ""
	var angles: Array[int] = [0,-8,8]
	var only: PackedStringArray = []
	var spot_town := ""
	var views: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town="): town_name = arg.trim_prefix("--town=")
		if arg.begins_with("--payloads="): names = arg.trim_prefix("--payloads=").split(",")
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--spot-town="): spot_town = arg.trim_prefix("--spot-town=")
		if arg.begins_with("--photos="): only = arg.trim_prefix("--photos=").split(",")
		if arg.begins_with("--view="):
			# --view=name:ex,ey,ez:tx,ty,tz[:fov] adds an explicit detail camera.
			var parts := arg.trim_prefix("--view=").split(":")
			var e := parts[1].split(","); var t := parts[2].split(",")
			views.append({"name": parts[0], "eye": Vector3(float(e[0]),float(e[1]),float(e[2])),
				"target": Vector3(float(t[0]),float(t[1]),float(t[2])), "fov": float(parts[3]) if parts.size() > 3 else 50.0})
		if arg.begins_with("--angles="):
			angles.clear()
			for value in arg.trim_prefix("--angles=").split(","): angles.append(int(value))
	var dir := "res://docs/qa/2026-09-22-manual/" + town_name
	if spot_town.is_empty(): spot_town = town_name
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9fb6c4")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .8
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	stage.add_child(sun)
	sun.rotation_degrees = Vector3(-50,-35,0)
	sun.shadow_enabled = true
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 75
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var towns: Array[Node3D] = []
	var views_by_photo: Dictionary = {}
	for name: String in names:
		var data: Dictionary = FileAccess.open(dir.path_join(name + ".bin"), FileAccess.READ).get_var()
		var town := Node3D.new()
		stage.add_child(town)
		# Production record payloads are already in world space; recompiled
		# fabric payloads are town-local.
		town.transform = Transform3D.IDENTITY if data.get("world_space", name == "payload") else data.transform
		var payload := preload("res://tests/fixtures/september11/floating_payload.gd").payload(data,false)
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO,1,town,payload)
		while queue.pending_count()>0:
			queue.drain(100000,100000,100000)
			await process_frame
		town.visible = false
		towns.append(town)
		if towns.size() == 1:
			# Matched renders share the game camera resolved against the first
			# payload's collision only (hidden later payloads still collide).
			for _i in 3: await physics_frame
			for photo: String in SPOTS.town_photos(spot_town):
				var spot: Dictionary = SPOTS.SPOTS[photo]
				views_by_photo[photo] = SPOTS.resolved(stage.get_world_3d().direct_space_state, spot.feet, spot.aim)
	await physics_frame
	var poses := []
	for photo: String in SPOTS.town_photos(spot_town):
		if not only.is_empty() and not photo in only: continue
		camera.fov = 75
		var spot: Dictionary = SPOTS.SPOTS[photo]
		var view: Dictionary = views_by_photo[photo]
		var pivot: Vector3 = view.pivot
		var eye: Vector3 = view.eye
		for angle: int in angles:
			camera.position = pivot + (eye - pivot).rotated(Vector3.UP, deg_to_rad(angle))
			camera.look_at(pivot)
			poses.append({"photo": photo, "angle": angle, "camera": str(camera.transform)})
			for index in towns.size():
				towns[index].visible = true
				for frame in 8: await process_frame
				RenderingServer.force_draw(false)
				var directory := output.path_join(names[index])
				DirAccess.make_dir_recursive_absolute(directory)
				root.get_texture().get_image().save_png(directory.path_join("%s_%d.png" % [photo, angle]))
				towns[index].visible = false
	for view: Dictionary in views:
		camera.fov = view.fov
		camera.position = view.eye
		camera.look_at(view.target)
		poses.append({"view": view.name, "camera": str(camera.transform)})
		for index in towns.size():
			towns[index].visible = true
			for frame in 8: await process_frame
			RenderingServer.force_draw(false)
			var directory := output.path_join(names[index])
			DirAccess.make_dir_recursive_absolute(directory)
			root.get_texture().get_image().save_png(directory.path_join("%s.png" % view.name))
			towns[index].visible = false
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	print("NATIVE_DONE ", output)
	quit()
