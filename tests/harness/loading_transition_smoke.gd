extends Node
## Headless smoke test for the threaded load -> scene install handoff.

const LOADING_SCENE: PackedScene = preload(
	"res://ui/loading_screens/mythos_loading_screen.tscn")
const TARGET_PATH: String = "res://tests/harness/loading_transition_target.tscn"
const TIMEOUT_FRAMES: int = 300

var _frames: int = 0
var _loading: MythosLoadingScreen


func _ready() -> void:
	_loading = LOADING_SCENE.instantiate() as MythosLoadingScreen
	_loading.auto_start = false
	_loading.fade_duration = 0.0
	_loading.target_scene_path = TARGET_PATH
	add_child(_loading)
	_loading.start_loading()


func _process(_delta: float) -> void:
	_frames += 1
	var current := get_tree().current_scene
	if current != null and current.name == &"LoadingTransitionTarget" \
			and not is_instance_valid(_loading):
		print("[loading-transition] target installed and overlay dismissed in ",
			_frames, " frames")
		get_tree().quit()
	elif _frames >= TIMEOUT_FRAMES:
		push_error("Loading-screen threaded transition timed out.")
		get_tree().quit(1)
