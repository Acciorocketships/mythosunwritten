extends Node3D
## The real world, with bounded input/physics diagnostics. Run this scene in
## the editor's embedded Game view to exercise native capture and streaming.
const TracedCamera := preload("res://tests/harness/tactical_input_review.gd").TracedCamera
var _elapsed := 0.0

func _enter_tree() -> void:
	var camera := get_node("Camera3D") as Camera3D
	camera.set_script(TracedCamera)
	camera.camera = camera
	camera.target = get_node("Characters/Character")

func _ready() -> void:
	$FieldTerrain.startup_loading_completed.connect(func():
		print("GAME_INPUT_READY player=", $Characters/Character.position))

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.5: return
	_elapsed = 0.0
	var actor := $Characters/Character
	print("GAME_INPUT_STATE player=", actor.position, " velocity=", actor.velocity,
		" move=", Input.get_vector("left","right","forward","backward"),
		" yaw=", $Camera3D._yaw, " captured=", $Camera3D._edge_captured,
		" mode=", Input.mouse_mode, " physics=", Engine.get_physics_frames())
