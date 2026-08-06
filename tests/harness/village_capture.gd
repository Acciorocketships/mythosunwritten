extends Node3D

## Streamed production capture runner for a manifest emitted by
## village_visual_corpus.gd. One world stays alive across teleports so route,
## field, and asset caches are exercised exactly as they are during play.
const WAIT_BASE_TIMEOUT_SECONDS := 120.0
const WAIT_ACTIVE_PHASE_LIMIT_SECONDS := 300.0
const WAIT_PROGRESS_LEASE_SECONDS := 30.0
const WAIT_HARD_TIMEOUT_SECONDS := 420.0

var _manifest_path := "/tmp/mythos-village-visual-corpus.json"
var _output_dir := "/tmp/mythos-village-visual-review"
var _start := 0
var _limit := -1
var _representative_views_only := false
var _manifest: Dictionary
var _entries: Array
var _streamer: FieldTerrainStreamer
var _character: CharacterBody3D
var _camera := Camera3D.new()
var _camera_solver := CameraObstructionSolver.new()
var _captured: Array[Dictionary] = []


func _ready() -> void:
	_read_args()
	_manifest = _read_json(_manifest_path)
	assert(not _manifest.is_empty() and _manifest.has("villages"),
		"Village capture requires a visual corpus manifest")
	_entries = _manifest.villages
	if _limit >= 0:
		_entries = _entries.slice(_start, mini(_entries.size(), _start + _limit))
	elif _start > 0:
		_entries = _entries.slice(_start)
	assert(not _entries.is_empty(), "Village capture selection is empty")
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	_streamer = world.find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	_character = world.find_child("Character", true, false) as CharacterBody3D
	assert(_streamer != null and _character != null)
	_character.visible = false
	_streamer.SEED_OVERRIDE = int(_manifest.world_seed)
	_streamer.CHUNK_RADIUS = 1
	_streamer.KEEP_RADIUS = 1
	_streamer.GRASS_ENABLED = false
	_move_character(_entries[0])
	add_child(world)
	_camera.current = true
	add_child(_camera)
	_run.call_deferred()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		match args[index]:
			"--manifest":
				if index + 1 < args.size():
					_manifest_path = args[index + 1]
			"--output":
				if index + 1 < args.size():
					_output_dir = args[index + 1]
			"--start":
				if index + 1 < args.size():
					_start = int(args[index + 1])
			"--limit":
				if index + 1 < args.size():
					_limit = int(args[index + 1])
			"--representative-views":
				_representative_views_only = true


func _run() -> void:
	for entry_index in _entries.size():
		var entry: Dictionary = _entries[entry_index]
		_move_character(entry)
		if not await _wait_for_site(entry):
			push_error("Village capture timed out: %s" % entry.settlement_id)
			get_tree().quit(1)
			return
		for unused in 2:
			await get_tree().process_frame
		var views: Array = _representative_views(entry.views) \
			if _representative_views_only else entry.views
		for view_index in views.size():
			await _capture(entry, views[view_index], view_index)
		print("[village_capture] village=%d/%d id=%s images=%d" % [
			entry_index + 1, _entries.size(), entry.settlement_id,
			views.size()])
		_write_capture_index(entry_index + 1,
			entry_index + 1 == _entries.size())
	print("[village_capture] complete villages=%d captures=%d output=%s" % [
		_entries.size(), _captured.size(), _output_dir])
	get_tree().quit()


## Checkpoint after every village. A later slow or malformed record can never
## erase the metadata that makes already-rendered evidence auditable.
func _write_capture_index(completed_villages: int, complete: bool) -> void:
	_write_json("%s/index.json" % _output_dir, {
		"manifest": _manifest_path,
		"source_coverage": _manifest.coverage,
		"capture_complete": complete,
		"selection_village_count": _entries.size(),
		"completed_village_count": completed_villages,
		"capture_count": _captured.size(),
		"view_diagnostics": _view_diagnostics(),
		"captures": _captured,
	})


