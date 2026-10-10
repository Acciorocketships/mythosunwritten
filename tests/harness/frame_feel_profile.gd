extends Node

## How smooth does the game FEEL? The real world scene and streamer, the close
## (over-the-shoulder) camera, and scripted input: stand, turn the view at a
## constant rate, run, run while turning. Every displayed frame logs its
## interval, CPU (process/physics/render) and GPU time, how many physics ticks
## ran in it, and how far the camera actually turned. A camera that only moves
## on physics ticks shows up as frames whose turn is far from rate * interval
## ("judder"), even when the frame rate is fine.
##   Godot --path . res://tests/harness/frame_feel_profile.tscn -- \
##     [--seed N] [--phase-seconds 8] [--report /tmp/feel.json] [--size 1920x1080]
##     [--no-vsync] [--turn-deg 120] [--x X --z Z] [--ablate] [--imposter-distance M] [--view-shots DIR]
## --shared-profile selects the continuous tile candidate before any plan.
## --ablate then holds a slow turn and switches one render feature off at a
## time (ablate_* phases), so each feature's cost is the difference from the
## ablate_full phases before and after.
## --steady-ablate instead waits for the full ring and compares a fixed view,
## with streamer integration paused and a baseline before every variant.
const WORLD := preload("res://scenes/world.tscn")
const CALLBACK_PROBE = preload("res://tests/harness/ProcessCallbackProbe.gd")
const PHASES := ["idle", "turn", "run", "run_turn", "idle_end"]
const ABLATIONS := ["full", "no_shadows", "shadow_2048", "shadow_2_splits", "no_fog", "no_ssao", "no_msaa", "no_glow", "no_grass", "grass_flat_material", "grass_lod_bias_half", "grass_lod_bias_quarter", "grass_density_half",
	"no_water", "no_dressing", "no_cliff_sheet", "no_terrain_mesh", "half_res", "full_end"]

