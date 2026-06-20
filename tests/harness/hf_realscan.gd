extends Node3D
## Scans the REAL heightfield plan for the reported interior-corner failure:
## a cell with two perpendicular SAME-height cardinal neighbours and a HIGHER
## cell at the diagonal between them ("a cell on top" at the corner). Prints the
## matches, places the surrounding tiles, and frames the first match at eye level.

const TILE: float = 24.0
const OUT_PATH: String = "user://hf_realscan.png"
const WARMUP_FRAMES: int = 30

# diagonal socket -> [cardinal offset 1, cardinal offset 2, diagonal offset]
const CORNERS: Array = [
	[Vector2i(0, -1), Vector2i(1, 0), Vector2i(1, -1)],   # front,right -> frontright
	[Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)],     # back,right  -> backright
	[Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, 1)],   # back,left   -> backleft
	[Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, -1)], # front,left  -> frontleft
]

var world: Node3D
var terrain
var cam: Camera3D
var _frame: int = 0
var _saved: bool = false
var _focus: Vector3
var _eye: Vector3


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	seed(4242)
	world = load("res://scenes/world.tscn").instantiate()
	terrain = world.get_node("Terrain")
	add_child(world)
	var plan = terrain.heightfield_plan

	# Search a cliffy area (the tall NW region used by other shots).
	var ccx: int = -112
	var ccz: int = -150
	var radius: int = 26
	var region: HeightfieldRegion = plan.compute_region(ccx, ccz, radius)

	var matches: Array = []
	for dz in range(-radius + 1, radius):
		for dx in range(-radius + 1, radius):
			var cx: int = ccx + dx
			var cz: int = ccz + dz
			var s: int = region.storey_at(cx, cz)
			for corner in CORNERS:
				var s1: int = region.storey_at(cx + corner[0].x, cz + corner[0].y)
				var s2: int = region.storey_at(cx + corner[1].x, cz + corner[1].y)
				var sd: int = region.storey_at(cx + corner[2].x, cz + corner[2].y)
				if s1 == s and s2 == s and sd == s + 1:
					matches.append([Vector2i(cx, cz), corner[2]])
	print("[realscan] matches (two same-height cardinals + higher diagonal): ", matches.size())
	for i in range(min(8, matches.size())):
		var m = matches[i]
		print("  cell ", m[0], " higher-diagonal dir ", m[1])

	# Place the tiles (no water) so geometry reads cleanly, with debug labels.
	HeightfieldInstantiator.debug_labels = true
	var placer := HeightfieldInstantiator.new()
	placer.place_region(plan, terrain.library, terrain.terrain_parent, ccx, ccz, radius)

	var character = world.get_node("Characters/Character")
	character.set_physics_process(false)
	character.global_position = Vector3(0, -200, 0)

	# Frame the first match at eye level, looking at the higher corner.
	if matches.size() > 0:
		var cell: Vector2i = matches[0][0]
		var diag: Vector2i = matches[0][1]
		var surf: float = region.surface_height(cell.x, cell.y)
		var base: Vector3 = Vector3(cell.x * TILE, surf, cell.y * TILE)
		_focus = base + Vector3(0, 1.0, 0)
		_eye = base + Vector3(16.0, 12.0, 16.0)   # close-up to confirm labels are legible
	else:
		_focus = Vector3(ccx * TILE, region.surface_height(ccx, ccz), ccz * TILE)
		_eye = _focus + Vector3(60, 40, 60)

	cam = Camera3D.new()
	add_child(cam)
	cam.global_position = _eye
	cam.look_at(_focus, Vector3.UP)
	cam.current = true


func _process(_dt: float) -> void:
	_frame += 1
	if _frame >= WARMUP_FRAMES and not _saved:
		_saved = true
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(OUT_PATH)
		print("[realscan] saved=", ProjectSettings.globalize_path(OUT_PATH))
		get_tree().quit()
