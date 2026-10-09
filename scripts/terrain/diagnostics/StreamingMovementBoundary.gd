extends RefCounted

## Sweep the requested horizontal displacement against committed collision.
## Substeps prevent a fast mover skipping an unloaded cell; axis trials retain
## sliding along the frontier and, crucially, movement back into loaded ground.
static func clip(from: Vector3, to: Vector3, ready: Callable) -> Vector3:
	var delta := Vector3(to.x-from.x, 0, to.z-from.z)
	var steps := maxi(1, ceili(delta.length() / 0.25))
	var step := delta / float(steps)
	var at := from
	for i in steps:
		var next := at + step
		if ready.call(next):
			at = next
		else:
			var x := at + Vector3(step.x, 0, 0)
			if ready.call(x): at = x
			var z := at + Vector3(0, 0, step.z)
			if ready.call(z): at = z
	at.y = to.y
	return at
