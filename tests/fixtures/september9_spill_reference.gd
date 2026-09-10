extends RefCounted

## Frozen complete-domain heap reference for the optimized spill traversal.
const EPS := WaterField.EPS
const FILL_STEP := WaterField.FILL_STEP

static func solve(region, base: Vector2, side: int,
		levels: PackedFloat32Array, ground: PackedFloat32Array,
		rivers: PackedFloat32Array, step: float = FILL_STEP) -> void:
	var spills := PackedFloat64Array()
	spills.resize(levels.size())
	spills.fill(INF)
	var queue := PriorityQueue.new()
	for index in levels.size():
		var x := index % side
		var z := int(index / side)
		var outlet := INF
		if is_finite(levels[index]) and is_finite(rivers[index]):
			outlet = float(rivers[index]) + EPS
		elif x == 0 or z == 0 or x == side - 1 or z == side - 1:
			outlet = WaterField._ground_at(region, base, side, ground, x, z, step)
		if not is_finite(outlet): continue
		outlet = maxf(outlet, WaterField._ground_at(region, base, side, ground, x, z, step))
		spills[index] = outlet
		queue.push([index, outlet], outlet)
	while not queue.is_empty():
		var item: Array = queue.pop()
		var index: int = item[0]
		var height: float = item[1]
		if height != spills[index]: continue
		var x := index % side
		var z := int(index / side)
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nx: int = x + direction.x
			var nz: int = z + direction.y
			if nx < 0 or nz < 0 or nx >= side or nz >= side: continue
			var next := nz * side + nx
			if is_finite(levels[next]) and is_finite(rivers[next]): continue
			var candidate := maxf(height, WaterField._ground_at(region, base, side, ground, nx, nz, step))
			if candidate >= spills[next]: continue
			spills[next] = candidate
			queue.push([next, candidate], candidate)
	queue.free()
	for index in levels.size():
		if not is_finite(levels[index]) or is_finite(rivers[index]): continue
		var level := minf(levels[index], spills[index] - EPS)
		levels[index] = level if level > ground[index] + EPS else -INF

