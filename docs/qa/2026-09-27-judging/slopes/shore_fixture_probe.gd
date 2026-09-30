extends SceneTree
func _init() -> void:
	var data:Dictionary=FileAccess.open("res://tests/fixtures/september15/water-drops/shore_before.bin",FileAccess.READ).get_var()
	var region := HeightfieldRegion.new(data.storeys,data.levels,data.carved)
	for z in range(-75, -68):
		var line := "z=%d: " % z
		for x in range(25, 33):
			line += "%2d " % region.storey_at(x, z)
		print(line)
	for z in [-1740.0,-1739.0,-1737.0,-1734.0]:
		var line := "Z=%.0f " % z
		for i in range(0, 8):
			line += "%.2f " % TerrainSurfaceField.surface_y(region, 684.0 + i, z)
		print(line)
	quit()
