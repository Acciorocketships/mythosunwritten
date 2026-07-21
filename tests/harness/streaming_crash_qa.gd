extends Node

## Self-driving regression harness for worker-thread cache SIGSEGVs. The real
## F3 overlay remains enabled while the streamer builds, exercising the safe
## immutable-snapshot debug path alongside worker cache mutation.
## Loads the real world, waits until the spawn payload has been committed,
## then uses the real player input path to run forward while chunk generation
## and main-thread integration continue around it.

const WORLD := preload("res://scenes/world.tscn")
const RUN_SECONDS := 15.0
const STARTUP_TIMEOUT := 120.0

var _world: Node3D
var _player: Node3D
var _streamer: FieldTerrainStreamer
var _startup_elapsed := 0.0
var _run_elapsed := 0.0
var _running := false


func _ready() -> void:
	_world = WORLD.instantiate()
	_player = _world.get_node("Characters/Character")
	_streamer = _world.get_node("FieldTerrain")
	_streamer.SEED_OVERRIDE = 2697992464
	add_child(_world)


func _process(delta: float) -> void:
	if not _running:
		_startup_elapsed += delta
		var player_chunk := FieldTerrainStreamer.chunk_of(_player.global_position)
		if _streamer._built.has(player_chunk):
			_running = true
			Input.action_press(&"forward")
			print("STREAMING_CRASH_QA: spawn ready; running forward")
		elif _startup_elapsed >= STARTUP_TIMEOUT:
			push_error("STREAMING_CRASH_QA: spawn chunk did not arrive before timeout")
			get_tree().quit(1)
		return

	_run_elapsed += delta
	if _run_elapsed < RUN_SECONDS:
		return
	Input.action_release(&"forward")
	print("STREAMING_CRASH_QA: PASS after %.1fs movement; built=%d" % [
		_run_elapsed, _streamer._built.size()])
	get_tree().quit(0)