var _world: Node3D
var _player: CharacterBody3D
var _streamer: FieldTerrainStreamer
var _memory_idle_end := 0.0
var _texture_mem_idle_end := 0.0
var _video_mem_idle_end := 0.0
var _rig: Node
var _camera: Camera3D
var _seed := 2697992464
var _runtime_probe: RefCounted
var _collision_stats: Dictionary = {}
var _managed_heap_bytes := -1
var _managed_full_collections := -1
var _phase_seconds := 8.0
var _turn_rate := deg_to_rad(120.0)
var _report_path := "/private/tmp/frame-feel.json"
var _phase := "startup"
var _frames: Array[Dictionary] = []
var _last_usec := 0
var _ticks := 0
var _last_yaw := 0.0
var _last_cam := Vector3.ZERO
var _turning := false
var _start := 0
var _x := 0.5
var _z := 0.5
var _ablate := false
var _steady_ablate := false
var _steady_status := {}
var _ablation_variants: Array = []
var _ablation_shots := ""
var _grass_trial_materials: Dictionary = {}
var _profile_callbacks := false
var _idle_only := false
var _stop_after_run := false
var _callback_times: Dictionary = {}
var _fixed_route := false
var _return_to_start := false
var _return_status := {}
var _shots_dir := ""
var _view_shots := ""
var _prespin := false
var _terrain_radius := -1
# Exact per-frame spans: this node runs first (priority -1000) and a tail
# node runs last, so their difference is every script's _process (resp.
# _physics_process) time this frame. The Performance monitors are not usable
# per frame (they update about once a second).
var _process_begin := 0
var _process_usec := 0
var _physics_begin := 0
var _physics_usec := 0
var _tail: Node
var _all_phases: Array = PHASES.duplicate()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var size := Vector2i.ZERO
	var vsync := true
	for i in args.size():
		var next := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--collision-residency": FieldTerrainStreamer.COLLISION_RESIDENCY = true
			"--full-collision": FieldTerrainStreamer.COLLISION_RESIDENCY = false
			"--shared-profile": TerrainTileField.cliff_end = TerrainTileField.CliffEnd.SHARED_PROFILE
			"--seed": _seed = int(next)
			"--phase-seconds": _phase_seconds = float(next)
			"--terrain-radius": _terrain_radius = maxi(1, int(next))
			"--fixed-route": _fixed_route = true
			"--return-to-start": _return_to_start = true
			"--report": _report_path = next
			"--turn-deg": _turn_rate = deg_to_rad(float(next))
			"--size": size = Vector2i(int(next.split("x")[0]), int(next.split("x")[1]))
			"--no-vsync": vsync = false
			"--maximize": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
			"--x": _x = float(next)
			"--z": _z = float(next)
			"--ablate": _ablate = true
			"--steady-ablate": _steady_ablate = true
			"--ablate-variants": _ablation_variants = Array(next.split(",", false))
			"--ablate-shots": _ablation_shots = next
			"--profile-callbacks": _profile_callbacks = true
			"--capture-ripple":
				_profile_callbacks = true
				CALLBACK_PROBE.capture_ripple_enabled = true
			"--idle-only": _idle_only = true
			"--stop-after-run": _stop_after_run = true
			"--grass-shots": _shots_dir = next
			# Close and tactical views at four headings, then quit (imposter review).
			"--view-shots": _view_shots = next
			"--prespin": _prespin = true
			# Tree imposter switch distance (1e6 = never; before/after checks).
			"--imposter-distance": EnvironmentCommitQueue.set_imposter_distance(float(next))
			# Bark crossfade ablation (off = trunks without the dither discard).
			"--bark-dither": EnvironmentCommitQueue.BARK_DITHER = next != "off"
			"--grass-workers": GrassWorkQueue.WORKERS = int(next)
			"--grass-lod-bias": GrassStreamer.BLADE_LOD_BIAS = float(next)
			"--grass-radius":
				var pair := next.split(",")
				GrassStreamer.set_radii(float(pair[0]), float(pair[1]))
	if size != Vector2i.ZERO: get_window().size = size
	if not vsync: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if ClassDB.class_exists(&"CSharpScript"):
		var probe_script := load("res://scripts/native/NativeRuntimeProbe.cs") as Script
		if probe_script != null and probe_script.can_instantiate():
			_runtime_probe = probe_script.new()
	_start = Time.get_ticks_msec()
	if _profile_callbacks:
		for path: String in ["camera/camera.gd", "terrain/grass/TrampleField.gd",
			"terrain/water/WaterRippleSim.gd", "terrain/biome/AtmosphereDirector.gd",
			"terrain/biome/SmallSpiritOrbs.gd", "terrain/biome/SpiritOrb.gd",
			"terrain/field/FirstViewWarmer.gd", "terrain/field/FieldTerrainStreamer.gd",
			"terrain/tools/CoordOverlay.gd", "terrain/tools/TerrainCategoryOverlay.gd"]:
			CALLBACK_PROBE.install("res://scripts/" + path)
		CALLBACK_PROBE.install_method("res://scripts/terrain/diagnostics/ManualJudgingLogger.gd", "_record_frame", "_dt: float", "_dt", "void")
		for method: String in ["_refresh_flow_texture", "_upload_packets"]:
			CALLBACK_PROBE.install_method("res://scripts/terrain/water/WaterRippleSim.gd", method, "", "", "void")
		CALLBACK_PROBE.install_method("res://scripts/terrain/water/WaterRippleSim.gd", "_update_packets", "delta: float", "delta", "void")
		CALLBACK_PROBE.install_method("res://scripts/terrain/water/WaterRippleSim.gd", "_spawn_packet", "", "", "bool")
		CALLBACK_PROBE.install_method("res://scripts/terrain/water/WaterRippleSim.gd", "_sampler_at", "p: Vector2", "p", "WaterSampler")
		for method: String in ["_surface_frame", "current_frame_at"]:
			CALLBACK_PROBE.install_method("res://scripts/terrain/water/WaterSampler.gd", method, "xz: Vector2", "xz", "PackedVector2Array")
		for method: String in ["_native_fill_level_at", "_current_fill_level_at"]:
			CALLBACK_PROBE.install_method("res://scripts/terrain/water/WaterSampler.gd", method, "xz: Vector2", "xz", "float")
	_world = WORLD.instantiate()
	_player = _world.get_node("Characters/Character")
	_streamer = _world.get_node("FieldTerrain")
	_rig = _world.get_node("Camera3D")
	_camera = _rig as Camera3D
	_streamer.SEED_OVERRIDE = _seed
	if _terrain_radius > 0:
		_streamer.CHUNK_RADIUS = _terrain_radius
		_streamer.KEEP_RADIUS = _terrain_radius + 1
	_player.position = Vector3(_x, 32.0, _z)
	add_child(_world)
	_tail = Tail.new()
	_tail.owner_profile = self
	add_child(_tail)
	process_priority = -1000          # sample before the game's own _process
	process_physics_priority = -1000
	_run.call_deferred()


