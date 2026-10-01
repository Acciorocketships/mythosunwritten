extends SceneTree
## Re-pin scan for the live photo-16 tests (dual-grid terrain, 2026-09-30):
## the photographed geography (tests/fixtures/September10WaterFields.gd) is
## now resampled on 12 m points, so its storeys and shorelines moved.
## RIM: for each chunk, emit WaterSkin._rim over the chunk's curves and report
##   every unpaired boundary vertex's height above max(ground, water level)
##   (count, worst, worst position) -- test_september10_water_shore.
## PAIR: every (x, z) / (x, z + 3) pair on a 1 m grid, both wet, ground flat
##   between them (0.5 m samples within 1 mm), with level difference
##   reported when > 0.3 m (the connected-descent case), plus the maximum
##   difference -- test_photographed_connected_water_does_not_form_a_cliff.
## usage: godot --headless -s res://tests/harness/september10_photo16_rescan.gd -- x0 z0 x1 z1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lo := Vector2i(int(args[0]), int(args[1]))
	var hi := Vector2i(int(args[2]), int(args[3]))
	var fields := preload("res://tests/fixtures/September10WaterFields.gd").get_fields()
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var key := Vector2i(cx, cz)
			var field := fields.water(key)
			if not field.has_sources():
				continue
			var ctx := field.raw_context()
			_rim(ctx, Rect2(Vector2(key) * 192.0, Vector2.ONE * 192.0), key)
			_pairs(field, ctx, Vector2(key) * 192.0, key)
	print("PHOTO16_RESCAN_DONE")
	quit()

func _rim(ctx: Dictionary, rect: Rect2, key: Vector2i) -> void:
	var curves := WaterContour.curves(ctx, rect)
	var st: Dictionary = {"ctx": ctx, "region": ctx.region, "verts": PackedVector3Array(),
		"idx": PackedInt32Array(), "weld": {}, "normal_accum": PackedVector3Array()}
	for curve: Dictionary in curves:
		WaterSkin._rim(st, curve)
	var counts: Dictionary = {}
	for i in range(0, st.idx.size(), 3):
		for k in 3:
			var a: int = st.idx[i + k]
			var b: int = st.idx[i + (k + 1) % 3]
			var e := Vector2i(mini(a, b), maxi(a, b))
			counts[e] = counts.get(e, 0) + 1
	var seen: Dictionary = {}
	var worst := -INF
	var worst_at := Vector3.ZERO
	var over := 0
	for edge: Vector2i in counts:
		if counts[edge] != 1:
			continue
		for index in [edge.x, edge.y]:
			if seen.has(index):
				continue
			seen[index] = true
			var v: Vector3 = st.verts[index]
			var support := TerrainSurfaceField.surface_y(ctx.region, v.x, v.z)
			var level := WaterField.level_at(ctx, Vector2(v.x, v.z))
			if is_finite(level):
				support = maxf(support, level)
			if v.y - support > 0.05:
				over += 1
			if v.y - support > worst:
				worst = v.y - support
				worst_at = v
	print("RIM chunk=", key, " boundary_vertices=", seen.size(), " over_5cm=", over,
		" worst=", worst, " at=", worst_at)

func _pairs(field: WaterFieldContext, ctx: Dictionary, origin: Vector2, key: Vector2i) -> void:
	var biggest := 0.0
	var biggest_at := Vector2.ZERO
	var biggest_interior := 0.0
	var biggest_interior_at := Vector2.ZERO
	var region: HeightfieldRegion = ctx.region
	for j in 189:
		for i in 193:
			var a := origin + Vector2(i, j)
			var b := a + Vector2(0, 3)
			if not field.is_wet(a) or not field.is_wet(b):
				continue
			var g0 := TerrainSurfaceField.surface_y(region, a.x, a.y)
			var flat := true
			for s in range(1, 7):
				if absf(TerrainSurfaceField.surface_y(region, a.x, a.y + s * 0.5) - g0) > 0.001:
					flat = false
					break
			if not flat:
				continue
			var diff := absf(WaterField.level_at(ctx, a) - WaterField.level_at(ctx, b))
			var interior := _interior(field, a) and _interior(field, b)
			if diff > biggest:
				biggest = diff
				biggest_at = a
			if interior and diff > biggest_interior:
				biggest_interior = diff
				biggest_interior_at = a
			if diff > 0.3:
				print("PAIR chunk=", key, " a=", a, " diff=", diff, " ground=", g0,
					" interior=", interior)
	print("PAIR_MAX chunk=", key, " max=", biggest, " at=", biggest_at,
		" interior_max=", biggest_interior, " at=", biggest_interior_at)

## Connected water, not a shoreline taper: wet at every 1 m sample within 3 m
## along both axes.
func _interior(field: WaterFieldContext, p: Vector2) -> bool:
	for s in range(-3, 4):
		if not field.is_wet(p + Vector2(s, 0)) or not field.is_wet(p + Vector2(0, s)):
			return false
	return true
