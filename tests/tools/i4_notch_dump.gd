# h-task-4 instrument-first dump: decides H-A vs H-B for I4 ("strangely
# missing water" wedge at a wall inside a pool). Fix-independent — prints
# raw field state, no assertions, no repair.
#
# Rect per h-task-4-brief.md: x in [28,40], z in [-1116,-1104]. Prints:
#   1. Fill-lattice (FILL_STEP=6m) sample positions inside/near the rect —
#      memo ground (_ground_at equivalent, via TerrainSurfaceField directly
#      since _ground_at itself is private) vs wet/dry vs level.
#   2. Region surface_y on the WaterMesher 3m subgrid (S=3.0) across the
#      rect, alongside WaterField.level_at at the same points.
#   3. wet_cells entries (WaterMesher._attributes) for the 24m cells
#      covering the rect, with their single plane (lvl/grad/gnd_lo).
#   4. Owner's exact evidence-point checks: (36.4,-1108.7), (36.0,-1109.5),
#      (35.2,-1110.5), (34.5,-1111.5), (31.0,-1114.0).
#
# Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/tools/i4_notch_dump.gd
extends SceneTree

const SEED := 2697992464
const SITE_CHUNK := Vector2i(0, -6)


func _init() -> void:
	var plan := HeightfieldPlan.new(SEED, 22.0, 8, "mean", 3)
	var water := WaterPlan.new(SEED, 22.0, 8)
	plan.set_water_plan(water)
	var region = plan.compute_region(SITE_CHUNK.x * 8 + 4, SITE_CHUNK.y * 8 + 4, 8)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)

	print("=== I4 NOTCH DUMP seed=%d site_chunk=%s ===" % [SEED, SITE_CHUNK])
	_section_fill_lattice(ctx, region)
	_section_mesher_subgrid(ctx, region)
	_section_wet_cells(water, region)
	_section_owner_points(ctx, region)
	print("=== I4 NOTCH DUMP done ===")
	quit()


## 1. Fill-lattice dump: every FILL_STEP=6m lattice sample whose world
## position falls in/near [28,40]x[-1116,-1104]. `fill_base` + index*FILL_STEP
## is how WaterField locates lattice samples (see _build_fill/_ground_at);
## reconstruct the same indices here from ctx's own fill_base.
func _section_fill_lattice(ctx: Dictionary, region) -> void:
	print("\n--- SECTION 1: fill lattice (FILL_STEP=%.1f) samples near rect x[28,40] z[-1116,-1104] ---" % WaterField.FILL_STEP)
	var base: Vector2 = ctx.fill_base
	var levels: PackedFloat32Array = ctx.fill.levels
	var m1 := WaterField.FILL_M + 1
	var step: float = WaterField.FILL_STEP
	for j in range(0, m1):
		for i in range(0, m1):
			var p: Vector2 = base + Vector2(i, j) * step
			if p.x < 22.0 or p.x > 46.0 or p.y < -1122.0 or p.y > -1098.0:
				continue
			var lvl: float = levels[j * m1 + i]
			var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
			var wet_str: String = "DRY" if lvl == -INF else "WET"
			print("FILL: i=%d j=%d p=(%.1f,%.1f) memo_ground=%.2f level=%s [%s]" % [
				i, j, p.x, p.y, g, ("-INF" if lvl == -INF else "%.2f" % lvl), wet_str])


## 2. Mesher's own 3m subgrid (S=3.0) across the rect: region surface_y
## (the REAL ground the mesher gates rendering on) vs WaterField.level_at
## (what the fill says, bilinear over the coarse lattice) at the SAME
## points. A "MESH=DRY, FIELD-WET-NEARBY" row is the smoking gun for H-A:
## the mesher's ground is genuinely low but the field (fed by the coarse
## lattice) doesn't know it's reachable.
func _section_mesher_subgrid(ctx: Dictionary, region) -> void:
	print("\n--- SECTION 2: mesher 3m subgrid (S=%.1f) across rect ---" % WaterMesher.S)
	var x := 28.0
	while x <= 40.0:
		var z := -1116.0
		while z <= -1104.0:
			var p := Vector2(x, z)
			var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
			var lvl: float = WaterField.level_at(ctx, p)
			var wet: bool = WaterField.wet(ctx, region, p)
			print("SUB: p=(%.1f,%.1f) ground=%.2f level=%s wet=%s" % [
				p.x, p.y, g, ("-INF" if lvl == -INF else "%.2f" % lvl), str(wet)])
			z += 3.0
		x += 3.0


## 3. wet_cells for the 24m cells covering the rect — the volume-side data
## consumed by WaterSurfaceBuilder into one Area3D/plane per cell.
func _section_wet_cells(water: WaterPlan, region) -> void:
	print("\n--- SECTION 3: wet_cells for 24m cells covering rect ---")
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	if m.is_empty():
		print("WET_CELLS: build() returned empty (dry chunk)")
		return
	var wet_cells: Dictionary = m.wet_cells
	for cell: Vector2i in wet_cells:
		var cell_x0: float = cell.x * WaterField.TILE
		var cell_z0: float = cell.y * WaterField.TILE
		# only print cells whose 24m footprint overlaps the rect
		if cell_x0 > 40.0 or cell_x0 + 24.0 < 28.0 or cell_z0 > -1104.0 or cell_z0 + 24.0 < -1116.0:
			continue
		for wc: Dictionary in wet_cells[cell]:
			print("WET_CELLS: cell=%s footprint=[%.0f..%.0f, %.0f..%.0f] lvl=%.2f grad=%s gnd_lo=%.2f" % [
				cell, cell_x0, cell_x0 + 24.0, cell_z0, cell_z0 + 24.0,
				wc.lvl, wc.grad, wc.gnd_lo])


## 4. The owner's exact evidence points from the brief, cross-checked
## against BOTH the field (level_at/wet) and mesher-truth ground.
func _section_owner_points(ctx: Dictionary, region) -> void:
	print("\n--- SECTION 4: owner's evidence points ---")
	var pts := [
		Vector2(36.4, -1108.7),   # crosshair / teleport site
		Vector2(36.0, -1109.5),
		Vector2(35.2, -1110.5),
		Vector2(34.5, -1111.5),
		Vector2(31.0, -1114.0),
		Vector2(32.0, -1112.0),
		Vector2(30.0, -1110.0),
	]
	for p: Vector2 in pts:
		var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
		var lvl: float = WaterField.level_at(ctx, p)
		var wet: bool = WaterField.wet(ctx, region, p)
		print("PT: p=(%.1f,%.1f) ground=%.2f level=%s wet=%s" % [
			p.x, p.y, g, ("-INF" if lvl == -INF else "%.2f" % lvl), str(wet)])
