extends Node3D
## Spawn-burst harness: runs the character in a straight line at full speed
## and records the per-frame piece-count delta. Healthy generation places a
## small, steady number of pieces every frame; the burst pathology is long
## runs of zero-placement frames followed by a flood (visible as a lag spike
## plus everything popping in at once).
##
## Run with: godot --path . res://tests/harness/burst_harness.tscn

const RUN_SECONDS: float = 45.0

const RUN_SPEED: float = 8.0

var world: Node3D
var character: CharacterBody3D
var terrain: Node3D
var _last_count: int = -1
var _deltas: Array[int] = []
var _min_fps: float = INF
var _elapsed: float = 0.0


var _visible_churn: int = 0


func _ready() -> void:
	get_window().always_on_top = true
	# Deterministic world so runs are comparable.
	seed(4242)
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	character = world.get_node("Characters/Character")
	terrain = world.get_node("Terrain")
	# Kinematic glide: physics off so the runner can't get stuck on walls or
	# fall into water — generation only reads the XZ position anyway.
	character.set_physics_process(false)
	# Visible churn: pieces removed within sight of the player (the
	# "things appear and then disappear" report).
	terrain.terrain_parent.child_exiting_tree.connect(_on_piece_removed)
	terrain.terrain_parent.child_entered_tree.connect(_on_piece_added)


var _birth_time: Dictionary = {}


func _on_piece_added(node: Node) -> void:
	_birth_time[node.get_instance_id()] = _elapsed


func _on_piece_removed(node: Node) -> void:
	if _elapsed < 3.0 or not (node is Node3D):
		return
	# Only count pieces that visually VANISH: decorations and hills. Cliff /
	# ground / bank / level removals are usually same-footprint retile swaps
	# (a different mesh appears in the same spot), not pop-out.
	var vanishing: bool = false
	for prefix in ["Tree", "Bush", "Grass", "Rock", "Hill"]:
		if String(node.name).begins_with(prefix):
			vanishing = true
			break
	if not vanishing:
		return
	var d: float = Vector2(
		node.global_position.x - character.global_position.x,
		node.global_position.z - character.global_position.z
	).length()
	if d < 260.0:
		_visible_churn += 1
		var age: float = _elapsed - float(_birth_time.get(node.get_instance_id(), -1.0))
		var pos: Vector3 = node.global_position
		var macro: float = Helper.macro_density01(pos, terrain.world_seed)
		print("[vanish] %s at %s age=%.1fs dist=%.0f macro=%.2f water=%s" % [
			node.name, str(pos.snappedf(0.1)), age, d, macro,
			str(Helper.is_water(Vector3(snappedf(pos.x, 24.0), 0.0, snappedf(pos.z, 24.0)), terrain.world_seed)),
		])


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 3.0:
		return  # let initial generation settle
	character.global_position += Vector3(1, 0, 0.31).normalized() * RUN_SPEED * delta
	character.global_position.y = 5.0
	var count: int = terrain.terrain_parent.get_child_count()
	if _last_count >= 0:
		_deltas.append(count - _last_count)
		if _elapsed > 5.0:
			_min_fps = minf(_min_fps, Engine.get_frames_per_second())
	_last_count = count
	if _elapsed >= RUN_SECONDS:
		_report()
		get_tree().quit()


func _report() -> void:
	var histogram: Dictionary = {}
	var zero_streak: int = 0
	var max_zero_streak: int = 0
	var max_delta: int = 0
	for d in _deltas:
		var bucket: int = clampi(d, -1, 12)
		histogram[bucket] = histogram.get(bucket, 0) + 1
		if d == 0:
			zero_streak += 1
			max_zero_streak = maxi(max_zero_streak, zero_streak)
		else:
			zero_streak = 0
		max_delta = maxi(max_delta, d)
	print("[burst] frames=%d histogram=%s" % [_deltas.size(), str(histogram)])
	print("[burst] max_delta=%d max_zero_streak=%d min_fps=%.0f player_x=%.0f visible_churn=%d" % [
		max_delta, max_zero_streak, _min_fps, character.global_position.x, _visible_churn
	])
