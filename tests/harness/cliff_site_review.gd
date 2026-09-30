extends Node3D

## Iterative cliff-rock review at one streamed production site.
## Streams the real world around `--at`, captures every `--view`, then waits.
## Touch `<output>/reload` to hot-reload the cliff rock scripts, recompute the
## rock formations and cliff vegetation of every loaded chunk from the same
## worker regions/features/water, and capture again into the next iteration
## folder. Touch `<output>/quit` to exit. Without --full only the rock layer changes. With --full, terrain,
## collision and grass are regenerated for the framed chunks.
##
##   Godot --path . res://tests/harness/cliff_site_review.tscn -- \
##     --seed 2697992464 --at 300,20,995 --output DIR \
##     --view id:px,py,pz:tx,ty,tz[:fov]
const WAIT_HARD_TIMEOUT_SECONDS := 1500.0
const IDLE_SETTLE_SECONDS := 3.0
const RELOAD := [
	"res://scripts/terrain/field/CliffRockEndCaps.gd",
	"res://scripts/terrain/field/CliffLedgeJoin.gd",
	"res://scripts/terrain/field/CliffRockCrags.gd",
	"res://scripts/terrain/field/CliffCornerCrags.gd",
	"res://scripts/terrain/field/CliffRockRelief.gd",
	"res://scripts/terrain/field/CliffInnerSurface.gd",
	"res://scripts/terrain/field/CliffStepSurface.gd",
	"res://scripts/terrain/field/CliffInnerConnections.gd",
	"res://scripts/terrain/field/CliffRockDressing.gd",
	"res://scripts/terrain/field/CliffVegetation.gd",
	"res://scripts/terrain/field/CliffKitDressing.gd",
	"res://scripts/terrain/dressing/RockSkirt.gd",
	"res://scripts/terrain/field/CliffSlopeRocks.gd",
	"res://scripts/terrain/field/CliffSlopeEnvelope.gd",
	"res://scripts/terrain/field/CliffSlopeField.gd",
	"res://scripts/terrain/grass/GrassSupportSurfaces.gd",
	"res://scripts/terrain/grass/GrassField.gd",
	"res://scripts/terrain/field/TerrainSurfaceField.gd",
	"res://scripts/terrain/field/TerrainChunkMesher.gd",
	"res://scripts/terrain/water/WaterSkin.gd",
]
const CRAG_SHADER := "res://terrain/materials/cliff_crag.gdshader"
const STYLE = preload("res://scripts/terrain/field/CliffRockStyle.gd")

var _seed := 2697992464
var _at := Vector3.ZERO
var _radius := 1
var _grass := false
var _output_dir := "/tmp/mythos-cliff-site-review"
var _views: Array[Dictionary] = []
var _walks: Array[Dictionary] = []
## Art-direction variants rendered per iteration (CliffRockStyle.apply names).
var _styles: PackedStringArray = []
var _plain := false
## Also capture each view with the terrain category overlay (F9 view).
var _categories := false
## Full mode: each iteration discards the framed terrain chunks (and their
## grass) so the streamer rebuilds them whole with the current scripts.
var _full := false
var _streamer: FieldTerrainStreamer
var _character: CharacterBody3D
var _camera := Camera3D.new()
var _inputs: Dictionary = {}


