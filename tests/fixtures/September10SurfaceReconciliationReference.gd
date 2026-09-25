extends RefCounted
## Frozen complete-heap operation accepted in water candidate 14.
const EPS := WaterField.EPS

static func reconcile(levels: PackedFloat32Array,
		ground: PackedFloat32Array, columns: int, step: float) -> void:
	const MAX_GRADE := 0.30
	const MIN_DEPTH := 0.10
	var rows := int(levels.size() / columns)
	var queue := PriorityQueue.new()
	for index in levels.size():
		if is_finite(levels[index]) and levels[index] > ground[index] + EPS:
			queue.push([index, levels[index]], levels[index])
	while not queue.is_empty():
		var entry: Array = queue.pop()
		var index: int = entry[0]
		if entry[1] != levels[index]: continue
		var x := index % columns
		var z := int(index / columns)
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nx := x + direction.x
			var nz := z + direction.y
			if nx < 0 or nz < 0 or nx >= columns or nz >= rows: continue
			var next := nz * columns + nx
			if not is_finite(levels[next]) or levels[next] <= ground[next] + EPS: continue
			var ceiling := maxf(ground[next] + MIN_DEPTH, levels[index] + MAX_GRADE * step)
			if ceiling >= levels[next]: continue
			levels[next] = ceiling
			queue.push([next, levels[next]], levels[next])
	queue.free()

