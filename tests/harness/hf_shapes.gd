extends Node3D
## Diagnostic harness for cliff/level tiling bugs. Injects a synthetic raw_height
## field describing known shapes (a stepped pyramid, a 2x2 block on a plateau, and
## an L-notch plateau), prints the chosen variant descriptor for every shape cell,
## then renders the result so the geometry can be eyeballed.
##
## Run WITH a rendering context (NOT --headless):
##   /Applications/Godot.app/.../Godot --path . res://tests/harness/hf_shapes.tscn

const WARMUP_FRAMES: int = 30
const TILE: float = 24.0
const OUT_PATH: String = "user://hf_shapes.png"

var world: Node3D
var terrain
var cam: Camera3D
var _frame: int = 0
var _saved: bool = false

# Storey height (in storeys) per cell. Default 0. All shapes respect the
# adjacent-<=1-step invariant so the plan's clamp leaves them intact.
var _grid: Dictionary = {}


func _height(cx: int, cz: int) -> float:
	# raw_height in metres; quantize_storey rounds h/4. Multiply storeys by 4.
	return float(_grid.get(Vector2i(cx, cz), 0)) * 4.0


func _set_rect(x0: int, z0: int, x1: int, z1: int, storey: int) -> void:
	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			_grid[Vector2i(cx, cz)] = storey


func _build_shapes() -> void:
	# A clean stepped pyramid at origin: 7x7 storey-1 plateau, 3x3 storey-2 block,
	# plus an L-notch in the storey-1 plateau (remove a corner) to exercise an
	# inner corner. storey-0 elsewhere.
	_set_rect(-3, -3, 3, 3, 1)
	_set_rect(-1, -1, 1, 1, 2)
	# Notch the front-right corner of the storey-1 plateau -> inner corner at (2,2).
	_grid[Vector2i(3, 3)] = 0


func _print_descriptors() -> void:
	var plan = terrain.heightfield_plan
	print("[hf-shapes] descriptors (cx,cz storey -> family/tag/rot):")
	var cells: Array = _grid.keys()
	cells.sort_custom(func(a, b): return (a.y * 1000 + a.x) < (b.y * 1000 + b.x))
	for cell in cells:
		var s: int = _grid[cell]
		if s == 0:
			continue
		var rec: Dictionary = HeightfieldInstantiator.placement_for_cell(plan, cell.x, cell.y)
		print("  (%d,%d) s=%d -> %s rot=%.0f y=%.1f" % [
			cell.x, cell.y, s, rec["variant_tag"],
			rad_to_deg(rec["yaw"]) / 90.0, rec["origin_y"]
		])


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	seed(4242)
	world = load("res://scenes/world.tscn").instantiate()
	terrain = world.get_node("Terrain")
	add_child(world)
	terrain.HEIGHTFIELD_PLACE_RADIUS = 16

	_build_shapes()
	terrain.heightfield_plan.set_raw_height_override(Callable(self, "_height"))

	_print_descriptors()

	# Place tiles directly (no WaterRule) so storey-0 stays green ground and the
	# shapes read clearly. Uses compute_region, the same batched path as in-game.
	var placer := HeightfieldInstantiator.new()
	placer.place_region(terrain.heightfield_plan, terrain.library, terrain.terrain_parent, 0, 0, 16)

	var character = world.get_node("Characters/Character")
	character.set_physics_process(false)
	character.global_position = Vector3(-200, -50, 0)  # out of frame

	# 3/4 close view of the stepped pyramid (storey-0 ground -> storey-1 plateau
	# -> storey-2 block, with an L-notch inner corner) from the shaded side.
	cam = Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(-58.0, 34.0, 60.0)
	cam.look_at(Vector3(0.0, 4.0, 0.0), Vector3.UP)
	cam.current = true


func _process(_dt: float) -> void:
	_frame += 1
	if _frame >= WARMUP_FRAMES and not _saved:
		_saved = true
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(OUT_PATH)
		var tiles: int = terrain.terrain_parent.get_child_count() if terrain.terrain_parent != null else -1
		print("[hf-shapes] saved=", ProjectSettings.globalize_path(OUT_PATH), " tiles=", tiles)
		get_tree().quit()
