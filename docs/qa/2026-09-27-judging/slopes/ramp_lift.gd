extends SceneTree
func _init() -> void:
	var ENV = load("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
	var storeys := {}
	var levels := {}
	for z in range(-6, 7):
		for x in range(-6, 7):
			storeys[Vector2i(x, z)] = 5 if x <= 0 else 4
			levels[Vector2i(x, z)] = 0
	var region := HeightfieldRegion.new(storeys, levels)
	var ground := func(q: Vector2) -> float: return TerrainSurfaceField.surface_y(region, q.x, q.y)
	var env = ENV.build(Rect2(-30, -10, 60, 20), ground, Callable(), 7)
	for xi in range(-8, 40, 2):
		var q := Vector2(float(xi) * 0.5, 0)
		print("x=%5.1f ground=%6.3f env=%6.3f lift=%5.3f" % [q.x, env.ground_node(q), env.at(q), env.at(q) - env.ground_node(q)])
	quit()