## Deterministic development subset spanning the village-scale and structural
## review categories. Full closure deliberately omits this flag and captures
## every authored view; iterative falsification can review several villages
## without letting dozens of near-identical door shots crowd out whole-town,
## market, vertical, support, and outskirts evidence.
static func _representative_views(source: Array) -> Array:
	# Volumetric warrens already expose a compact adversarial camera battery
	# rather than the much larger legacy per-door/per-object list. Returning all
	# of it is both representative and essential: the old village-name filter
	# otherwise selected zero views and could make a production run look complete
	# without producing any visual evidence.
	for value: Variant in source:
		var source_view := value as Dictionary
		if String(source_view.get("recipe", "")).begins_with("warren_"):
			return source.duplicate()
	var exact := ["skyline", "skyline_reverse", "plaza_eye",
		"main_approach", "street_inbound", "lowest_foundation_edge",
		"urban_web_above", "urban_lower_street"]
	var prefixes := ["door_sfm_stall_", "urban_building_", "urban_aerial_",
		"urban_platform_", "urban_stair_", "outskirts_"]
	var selected: Array = []
	var selected_recipes: Dictionary = {}
	for expected: String in exact:
		for value: Variant in source:
			var view := value as Dictionary
			if String(view.get("recipe", "")) != expected:
				continue
			selected.append(view)
			selected_recipes[expected] = true
			break
	for prefix: String in prefixes:
		for value: Variant in source:
			var view := value as Dictionary
			var recipe := String(view.get("recipe", ""))
			if selected_recipes.has(recipe) or not recipe.begins_with(prefix):
				continue
			selected.append(view)
			selected_recipes[recipe] = true
			break
	return selected


func _move_character(entry: Dictionary) -> void:
	var centre := _array_v3(entry.centre)
	_character.position = centre + Vector3.UP * 8.0
	_character.velocity = Vector3.ZERO


func _wait_for_site(entry: Dictionary) -> bool:
	var centre := _array_v3(entry.centre)
	var centre_chunk := FieldTerrainStreamer.chunk_of(centre)
	var started := Time.get_ticks_msec()
	var last_relevant_progress := started
	while true:
		var now := Time.get_ticks_msec()
		var elapsed := float(now - started) / 1000.0
		if elapsed >= WAIT_HARD_TIMEOUT_SECONDS:
			return false
		var progress := _streamer.worker_progress_snapshot()
		var relevant_active := _relevant_worker_is_active(progress, centre_chunk,
			_streamer.KEEP_RADIUS + 1)
		if relevant_active:
			last_relevant_progress = now
		var complete := true
		for z in range(-1, 2):
			for x in range(-1, 2):
				var key := centre_chunk + Vector2i(x, z)
				complete = complete and _streamer._built.has(key) \
					and _streamer._feature_ready.has(key)
		if complete and _streamer._feature_queue != null \
				and _streamer._feature_queue.pending_count() == 0:
			return true
		var seconds_since_relevant := float(now - last_relevant_progress) / 1000.0
		if _progress_lease_expired(elapsed, seconds_since_relevant,
				relevant_active):
			return false
		await get_tree().create_timer(0.25).timeout
	return false


static func _relevant_worker_is_active(progress: Dictionary,
		centre_chunk: Vector2i, maximum_chunk_distance: int) -> bool:
	if not bool(progress.get("active", false)) \
			or StringName(progress.get("phase", &"idle")) == &"idle":
		return false
	var chunk: Vector2i = progress.get("chunk", Vector2i(1000000, 1000000))
	if maxi(absi(chunk.x - centre_chunk.x), absi(chunk.y - centre_chunk.y)) \
			> maximum_chunk_distance:
		return false
	return float(progress.get("phase_elapsed_msec", INF)) / 1000.0 \
		< WAIT_ACTIVE_PHASE_LIMIT_SECONDS


