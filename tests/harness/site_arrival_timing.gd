extends SceneTree
## Time until the player can move at the world scene's spawn, then proof that
## they do: unfrozen, landed on the ground and walking under a held input.
## Headless. Args: --at x,y,z (default: the scene's own spawn).
var _streamer: FieldTerrainStreamer
var _character: CharacterBody3D
var _started := 0
var _ready_at := -1
var _start_position := Vector3.ZERO

func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	_streamer = world.find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	_streamer.GRASS_ENABLED = false
	_character = world.find_child("Character", true, false) as CharacterBody3D
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--at":
			var p := args[i + 1].split(",")
			_character.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	root.add_child(world)
	_started = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if _ready_at < 0:
		if not _streamer.startup_loading_complete():
			return false
		_ready_at = Time.get_ticks_msec()
		print("[site_arrival_timing] movable after %.1f s (style %s) at %s" % [
			(_ready_at - _started) / 1000.0, _streamer.CLIFF_STYLE, _character.global_position])
		return false
	var since := Time.get_ticks_msec() - _ready_at
	if since < 4000:
		return false
	if _start_position == Vector3.ZERO:
		_start_position = _character.global_position
		print("[site_arrival_timing] landed frozen=%s floor=%s at %s" % [
			_streamer._player_frozen, _character.is_on_floor(), _character.global_position])
		Input.action_press("forward")
		return false
	if since < 8000:
		return false
	Input.action_release("forward")
	print("[site_arrival_timing] walked %.1f m (frozen=%s) to %s" % [
		_character.global_position.distance_to(_start_position), _streamer._player_frozen,
		_character.global_position])
	return true
