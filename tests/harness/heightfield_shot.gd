extends Node3D
## Visual-acceptance harness for the heightfield terrain cutover (Phase 3c, Task 4).
## Turns on use_heightfield, parks the player in a feature-rich region (far from the
## flat spawn clearing), lets the plan place/reveal tiles, then saves a screenshot
## for inspection. Run WITH a rendering context (NOT --headless):
##   /Applications/Godot.app/Contents/MacOS/Godot -s --path . res://tests/harness/heightfield_shot.tscn
##
## Output PNG path is printed at the end.

const WARMUP_FRAMES: int = 40
const PLAYER_POS: Vector3 = Vector3(1200.0, 5.0, 1200.0)  # cell ~(50,50): full macro density
const OUT_PATH: String = "user://heightfield_shot.png"

var world: Node3D
var terrain
var character
var cam: Camera3D
var _frame: int = 0
var _saved: bool = false


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	seed(4242)
	world = load("res://scenes/world.tscn").instantiate()
	terrain = world.get_node("Terrain")
	add_child(world)
	# Tune the plan for a clearly-readable view: taller amplitude, a handful of
	# storeys, a modest place radius (the per-cell reference path is slow).
	terrain.heightfield_plan = HeightfieldPlan.new(terrain.world_seed, 80.0, 12, "mean")
	terrain.HEIGHTFIELD_PLACE_RADIUS = 5
	character = world.get_node("Characters/Character")
	character.set_physics_process(false)
	character.global_position = PLAYER_POS

	cam = Camera3D.new()
	add_child(cam)
	cam.global_position = PLAYER_POS + Vector3(0.0, 45.0, 150.0)
	cam.look_at(PLAYER_POS + Vector3(0.0, 18.0, -30.0), Vector3.UP)
	cam.current = true


func _process(_dt: float) -> void:
	# Keep the player parked so terrain settles around PLAYER_POS.
	if character != null:
		character.global_position = PLAYER_POS
	_frame += 1
	if _frame >= WARMUP_FRAMES and not _saved:
		_saved = true
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(OUT_PATH)
		var tiles: int = terrain.terrain_parent.get_child_count() if terrain.terrain_parent != null else -1
		print("[hf-shot] saved=", ProjectSettings.globalize_path(OUT_PATH), " tiles=", tiles)
		get_tree().quit()
