extends SceneTree
## Envelope lift over the top of a stepping crest / dying cliff (synthetic).
func _init() -> void:
	var ENV = load("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
	for kind in ["step", "dying"]:
		var storeys := {}
		var levels := {}
		for z in range(-12, 13):
			for x in range(-12, 13):
				if kind == "step": storeys[Vector2i(x, z)] = (5 if x <= 0 else 4) if z <= 0 else 2
				else: storeys[Vector2i(x, z)] = 5 if z <= 0 else (3 if x <= 0 else 4)
				levels[Vector2i(x, z)] = 0
		var region := HeightfieldRegion.new(storeys, levels)
		var ground := func(q: Vector2) -> float: return TerrainSurfaceField.surface_y(region, q.x, q.y)
		var env = ENV.build(Rect2(-30, -10, 80, 40), ground, Callable(), 11)
		print(kind)
		for iz in [4, 8, 10, 11, 11.5, 12, 12.5, 13, 14, 16]:
			var line := "z=%5.1f " % iz
			for ix in range(-4, 26, 2):
				var q := Vector2(ix, iz)
				line += "%5.2f " % (env.at(q) - env.ground_node(q))
			print(line)
	quit()