func _ready() -> void:
	_read_args()
	get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	_streamer = world.find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	_character = world.find_child("Character", true, false) as CharacterBody3D
	_character.visible = false
	_streamer.SEED_OVERRIDE = _seed
	_streamer.CHUNK_RADIUS = _radius
	_streamer.KEEP_RADIUS = _radius + 1
	_streamer.GRASS_ENABLED = _grass
	_character.position = _at + Vector3.UP * 4.0
	add_child(world)
	_camera.current = true
	add_child(_camera)
	_run.call_deferred()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		var next := args[index + 1] if index + 1 < args.size() else ""
		match args[index]:
			"--seed": _seed = int(next)
			"--at": _at = _v3(next)
			"--radius": _radius = int(next)
			"--grass": _grass = true
			"--output": _output_dir = next
			"--styles": _styles = next.split(",", false)
			"--plain": _plain = true
			"--categories": _categories = true
			"--full": _full = true
			"--override":
				# res://path=/abs/source: start from another revision of a
				# reloadable script (a matched before/after in one process).
				var pair := next.split("=")
				var script := load(pair[0]) as GDScript
				script.source_code = FileAccess.get_file_as_string(pair[1])
				assert(script.reload(false) == OK)
			"--shot", "--mouse-shot":
				# id:player:crosshair from the owner's F3 overlay; the tactical
				# camera (26 m back, 16 m up, looking 1 m above the player).
				var shot := next.split(":", false)
				var player := _v3(shot[1])
				_views.append({"id": shot[0], "position": ReviewCam.solve_cam(player, _v3(shot[2]), 26.0, 16.0, 1.0),
					"target": player + Vector3.UP, "fov": 50.0, "player": player})
				if args[index] == "--mouse-shot":
					var pivot := player + Vector3.UP * CameraMouseView.PIVOT_HEIGHT
					var delta := _v3(shot[2]) - pivot
					var pitch := atan2(-delta.y, Vector2(delta.x,delta.z).length())
					var boom := CameraMouseView.BOOM_LENGTH
					_views[-1].position = ReviewCam.solve_cam(player,_v3(shot[2]),
						boom*cos(pitch),CameraMouseView.PIVOT_HEIGHT+boom*sin(pitch),CameraMouseView.PIVOT_HEIGHT)
					_views[-1].target = pivot
					_views[-1].fov = 75.0
			"--walk":
				var parts := next.split(":",false)
				_walks.append({"id":parts[0],"start":_v3(parts[1]),"direction":_v3(parts[2]),"distance":float(parts[3])})
			"--view":
				var parts := next.split(":", false)
				_views.append({"id": parts[0], "position": _v3(parts[1]), "target": _v3(parts[2]),
					"fov": float(parts[3]) if parts.size() > 3 else 62.0})


static func _v3(text: String) -> Vector3:
	var p := text.split(",", false)
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _run() -> void:
	var ready := await _wait_for_site()
	print("[cliff_site_review] site_ready=", ready)
	_character.set_physics_process(false)
	_collect_inputs()
	var iteration := 0
	await _capture_iteration(iteration)
	await _run_walks(iteration)
	while true:
		# Test-only probes can inspect the settled native world between reviews.
		if FileAccess.file_exists(_output_dir + "/probe"):
			var path:=FileAccess.get_file_as_string(_output_dir+"/probe").strip_edges()
			DirAccess.remove_absolute(_output_dir+"/probe")
			assert(path.begins_with("res://tests/"))
			var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(path)
			if script.reload()==OK:
				await script.new().run(self)
			else:
				push_error("Review probe failed to parse: %s" % path)
		if FileAccess.file_exists(_output_dir + "/quit"):
			DirAccess.remove_absolute(_output_dir + "/quit")
			break
		if FileAccess.file_exists(_output_dir + "/recapture"):
			DirAccess.remove_absolute(_output_dir + "/recapture")
			iteration += 1
			await _capture_all(iteration)
		if FileAccess.file_exists(_output_dir + "/reload"):
			DirAccess.remove_absolute(_output_dir + "/reload")
			iteration += 1
			var started := Time.get_ticks_msec()
			_reload_scripts()
			await _capture_iteration(iteration)
			await _run_walks(iteration)
			print("[cliff_site_review] iteration=%d ms=%d" % [iteration, Time.get_ticks_msec() - started])
		await get_tree().create_timer(0.3).timeout
	get_tree().quit(0)


func _capture_iteration(iteration: int) -> void:
	if _full:
		for style: String in (_styles if not _styles.is_empty() else PackedStringArray([""])):
			if not style.is_empty():
				STYLE.apply(style)
			if iteration > 0 or not style.is_empty():
				await _rebuild_full()
			await _capture_all(iteration, style)
		return
	if _styles.is_empty():
		if iteration > 0:
			_rebuild_rocks()
		await _capture_all(iteration)
		return
	for style: String in _styles:
		STYLE.apply(style)
		var started := Time.get_ticks_msec()
		_rebuild_rocks()
		print("[cliff_site_review] style=%s rebuilt ms=%d" % [style, Time.get_ticks_msec() - started])
		await _capture_all(iteration, style)
	STYLE.apply("current")


func _framed_chunks() -> Array:
	var framed := {}
	for view: Dictionary in _views:
		var target: Vector3 = view.target
		for dx in [-24.0, 0.0, 24.0]:
			for dz in [-24.0, 0.0, 24.0]:
				framed[FieldTerrainStreamer.chunk_of(target + Vector3(dx, 0, dz))] = true
	return framed.keys()