class Tail extends Node:
	var owner_profile: Node
	func _ready() -> void:
		process_priority = 100000
		process_physics_priority = 100000
	func _process(_d: float) -> void:
		owner_profile._process_usec = Time.get_ticks_usec() - owner_profile._process_begin
		if owner_profile._profile_callbacks:
			owner_profile._callback_times = CALLBACK_PROBE.samples.duplicate()
		owner_profile._sample_camera(_d)
	func _physics_process(_d: float) -> void:
		owner_profile._physics_usec += Time.get_ticks_usec() - owner_profile._physics_begin


func _physics_process(_delta: float) -> void:
	_ticks += 1
	_physics_begin = Time.get_ticks_usec()


var _pending_frame := 0
var _pending_last := 0
var _grass_backlog := {}


## pending_tiles() sorts the whole ring; sampling it every frame would sit inside the measured
## process time and grow with the ring, so sample every 10th frame and carry the value forward.
func _sampled_pending() -> int:
	if _streamer._grass_streamer == null:
		return 0
	if _pending_frame % 10 == 0:
		var grass: GrassStreamer = _streamer._grass_streamer
		var backlog := {"waiting_ground": 0, "waiting_sampler": 0,
			"unrequested": 0, "requested": 0, "waiting_commit": 0}
		_pending_last = 0
		for tile: Vector2i in GrassStreamer.desired_tiles(grass._lod_origin):
			if grass._built.has(tile): continue
			_pending_last += 1
			if grass._pending_tiles.has(tile): backlog.waiting_commit += 1
			elif grass._requested.has(tile): backlog.requested += 1
			else:
				var chunk := GrassField.parent_chunk(tile)
				if not _streamer._built.has(chunk): backlog.waiting_ground += 1
				elif not (_streamer._built[chunk] as Node).has_meta(&"grass_sampling"):
					backlog.waiting_sampler += 1
				else: backlog.unrequested += 1
		if _streamer._grass_work != null: backlog.worker = _streamer._grass_work.stats()
		_grass_backlog = backlog
	_pending_frame += 1
	return _pending_last


