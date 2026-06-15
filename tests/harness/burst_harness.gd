extends Node3D
## Spawn-burst + churn harness: glides the character in a straight line and
## records (a) per-frame piece-count delta (burst/lag detection) and (b) every
## piece removed within sight, classified by tile family, age, and whether it
## was REPLACED (another piece occupies its column afterward — a morph) or
## VANISHED (nothing there — a pop-out). The "things appear and disappear in
## the distance" report is dominated by short-age visible removals.
##
## Run with: godot --path . res://tests/harness/burst_harness.tscn

const RUN_SECONDS: float = 45.0
const RUN_SPEED: float = 8.0
const SIGHT: float = 320.0
const CHURN_MAX_AGE: float = 3.0  # placed-then-removed within this = churn

var world: Node3D
var character: CharacterBody3D
var terrain: Node3D
var _last_count: int = -1
var _deltas: Array[int] = []
var _min_fps: float = INF
var _elapsed: float = 0.0

var _birth: Dictionary = {}            # instance_id -> {t, pos}
var _churn_by_family: Dictionary = {}  # family -> {replaced, vanished}
var _churn_total: int = 0
var _max_churn_dist: float = 0.0
var _samples: Array[String] = []


func _ready() -> void:
	get_window().always_on_top = true
	seed(4242)
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	character = world.get_node("Characters/Character")
	terrain = world.get_node("Terrain")
	character.set_physics_process(false)
	terrain.terrain_parent.child_entered_tree.connect(_on_added)
	terrain.terrain_parent.child_exiting_tree.connect(_on_removed)


func _family(node: Node) -> String:
	# scene_file_path survives Godot's duplicate-sibling name mangling and
	# the cliff-interior/bank scene reuse that node names can't disambiguate.
	var p: String = (node as Node3D).scene_file_path if node is Node3D else ""
	if p == "":
		return "other"
	var base: String = p.get_file().get_basename()
	if base.begins_with("Cliff"):
		return "cliff/bank"
	if base.begins_with("Level"):
		return "level"
	if base == "GroundTile":
		return "ground/interior"
	if base == "WaterTile":
		return "water"
	if base.begins_with("Hill"):
		return "hill"
	return "deco"


func _on_added(node: Node) -> void:
	if node is Node3D:
		_birth[node.get_instance_id()] = {
			"t": _elapsed, "pos": (node as Node3D).global_position, "fam": _family(node)
		}


func _on_removed(node: Node) -> void:
	if _elapsed < 3.0 or not (node is Node3D):
		return
	var id: int = node.get_instance_id()
	var birth: Variant = _birth.get(id, null)
	_birth.erase(id)
	if birth == null:
		return
	# Only VISIBLE churn reaches the player's eyes. Tiles that retile while
	# still hidden in the settling band beyond the reveal radius are invisible.
	if node is Node3D and not (node as Node3D).is_visible_in_tree():
		return
	var pos: Vector3 = birth["pos"]
	var age: float = _elapsed - float(birth["t"])
	var d: float = Vector2(pos.x - character.global_position.x, pos.z - character.global_position.z).length()
	if d > SIGHT or age > CHURN_MAX_AGE:
		return
	# Replaced (another piece now occupies the same 24-column) vs vanished.
	var replaced: bool = false
	var col: AABB = AABB(Vector3(pos.x - 1.0, -50.0, pos.z - 1.0), Vector3(2.0, 100.0, 2.0))
	for hit in terrain.terrain_index.query_box(col):
		if hit is TerrainModuleInstance and hit.root != node:
			replaced = true
			break
	var fam: String = birth["fam"]
	if not _churn_by_family.has(fam):
		_churn_by_family[fam] = {"replaced": 0, "vanished": 0}
	_churn_by_family[fam]["replaced" if replaced else "vanished"] += 1
	_churn_total += 1
	_max_churn_dist = maxf(_max_churn_dist, d)
	# Sample only VANISHED pop-outs — the jarring "appear then disappear".
	if not replaced and _samples.size() < 25:
		var macro: float = Helper.macro_density01(pos, terrain.world_seed)
		_samples.append("[vanish] %s age=%.1f dist=%.0f macro=%.2f %s" % [
			fam, age, d, macro, str(pos.snappedf(0.1))
		])


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 3.0:
		return
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
	var max_delta: int = 0
	var zero_streak: int = 0
	var max_zero_streak: int = 0
	for d in _deltas:
		max_delta = maxi(max_delta, d)
		if d == 0:
			zero_streak += 1
			max_zero_streak = maxi(max_zero_streak, zero_streak)
		else:
			zero_streak = 0
	for s in _samples:
		print(s)
	print("[burst] frames=%d max_delta=%d max_zero_streak=%d min_fps=%.0f" % [
		_deltas.size(), max_delta, max_zero_streak, _min_fps
	])
	print("[burst] churn_total=%d max_churn_dist=%.0f by_family=%s" % [
		_churn_total, _max_churn_dist, str(_churn_by_family)
	])
