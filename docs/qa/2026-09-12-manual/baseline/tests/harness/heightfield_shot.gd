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
var _park: Vector3 = PLAYER_POS


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	seed(4242)
	world = load("res://scenes/world.tscn").instantiate()
	terrain = world.get_node("Terrain")
	add_child(world)
	# Use the generator's real plan params (set in _ready). Just trim the place
	# radius so the render is quick.
	terrain.HEIGHTFIELD_PLACE_RADIUS = 8
	# Find the highest-elevation spot in a search area so the shot frames mountains.
	var spot: Vector3 = _find_high_spot(terrain.heightfield_plan)
	print("[hf-shot] high spot=", spot)
	_park = spot
	character = world.get_node("Characters/Character")
	character.set_physics_process(false)
	character.global_position = spot

	# Camera kept INSIDE the placed region (radius 8 = 192m) so terrain fills frame.
	cam = Camera3D.new()
	add_child(cam)
	cam.global_position = spot + Vector3(70.0, 50.0, 90.0)
	cam.look_at(spot + Vector3(0.0, -6.0, 0.0), Vector3.UP)
	cam.current = true


func _find_high_spot(plan) -> Vector3:
	var best: Vector2i = Vector2i(50, 50)
	var best_h: float = -1.0
	# Scan the fast raw height field (not the slow clamped surface_height) for the
	# tallest column to frame the shot on a mountain.
	for cz in range(-150, 150, 2):
		for cx in range(-150, 150, 2):
			var h: float = plan.raw_height(cx, cz)
			if h > best_h:
				best_h = h
				best = Vector2i(cx, cz)
	return Vector3(best.x * 24.0, best_h + 4.0, best.y * 24.0)


func _process(_dt: float) -> void:
	# Keep the player parked so terrain settles around PLAYER_POS.
	if character != null:
		character.global_position = _park
	_frame += 1
	if _frame >= WARMUP_FRAMES and not _saved:
		_saved = true
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(OUT_PATH)
		var tiles: int = terrain.terrain_parent.get_child_count() if terrain.terrain_parent != null else -1
		print("[hf-shot] saved=", ProjectSettings.globalize_path(OUT_PATH), " tiles=", tiles)
		get_tree().quit()
