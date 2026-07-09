# Enumerate every STEEP, NOT-FULLY-BURIED sheet triangle around the owner's
# "diagonal water skirt" site — a flat water surface has no business being
# steep except at fall faces, so whatever prints here IS the skirt (or a
# shoreline dive to inspect), with the generating cell attached. Scans BOTH
# chunks at the site and includes WET cells: round 14 proved the stripe can
# be the wet cell's own edge row, not just rim overshoot. Run:
#   Godot --headless --path . -s tests/tools/skirt_probe.gd
extends SceneTree

const SEED := 2697992464
const CHUNKS: Array = [Vector2i(-1, -6), Vector2i(0, -6), Vector2i(1, -6)]
const Z_MIN := -1140.0
const Z_MAX := -1070.0
const X_MIN := -60.0
const X_MAX := 110.0


func _init() -> void:
	var plan := HeightfieldPlan.new(SEED, 22.0, 8, "mean", 3)
	var water := WaterPlan.new(SEED, 22.0, 8)
	plan.set_water_plan(water)
	var count := 0
	for chunk: Vector2i in CHUNKS:
		var region = plan.compute_region(chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
		var field: Dictionary = WaterSurfaceBuilder.compute_field(water, chunk, region)
		var cm: Dictionary = WaterSurfaceBuilder.corner_map(field, region)
		var lo := Vector2i(chunk.x * 8, chunk.y * 8)
		for cell: Vector2i in field:
			if cell.x < lo.x or cell.x >= lo.x + 8 or cell.y < lo.y or cell.y >= lo.y + 8:
				continue
			var verts: Array = WaterSurfaceBuilder.sheet_cell_grid(cell, field, cm, water, region)
			var i := 0
			while i < verts.size():
				var a: Vector3 = verts[i].pos
				var b: Vector3 = verts[i + 1].pos
				var c: Vector3 = verts[i + 2].pos
				i += 3
				var mid: Vector3 = (a + b + c) / 3.0
				if mid.z < Z_MIN or mid.z > Z_MAX or mid.x < X_MIN or mid.x > X_MAX:
					continue
				var yspan: float = maxf(a.y, maxf(b.y, c.y)) - minf(a.y, minf(b.y, c.y))
				if yspan <= 0.25:
					continue
				# Only VISIBLE steepness matters — but visibility must be
				# sampled ACROSS the face, not at the corners: a triangle
				# whose endpoints are each buried in their own terrain column
				# still surfaces through a vertical step face BETWEEN them
				# (the round-12 lesson; a corner-only test hides exactly the
				# skirt it is hunting).
				var above := false
				var gs: Array = []
				for v in [a, b, c]:
					gs.append(TerrainSurfaceField.surface_y(region, v.x, v.z))
				var n := 5
				for p in range(n + 1):
					for q in range(n + 1 - p):
						var w0: float = float(p) / float(n)
						var w1: float = float(q) / float(n)
						var s: Vector3 = a * w0 + b * w1 + c * (1.0 - w0 - w1)
						if s.y > TerrainSurfaceField.surface_y(region, s.x, s.z) - 0.05:
							above = true
				if not above:
					continue
				count += 1
				print("STEEP cell %s wet=%s lvl=%.1f yspan=%.2f" % [
					cell, field[cell].wet, field[cell].level, yspan])
				for k in 3:
					var v: Vector3 = [a, b, c][k]
					print("   v (%.1f, %.2f, %.1f)  ground %.2f  y-g %+.2f  lvl-g %+.2f" % [
						v.x, v.y, v.z, gs[k], v.y - gs[k], field[cell].level - gs[k]])
	print("TOTAL steep visible sheet triangles at site: %d" % count)
	# Second pass: FLAT FLOATERS. The round-14 skirt is not steep — it is the
	# rim's waterline film riding AT level over ground that already dropped
	# below the waterline (nothing caps rg in [level-0.6, level-0.1)): a
	# pale flat ribbon along descending banks. Print every sheet vert over a
	# DRY cell floating clear of sub-waterline ground.
	var film := 0
	for chunk: Vector2i in CHUNKS:
		var region = plan.compute_region(chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
		var field: Dictionary = WaterSurfaceBuilder.compute_field(water, chunk, region)
		var cm: Dictionary = WaterSurfaceBuilder.corner_map(field, region)
		var lo := Vector2i(chunk.x * 8, chunk.y * 8)
		for cell: Vector2i in field:
			if cell.x < lo.x or cell.x >= lo.x + 8 or cell.y < lo.y or cell.y >= lo.y + 8:
				continue
			var ctx: Dictionary = WaterSurfaceBuilder.sheet_ctx(cell, field, cm, water, region)
			var verts: Array = WaterSurfaceBuilder.sheet_cell_grid(cell, field, cm, water, region)
			var hits: Array = []
			var banded := 0
			for v in verts:
				var p: Vector3 = v.pos
				if p.z < Z_MIN or p.z > Z_MAX or p.x < X_MIN or p.x > X_MAX:
					continue
				var pc := Vector2i(floori(p.x / 24.0), floori(p.z / 24.0))
				if field.has(pc) and field[pc].wet:
					continue
				var rg: float = TerrainSurfaceField.surface_y(region, p.x, p.z)
				# Carve-feather ground (deep dip inside a dry-flagged cell) is
				# real water bed — cell wetness is quantized, the water is not.
				var cg: float = field[pc].ground if field.has(pc) \
					else region.surface_height(pc.x, pc.y)
				if cg - rg >= 1.5:
					continue
				var lvl: float = field[cell].level
				# Fiction = static water more than a fall-height above its
				# ground (shallow margins are legitimate unflooded shelves).
				if rg < lvl - WaterSurfaceBuilder.BRIDGE_MAX and p.y > rg + 0.25:
					if not WaterSurfaceBuilder._clear_of_droops(ctx, p):
						banded += 1
						continue
					hits.append("(%.0f, %.2f, %.0f) g %.2f float %.2f" % [p.x, p.y, p.z, rg, p.y - rg])
			if banded > 0:
				print("BAND cell %s: %d droop-band floaters (fall-flank corners, issue-3 scope)" % [cell, banded])
			if not hits.is_empty():
				film += hits.size()
				print("FILM cell %s wet=%s lvl=%.1f  %d floaters, e.g. %s | %s" % [
					cell, field[cell].wet, field[cell].level, hits.size(),
					hits[0], hits[min(hits.size() - 1, 3)]])
	print("TOTAL flat film floaters at site: %d" % film)
	quit()
