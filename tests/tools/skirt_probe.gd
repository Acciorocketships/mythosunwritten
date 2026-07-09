# Enumerate every STEEP sheet triangle in a probe box around the owner's
# "diagonal water skirt" site — a flat water surface has no business being
# steep except at fall faces, so whatever prints here IS the skirt, with the
# generating cell attached. Run:
#   Godot --headless --path . -s tests/tools/skirt_probe.gd
extends SceneTree

const SEED := 2697992464


func _init() -> void:
	var plan := HeightfieldPlan.new(SEED, 22.0, 8, "mean", 3)
	var water := WaterPlan.new(SEED, 22.0, 8)
	plan.set_water_plan(water)
	var chunk := Vector2i(0, -6)
	var region = plan.compute_region(chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	var field: Dictionary = WaterSurfaceBuilder.compute_field(water, chunk, region)
	var cm: Dictionary = WaterSurfaceBuilder.corner_map(field, region)
	var box := AABB(Vector3(24.0, 2.0, -1110.0), Vector3(20.0, 12.0, 26.0))
	for cell: Vector2i in field:
		if cell.x < 0 or cell.x >= 8 or cell.y < -48 or cell.y >= -40:
			continue
		var verts: Array = WaterSurfaceBuilder.sheet_cell_grid(cell, field, cm, water, region)
		var i := 0
		while i < verts.size():
			var a: Vector3 = verts[i].pos
			var b: Vector3 = verts[i + 1].pos
			var c: Vector3 = verts[i + 2].pos
			i += 3
			if not (box.has_point(a) or box.has_point(b) or box.has_point(c)):
				continue
			var yspan: float = maxf(a.y, maxf(b.y, c.y)) - minf(a.y, minf(b.y, c.y))
			if yspan <= 0.6:
				continue
			# Only VISIBLE steepness matters: skip triangles fully buried
			# under the rendered terrain.
			var above := false
			for v in [a, b, c]:
				if v.y > TerrainSurfaceField.surface_y(region, v.x, v.z) - 0.05:
					above = true
			if above:
				print("STEEP cell %s wet=%s lvl=%.1f yspan=%.2f  A%s B%s C%s"
					% [cell, field[cell].wet, field[cell].level, yspan, a, b, c])
	quit()
