extends SceneTree
## Re-renders a frozen live world (world.scn saved by live.gd) at every photo of
## its town with the game's resolved close camera. Matched before/after pairs
## come from two such snapshots rendered by this one harness.
## Usage (GUI): -s replay.gd -- --town=town-e --world=res://.../world.scn --out=DIR
const SPOTS := preload("res://tests/fixtures/september22/spots.gd")
const GLOBALS := [&"biome_ground_a",&"biome_ground_b",&"biome_ground_color",&"biome_ground_origin",&"grass_lod_origin",&"wind_direction",&"wind_idle_bend",&"wind_gust_texture",&"wind_gust_scale",&"wind_gust_speed",&"wind_gust_bend",&"grass_trample_texture",&"grass_static_trample_texture",&"grass_trample_origin",&"grass_trample_size",&"grass_trample_epoch"]
func _init() -> void: run.call_deferred()
func run() -> void:
	var town := "town-e"; var world_path := ""; var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town="): town = arg.trim_prefix("--town=")
		if arg.begins_with("--world="): world_path = arg.trim_prefix("--world=")
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	Engine.max_fps = 30
	root.size = SPOTS.SIZE
	var stage: Node3D = (load(world_path) as PackedScene).instantiate()
	root.add_child(stage)
	var globals: Dictionary = stage.get_meta("shader_globals", {})
	for key: StringName in globals:
		if key in GLOBALS: RenderingServer.global_shader_parameter_set(key, globals[key])
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 75
	for i in 4: await physics_frame
	for photo: String in SPOTS.town_photos(town):
		var spot: Dictionary = SPOTS.SPOTS[photo]
		var view: Dictionary = SPOTS.resolved(camera.get_world_3d().direct_space_state, spot.feet, spot.aim)
		camera.global_position = view.eye
		camera.look_at(view.pivot)
		for i in 8: await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(out.path_join(photo + ".png"))
	print("REPLAY_DONE ", out)
	quit()
