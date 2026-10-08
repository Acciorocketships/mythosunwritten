# tests/harness/imposter_review.gd
# Tree imposter switch-distance review (WINDOWED). Streams a 3 x 3 chunk
# forest site through the real chunk pipeline (terrain, cliff sheet, dressing
# visuals via EnvironmentCommitQueue; no road layer, as profile_chunk_commit),
# keeps one 48 m tree tile, and dollies the camera away from it in 10 m steps.
# Every step renders the tile as
#   mesh       the painted-leaf meshes, no ranges;
#   imp_bN     the baked imposter cards only, mip_alpha_boost N;
#   on_D       production ranges switched at D m (crossfade IMPOSTER_FADE);
#   orig       the meshes with the bake's own materials (the shadow proxy's
#              copies), checking the crossfade bark shader against them;
#   none       no tile (the background, for the coverage mask);
# and reports per step the tile's screen coverage (pixels that differ from
# `none`) and mean colour, plus coverage ratio and CIELAB dE of each imposter
# and production variant against `mesh`.
#
#   Godot --path . -s res://tests/harness/imposter_review.gd -- \
#     [--seed=N] [--centre=cx,cz] [--out=DIR] [--boosts=0,0.25,0.5]
#     [--distances=100,140,180] [--near=60] [--far=300] [--elevation=12] [--azimuth=225]
extends SceneTree