## Grass grows around the player: stand the (hidden) player at a shot and wait
## for its tiles. Radius 0 keeps the move from requesting unloaded chunks.
func _grass_at(player: Vector3) -> void:
	_streamer.CHUNK_RADIUS = 0
	_character.global_position = player + Vector3.UP * .5
	var started := Time.get_ticks_msec()
	var idle_since := -1
	while Time.get_ticks_msec() - started < 90000:
		var grass: GrassStreamer = _streamer._grass_streamer
		if grass.pending_count() == 0 and grass._requested.is_empty():
			if idle_since < 0:
				idle_since = Time.get_ticks_msec()
			elif Time.get_ticks_msec() - idle_since > 1500:
				return
		else:
			idle_since = -1
		await get_tree().create_timer(0.25).timeout


func _rebuild_full() -> void:
	_character.global_position = _at + Vector3.UP * 4.0
	_streamer.CHUNK_RADIUS = _radius
	var chunks := _framed_chunks()
	var started := Time.get_ticks_msec()
	_streamer.rebuild_terrain(chunks)
	var idle_since := -1
	while float(Time.get_ticks_msec() - started) / 1000.0 < WAIT_HARD_TIMEOUT_SECONDS:
		var missing := chunks.filter(func(c: Vector2i) -> bool: return not _streamer._built.has(c))
		var progress := _streamer.worker_progress_snapshot()
		var active := bool(progress.get("active", false)) and StringName(progress.get("phase", &"idle")) != &"idle"
		var grass_busy := _grass and int(_streamer._grass_streamer.pending_count()) > 0
		if missing.is_empty() and not active and not grass_busy:
			if idle_since < 0:
				idle_since = Time.get_ticks_msec()
			elif float(Time.get_ticks_msec() - idle_since) / 1000.0 >= 4.0:
				break
		else:
			idle_since = -1
		await get_tree().create_timer(0.25).timeout
	print("[cliff_site_review] full rebuild chunks=%d ms=%d" % [chunks.size(), Time.get_ticks_msec() - started])


func _collect_inputs() -> void:
	# The worker is idle: its canonical caches are safe to read here.
	# Only chunks framed by a view are rebuilt; rock generation is expensive.
	var framed := {}
	for view: Dictionary in _views:
		var target: Vector3 = view.target
		for dx in [-40.0, 0.0, 40.0]:
			for dz in [-40.0, 0.0, 40.0]:
				framed[FieldTerrainStreamer.chunk_of(target + Vector3(dx, 0, dz))] = true
	for chunk: Vector2i in _streamer._built.keys():
		if not framed.has(chunk):
			continue
		var features: FeatureContext = _streamer._features.context_for(chunk, Callable())
		_inputs[chunk] = {"region": features.graded_region(_streamer._fields.region(chunk)),
			"water": _streamer._fields.water(chunk), "features": features}


func _reload_scripts() -> void:
	for path: String in RELOAD:
		var script := load(path) as GDScript
		script.source_code = FileAccess.get_file_as_string(path)
		# Live instances (the streamer's mesher) keep their state across a reload.
		var error := script.reload(true)
		if error != OK:
			push_error("reload failed: %s (%d)" % [path, error])
	# Shared includes first (cached ShaderIncludes keep their old code), then
	# the crag shader: every material holding this Shader recompiles.
	for file: String in DirAccess.get_files_at("res://terrain/materials/"):
		if file.ends_with(".gdshaderinc"):
			var include := load("res://terrain/materials/" + file) as ShaderInclude
			include.code = FileAccess.get_file_as_string("res://terrain/materials/" + file)
	var shader := load(CRAG_SHADER) as Shader
	shader.code = FileAccess.get_file_as_string(CRAG_SHADER)
	var meadow := load("res://terrain/materials/meadow_rock.gdshader") as Shader
	meadow.code = FileAccess.get_file_as_string("res://terrain/materials/meadow_rock.gdshader")
	var grass_shader := load("res://terrain/grass/grass.gdshader") as Shader
	grass_shader.code = FileAccess.get_file_as_string("res://terrain/grass/grass.gdshader")
	load("res://scripts/terrain/field/CliffRockDressing.gd").prepare()
	load("res://scripts/terrain/field/CliffVegetation.gd").prepare()


