extends SceneTree
## Plan width of the rounded face in front of a synthetic dying cliff (the
## cliff of (0,0) toward +z dies at x = 12): per x, how far in front the
## envelope stands RAISED (0.15 m) above the ground, and the wall's drop.
func _init() -> void:
	var ENV = load("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
	for storeys_low in [3]:
		var storeys := {}
		var levels := {}
		for z in range(-12, 13):
			for x in range(-12, 13):
				storeys[Vector2i(x, z)] = 5 if z <= 0 else (storeys_low if x <= 0 else 4)
				levels[Vector2i(x, z)] = 0
		var region := HeightfieldRegion.new(storeys, levels)
		var ground := func(q: Vector2) -> float: return TerrainSurfaceField.surface_y(region, q.x, q.y)
		var env = ENV.build(Rect2(-30, -10, 80, 40), ground, Callable(), 11)
		print("drop storeys=", 5 - storeys_low)
		for xi in range(-8, 30):
			var x := xi * 0.5
			var width := 0.0
			for zi in range(0, 40):
				var q := Vector2(x, 12.0 + zi * 0.5)
				if env.at(q) - env.ground_node(q) > 0.15: width = zi * 0.5
			var drop: float = TerrainSurfaceField.surface_y_in_cell(region, x, 12.0, 0, 0) - TerrainSurfaceField.surface_y_in_cell(region, x, 12.0, 0, 1)
			print("x=%5.1f drop=%5.2f width=%4.1f %s" % [x, drop, width, "#".repeat(int(width * 2))])
	quit()
