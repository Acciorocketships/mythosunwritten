extends RefCounted
## Seat complete native flower boxes under the finished window's measured pane.
const CONTACTS = preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")
const MAX_PANE_OVERLAP := 0.15


static func fit(
	parts: Array[Dictionary], kit: BuildingKit, catalog: EnvironmentCatalog, openings: Dictionary
) -> int:
	var panes: Array[AABB] = []
	for part: Dictionary in parts:
		if not String(part.role).begins_with("wall."):
			continue
		var asset := CONTACTS.opening_asset(part.asset_id)
		if openings.has(asset):
			panes.append(part.transform * (openings[asset] as AABB))
	var changed := 0
	for index in range(parts.size() - 1, -1, -1):
		var part: Dictionary = parts[index]
		if part.role != &"window_box" or not part.has("window_wall_centre"):
			continue
		var centre: Vector2 = part.window_wall_centre
		var y := float(part.window_storey_y)
		var best := INF
		var pane := AABB()
		for candidate: AABB in panes:
			if candidate.position.y < y - .2 or candidate.end.y > y + kit.storey_height + .2:
				continue
			var at := candidate.get_center()
			var distance := Vector2(at.x, at.z).distance_to(centre)
			if distance > kit.module_width * .45 or distance >= best:
				continue
			best = distance
			pane = candidate
		if best == INF:
			parts.remove_at(index)
			changed += 1
			continue
		var bounds: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		var maximum := pane.position.y + pane.size.y * MAX_PANE_OVERLAP
		var drop := maxf(0.0, bounds.end.y - maximum)
		if bounds.position.y - drop < float(part.window_ground_y) + .02:
			parts.remove_at(index)
			changed += 1
		elif drop > .001:
			part.transform.origin.y -= drop
			changed += 1
	return changed