func _rebuild_rocks() -> void:
	var rocks: GDScript = load("res://scripts/terrain/field/CliffRockDressing.gd")
	var vegetation: GDScript = load("res://scripts/terrain/field/CliffVegetation.gd")
	var cells := TerrainChunkMesher.CELLS_PER_CHUNK
	var seed_value: int = _streamer._mesher._water_seed
	for chunk: Vector2i in _inputs:
		var root: Node3D = _streamer._built.get(chunk)
		if root == null:
			continue
		var input: Dictionary = _inputs[chunk]
		var lo := chunk * cells
		for name: String in ["CliffRockFormations", "CliffVegetation", "CliffKit"]:
			var old := root.get_node_or_null(name)
			if old != null:
				root.remove_child(old)
				old.free()
		if STYLE.crags:
			var cliffs := CliffDressing.compute(input.region, lo.x, lo.y, cells)
			var data: Dictionary = rocks.compute(input.region, lo.x, lo.y, cells, seed_value, input.features, input.water)
			var plants: Array = vegetation.compute(cliffs, data, input.region, seed_value, input.features, input.water)
			root.add_child(rocks.build(data, _streamer._mesher._water_seed))
			root.add_child(vegetation.build(plants))



func _wait_for_site() -> bool:
	var wanted: Array = _streamer.desired_chunks(FieldTerrainStreamer.chunk_of(_at), _radius)
	var started := Time.get_ticks_msec()
	var idle_since := -1
	while float(Time.get_ticks_msec() - started) / 1000.0 < WAIT_HARD_TIMEOUT_SECONDS:
		var missing := wanted.filter(func(c: Vector2i) -> bool:
			return not _streamer._built.has(c) or not _streamer._feature_square_ready(c))
		var progress := _streamer.worker_progress_snapshot()
		var active := bool(progress.get("active", false)) and StringName(progress.get("phase", &"idle")) != &"idle"
		if missing.is_empty() and _streamer.startup_loading_complete() and not active:
			if idle_since < 0:
				idle_since = Time.get_ticks_msec()
			elif float(Time.get_ticks_msec() - idle_since) / 1000.0 >= IDLE_SETTLE_SECONDS:
				return true
		else:
			idle_since = -1
		await get_tree().create_timer(0.25).timeout
	return false


func _capture_all(iteration: int, style := "") -> void:
	var dir := "%s/%02d" % [_output_dir, iteration]
	if not style.is_empty():
		dir += "/" + style
	DirAccess.make_dir_recursive_absolute(dir)
	# Views may be added between iterations: one "id:px,py,pz:tx,ty,tz[:fov]"
	# per line in <output>/views.txt (the rebuilt chunks stay those framed at start).
	var extra := FileAccess.get_file_as_string(_output_dir + "/views.txt")
	for line: String in extra.split("\n", false):
		var parts := line.strip_edges().split(":", false)
		if parts.size() >= 3 and not _views.any(func(v: Dictionary) -> bool: return v.id == parts[0]):
			_views.append({"id": parts[0], "position": _v3(parts[1]), "target": _v3(parts[2]),
				"fov": float(parts[3]) if parts.size() > 3 else 62.0})
	for view: Dictionary in _views:
		if _grass and view.has("player"):
			await _grass_at(view.player)
		_camera.fov = float(view.fov)
		var up := Vector3.FORWARD if String(view.id).begins_with("plan") else Vector3.UP
		_camera.look_at_from_position(view.position, view.target, up)
		_camera.force_update_transform()
		for unused in 4:
			await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/%s.png" % [dir, String(view.id)])
		var overlay := get_tree().root.find_child("TerrainCategoryOverlay", true, false)
		if _categories and overlay != null:
			overlay.set_enabled(true)
			for unused in 4:
				await get_tree().process_frame
			RenderingServer.force_draw()
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/%s_categories.png" % [dir, String(view.id)])
			overlay.set_enabled(false)
		for mode: String in ([] if _plain else ["kinds", "ids"]):
			_paint(mode)
			for unused in 3:
				await get_tree().process_frame
			RenderingServer.force_draw()
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [dir, String(view.id), mode])
		_paint("")
	if _grass:
		_character.global_position = _at + Vector3.UP * 4.0
		_streamer.CHUNK_RADIUS = _radius
	print("[cliff_site_review] captured iteration=%d dir=%s" % [iteration, dir])