var _seed := 2697992464
var _centre := Vector2i(-3, 2)
var _out := "/private/tmp/imposter-review"
var _boosts: Array[float] = [0.0, 0.25, 0.5]
var _switches: Array[float] = [100.0, 140.0, 180.0]
var _near := 60.0
var _far := 300.0
var _elevation := 12.0
var _azimuth := 225.0
var plan: HeightfieldPlan
var water: WaterPlan
var mesher: TerrainChunkMesher
var dressing_program: DressingProgram
var fields: WorldFieldBlockCache
var render_cache: EnvironmentRenderCache
var _thread: Thread
var _mutex := Mutex.new()
var _ready_items: Array[Dictionary] = []
var _worker_done := false
var _root: Node3D
var _camera: Camera3D
var _target_tile := Vector2i.ZERO
var _target := Vector3.ZERO
var _tile_batches: Array[MultiMeshInstance3D] = []
var _modes: Array[String] = []
var _jobs: Array = []
var _job := 0
var _wait := 0
var _results: Dictionary = {}
var _started := false
var _settle_until := 0
## mesh -> [faded surface materials, original surface materials]
var _surface_sets: Dictionary = {}

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): _seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--out="): _out = arg.trim_prefix("--out=")
		elif arg.begins_with("--near="): _near = float(arg.trim_prefix("--near="))
		elif arg.begins_with("--far="): _far = float(arg.trim_prefix("--far="))
		elif arg.begins_with("--elevation="): _elevation = float(arg.trim_prefix("--elevation="))
		elif arg.begins_with("--azimuth="): _azimuth = float(arg.trim_prefix("--azimuth="))
		elif arg.begins_with("--centre="):
			var p := arg.trim_prefix("--centre=").split(",")
			_centre = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--boosts="):
			_boosts.clear()
			for v in arg.trim_prefix("--boosts=").split(","): _boosts.append(float(v))
		elif arg.begins_with("--distances="):
			_switches.clear()
			for v in arg.trim_prefix("--distances=").split(","): _switches.append(float(v))
	DirAccess.make_dir_recursive_absolute(_out)
	water = TerrainWorldTuning.make_water(_seed)
	plan = TerrainWorldTuning.make_heightfield(_seed, water)
	mesher = TerrainChunkMesher.new()
	mesher.set_seed(_seed)
	var catalog := EnvironmentCatalog.load_default()
	render_cache = EnvironmentRenderCache.new(catalog)
	var index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	render_cache.prepare(DressingCompiler.authored_asset_ids(index))
	dressing_program = DressingCompiler.compile(index, catalog)
	fields = WorldFieldBlockCache.new(plan, water, dressing_program.query_margin,
		dressing_program.shore_distance_limit, 64)
	mesher.water_blocks = fields
	CliffDressing.prepare(render_cache)
	mesher.prepare_resources()
	_root = Node3D.new()
	root.add_child(_root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	_root.add_child(sun)
	_camera = Camera3D.new()
	_camera.far = 2000.0
	_camera.fov = 50.0
	_root.add_child(_camera)
	var director := AtmosphereDirector.new()
	director.environment_node = env
	director.sun = sun
	director.camera = _camera
	_root.add_child(director)
	var c := Vector3(_centre.x * 192.0 + 96.0, 0.0, _centre.y * 192.0 + 96.0)
	var mood := BiomeRegistry.blend_atmosphere(Helper.biome_weights5(c, _seed))
	director.ready.connect(func() -> void: director._apply_mood(mood))
	_modes = ["none", "mesh", "orig"]
	for b in _boosts: _modes.append("imp_b%s" % str(b))
	for d in _switches: _modes.append("on_%d" % int(d))
	_thread = Thread.new()
	_thread.start(_work)

func _work() -> void:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var chunk := _centre + Vector2i(dx, dz)
			var region := fields.region(chunk)
			var water_ctx := fields.water(chunk)
			var terrain := mesher.compute_chunk(chunk, region, water_ctx, null)
			var core := Rect2(Vector2(chunk) * 192.0, Vector2.ONE * 192.0)
			var dressing := DressingField.compute(dressing_program, _seed, core, region,
				water_ctx, null, terrain.cliff_terraces.ground_reservations)
			_mutex.lock()
			_ready_items.append({"chunk": chunk, "terrain": terrain, "dressing": dressing})
			_mutex.unlock()
	_mutex.lock()
	_worker_done = true
	_mutex.unlock()

func _process(_delta: float) -> bool:
	if not _started:
		_mutex.lock()
		var item: Dictionary = {} if _ready_items.is_empty() else _ready_items.pop_front()
		var done := _worker_done and _ready_items.is_empty()
		_mutex.unlock()
		if not item.is_empty():
			var full := mesher.commit_chunk(item.terrain)
			_root.add_child(full)
			var queue := EnvironmentCommitQueue.new(render_cache, &"Dressing")
			queue.register_chunk(item.chunk, 1)
			queue.enqueue(item.chunk, 1, full, item.dressing)
			queue.drain(1000000)
			print("[imposter] committed chunk ", item.chunk)
			return false
		if not done:
			return false
		_thread.wait_to_finish()
		_pick_tile()
		_plan_jobs()
		_started = true
		_settle_until = Time.get_ticks_msec() + 6000
		return false
	if Time.get_ticks_msec() < _settle_until:
		# The atmosphere eases into the biome mood over about three seconds.
		_apply("none", _near)
		RenderingServer.force_draw(false)
		return false
	return _step()

## The centre chunk's tile with the most trees that have an imposter; every
## other tree batch (and every leaf shadow) is hidden for the whole run.
func _pick_tile() -> void:
	var counts: Dictionary = {}
	var per_chunk: Dictionary = {}
	var batches: Array[MultiMeshInstance3D] = []
	var imposters := _root.find_children("Imposter", "", true, false)
	print("[imposter] imposter nodes=%d dressing batches=%d" % [imposters.size(),
		_root.find_children("Dressing", "", true, false).size()])
	for node in imposters:
		var near := node.get_parent() as MultiMeshInstance3D
		batches.append(near)
		var centre := near.global_transform * near.multimesh.get_aabb().get_center()
		var key := Vector2i(floori(centre.x / EnvironmentCommitQueue.FOLIAGE_TILE),
			floori(centre.z / EnvironmentCommitQueue.FOLIAGE_TILE))
		var in_centre := Rect2(Vector2(_centre) * 192.0, Vector2(192, 192)).has_point(
			Vector2(centre.x, centre.z))
		var ck := Vector2i(floori(centre.x / 192.0), floori(centre.z / 192.0))
		per_chunk[ck] = int(per_chunk.get(ck, 0)) + near.multimesh.instance_count
		if in_centre:
			counts[key] = int(counts.get(key, 0)) + near.multimesh.instance_count
	print("[imposter] trees per chunk ", per_chunk)
	print("[imposter] centre chunk tree counts per tile ", counts)
	var best := -1
	for key: Vector2i in counts:
		if counts[key] > best:
			best = counts[key]
			_target_tile = key
	if counts.is_empty():
		push_error("no tree tile in the centre chunk")
		quit(1)
		return
	var sum := Vector3.ZERO
	var n := 0
	for near in batches:
		for shadow in ["LeafShadow", "CanopyShadow"]:
			var s := near.get_node_or_null(shadow) as Node3D
			if s != null: s.visible = false
		var centre := near.global_transform * near.multimesh.get_aabb().get_center()
		var key := Vector2i(floori(centre.x / EnvironmentCommitQueue.FOLIAGE_TILE),
			floori(centre.z / EnvironmentCommitQueue.FOLIAGE_TILE))
		if key == _target_tile:
			_tile_batches.append(near)
			var mesh := near.multimesh.mesh
			var proxy := (near.get_node("LeafShadow") as MultiMeshInstance3D).multimesh.mesh
			var faded: Array = []
			var original: Array = []
			for surface in mesh.get_surface_count():
				faded.append(mesh.surface_get_material(surface))
				original.append(proxy.surface_get_material(surface))
			_surface_sets[mesh] = [faded, original]
			var imposter := near.get_node("Imposter") as MultiMeshInstance3D
			for i in imposter.multimesh.instance_count:
				sum += near.global_transform * imposter.multimesh.get_instance_transform(i).origin
				n += 1
		else:
			near.visible = false
	_target = sum / maxf(n, 1)
	var top := 0.0
	for near in _tile_batches:
		top = maxf(top, (near.global_transform * near.multimesh.get_aabb()).end.y)
	_target.y = lerpf(_target.y, top, 0.5)
	print("[imposter] tile=%s trees=%d batches=%d target=%s" % [_target_tile, n, _tile_batches.size(), _target])

func _plan_jobs() -> void:
	var d := _near
	while d <= _far + 0.01:
		for mode in _modes:
			_jobs.append([d, mode])
		d += 10.0

func _apply(mode: String, distance: float) -> void:
	# The crossfade lives in the shaders (global switch distance): mesh = a
	# switch never reached, imp = a switch at 0 m, on_D = production at D.
	var switch := 1e6
	var boost := 1.0
	if mode.begins_with("imp_b"):
		switch = 0.0
		boost = float(mode.trim_prefix("imp_b"))
	elif mode.begins_with("on_"):
		switch = float(mode.trim_prefix("on_"))
	EnvironmentCommitQueue.set_imposter_distance(switch)
	for mesh: Mesh in _surface_sets:
		var set: Array = _surface_sets[mesh][1 if mode == "orig" else 0]
		for surface in set.size():
			mesh.surface_set_material(surface, set[surface])
	for near in _tile_batches:
		var imposter := near.get_node("Imposter") as MultiMeshInstance3D
		near.visible = mode != "none"
		near.visibility_range_end = EnvironmentCommitQueue.imposter_range_end() if mode.begins_with("on_") else 0.0
		imposter.visibility_range_begin = EnvironmentCommitQueue.imposter_range_begin() if mode.begins_with("on_") else 0.0
		(imposter.material_override as ShaderMaterial).set_shader_parameter("mip_alpha_boost", boost)
	var dir := Vector3(sin(deg_to_rad(_azimuth)), 0.0, cos(deg_to_rad(_azimuth)))
	var e := deg_to_rad(_elevation)
	var eye := _target + dir * distance * cos(e) + Vector3.UP * distance * sin(e)
	_camera.look_at_from_position(eye, _target, Vector3.UP)

func _step() -> bool:
	if _job >= _jobs.size():
		_report()
		return true
	var job: Array = _jobs[_job]
	if _wait == 0:
		_apply(job[1], job[0])
		_wait = 4
		RenderingServer.force_draw(false)
		return false
	_wait -= 1
	RenderingServer.force_draw(false)
	if _wait > 0:
		return false
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	_results["%d|%s" % [int(job[0]), job[1]]] = image
	if job[1] != "none":
		image.save_png("%s/d%03d_%s.png" % [_out, int(job[0]), job[1]])
	_job += 1
	return false

func _report() -> void:
	var lines: Array[String] = []
	var summary := {}
	var d := _near
	while d <= _far + 0.01:
		var bg: Image = _results["%d|none" % int(d)]
		var mesh_stats := _stats(_results["%d|mesh" % int(d)], bg, null)
		var row := {"mesh_cov": mesh_stats.coverage}
		var line := "d=%3d mesh cov=%.4f" % [int(d), mesh_stats.coverage]
		for mode in _modes:
			if mode == "none" or mode == "mesh": continue
			var s := _stats(_results["%d|%s" % [int(d), mode]], bg, mesh_stats)
			var ratio: float = s.coverage / maxf(mesh_stats.coverage, 1e-9)
			row[mode] = {"cov_ratio": snappedf(ratio, 0.001), "dE": snappedf(s.delta_e, 0.01)}
			line += " | %s cov=%.3f dE=%.1f" % [mode, ratio, s.delta_e]
		summary[int(d)] = row
		lines.append(line)
		d += 10.0
	for l in lines: print("[imposter] ", l)
	var file := FileAccess.open(_out + "/summary.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	print("[imposter] DONE ", _out)

## Coverage = pixels that differ from the background frame. Colour: mean
## sRGB of those pixels, compared in CIELAB against the mesh's mean colour
## over the union of both masks.
func _stats(image: Image, bg: Image, reference: Variant) -> Dictionary:
	var w := image.get_width()
	var h := image.get_height()
	var covered := 0
	var sum := Vector3.ZERO
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c := image.get_pixel(x, y)
			var b := bg.get_pixel(x, y)
			if absf(c.r - b.r) + absf(c.g - b.g) + absf(c.b - b.b) > 0.06:
				covered += 1
				sum += Vector3(c.r, c.g, c.b)
	var mean := sum / maxf(covered, 1)
	var out := {"coverage": float(covered) / float((w / 2) * (h / 2)), "mean": mean, "delta_e": 0.0}
	if reference != null:
		out.delta_e = _lab(mean).distance_to(_lab(reference.mean))
	return out

static func _lab(srgb: Vector3) -> Vector3:
	var lin := Vector3.ZERO
	for i in 3:
		var v := srgb[i]
		lin[i] = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var x := (0.4124 * lin.x + 0.3576 * lin.y + 0.1805 * lin.z) / 0.95047
	var y := 0.2126 * lin.x + 0.7152 * lin.y + 0.0722 * lin.z
	var z := (0.0193 * lin.x + 0.1192 * lin.y + 0.9505 * lin.z) / 1.08883
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))
