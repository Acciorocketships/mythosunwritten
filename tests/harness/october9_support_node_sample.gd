extends RefCounted

static func sample(ctx: Dictionary, point: Vector2, index: int) -> float:
	return preload("res://scripts/terrain/water/WaterSourceSupport.gd").sample_node(ctx, point, index)
