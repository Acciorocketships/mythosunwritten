class_name MythosLoadingScreen
extends Node
## Animated transition that remains above the world until spawn terrain exists.
##
## The target PackedScene is loaded on a ResourceLoader thread, then installed
## behind this scene's high CanvasLayer. If that scene owns a
## FieldTerrainStreamer, the overlay stays visible until every chunk beneath the
## player's startup footprint has been integrated on the main thread.

signal scene_load_started(path: String)
signal scene_resource_progress(path: String, progress: float)
signal scene_load_progress(path: String, progress: float)
signal scene_load_failed(path: String, error: Error)

const RESOURCE_LOAD_WEIGHT := 0.03
const STREAMER_LOAD_WEIGHT := 1.0 - RESOURCE_LOAD_WEIGHT

@export_file("*.tscn") var target_scene_path: String = "res://scenes/world.tscn"
@export var auto_start: bool = true
## Harness-only visualisation when no target is being loaded. Production keeps
## this false; its bar is driven exclusively by real streamer readiness.
@export var preview_progress: bool = false
@export_range(0.0, 2.0, 0.05) var fade_duration: float = 0.45

@onready var _overlay: Control = %Overlay
@onready var _progress_bar: MythosTaperedProgressBar = %ProgressBar

var _loading_resource: bool = false
var _installing_scene: bool = false
var _waiting_for_spawn: bool = false
var _finishing: bool = false
var _startup_streamer: FieldTerrainStreamer
var _requested_progress: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if auto_start and not target_scene_path.is_empty():
		start_loading.call_deferred(target_scene_path)


func _process(_delta: float) -> void:
	if _loading_resource:
		_poll_threaded_resource_load()
	elif _waiting_for_spawn:
		_poll_spawn_loading()
	elif preview_progress and not _finishing:
		_requested_progress = 0.08 + fmod(Time.get_ticks_msec() * 0.000085, 0.84)
	_progress_bar.progress = _requested_progress


func start_loading(path: String = target_scene_path) -> void:
	if _loading_resource or _installing_scene or _waiting_for_spawn or _finishing:
		return
	if path.is_empty():
		_fail_load(path, ERR_INVALID_PARAMETER)
		return
	target_scene_path = path
	var request_error: Error = ResourceLoader.load_threaded_request(
		target_scene_path, "PackedScene", true)
	if request_error != OK:
		_fail_load(target_scene_path, request_error)
		return
	_requested_progress = 0.0
	_loading_resource = true
	scene_load_started.emit(target_scene_path)


func _poll_threaded_resource_load() -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var resource_progress := float(progress[0]) if not progress.is_empty() else 0.0
			resource_progress = clampf(resource_progress, 0.0, 1.0)
			scene_resource_progress.emit(target_scene_path, resource_progress)
			_set_requested_progress(resource_progress * RESOURCE_LOAD_WEIGHT)
		ResourceLoader.THREAD_LOAD_LOADED:
			_loading_resource = false
			_installing_scene = true
			_install_loaded_scene.call_deferred()
		ResourceLoader.THREAD_LOAD_FAILED:
			_fail_load(target_scene_path, ERR_CANT_OPEN)
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail_load(target_scene_path, ERR_FILE_UNRECOGNIZED)


func _install_loaded_scene() -> void:
	var resource := ResourceLoader.load_threaded_get(target_scene_path)
	var packed_scene := resource as PackedScene
	if packed_scene == null:
		_fail_load(target_scene_path, ERR_FILE_CORRUPT)
		return

	# The CanvasLayer remains above the installed world while its startup worker
	# runs. Setting current_scene here transfers normal scene ownership without
	# removing this still-live transition node from the root.
	var next_scene := packed_scene.instantiate()
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	_installing_scene = false
	_startup_streamer = next_scene.find_child(
		"FieldTerrain", true, false) as FieldTerrainStreamer
	if _startup_streamer == null:
		_requested_progress = 1.0
		scene_load_progress.emit(target_scene_path, 1.0)
		_finish_transition.call_deferred()
		return
	_startup_streamer.startup_loading_progress_changed.connect(
		_on_startup_loading_progress_changed)
	_startup_streamer.startup_loading_completed.connect(
		_on_startup_loading_completed, CONNECT_ONE_SHOT)
	_waiting_for_spawn = true
	_set_requested_progress(RESOURCE_LOAD_WEIGHT)
	_poll_spawn_loading()


func _poll_spawn_loading() -> void:
	if not is_instance_valid(_startup_streamer):
		_fail_load(target_scene_path, ERR_DOES_NOT_EXIST)
		return
	var actual_progress := _startup_streamer.startup_loading_progress()
	_set_requested_progress(RESOURCE_LOAD_WEIGHT
		+ actual_progress * STREAMER_LOAD_WEIGHT)
	if _startup_streamer.startup_loading_complete():
		_on_startup_loading_completed()


func _on_startup_loading_progress_changed(
		progress: float, _ready_chunks: int, _total_chunks: int) -> void:
	if _finishing:
		return
	_set_requested_progress(RESOURCE_LOAD_WEIGHT
		+ clampf(progress, 0.0, 1.0) * STREAMER_LOAD_WEIGHT)


func _on_startup_loading_completed() -> void:
	if _finishing:
		return
	_waiting_for_spawn = false
	var emit_completion := not is_equal_approx(_requested_progress, 1.0)
	_requested_progress = 1.0
	_progress_bar.progress = 1.0
	if emit_completion:
		scene_load_progress.emit(target_scene_path, 1.0)
	_finish_transition.call_deferred()


func _set_requested_progress(progress: float) -> void:
	var next := maxf(_requested_progress, clampf(progress, 0.0, 1.0))
	if is_equal_approx(next, _requested_progress):
		return
	_requested_progress = next
	_progress_bar.progress = _requested_progress
	scene_load_progress.emit(target_scene_path, _requested_progress)


func _finish_transition() -> void:
	if _finishing:
		return
	_finishing = true
	_loading_resource = false
	_waiting_for_spawn = false
	_requested_progress = 1.0
	_progress_bar.progress = 1.0
	# Present one complete-bar frame before fading; this is a completion visual,
	# not a time-based readiness gate.
	await get_tree().process_frame
	if fade_duration > 0.0:
		var fade := create_tween()
		fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade.set_trans(Tween.TRANS_SINE)
		fade.set_ease(Tween.EASE_IN_OUT)
		fade.tween_property(_overlay, "modulate:a", 0.0, fade_duration)
		await fade.finished
	queue_free()


func _fail_load(path: String, error: Error) -> void:
	_loading_resource = false
	_installing_scene = false
	_waiting_for_spawn = false
	_finishing = false
	_requested_progress = 0.0
	push_error("Mythos loading screen could not load '%s' (error %d)." % [path, error])
	scene_load_failed.emit(path, error)
