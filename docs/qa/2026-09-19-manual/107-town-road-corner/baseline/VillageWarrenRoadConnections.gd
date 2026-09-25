extends RefCounted

## External roads consume the completed source town's public gates. They do
## not create building frontage or an unconditional perimeter circuit.
static func topology(occupied: Rect2, contacts: Array[VillageCirculationNode],
		ground: FeatureGroundField, settlement_id: StringName) -> Dictionary:
	var bounds := occupied
	for contact: VillageCirculationNode in contacts:
		bounds = bounds.expand(contact.point)
	# The full rounded road corner stays outside the occupied construction.
	bounds = bounds.grow(PathProgram.PATH_HALF_WIDTH + PathProgram.CORNER_RADIUS)
	var domain := FeatureGroundShape.oriented_rect(bounds.get_center(),
		bounds.size * 0.5, 0.0, FeatureGroundField.NATURAL,
		VillagePlan.SURFACE_PRIORITY - 1,
		StringName("%s.street-domain" % settlement_id))
	var paths: Array[Dictionary] = []
	for handoff: Dictionary in VillageOutskirtsConstruction._world_road_handoffs(
			domain, ground, settlement_id):
		var boundary: Vector2 = handoff.points[0]
		var selected: Array[Vector2] = []
		var shortest := INF
		for contact: VillageCirculationNode in contacts:
			var projection := contact.point
			if absf(contact.outward.x) > absf(contact.outward.y):
				projection.x = bounds.end.x if contact.outward.x > 0 else bounds.position.x
			else:
				projection.y = bounds.end.y if contact.outward.y > 0 else bounds.position.y
			var route := boundary_path(boundary, projection, bounds)
			route.append(contact.point)
			var distance := 0.0
			for index in range(1, route.size()):
				distance += route[index - 1].distance_to(route[index])
			if distance < shortest - 0.001:
				shortest = distance
				selected = route
		if selected.is_empty():
			continue
		selected.push_front(handoff.points[1])
		paths.append({"points": selected, "owner": handoff.owner})
	return {"domain": domain, "paths": paths}


static func boundary_path(a: Vector2, b: Vector2, bounds: Rect2) -> Array[Vector2]:
	var perimeter := 2.0 * (bounds.size.x + bounds.size.y)
	var start := _coordinate(a, bounds)
	var finish := _coordinate(b, bounds)
	if fposmod(finish - start, perimeter) > perimeter * 0.5:
		var reverse := _clockwise(b, a, bounds)
		reverse.reverse()
		return reverse
	return _clockwise(a, b, bounds)


static func _coordinate(point: Vector2, bounds: Rect2) -> float:
	var p := point - bounds.position
	var w := bounds.size.x
	var h := bounds.size.y
	if absf(p.y) < 0.001: return p.x
	if absf(p.x - w) < 0.001: return w + p.y
	if absf(p.y - h) < 0.001: return w + h + w - p.x
	return 2.0 * w + h + h - p.y


static func _clockwise(a: Vector2, b: Vector2, bounds: Rect2) -> Array[Vector2]:
	var result: Array[Vector2] = [a]
	var perimeter := 2.0 * (bounds.size.x + bounds.size.y)
	var start := _coordinate(a, bounds)
	var distance := fposmod(_coordinate(b, bounds) - start, perimeter)
	var corners: Array[Vector2] = [bounds.position,
		Vector2(bounds.end.x, bounds.position.y), bounds.end,
		Vector2(bounds.position.x, bounds.end.y)]
	corners.sort_custom(func(p: Vector2, q: Vector2) -> bool:
		return fposmod(_coordinate(p, bounds) - start, perimeter) \
			< fposmod(_coordinate(q, bounds) - start, perimeter))
	for corner: Vector2 in corners:
		var along := fposmod(_coordinate(corner, bounds) - start, perimeter)
		if along > 0.001 and along < distance - 0.001:
			result.append(corner)
	if a.distance_to(b) > 0.001:
		result.append(b)
	return result
