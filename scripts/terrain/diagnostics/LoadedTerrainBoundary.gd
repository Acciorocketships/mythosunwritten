extends RefCounted

## Main-thread committed ground only. Pending meshes and feature readiness do
## not establish coverage. Empty cells, including holes, remain fog boundaries.
const CHUNK_SIZE := 192.0

static func exit_distance(loaded: Dictionary, eye: Vector2, direction: Vector2) -> float:
	var cell := Vector2i((eye / CHUNK_SIZE).floor())
	if not loaded.has(cell): return 0.0
	if direction.length_squared() < 0.000001: return INF
	var ray := direction.normalized()
	var step := Vector2i(signf(ray.x), signf(ray.y))
	var increment := Vector2(INF, INF)
	var crossing := Vector2(INF, INF)
	for axis in 2:
		if step[axis] == 0: continue
		increment[axis] = CHUNK_SIZE / absf(ray[axis])
		var boundary := (cell[axis] + (1 if step[axis] > 0 else 0)) * CHUNK_SIZE
		crossing[axis] = (boundary - eye[axis]) / ray[axis]
	for _i in loaded.size() + 1:
		var distance := minf(crossing.x, crossing.y)
		if crossing.x <= distance:
			cell.x += step.x
			crossing.x += increment.x
		if crossing.y <= distance:
			cell.y += step.y
			crossing.y += increment.y
		if not loaded.has(cell): return maxf(0.0, distance)
	return INF
