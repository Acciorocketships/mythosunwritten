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


var _lgrid: Dictionary = {}  # half-storey LEVEL per cell (within storey)


func _height(cx: int, cz: int) -> float:
	# raw_height in metres; storey*4 + level*0.5 reproduces a level-tier corner.
	var k := Vector2i(cx, cz)
	return float(_grid.get(k, 0)) * 4.0 + float(_lgrid.get(k, 0)) * 0.5


func _set_rect(x0: int, z0: int, x1: int, z1: int, storey: int) -> void:
	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			_grid[Vector2i(cx, cz)] = storey


func _set_levels(x0: int, z0: int, x1: int, z1: int, level: int) -> void:
	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			_lgrid[Vector2i(cx, cz)] = level


func _build_shapes() -> void:
	# Multi-LEVEL corner, all within storey 0: a level-2 plateau quadrant (top-left),
	# level-1 strips, level-0 pit quadrant (bottom-right). At (0,0) the diagonal (1,1)
	# drops two levels while cardinals (1,0)/(0,1) drop one — the reported L-shape
	# where (0,0) was rendered as a center tile instead of a level inner corner.
	_set_rect(-5, -5, 6, 6, 0)
	_set_levels(-5, -5, 6, 6, 1)
	_set_levels(-5, -5, 0, 0, 2)
	_set_levels(1, 1, 6, 6, 0)


func _short(tag: String) -> String:
	# Compact code for the grid view.
	tag = tag.replace("cliff-", "C").replace("level-", "L").replace("ground-plain", "G")
	tag = tag.replace("inner-corner", "IC").replace("interior", "in").replace("center", "ce")
	tag = tag.replace("corner", "co").replace("side", "sd").replace("peninsula", "pe")
	return tag


func _print_descriptors() -> void:
	var plan = terrain.heightfield_plan
	print("[hf-shapes] variant grid (cx ->, cz down). storey in (). '.'=storey0")
	for cz in range(-2, 3):
		var row: String = "cz=%2d  " % cz
		for cx in range(-2, 13):
			var s: int = _grid.get(Vector2i(cx, cz), 0)
			if s == 0:
				row += "%-9s" % "."
				continue
			var rec: Dictionary = HeightfieldInstantiator.placement_for_cell(plan, cx, cz)
			var code: String = _short(String(rec["variant_tag"]))
			row += "%-9s" % ("%s%d" % [code, s])
		print(row)
	print("  Test A interior corner (0,0); Test B interior corner (10,0) has s2 on left.")


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
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var r: Dictionary = HeightfieldInstantiator.placement_for_cell(terrain.heightfield_plan, c.x, c.y)
		print("[hf-shapes] ", c, " variant=", r["variant_tag"], " understacks=", r.get("understacks", []))

	# Place tiles directly (no WaterRule) so storey-0 stays green ground and the
	# shapes read clearly. Uses compute_region, the same batched path as in-game.
	HeightfieldInstantiator.debug_labels = false
	var placer := HeightfieldInstantiator.new()
	placer.place_region(terrain.heightfield_plan, terrain.library, terrain.terrain_parent, 0, 0, 16)

	var character = world.get_node("Characters/Character")
	character.set_physics_process(false)
	character.global_position = Vector3(-200, -50, 0)  # out of frame

	# Low eye-level view of the saddle pinch (shared corner of the two blocks at
	# world ~(-12,*,-12)), looking from the lower-front side.
	cam = Camera3D.new()
	add_child(cam)
	# Very close, near-ground vantage on the (0,0)/(1,1) junction (world ~(12,*,12))
	# so the 0.5m level steps and the stacked level inner corner at (0,0) read.
	cam.global_position = Vector3(20.0, 3.2, -2.0)
	cam.look_at(Vector3(11.0, 0.2, 13.0), Vector3.UP)
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
