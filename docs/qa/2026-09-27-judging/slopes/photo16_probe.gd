extends SceneTree
## Storeys, cliff edges and water around the September 10 photo-16 outlet.
func _init() -> void:
	var fields = preload("res://tests/fixtures/September10WaterFields.gd").get_fields()
	var region: HeightfieldRegion = fields.region(Vector2i(3, -10))
	for z in range(-75, -69):
		var line := "z=%d: " % z
		for x in range(25, 32):
			line += "%2d.%d%s " % [region.storey_at(x, z), region.level_at(x, z), "C" if TerrainSurfaceField._is_cliff_top(region, x, z) else " "]
		print(line)
	var field = fields.water(Vector2i(3, -10))
	for z in [-1745.0, -1742.0, -1739.0, -1737.0, -1734.0, -1731.0, -1728.0]:
		var line := "z=%.0f: " % z
		for i in range(-6, 16):
			var p := Vector2(678 + i, z)
			line += "%s%.1f/%.1f " % ["" if is_finite(field.level_at(p)) else "!", field.level_at(p), TerrainSurfaceField.surface_y(region, p.x, p.y)]
		print(line)
	quit()
