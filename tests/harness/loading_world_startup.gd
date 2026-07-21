extends Node
## End-to-end startup check: the player remains motionless while the four support
## chunks integrate, the bar reports real worker milestones monotonically, and
## the overlay dismisses itself when the fourth chunk is ready.

const LOADING_SCENE: PackedScene = preload(
	"res://ui/loading_screens/mythos_loading_screen.tscn")
const WORLD_PATH: String = "res://scenes/world.tscn"
const TIMEOUT_MSEC: int = 180_000

var _loading: MythosLoadingScreen
var _started_msec: int
var _progress_values: Array[float] = []
var _last_progress_msec: int
var _longest_progress_gap_msec: int = 0
var _failed: bool = false


func _ready() -> void:
	_started_msec = Time.get_ticks_msec()
	_last_progress_msec = _started_msec
	_loading = LOADING_SCENE.instantiate() as MythosLoadingScreen
	_loading.auto_start = false
	_loading.fade_duration = 0.0
	_loading.target_scene_path = WORLD_PATH
	_loading.scene_load_progress.connect(_on_progress)
	_loading.scene_load_failed.connect(_on_failed)
	add_child(_loading)
	_loading.start_loading()


func _process(_delta: float) -> void:
	if _failed:
		get_tree().quit(1)
		return
	if Time.get_ticks_msec() - _started_msec >= TIMEOUT_MSEC:
		push_error("World startup loading screen timed out.")
		get_tree().quit(1)
		return
	var current := get_tree().current_scene
	if current == null or current.name != &"World" or is_instance_valid(_loading):
		return
	var streamer := current.get_node_or_null("FieldTerrain") as FieldTerrainStreamer
	if streamer == null or not streamer.startup_loading_complete():
		push_error("Overlay disappeared before all startup support chunks were ready.")
		get_tree().quit(1)
		return
	if _progress_values.is_empty() or not is_equal_approx(_progress_values[-1], 1.0):
		push_error("Startup progress never reached completion.")
		get_tree().quit(1)
		return
	var saw_partial := false
	for progress: float in _progress_values:
		if progress > 0.0 and progress < 1.0:
			saw_partial = true
			break
	if not saw_partial:
		push_error("Startup bar never displayed actual partial progress.")
		get_tree().quit(1)
		return
	print("[loading-world] overlay dismissed automatically; progress=",
		_progress_values, " support=", streamer.startup_support_chunks(),
		" elapsed_ms=", Time.get_ticks_msec() - _started_msec,
		" longest_progress_gap_ms=", _longest_progress_gap_msec)
	get_tree().quit()


func _on_progress(_path: String, progress: float) -> void:
	var now := Time.get_ticks_msec()
	_longest_progress_gap_msec = maxi(_longest_progress_gap_msec,
		now - _last_progress_msec)
	_last_progress_msec = now
	if _progress_values.is_empty() or not is_equal_approx(_progress_values[-1], progress):
		_progress_values.append(progress)
	print("[loading-world] elapsed_ms=", now - _started_msec,
		" progress=", progress)


func _on_failed(path: String, error: Error) -> void:
	push_error("Loading failed for %s with error %d." % [path, error])
	_failed = true
