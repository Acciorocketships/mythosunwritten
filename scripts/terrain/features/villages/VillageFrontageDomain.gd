class_name VillageFrontageDomain
extends RefCounted

## A one-dimensional construction domain for a measured house along a street.
## Space is subtracted before a placement exists. Choosing a coordinate consumes
## that interval in every other frontage; there are no trial houses or retries.

static func subtract_obstacles(intervals: Array[Vector2], origin: Vector2,
		tangent: Vector2, local_bounds: Rect2, obstacles: Array[Rect2],
		margin: float = 0.25) -> Array[Vector2]:
	var result := intervals.duplicate()
	var normal := Vector2(-tangent.y, tangent.x)
	var house_t := projection(local_bounds, tangent)
	var house_n := projection(local_bounds, normal)
	var origin_t := origin.dot(tangent)
	var origin_n := origin.dot(normal)
	for obstacle: Rect2 in obstacles:
		var blocker_n := projection(obstacle, normal)
		if house_n.y + origin_n <= blocker_n.x - margin \
				or house_n.x + origin_n >= blocker_n.y + margin:
			continue
		var blocker_t := projection(obstacle, tangent)
		var forbidden := Vector2(blocker_t.x - margin - house_t.y - origin_t,
			blocker_t.y + margin - house_t.x - origin_t)
		result = subtract_interval(result, forbidden)
	return result

static func subtract_interval(intervals: Array[Vector2], cut: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for interval: Vector2 in intervals:
		if cut.y <= interval.x or cut.x >= interval.y:
			result.append(interval)
		else:
			if cut.x > interval.x:
				result.append(Vector2(interval.x, minf(cut.x, interval.y)))
			if cut.y < interval.y:
				result.append(Vector2(maxf(cut.y, interval.x), interval.y))
	return result

static func projection(rect: Rect2, axis: Vector2) -> Vector2:
	var centre := rect.get_center().dot(axis)
	var radius := (rect.size * axis.abs()).dot(Vector2.ONE) * 0.5
	return Vector2(centre - radius, centre + radius)

static func allocate(domains: Array[Dictionary], count: int,
		world_seed: int, substantial_fraction: float = 1.0) -> Array[Dictionary]:
	var remaining: Array[Dictionary] = []
	for domain: Dictionary in domains:
		remaining.append(domain.duplicate(true))
	var selected: Array[Dictionary] = []
	var served: Dictionary = {}
	for slot in count:
		# Rank the already-existing free space. A domain is a range of legal
		# coordinates, not a constructed candidate that can pass or fail.
		var available: Array[Dictionary] = []
		for domain: Dictionary in remaining:
			if not (domain.intervals as Array).is_empty(): available.append(domain)
		if available.is_empty(): break
		available.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			var a_served := int(served.get(a.group,0))
			var b_served := int(served.get(b.group,0))
			if a_served != b_served: return a_served < b_served
			if not is_equal_approx(float(a.area),float(b.area)):
				return float(a.area) > float(b.area) if slot < ceili(count * substantial_fraction) \
					else float(a.area) < float(b.area)
			var a_hash := Helper._mix64(world_seed ^ String(a.id).hash() ^ slot)
			var b_hash := Helper._mix64(world_seed ^ String(b.id).hash() ^ slot)
			return String(a.id) < String(b.id) if a_hash == b_hash else a_hash < b_hash)
		var chosen: Dictionary = available[0]
		var intervals: Array = chosen.intervals
		var interval: Vector2 = intervals[0]
		# Pack from one end so unused frontage remains contiguous. A midpoint
		# consumes space on both sides and can strand two sub-house gaps.
		var coordinate := minf(interval.x + 0.0001, interval.y)
		var translation: Vector2 = chosen.origin + chosen.tangent * coordinate
		var bounds: Rect2 = chosen.bounds
		bounds.position += translation
		var lot := chosen.duplicate(true)
		lot["translation"] = translation
		lot["world_bounds"] = bounds
		selected.append(lot)
		served[chosen.group] = int(served.get(chosen.group,0)) + 1
		for domain: Dictionary in remaining:
			domain.intervals = subtract_obstacles(domain.intervals, domain.origin,
				domain.tangent, domain.get("access_bounds", domain.bounds), [bounds] as Array[Rect2])
			if chosen.has("access_bounds"):
				var access: Rect2 = chosen.access_bounds
				access.position += translation
				domain.intervals = subtract_obstacles(domain.intervals, domain.origin,
					domain.tangent, domain.bounds, [access] as Array[Rect2])
			# Different construction datums cannot own overlapping ground pads.
			# Reserve their space before choosing the next coordinate.
			if chosen.has("pad") and domain.has("pad") \
					and not is_equal_approx(float(chosen.ground_y), float(domain.ground_y)):
				var pad: Rect2 = chosen.pad
				pad.position += translation
				domain.intervals = subtract_obstacles(domain.intervals, domain.origin,
					domain.tangent, domain.pad, [pad] as Array[Rect2], 0.0)
	return selected
