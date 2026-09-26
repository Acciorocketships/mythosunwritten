extends RefCounted
## Reconcile roofs across house ownership. Gaps of one module are short roofed
## lanes; a caller checks all newly covered air against the sealed public grid.
static func join(masses: Array[BuildingMass], clear: Callable = Callable()) -> int:
	var joins := 0
	var changed := true
	while changed:
		changed = false
		for ai in masses.size():
			for a: Dictionary in masses[ai].roofs:
				for bi in range(ai, masses.size()):
					for b: Dictionary in masses[bi].roofs.duplicate():
						if is_same(a, b) or a.axis != b.axis or a.eave_band != b.eave_band: continue
						var ar: Rect2i = a.rect
						var br: Rect2i = b.rect
						var axis := int(a.axis)
						var side := 1 - axis
						if ar.position[side] != br.position[side] or ar.size[side] != br.size[side]: continue
						var gap := maxi(ar.position[axis], br.position[axis]) - mini(ar.end[axis], br.end[axis])
						if gap > 1: continue
						var united := ar.merge(br)
						var allowed := true
						if clear.is_valid():
							for cell: Vector2i in BuildingMass.rect_cells(united):
								if ar.has_point(cell) or br.has_point(cell): continue
								# Both slope and gable need this air; the check deliberately
								# includes the highest possible ridge band.
								for band in range(int(a.eave_band), int(a.eave_band) + united.size[side] + 1):
									allowed = allowed and bool(clear.call(cell, band))
						if not allowed: continue
						var lower: Dictionary = a if ar.position[axis] <= br.position[axis] else b
						var upper: Dictionary = a if ar.end[axis] >= br.end[axis] else b
						a.open_min = lower.open_min
						a.extend_min = lower.extend_min
						a.open_max = upper.open_max
						a.extend_max = upper.extend_max
						a.rect = united
						for key: Vector2i in b.dormers: a.dormers[key] = true
						masses[bi].roofs.erase(b)
						joins += 1
						changed = true
						break
					if changed: break
				if changed: break
			if changed: break
	var roofs: Array[Dictionary] = []
	for mass: BuildingMass in masses: roofs.append_array(mass.roofs)
	for branch: Dictionary in roofs:
		var r: Rect2i = branch.rect
		var axis := int(branch.axis)
		var depth := r.size[1 - axis]
		for end in 2:
			var key := "min" if end == 0 else "max"
			if bool(branch["open_" + key]): continue
			var best: Dictionary = {}
			var best_gap := 2
			for host: Dictionary in roofs:
				if is_same(branch, host) or host.axis == axis or host.eave_band != branch.eave_band: continue
				var h: Rect2i = host.rect
				if h.size[axis] < depth: continue
				if r.position[1 - axis] < h.position[1 - axis] or r.end[1 - axis] > h.end[1 - axis]: continue
				var gap := r.position[axis] - h.end[axis] if end == 0 else h.position[axis] - r.end[axis]
				if gap < 0 or gap >= best_gap: continue
				var allowed := true
				if clear.is_valid() and gap > 0:
					var bridge := r
					bridge.position[axis] = h.end[axis] if end == 0 else r.end[axis]
					bridge.size[axis] = gap
					for cell: Vector2i in BuildingMass.rect_cells(bridge):
						for band in range(int(branch.eave_band), int(branch.eave_band) + depth + 1):
							allowed = allowed and bool(clear.call(cell, band))
				if allowed:
					best = host
					best_gap = gap
			if best.is_empty(): continue
			branch["open_" + key] = true
			branch["extend_" + key] = best_gap + ceili(float(depth) * 0.5)
			branch.colour = best.colour
			joins += 1
	# Dormers at a new valley would expose a half-window after trimming.
	# Keep full dormers on free slopes, use plain roof modules at junctions.
	for roof: Dictionary in roofs:
		var r: Rect2i = roof.rect
		var axis := int(roof.axis)
		for key: Vector2i in roof.dormers.keys():
			var point := Vector2.ZERO
			point[axis] = key.y
			point[1 - axis] = r.end[1 - axis] if key.x == 0 else r.position[1 - axis]
			for other: Dictionary in roofs:
				if is_same(roof, other) or other.eave_band != roof.eave_band: continue
				if Rect2(other.rect).grow(1.0).has_point(point):
					roof.dormers.erase(key)
					break
	return joins
