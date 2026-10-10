extends RefCounted
## Whole native opening panels in inhabited-town retaining faces. The sealed
## structural mass stays unchanged; windows replace masonry, not overlay it.
const RECESSES := preload("res://scripts/terrain/features/villages/kit/KitRetainingRecesses.gd")


static func fit(
	placements: Array[Dictionary],
	kit: BuildingKit,
	catalog: EnvironmentCatalog,
	air: Array[Dictionary],
	context: Dictionary
) -> int:
	var count := 0
	var obstacles := []
	var chosen: Array[Transform3D] = []
	for part: Dictionary in placements:
		obstacles.append(part.transform * catalog.descriptor(part.asset_id).measured_aabb)
		if part.get("fortified_window", false):
			chosen.append(part.transform)
	for index in placements.size():
		var wall: Dictionary = placements[index]
		if wall.get("role", &"") != &"wall.fort":
			continue
		if not String(wall.stable_id).begins_with("kit.platform-wall/"):
			continue
		var pose: Transform3D = wall.transform
		# Piers, half-courses and lintels cannot squash a full window module.
		if (
			not is_equal_approx(pose.basis.x.length(), 1.0)
			or not is_equal_approx(pose.basis.y.length(), 1.0)
			or not is_equal_approx(pose.basis.z.length(), 1.0)
		):
			continue
		var tangent := pose.basis.x.normalized()
		var spaced := true
		for previous: Transform3D in chosen:
			var delta := pose.origin - previous.origin
			if (
				pose.basis.z.dot(previous.basis.z) > .99
				and absf(delta.y) < .01
				and absf(delta.dot(pose.basis.z)) < .1
				and absf(delta.dot(tangent)) < kit.module_width * 2.0 - .01
			):
				spaced = false
				break
		if not spaced:
			continue
		var candidate := wall.duplicate()
		if not RECESSES.replace(candidate, catalog, air, context):
			continue
		var frames: Array = context.get("frames", {}).get(RECESSES.WINDOW, [])
		if frames.is_empty():
			continue
		var blocked := false
		for component: AABB in frames:
			var box: AABB = candidate.transform * component
			for other in placements.size():
				if other == index:
					continue
				if box.intersects(obstacles[other]):
					blocked = true
					break
			if blocked:
				break
		if blocked:
			continue
		wall.merge(candidate, true)
		wall["fortified_window"] = true
		chosen.append(candidate.transform)
		obstacles[index] = (
			candidate.transform * catalog.descriptor(candidate.asset_id).measured_aabb
		)
		count += 1
	return count