static func _progress_lease_expired(elapsed_seconds: float,
		seconds_since_relevant: float, relevant_active: bool) -> bool:
	return elapsed_seconds >= WAIT_BASE_TIMEOUT_SECONDS \
		and not relevant_active \
		and seconds_since_relevant >= WAIT_PROGRESS_LEASE_SECONDS


func _capture(entry: Dictionary, view: Dictionary, view_index: int) -> void:
	_camera.fov = float(view.fov)
	var authored_position := _array_v3(view.position)
	var target := _array_v3(view.target)
	var resolution := _resolve_view(authored_position, target,
		float(view.get("subject_radius", 0.0)))
	_camera.look_at_from_position(resolution.position, target)
	for unused in 2:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var screenshot_id := "v%03d-%s-%s" % [int(entry.review_index),
		_safe_id(entry.settlement_id), String(view.recipe)]
	var image_path := "%s/%s.png" % [_output_dir, screenshot_id]
	var image := get_viewport().get_texture().get_image()
	assert(image != null and image.save_png(image_path) == OK,
		"Could not write village screenshot")
	var metadata := {
		"screenshot_id": screenshot_id,
		"image": image_path,
		"world_seed": _manifest.world_seed,
		"settlement_id": entry.settlement_id,
		"super_cell": entry.super_cell,
		"cell": entry.cell,
		"tier": entry.tier,
		"theme": entry.theme,
		"recipe": view.recipe,
		"camera_position": _v3(_camera.global_position),
		"authored_camera_position": view.position,
		"camera_target": view.target,
		"camera_subject_radius": float(view.get("subject_radius", 0.0)),
		"camera_basis": _basis(_camera.global_basis),
		"camera_adjustment": _v3(_camera.global_position - authored_position),
		"authored_view_clear": resolution.authored_clear,
		"capture_view_clear": resolution.valid,
		"camera_candidate_index": resolution.candidate_index,
		"obstruction_retraction": resolution.retraction,
		"fov": view.fov,
		"fixed_capture": _manifest.fixed_capture,
		"assets": entry.assets,
		"buildings": entry.buildings,
		"props": entry.get("props", []),
		"foundations": entry.get("foundations", []),
		"payload_instances": entry.payload_instances,
		"foundation_instances": entry.foundation_instances,
		"street_axis": entry.get("street_axis", [0.0, 0.0]),
		"prop_results": entry.get("prop_results", {}),
		"accepted_prop_count": entry.get("accepted_prop_count", 0),
		"urban_status": entry.get("urban_status", "rejected"),
		"urban_building_count": entry.get("urban_building_count", 0),
		"urban_building_design_count": entry.get(
			"urban_building_design_count", 0),
		"urban_natural_building_count": entry.get(
			"urban_natural_building_count", 0),
		"urban_retained_building_count": entry.get(
			"urban_retained_building_count", 0),
		"urban_elevation_band_count": entry.get(
			"urban_elevation_band_count", 0),
		"urban_half_rise_count": entry.get("urban_half_rise_count", 0),
		"urban_ground_street_count": entry.get(
			"urban_ground_street_count", 0),
		"urban_aerial_link_count": entry.get("urban_aerial_link_count", 0),
		"urban_platform_count": entry.get("urban_platform_count", 0),
		"urban_public_stair_count": entry.get("urban_public_stair_count", 0),
		"urban_support_count": entry.get("urban_support_count", 0),
		"urban_support_piece_count": entry.get(
			"urban_support_piece_count", 0),
		"urban_railing_count": entry.get("urban_railing_count", 0),
		"urban_timber_cell_count": entry.get("urban_timber_cell_count", 0),
		"urban_rock_piece_count": entry.get("urban_rock_piece_count", 0),
		"urban_buildings": entry.get("urban_buildings", []),
		"urban_links": entry.get("urban_links", []),
		"urban_platforms": entry.get("urban_platforms", []),
		"urban_stair_runs": entry.get("urban_stair_runs", []),
		"outskirts_shelter_count": entry.get("outskirts_shelter_count", 0),
		"outskirts_route_stair_count": entry.get(
			"outskirts_route_stair_count", 0),
		"outskirts_shelters": entry.get("outskirts_shelters", []),
		"outskirts_audit": entry.get("outskirts_audit", []),
		"urban_placements": entry.get("urban_placements", []),
		"block_local": entry.block_local,
		"feature_generations": _feature_generations(_array_v3(entry.centre)),
		"view_index": view_index,
	}
	_write_json("%s/%s.json" % [_output_dir, screenshot_id], metadata)
	_captured.append(metadata)