const KIND_COLORS := {"wall": Color(0.85, 0.85, 0.85), "joined": Color(1.0, 0.55, 0.1),
	"step": Color(1.0, 0.95, 0.1), "ledge": Color(0.1, 0.9, 0.95), "corner": Color(0.15, 0.35, 1.0),
	"inner_corner": Color(0.1, 0.8, 0.2), "inner_surface": Color(1.0, 0.1, 0.1), "waterline": Color(0.7, 0.2, 1.0)}


func _paint(mode: String) -> void:
	var index := 0
	for root: Node in _streamer._built.values():
		var formations := (root as Node).get_node_or_null("CliffRockFormations")
		if formations == null:
			continue
		for child: Node in formations.get_children():
			var instance := child as GeometryInstance3D
			if instance == null:
				continue
			if mode.is_empty():
				instance.material_override = null
				continue
			var color := Color(0.4, 0.4, 0.4)
			if instance.has_meta("relief_recipe"):
				var recipe: Dictionary = instance.get_meta("relief_recipe")
				if mode == "ids":
					color = Color.from_hsv(fposmod(float(hash(str(recipe)) % 1000) * 0.618, 1.0), 0.75, 0.95)
				else:
					var kind := String(recipe.get("kind", "wall"))
					if kind == "wall":
						if recipe.has("waterline"): kind = "waterline"
						elif recipe.has("step_surface"): kind = "step"
						elif recipe.has("inner_connections"): kind = "joined"
						elif recipe.has("ledge_joins"): kind = "ledge"
					color = KIND_COLORS.get(kind, Color.MAGENTA)
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			instance.material_override = material
			index += 1


class WalkController extends CharacterController:
	var direction:=Vector2.ZERO
	func get_move_vector(_body:CharacterBody3D,_dt:float)->Vector2:return direction

func _run_walks(iteration:int)->void:
	if _walks.is_empty():return
	var original:CharacterController=_character.controller
	var controller:=WalkController.new()
	_character.controller=controller
	_character.set_physics_process(false)
	_streamer.CHUNK_RADIUS=0
	var rows:=[]
	for walk:Dictionary in _walks:
		await _grass_at(walk.start)
		# Camera teleports can demand an arrival halo beyond the review's loaded
		# set. Walk only through verified loaded chunks, with streaming paused;
		# retain the production character, controller and collision unchanged.
		for distance in range(0,ceili(float(walk.distance))+2):
			var point:Vector3=walk.start+walk.direction.normalized()*distance
			assert(_streamer._built.has(FieldTerrainStreamer.chunk_of(point)))
		_streamer.set_process(false)
		_streamer._freeze_player(false)
		await get_tree().physics_frame
		_character.global_position=walk.start+Vector3.UP*.06
		_character.velocity=Vector3.ZERO
		controller.direction=Vector2.ZERO
		for tick in 30:
			await get_tree().physics_frame
			_character._physics_process(1.0/60.0)
		var start:=_character.global_position
		var direction:Vector3=(walk.direction as Vector3).normalized()
		controller.direction=Vector2(direction.x,direction.z)
		var trace:=[];var contacts:={}
		for tick in 360:
			await get_tree().physics_frame
			_character._physics_process(1.0/60.0)
			if tick%15==0:trace.append([_character.position.x,_character.position.y,_character.position.z])
			for index in _character.get_slide_collision_count():
				var hit:=_character.get_slide_collision(index)
				contacts[str(hit.get_normal().snapped(Vector3.ONE*.05))]=true
			if (_character.position-start).dot(direction)>=float(walk.distance):break
		var finish:=_character.global_position
		rows.append({"id":walk.id,"start":[start.x,start.y,start.z],"end":[finish.x,finish.y,finish.z],"travel":(finish-start).dot(direction),"rise":finish.y-start.y,"on_floor":_character.is_on_floor(),"passed":(finish-start).dot(direction)>=float(walk.distance),"trace":trace,"contacts":contacts.keys()})
		controller.direction=Vector2.ZERO
		_streamer.set_process(true)
	_character.controller=original
	FileAccess.open("%s/%02d/walks.json"%[_output_dir,iteration],FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("[cliff_site_review] walks ",JSON.stringify(rows))
