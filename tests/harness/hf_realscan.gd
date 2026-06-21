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


func _vcode(v: String) -> String:
	if v == "ground": return "."
	if v.begins_with("water") or v.begins_with("bank"): return "~"
	v = v.replace("cliff-", "").replace("level-", "")
	if v == "interior" or v == "center": return "i"
	if v == "inner-corner": return "I"
	if v.begins_with("inner-corner"): return "J"
	if v == "corner": return "c"
	if v == "side": return "s"
	if v == "line": return "L"
	if v == "peninsula": return "p"
	if v == "island": return "o"
	return "?"


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	seed(4242)
	world = load("res://scenes/world.tscn").instantiate()
	terrain = world.get_node("Terrain")
	add_child(world)
	var plan = terrain.heightfield_plan

	# Search a moderate-storey coastal area (low tiers like the report).
	var ccx: int = 9
	var ccz: int = 9
	var radius: int = 16
	var region: HeightfieldRegion = plan.compute_region(ccx, ccz, radius)

	# Variant map over the region.
	var vmap: Dictionary = {}
	for dz in range(-radius + 1, radius):
		for dx in range(-radius + 1, radius):
			var cx: int = ccx + dx
			var cz: int = ccz + dz
			vmap[Vector2i(cx, cz)] = String(HeightfieldInstantiator.placement_for_cell(region, cx, cz)["variant_tag"])

	# Find an interior-corner ('I') tile bordering a higher tier, and an inner cell
	# that the user's signature describes (interior next to corner+side same storey).
	var card: Array = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var found: Vector2i = Vector2i(ccx, ccz)
	for dz in range(-radius + 2, radius - 1):
		for dx in range(-radius + 2, radius - 1):
			var b: Vector2i = Vector2i(ccx + dx, ccz + dz)
			if vmap.get(b, "") != "cliff-inner-corner":
				continue
			var s: int = region.storey_at(b.x, b.y)
			for c in card:
				if region.storey_at(b.x + c.x, b.y + c.y) > s:
					found = b
					break
			if found != Vector2i(ccx, ccz):
				break
		if found != Vector2i(ccx, ccz):
			break
	print("[realscan] inner-corner bordering higher tier at ", found)
	print("  storey grid then variant grid around it (cx -> across, cz down):")
	for dz in range(-3, 4):
		var srow: String = "  "
		var vrow: String = "  "
		for dx in range(-3, 4):
			var cc: Vector2i = found + Vector2i(dx, dz)
			srow += "%2d " % region.storey_at(cc.x, cc.y)
			vrow += "%-13s" % vmap.get(cc, "?").replace("cliff-", "")
		print(srow, " | ", vrow)

	# Place the tiles (no water). Labels off for a clean geometry close-up.
	HeightfieldInstantiator.debug_labels = false
	var placer := HeightfieldInstantiator.new()
	placer.place_region(plan, terrain.library, terrain.terrain_parent, ccx, ccz, radius)

	var character = world.get_node("Characters/Character")
	character.set_physics_process(false)
	character.global_position = Vector3(0, -200, 0)

	# Frame the suspect close-up.
	if found.x != 99999:
		var surf: float = region.surface_height(found.x, found.y)
		var base: Vector3 = Vector3(found.x * TILE, surf, found.y * TILE)
		_focus = base + Vector3(-6.0, -1.0, 0.0)
		_eye = base + Vector3(14.0, 6.0, 14.0)
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