func _resolve_view(authored_position: Vector3, target: Vector3,
		subject_radius: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var excluded: Array[RID] = [_character.get_rid()]
	var candidates := _camera_candidates(authored_position, target)
	var authored_clear := false
	var authored_retraction := INF
	for index in candidates.size():
		var candidate: Vector3 = candidates[index]
		var direction := (candidate - target).normalized()
		var cast_start := target + direction * minf(subject_radius,
			target.distance_to(candidate) * 0.6)
		var resolved := _camera_solver.resolve_boom(space, cast_start, candidate,
			excluded)
		var retraction := resolved.distance_to(candidate)
		if index == 0:
			authored_clear = retraction <= 0.08
			authored_retraction = retraction
		if retraction <= 0.08:
			return {"position": candidate, "valid": true,
				"authored_clear": authored_clear, "candidate_index": index,
				"retraction": authored_retraction}
	# Preserve the authored frame when no nearby honest view is clear. The
	# adversarial review must see and report the obstruction; it is never hidden
	# by a distant or recipe-specific fallback.
	return {"position": authored_position, "valid": false,
		"authored_clear": false, "candidate_index": -1,
		"retraction": authored_retraction}


static func _camera_candidates(authored_position: Vector3,
		target: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = [authored_position]
	var horizontal := Vector2(authored_position.x - target.x,
		authored_position.z - target.z)
	var lateral := Vector2(-horizontal.y, horizontal.x).normalized()
	for lift: float in [1.5, 3.0, 6.0]:
		out.append(authored_position + Vector3.UP * lift)
	if not lateral.is_zero_approx():
		for offset: float in [1.5, -1.5, 3.0, -3.0]:
			var shift := Vector3(lateral.x * offset, 0.0, lateral.y * offset)
			for lift: float in [0.0, 1.5, 3.0]:
				out.append(authored_position + shift + Vector3.UP * lift)
	return out


func _view_diagnostics() -> Dictionary:
	var authored_obstructed := 0
	var adjusted := 0
	var unresolved := 0
	for capture: Dictionary in _captured:
		if not bool(capture.authored_view_clear):
			authored_obstructed += 1
		if int(capture.camera_candidate_index) > 0:
			adjusted += 1
		if not bool(capture.capture_view_clear):
			unresolved += 1
	return {"authored_obstructed": authored_obstructed,
		"adjusted": adjusted, "unresolved": unresolved}


func _feature_generations(centre: Vector3) -> Dictionary:
	var centre_chunk := FieldTerrainStreamer.chunk_of(centre)
	var out: Dictionary = {}
	for z in range(-1, 2):
		for x in range(-1, 2):
			var key := centre_chunk + Vector2i(x, z)
			out["%d,%d" % [key.x, key.y]] = int(
				_streamer._feature_ready.get(key, -1))
	return out


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}


static func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Could not write village capture metadata")
	file.store_string(JSON.stringify(value, "  "))
	file.close()


static func _array_v3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func _safe_id(value: String) -> String:
	return value.replace(".", "-").replace(":", "-").replace("/", "-")


static func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _basis(value: Basis) -> Array[Array]:
	return [_v3(value.x), _v3(value.y), _v3(value.z)]
