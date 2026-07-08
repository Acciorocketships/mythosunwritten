# Offline defect probe: dump the water FIELD (levels/wet/rim), real rendered
# ground, carve amounts and waterfall ribbons around the owner's five annotated
# review spots on the pinned seed — classifies floating edges / orphan slivers /
# holes / crest gaps from data instead of in-game archaeology.
# Run: Godot --headless --path . -s tests/tools/water_field_dump.gd
extends SceneTree

const SEED := 2697992464
const TILE := 24.0
const R := 6   # half window in cells

const SPOTS := [
	["N1 static dome / uneven", Vector2(216.6, -1145.9)],
	["N2 shore glitch shard", Vector2(317.5, -1180.5)],
	["N4 isolated puddle", Vector2(99.9, -1136.5)],
]

var _regions: Dictionary = {}
var _fields: Dictionary = {}


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE + 0.5)), int(floor(p.y / TILE + 0.5)))


func _chunk_of_cell(c: Vector2i) -> Vector2i:
	return Vector2i(int(floor(float(c.x) / 8.0)), int(floor(float(c.y) / 8.0)))


func _region(plan: HeightfieldPlan, ch: Vector2i) -> HeightfieldRegion:
	if not _regions.has(ch):
		_regions[ch] = plan.compute_region(ch.x * 8 + 4, ch.y * 8 + 4, 8)
	return _regions[ch]


func _field(water: WaterPlan, plan: HeightfieldPlan, ch: Vector2i) -> Dictionary:
	if not _fields.has(ch):
		_fields[ch] = WaterSurfaceBuilder.compute_field(water, ch, _region(plan, ch))
	return _fields[ch]


func _init() -> void:
	var plan := HeightfieldPlan.new(SEED, 22.0, 8, "mean", 3)
	var water := WaterPlan.new(SEED, 22.0, 8)
	plan.set_water_plan(water)
	for spot in SPOTS:
		var cc: Vector2i = _cell_of(spot[1])
		print("\n=== %s  world %s cell %s ===" % [spot[0], spot[1], cc])
		var header := "        "
		for dx in range(-R, R + 1):
			header += "%8d" % (cc.x + dx)
		print(header)
		for dz in range(-R, R + 1):
			var row_g := "g z%-4d " % (cc.y + dz)
			var row_l := "lvl     "
			var row_c := "crv     "
			for dx in range(-R, R + 1):
				var cell := Vector2i(cc.x + dx, cc.y + dz)
				var ch := _chunk_of_cell(cell)
				var reg: HeightfieldRegion = _region(plan, ch)
				var f: Dictionary = _field(water, plan, ch)
				row_g += "%8.2f" % reg.surface_height(cell.x, cell.y)
				if f.has(cell):
					var e: Dictionary = f[cell]
					var tag := "*" if e.wet else "~"   # wet vs rim
					row_l += "%7.2f%s" % [e.level, tag]
				else:
					row_l += "%8s" % "--"
				row_c += "%8.2f" % water.carve_at_cell(cell.x, cell.y)
			print(row_g)
			print(row_l)
			print(row_c)
		# Ribbons owned by every chunk the window straddles.
		var chunks: Dictionary = {}
		for dz in range(-R, R + 1, 4):
			for dx in range(-R, R + 1, 4):
				chunks[_chunk_of_cell(Vector2i(cc.x + dx, cc.y + dz))] = true
		for ch: Vector2i in chunks:
			var ribs: Array[Dictionary] = WaterSurfaceBuilder.compute_ribbons(
				_field(water, plan, ch), ch, _region(plan, ch))
			for r in ribs:
				if r.mid.distance_to(Vector2(float(cc.x), float(cc.y)) * TILE) < R * TILE:
					print("  ribbon mid %s tan %s top %.2f bottom %.2f" %
						[r.mid, r.tangent, r.top, r.bottom])
		# Ponds near the spot: continuous outline vs the cell grid.
		var bodies: Dictionary = water.bodies_near(cc, 8)
		for pond in bodies.ponds:
			if pond.center.distance_to(spot[1]) < 300.0:
				print("  pond centre %s r %.1f surface %.2f bed %.2f" %
					[pond.center, pond.radius, pond.surface_y(), pond.bed_y()])
	quit()