func _process(delta: float) -> void:
	if _turning:
		# The real input path: mouse motion through the rig's look handler,
		# delivered before the game's own _process this frame.
		var pixels := _turn_rate * delta / _gain()
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(pixels, 0.0)
		_rig._apply_look_motion(motion.relative)
	var now := Time.get_ticks_usec()
	var rid := get_viewport().get_viewport_rid()
	if _last_usec != 0 and _phase in _all_phases:
		if _frames.size() % 10 == 0:
			_collision_stats = _streamer._collision_residency.stats()
		if _runtime_probe != null and _frames.size() % 10 == 0:
			_managed_heap_bytes = _runtime_probe.HeapBytes()
			_managed_full_collections = _runtime_probe.FullCollections()
		_frames.append({"phase": _phase, "dt": (now - _last_usec) / 1000.0, "ticks": _ticks,
			"rate": _turn_rate if _turning else 0.0,
			"turn": _frame_turn, "cam_move": _frame_move, "delta": _frame_delta * 1000.0,
			"process": _process_usec / 1000.0, "physics": _physics_usec / 1000.0,
			"callbacks_usec": _callback_times,
			"render_cpu": RenderingServer.viewport_get_measured_render_time_cpu(rid),
			"gpu": RenderingServer.viewport_get_measured_render_time_gpu(rid),
			"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"pipe": _pipelines(),
			"warmed": _streamer._first_view.warmed if _streamer._first_view != null else 0,
			"grass_tiles": _streamer._grass_streamer.built_count() if _streamer._grass_streamer != null else 0,
			"grass_pending": _sampled_pending(),
			"grass_backlog": _grass_backlog,
			"chunks": _streamer._built.size(),
			"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			"gc_pause_usec": _runtime_probe.PauseUsec() if _runtime_probe != null else -1,
			"os_usage": _runtime_probe.OsUsage() if _runtime_probe != null else {},
			"collision_residency": _collision_stats,
			"managed_heap_bytes": _managed_heap_bytes,
			"managed_full_collections": _managed_full_collections,
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"frozen": _streamer._player_frozen,
			"hold_detail": _hold_detail() if _streamer._player_frozen else {},
			"dressing_pending": _streamer._dressing_queue.pending_count()})
	if _last_usec != 0 and _phase in _all_phases and now - _last_usec > 40000:
		print("FEEL spike frame dt=%.1f process=%.1f physics=%.1f ticks=%d phase=%s pipelines=%s draws=%d" % [
			(now - _last_usec) / 1000.0, _process_usec / 1000.0, _physics_usec / 1000.0, _ticks, _phase,
			_pipelines(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	_ticks = 0
	_physics_usec = 0
	_process_begin = Time.get_ticks_usec()
	if _profile_callbacks: CALLBACK_PROBE.begin_frame()
	_last_usec = now


## After every script moved this frame (from the tail node): the camera's
## change since the end of the previous frame, i.e. what this frame shows.
var _frame_turn := 0.0
var _frame_move := 0.0
var _frame_delta := 0.0
func _sample_camera(delta: float) -> void:
	_frame_delta = delta
	var forward := -_camera.global_basis.z
	var yaw := atan2(forward.x, forward.z)
	_frame_turn = absf(wrapf(yaw - _last_yaw, -PI, PI))
	_frame_move = _camera.global_position.distance_to(_last_cam)
	_last_yaw = yaw
	_last_cam = _camera.global_position


## Pipeline compilations by source this frame (canvas, mesh, surface, draw,
## specialization): draw/specialization compiles are in-frame stalls.
func _pipelines() -> Array:
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)]


var _flat: StandardMaterial3D
func _flat_grass() -> StandardMaterial3D:
	if _flat == null:
		_flat = StandardMaterial3D.new()
		_flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_flat.albedo_color = Color(0.45, 0.62, 0.25)
	return _flat


func _gain() -> float:
	return _rig.drag_radians_per_pixel(get_viewport().get_visible_rect().size, _camera.fov,
		_camera.keep_aspect == Camera3D.KEEP_WIDTH) * _rig.mouse_sensitivity


func _run() -> void:
	while not _streamer.startup_loading_complete():
		await get_tree().create_timer(0.2).timeout
	print("FEEL ready after %.1f s" % ((Time.get_ticks_msec() - _start) / 1000.0))
	await get_tree().create_timer(3.0).timeout
	if _steady_ablate:
		await _steady_render_review()
		_finish()
		return
	if not _shots_dir.is_empty(): await _grass_shots()
	if not _view_shots.is_empty():
		await _capture_views()
		get_tree().quit()
		return
	# PNG encoding and temporary mesh swaps belong to visual review, not the
	# first measured gameplay interval. Start with a fresh complete frame.
	_last_usec = 0
	var route_yaw: float = _rig._yaw
	var route_pitch: float = _rig._pitch
	var route_start: Vector3 = _player.global_position
	var phases: Array = ["idle"] if _idle_only else PHASES
	for phase: String in phases:
		if _fixed_route and phase == "run":
			# A timer ends on a frame boundary. Its last mouse-motion delta
			# otherwise changes the next 1 km traversal by tens of metres.
			_turning = false
			_phase = "route_reset"
			_rig._yaw = wrapf(route_yaw - _turn_rate * _phase_seconds, -PI, PI)
			await get_tree().process_frame
			_last_usec = 0
		if phase == "turn" and _prespin:
			_phase = "prespin"
			_all_phases.append("prespin")
			for frame in 48:
				_rig._yaw += TAU / 48.0
				await get_tree().process_frame
		_phase = phase
		if phase == "idle_end":
			_memory_idle_end = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
			_texture_mem_idle_end = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
			_video_mem_idle_end = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		_turning = phase in ["turn", "run_turn"]
		if phase.begins_with("run"): Input.action_press(&"forward")
		else: Input.action_release(&"forward")
		await get_tree().create_timer(_phase_seconds).timeout
		if _stop_after_run and phase == "run":
			Input.action_release(&"forward")
			_phase = "route_settle"
			_all_phases.append(_phase)
			await get_tree().create_timer(20.0).timeout
			break
	_turning = false
	Input.action_release(&"forward")
	if _return_to_start: await _profile_return(route_start, route_yaw, route_pitch)
	if _ablate: await _run_ablations()
	_finish()


## Compare the original pose after traversal; final idle elsewhere may simply
## face a denser forest. Loading is explicitly excluded and has a hard timeout.
func _profile_return(position: Vector3, yaw: float, pitch: float) -> void:
	_phase = "return_loading"
	_player.velocity = Vector3.ZERO
	_player.global_position = position + Vector3.UP * 2.0
	_rig._yaw = yaw
	_rig._pitch = pitch
	_last_usec = 0
	var centre := FieldTerrainStreamer.chunk_of(position)
	var started := Time.get_ticks_msec()
	var settled_since := -1
	var settled := false
	var ready := false
	while Time.get_ticks_msec() - started < 180000:
		ready = not _streamer._player_frozen
		for c: Vector2i in _streamer.desired_chunks(centre, 1):
			ready = ready and _streamer._built.has(c) and _streamer._feature_square_ready(c)
		if ready and _streamer._grass_streamer != null:
			ready = _streamer._grass_streamer.pending_tiles() == 0
		if ready:
			if settled_since < 0: settled_since = Time.get_ticks_msec()
			if Time.get_ticks_msec() - settled_since >= 3000:
				settled = true
				break
		else: settled_since = -1
		await get_tree().create_timer(0.25).timeout
	ready = ready and settled
	_return_status = {"ready": ready, "wait_ms": Time.get_ticks_msec() - started,
		"requested_position": str(position), "actual_position": str(_player.global_position)}
	print("FEEL return_to_start ", JSON.stringify(_return_status))
	if not ready:
		push_error("Return-to-start review timed out; no matched final idle recorded")
		return
	_last_usec = 0
	_phase = "idle_return"
	_all_phases.append(_phase)
	await get_tree().create_timer(_phase_seconds).timeout


## The same view with the grass blade LOD off and on, for visual comparison
## (swapping every tile's mesh here is fine: it is a test, not a frame).
func _grass_shots() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	var multimeshes: Array[MultiMesh] = []
	for tile: Node in _streamer._grass_root.get_children():
		for child: Node in tile.get_children():
			if child is MultiMeshInstance3D: multimeshes.append((child as MultiMeshInstance3D).multimesh)
	var lod_meshes := {}
	var plain_meshes := {}
	for mm: MultiMesh in multimeshes:
		if not lod_meshes.has(mm.mesh):
			var plain := ArrayMesh.new()
			plain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mm.mesh.surface_get_arrays(0))
			plain.surface_set_material(0, mm.mesh.surface_get_material(0))
			plain.custom_aabb = mm.mesh.get_aabb()
			lod_meshes[mm.mesh] = mm.mesh
			plain_meshes[mm.mesh] = plain
	var original := {}
	for mm: MultiMesh in multimeshes: original[mm] = mm.mesh
	var instances: Array[GeometryInstance3D] = []
	for tile: Node in _streamer._grass_root.get_children():
		for child: Node in tile.get_children():
			if child is GeometryInstance3D: instances.append(child)
	for pitch_deg: float in [12.7, 3.0, 30.0]:
		_rig._pitch = deg_to_rad(pitch_deg)
		for variant: String in ["off", "on", "bias05"]:
			for mm: MultiMesh in multimeshes:
				mm.mesh = plain_meshes[original[mm]] if variant == "off" else original[mm]
			for instance: GeometryInstance3D in instances:
				instance.lod_bias = 0.5 if variant == "bias05" else 1.0
			await get_tree().create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/grass_pitch%d_lod_%s.png"
				% [_shots_dir, int(pitch_deg), variant])
			print("FEEL shot lod=%s pitch=%d prims=%d" % [variant, int(pitch_deg),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	for instance: GeometryInstance3D in instances:
		instance.lod_bias = 1.0
	_rig._pitch = 0.22131444


func _capture_views() -> void:
	DirAccess.make_dir_recursive_absolute(_view_shots)
	for view: String in ["close", "tactical"]:
		if _rig.tactical_view != (view == "tactical"):
			_rig.toggle_view()
		for heading in 4:
			_rig._yaw = heading * TAU / 4.0
			await get_tree().create_timer(1.5).timeout
			await RenderingServer.frame_post_draw
			var path := "%s/%s_h%d.png" % [_view_shots, view, heading]
			get_viewport().get_texture().get_image().save_png(path)
			print("FEEL shot %s prims=%d draws=%d" % [path,
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


## Rendering-only diagnostic: finish the whole desired ring, then hold both
## camera and committed scene constant. Each variant follows a fresh baseline.
func _steady_render_review() -> void:
	_phase = "steady_loading"
	var started := Time.get_ticks_msec()
	var stable_since := -1
	var ready := false
	var settled := false
	var centre := FieldTerrainStreamer.chunk_of(_player.global_position)
	while Time.get_ticks_msec() - started < 900000:
		ready = not _streamer._player_frozen
		for c: Vector2i in _streamer.desired_chunks(centre, _streamer.CHUNK_RADIUS):
			ready = ready and _streamer._built.has(c) and _streamer._feature_square_ready(c)
		ready = ready and _streamer._dressing_queue.pending_count() == 0
		if _streamer._grass_streamer != null:
			ready = ready and _streamer._grass_streamer.pending_tiles() == 0
		if ready:
			if stable_since < 0: stable_since = Time.get_ticks_msec()
			if Time.get_ticks_msec() - stable_since >= 10000:
				settled = true
				break
		else: stable_since = -1
		await get_tree().create_timer(0.5).timeout
	ready = ready and settled
	_steady_status = {"ready": ready, "wait_ms": Time.get_ticks_msec() - started,
		"chunks": _streamer._built.size(), "position": str(_player.global_position)}
	print("FEEL steady_render ", JSON.stringify(_steady_status))
	if not ready:
		push_error("Full-ring render review timed out")
		return
	_streamer.set_process(false)
	if not _ablation_shots.is_empty():
		DirAccess.make_dir_recursive_absolute(_ablation_shots)
		RenderingServer.global_shader_parameter_set(&"review_visual_time", 12.0)
	await _run_ablations()
	_streamer.set_process(true)


func _grass_trial_material(source: ShaderMaterial, mode: String) -> ShaderMaterial:
	var key := str(source.get_instance_id()) + mode
	if _grass_trial_materials.has(key): return _grass_trial_materials[key]
	var material := source.duplicate() as ShaderMaterial
	var shader := Shader.new()
	var option := "vertex_lighting" if mode == "grass_vertex_lighting" else "diffuse_lambert, specular_disabled"
	shader.code = source.shader.code.replace("render_mode cull_disabled;",
		"render_mode cull_disabled, " + option + ";")
	material.shader = shader
	_grass_trial_materials[key] = material
	return material


func _run_ablations() -> void:
	var env := (_world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sun := _world.get_node("DirectionalLight3D") as DirectionalLight3D
	var vp := get_viewport()
	var saved := {"shadow": sun.shadow_enabled, "fog": env.volumetric_fog_enabled,
		"shadow_mode": sun.directional_shadow_mode, "scale": vp.scaling_3d_scale,
		"ssao": env.ssao_enabled, "msaa": vp.msaa_3d, "glow": env.glow_enabled}
	_turn_rate = deg_to_rad(20.0)
	_turning = not _steady_ablate
	var variants: Array = ABLATIONS.duplicate()
	if not _ablation_variants.is_empty(): variants = _ablation_variants.duplicate()
	if _steady_ablate:
		var requested := variants.duplicate()
		variants.clear()
		for name: String in requested:
			if name in ["full", "full_end"]: continue
			variants.append("full")
			variants.append(name)
		variants.append("full_end")
	var trial := 0
	for name: String in variants:
		var phase := "ablate_" + name + ("_%02d" % trial if _steady_ablate else "")
		trial += 1
		_all_phases.append(phase)
		sun.shadow_enabled = saved.shadow and name != "no_shadows"
		env.volumetric_fog_enabled = saved.fog and name != "no_fog"
		env.ssao_enabled = saved.ssao and name != "no_ssao"
		env.glow_enabled = saved.glow and name != "no_glow"
		vp.msaa_3d = Viewport.MSAA_DISABLED if name == "no_msaa" else saved.msaa
		vp.scaling_3d_scale = saved.scale * 0.5 if name == "half_res" else saved.scale
		RenderingServer.directional_shadow_atlas_set_size(2048 if name == "shadow_2048" else 4096, true)
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS \
			if name == "shadow_2_splits" else saved.shadow_mode
		_streamer._grass_root.visible = name != "no_grass"
		var bias := 0.5 if name == "grass_lod_bias_half" else (0.25 if name == "grass_lod_bias_quarter" else GrassStreamer.BLADE_LOD_BIAS)
		for tile: Node in _streamer._grass_root.get_children():
			for child: Node in tile.get_children():
				if child is GeometryInstance3D: (child as GeometryInstance3D).lod_bias = bias
		_streamer._grass_streamer.set_density_scale(0.5 if name == "grass_density_half" else 1.0)
		for tile: Node in _streamer._grass_root.get_children():
			for child: Node in tile.get_children():
				if child is GeometryInstance3D:
					var g := child as GeometryInstance3D
					if g.has_meta(&"feel_material"):
						g.material_override = g.get_meta(&"feel_material")
					if name == "grass_flat_material":
						if not g.has_meta(&"feel_material"): g.set_meta(&"feel_material", g.material_override)
						g.material_override = _flat_grass()
					elif name in ["grass_vertex_lighting", "grass_simple_lighting"]:
						if not g.has_meta(&"feel_material"): g.set_meta(&"feel_material", g.material_override)
						g.material_override = _grass_trial_material(g.material_override as ShaderMaterial, name)
		for chunk: Node3D in _streamer._built.values():
			for child: Node in chunk.get_children():
				if child is Node3D:
					var n := String(child.name)
					var hide := (name == "no_water" and n.begins_with("Water")) \
						or (name == "no_dressing" and n.begins_with("Dressing")) \
						or (name == "no_cliff_sheet" and (n.contains("Cliff") or n.contains("Slope"))) \
						or (name == "no_terrain_mesh" and n == "Surface")
					(child as Node3D).visible = not hide
		_phase = "settle"
		await get_tree().create_timer(1.5).timeout
		_phase = phase
		await get_tree().create_timer(6.0 if _steady_ablate else 4.0).timeout
		if not _ablation_shots.is_empty():
			_phase = "ablate_capture"
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_ablation_shots + "/" + phase + ".png")
	_turning = false


static func _stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	for value: float in values: sum += value
	return {"mean": snappedf(sum / values.size(), 0.01),
		"p50": snappedf(sorted[int((sorted.size() - 1) * 0.5)], 0.01),
		"p95": snappedf(sorted[int((sorted.size() - 1) * 0.95)], 0.01),
		"p99": snappedf(sorted[int((sorted.size() - 1) * 0.99)], 0.01),
		"max": snappedf(sorted.back(), 0.01)}


func _finish() -> void:
	var summary := {}
	for phase: String in _all_phases:
		var rows := _frames.filter(func(r: Dictionary) -> bool: return r.phase == phase)
		if rows.is_empty(): continue
		var pick := func(key: String) -> Array: return rows.map(func(r: Dictionary) -> float: return float(r[key]))
		var tick_hist := {}
		var judder: Array = []
		for r: Dictionary in rows:
			tick_hist[r.ticks] = tick_hist.get(r.ticks, 0) + 1
			if phase in ["turn", "run_turn"]:
				# Relative error of the displayed turn against the frame's own
				# interval: 0 = perfectly even motion, 1 = a frozen frame.
				# Against the delta the game itself used for this frame.
				var expect: float = float(r.rate) * float(r.delta) / 1000.0
				judder.append(absf(r.turn - expect) / maxf(expect, 1e-6))
		summary[phase] = {"frames": rows.size(), "dt": _stats(pick.call("dt")),
			"process": _stats(pick.call("process")), "physics": _stats(pick.call("physics")),
			"render_cpu": _stats(pick.call("render_cpu")), "gpu": _stats(pick.call("gpu")),
			"draws": _stats(pick.call("draws")), "prims": _stats(pick.call("prims")),
			"grass_tiles": _stats(pick.call("grass_tiles")), "grass_pending": _stats(pick.call("grass_pending")),
			"memory_mb": _stats(pick.call("memory_mb")), "nodes": _stats(pick.call("nodes")),
			"frozen_frames": rows.filter(func(r:Dictionary)->bool:return r.frozen).size(),
			"physics_ticks_per_frame": tick_hist, "turn_error": _stats(judder)}
	var result := {"seed": _seed, "terrain_radius": _streamer.CHUNK_RADIUS, "keep_radius": _streamer.KEEP_RADIUS, "grass_lod_bias": GrassStreamer.BLADE_LOD_BIAS, "fixed_route": _fixed_route, "return_to_start": _return_status, "steady_render": _steady_status, "viewport": str(get_viewport().get_visible_rect().size),
		"window": str(get_window().size), "screen_scale": DisplayServer.screen_get_scale(),
		"refresh": DisplayServer.screen_get_refresh_rate(),
		"vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
		"physics_tps": Engine.physics_ticks_per_second,
		"scaling_3d": get_viewport().scaling_3d_scale,
		"interpolation": ProjectSettings.get_setting("physics/common/physics_interpolation", false),
		"memory_static_mb": _memory_idle_end,
		"texture_mem_mb": _texture_mem_idle_end, "video_mem_mb": _video_mem_idle_end,
		"adapter": RenderingServer.get_video_adapter_name(), "summary": summary}
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	var raw := FileAccess.open(_report_path.get_basename() + ".frames.json", FileAccess.WRITE)
	raw.store_string(JSON.stringify(_frames))
	raw.close()
	print("FEEL_RESULT ", JSON.stringify(result))
	get_tree().quit(0)

## Only sampled while held: distinguish an unbuilt neighbor from restoration
## backlog before changing the safety guard in response to a profile freeze.
func _hold_detail() -> Dictionary:
	var blocked := []
	var margin := FieldTerrainStreamer.PLAYER_COLLISION_MARGIN
	for dx in [-margin,margin]:
		for dz in [-margin,margin]:
			var chunk := FieldTerrainStreamer.chunk_of(_player.global_position+Vector3(dx,0,dz))
			if _streamer._collision_residency.is_ready(chunk): continue
			var entry: Dictionary = _streamer._collision_residency._entries.get(chunk,{})
			blocked.append({"chunk":str(chunk),"built":_streamer._built.has(chunk),
				"registered":not entry.is_empty(),
				"archived_shapes":entry.archive.pending() if not entry.is_empty() else -1,
				"ready_frame":entry.get("ready_frame",-1)})
	var center := FieldTerrainStreamer.chunk_of(_player.global_position)
	_streamer._mutex.lock()
	var planning: Dictionary = _streamer._active_job.duplicate()
	var tails: Array = _streamer._tails_in_flight.keys()
	var free_slots: int = _streamer._tail_free.size()
	_streamer._mutex.unlock()
	var integration := {}
	if not _streamer._integrating.is_empty():
		integration = {"chunk":str(_streamer._integrating.result.chunk),
			"index":_streamer._integrating.index,"steps":_streamer._integrating.steps.size()}
	return {"position":str(_player.global_position),"center":str(center),
		"center_built":_streamer._built.has(center),
		"center_features":_streamer._feature_square_ready(center),
		"collision_blocked":blocked,"physics_frame":Engine.get_physics_frames(),
		"arrival":_streamer.arrival_status(),"planning":planning,"tails":tails,
		"free_tail_slots":free_slots,"integration":integration}
